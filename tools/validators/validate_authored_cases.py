#!/usr/bin/env python3
"""Read-only integrity and schema checks for authored-v2 case definitions."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Set, Tuple


PROJECT_ROOT = Path(__file__).resolve().parents[2]
AUTHORED_ROOT = PROJECT_ROOT / "data" / "cases" / "authored_v2"
GENERATED_V1_ROOT = PROJECT_ROOT / "data" / "cases" / "generated_v1"
LOCK_PATH = PROJECT_ROOT / "data" / "cases" / "authored_v2.lock.json"
CAMPAIGN_PATH = PROJECT_ROOT / "data" / "campaign" / "campaign.json"
ARTIFACT_SPECS_PATH = PROJECT_ROOT / "data" / "artifacts" / "index.json"
EXPANSION_ARTIFACT_SPECS_PATH = PROJECT_ROOT / "data" / "artifacts" / "stage_expansion.json"
DOCUMENTS_PATH = PROJECT_ROOT / "data" / "documents" / "documents.json"
NPCS_PATH = PROJECT_ROOT / "data" / "npcs" / "npcs.json"
REFERENCE_DATABASE_PATH = PROJECT_ROOT / "data" / "reference" / "reference_database.json"
REQUIRED_SOURCE_KINDS = {
    "ARTIFACT_OBSERVATION",
    "DOCUMENT",
    "NPC_STATEMENT",
    "REFERENCE",
}
ALLOWED_RELATIONS = {"SUPPORT", "REFUTE"}
ALLOWED_RELIABILITY = {"HIGH", "MEDIUM", "LOW"}
ALLOWED_PUBLIC_CLUE_IDS = {"PROVENANCE"}
ALLOWED_OUTCOMES = {
    "masterful",
    "credible",
    "mistaken",
    "reviewed_with_mentor",
}
OUTCOME_PRECEDENCE = {
    "masterful": 0,
    "credible": 1,
    "mistaken": 2,
    "reviewed_with_mentor": 3,
}
INTERNAL_PRESENTATION_PREFIXES = (
    "src.",
    "cite.",
    "hyp.",
    "doc.",
    "res://",
    "user://",
    "artifact_",
    "document_",
    "story_artifact_",
    "period_ref_",
    "material_note_",
    "maker_history_",
)


def sha256_file(path: Path) -> str:
    """Hash authored JSON in its repository text form, not checkout line endings.

    The lock records the LF bytes committed to Git.  On Windows a checkout with
    ``core.autocrlf=true`` may present the same JSON as CRLF bytes, which must
    not be reported as an editorial alteration.  Canonicalizing only line
    endings preserves the lock's content-integrity role while making the
    validator deterministic across supported checkout platforms.
    """
    contents = path.read_bytes()
    canonical = contents.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return hashlib.sha256(canonical).hexdigest()


def load_json(path: Path, errors: List[str]) -> Any:
    try:
        with path.open("r", encoding="utf-8-sig") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{path.relative_to(PROJECT_ROOT).as_posix()}: cannot load JSON: {exc}")
        return None


def localized(value: Any, location: str, errors: List[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{location}: expected localized object with en/ko")
        return
    for language in ("en", "ko"):
        text = value.get(language)
        if not isinstance(text, str) or not text.strip():
            errors.append(f"{location}.{language}: missing player-visible text")


def presentation_text_is_internal(text: str, forbidden_values: Iterable[Any] = ()) -> bool:
    normalized = text.strip()
    lowered = normalized.lower()
    if any(lowered.startswith(prefix) for prefix in INTERNAL_PRESENTATION_PREFIXES):
        return True
    forbidden = {str(value).strip() for value in forbidden_values if str(value).strip()}
    if normalized in forbidden:
        return True
    return " " not in normalized and "_" in normalized and normalized == lowered


def localized_presentation(
    value: Any,
    location: str,
    errors: List[str],
    forbidden_values: Iterable[Any] = (),
) -> None:
    before = len(errors)
    localized(value, location, errors)
    if len(errors) != before or not isinstance(value, dict):
        return
    for language in ("en", "ko"):
        text = value.get(language)
        if isinstance(text, str) and presentation_text_is_internal(text, forbidden_values):
            errors.append(f"{location}.{language}: internal identifier is not player-visible copy")


def unique_ids(rows: Any, key: str, location: str, errors: List[str]) -> Dict[str, Dict[str, Any]]:
    indexed: Dict[str, Dict[str, Any]] = {}
    if not isinstance(rows, list):
        errors.append(f"{location}: expected array")
        return indexed
    for index, row in enumerate(rows):
        row_location = f"{location}[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{row_location}: expected object")
            continue
        identifier = row.get(key)
        if not isinstance(identifier, str) or not identifier.strip():
            errors.append(f"{row_location}.{key}: missing non-empty identifier")
            continue
        if identifier in indexed:
            errors.append(f"{row_location}.{key}: duplicate identifier {identifier!r}")
            continue
        indexed[identifier] = row
    return indexed


def iter_case_definitions(path: Path, errors: List[str]) -> Iterable[Tuple[Path, Dict[str, Any]]]:
    payload = load_json(path, errors)
    if isinstance(payload, dict):
        yield path, payload
    elif isinstance(payload, list):
        for index, row in enumerate(payload):
            if isinstance(row, dict):
                yield path, row
            else:
                errors.append(f"{path.relative_to(PROJECT_ROOT).as_posix()}[{index}]: expected object")
    elif payload is not None:
        errors.append(f"{path.relative_to(PROJECT_ROOT).as_posix()}: expected object or array")


def index_registry_rows(rows: Any, location: str, errors: List[str]) -> Dict[str, Dict[str, Any]]:
    indexed: Dict[str, Dict[str, Any]] = {}
    if not isinstance(rows, list):
        errors.append(f"{location}: expected registry array")
        return indexed
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or not isinstance(row.get("id"), str) or not row["id"]:
            errors.append(f"{location}[{index}]: expected object with non-empty id")
            continue
        identifier = row["id"]
        if identifier in indexed:
            errors.append(f"{location}[{index}]: duplicate registry id {identifier!r}")
            continue
        indexed[identifier] = row
    return indexed


def validate_outcome_rules(
    value: Any,
    location: str,
    available_groups: int,
    available_citations: int,
    errors: List[str],
) -> None:
    """Validate ordered authored outcome rules without normalizing bad input away."""
    if not isinstance(value, list) or not value:
        errors.append(f"{location}: expected non-empty ordered array")
        return

    seen_outcomes: Set[str] = set()
    previous_precedence = -1
    fallback_count = 0
    threshold_limits = {
        "minimum_independent_groups": available_groups,
        "minimum_citations": available_citations,
        # Runtime evidence weights normalize to either one or two points.
        "minimum_net_support": available_citations * 2,
    }
    for index, rule in enumerate(value):
        rule_location = f"{location}[{index}]"
        if not isinstance(rule, dict):
            errors.append(f"{rule_location}: expected object")
            continue

        outcome = rule.get("outcome")
        if outcome not in ALLOWED_OUTCOMES:
            errors.append(
                f"{rule_location}.outcome: expected one of {sorted(ALLOWED_OUTCOMES)}"
            )
            continue
        if outcome in seen_outcomes:
            errors.append(f"{rule_location}.outcome: duplicate outcome {outcome!r}")
        seen_outcomes.add(outcome)
        precedence = OUTCOME_PRECEDENCE[outcome]
        if precedence <= previous_precedence:
            errors.append(f"{rule_location}: outcome precedence is not strictly ordered")
        previous_precedence = precedence

        fallback = rule.get("fallback", False)
        if not isinstance(fallback, bool):
            errors.append(f"{rule_location}.fallback: expected boolean")
            fallback = False
        if fallback:
            fallback_count += 1
            if index != len(value) - 1:
                errors.append(f"{rule_location}: fallback must be the final rule")
            if outcome != "reviewed_with_mentor":
                errors.append(f"{rule_location}: fallback outcome must be reviewed_with_mentor")
            conditional_keys = {
                "requires_correct_hypothesis",
                "requires_all_required_sources",
                "minimum_independent_groups",
                "minimum_citations",
                "minimum_net_support",
            }
            if conditional_keys.intersection(rule):
                errors.append(f"{rule_location}: fallback must be unconditional")
            continue

        if outcome == "reviewed_with_mentor":
            errors.append(f"{rule_location}: reviewed_with_mentor is reserved for final fallback")
        expected_correctness = outcome in {"masterful", "credible"}
        actual_correctness = rule.get("requires_correct_hypothesis")
        if not isinstance(actual_correctness, bool):
            errors.append(f"{rule_location}.requires_correct_hypothesis: expected boolean")
        elif actual_correctness != expected_correctness:
            errors.append(
                f"{rule_location}.requires_correct_hypothesis: conflicts with {outcome}"
            )
        required_sources = rule.get("requires_all_required_sources", False)
        if not isinstance(required_sources, bool):
            errors.append(f"{rule_location}.requires_all_required_sources: expected boolean")

        for threshold_key, maximum in threshold_limits.items():
            threshold = rule.get(threshold_key, 0)
            if not isinstance(threshold, int) or isinstance(threshold, bool):
                errors.append(f"{rule_location}.{threshold_key}: expected integer")
            elif threshold < 0 or threshold > maximum:
                errors.append(
                    f"{rule_location}.{threshold_key}: expected integer in [0, {maximum}]"
                )

    if fallback_count != 1:
        errors.append(f"{location}: expected exactly one final unconditional fallback")


def load_runtime_registries(errors: List[str]) -> Dict[str, Dict[str, Dict[str, Any]]]:
    artifact_specs = index_registry_rows(
        load_json(ARTIFACT_SPECS_PATH, errors),
        "data/artifacts/index.json",
        errors,
    )
    # The runtime registry registers the 20 MVP expansion specs after the
    # baseline index.  Authored-v2 cases for Stages 9/10 are allowed to cite
    # those specs, so the validator must resolve the same canonical registry
    # that the game does instead of treating expansion artifacts as stale IDs.
    expansion_specs = index_registry_rows(
        load_json(EXPANSION_ARTIFACT_SPECS_PATH, errors),
        "data/artifacts/stage_expansion.json",
        errors,
    )
    for identifier, row in expansion_specs.items():
        if identifier in artifact_specs:
            errors.append(
                "data/artifacts/stage_expansion.json: duplicate artifact id "
                f"{identifier!r} also present in data/artifacts/index.json"
            )
        else:
            artifact_specs[identifier] = row
    documents = index_registry_rows(
        load_json(DOCUMENTS_PATH, errors),
        "data/documents/documents.json",
        errors,
    )
    npcs = index_registry_rows(
        load_json(NPCS_PATH, errors),
        "data/npcs/npcs.json",
        errors,
    )
    reference_payload = load_json(REFERENCE_DATABASE_PATH, errors)
    references: Dict[str, Dict[str, Any]] = {}
    if not isinstance(reference_payload, dict):
        errors.append("data/reference/reference_database.json: expected object")
    else:
        for section in ("makerModelHistories", "materialConstructionNotes", "periodReferences"):
            section_rows = index_registry_rows(
                reference_payload.get(section),
                f"data/reference/reference_database.json.{section}",
                errors,
            )
            for identifier, row in section_rows.items():
                if identifier in references:
                    errors.append(
                        "data/reference/reference_database.json: "
                        f"duplicate reference id across sections {identifier!r}"
                    )
                else:
                    references[identifier] = row
    return {
        "ARTIFACT_OBSERVATION": artifact_specs,
        "DOCUMENT": documents,
        "NPC_STATEMENT": npcs,
        "REFERENCE": references,
    }


def validate_lock(authored_files: List[Path], errors: List[str]) -> Dict[str, Dict[str, Any]]:
    lock = load_json(LOCK_PATH, errors)
    if not isinstance(lock, dict):
        return {}
    if lock.get("schema_version") != 1 or lock.get("algorithm") != "SHA-256":
        errors.append("data/cases/authored_v2.lock.json: expected schema_version=1 and algorithm=SHA-256")
    entries = unique_ids(lock.get("files"), "path", "authored_v2.lock.files", errors)
    actual_relatives = {path.relative_to(PROJECT_ROOT).as_posix() for path in authored_files}
    locked_relatives = set(entries)
    for relative in sorted(actual_relatives - locked_relatives):
        errors.append(f"{relative}: authored file is not hash-locked")
    for relative in sorted(locked_relatives - actual_relatives):
        errors.append(f"{relative}: hash lock points to a missing or non-authored file")
    authored_root_resolved = AUTHORED_ROOT.resolve()
    for relative, entry in entries.items():
        target = (PROJECT_ROOT / relative).resolve()
        try:
            target.relative_to(authored_root_resolved)
        except ValueError:
            errors.append(f"authored_v2.lock.files[{relative!r}]: path escapes authored_v2 root")
            continue
        if not target.is_file():
            continue
        expected = entry.get("sha256")
        actual = sha256_file(target)
        if not isinstance(expected, str) or expected.lower() != actual:
            errors.append(f"{relative}: SHA-256 mismatch; expected={expected!r}, actual={actual}")
    return entries


def validate_authored_case(
    case: Dict[str, Any],
    relative: str,
    global_source_refs: Set[str],
    runtime_registries: Dict[str, Dict[str, Dict[str, Any]]],
    errors: List[str],
) -> Dict[str, int]:
    prefix = relative
    if case.get("schema_version") != 2:
        errors.append(f"{prefix}.schema_version: expected 2")
    if case.get("source_kind") != "AUTHORED_V2" or case.get("active") is not True:
        errors.append(f"{prefix}: authored case must be active and source_kind=AUTHORED_V2")
    case_id = case.get("case_id")
    if not isinstance(case_id, str) or not case_id.strip():
        errors.append(f"{prefix}.case_id: missing")
    for key in ("title", "briefing", "central_question", "fiction_notice"):
        localized(case.get(key), f"{prefix}.{key}", errors)
    if not isinstance(case.get("unlock"), dict) or not case["unlock"].get("op"):
        errors.append(f"{prefix}.unlock: missing unlock rule")
    if not isinstance(case.get("risk"), dict) or not case["risk"].get("retry_policy"):
        errors.append(f"{prefix}.risk: missing retry/risk contract")

    artifact = case.get("artifact")
    if not isinstance(artifact, dict) or not artifact.get("spec_id"):
        errors.append(f"{prefix}.artifact: missing artifact binding")
        artifact = {}
    else:
        # Player display name is optional: runtime falls back to the bound
        # ArtifactSpec displayName, never its registry id.
        if "display_name" in artifact:
            localized_presentation(
                artifact.get("display_name"),
                f"{prefix}.artifact.display_name",
                errors,
                (artifact.get("spec_id"), case_id),
            )
        localized(artifact.get("player_prompt"), f"{prefix}.artifact.player_prompt", errors)

    hypotheses = unique_ids(case.get("hypotheses"), "id", f"{prefix}.hypotheses", errors)
    if len(hypotheses) < 2:
        errors.append(f"{prefix}.hypotheses: at least two competing hypotheses are required")
    for hypothesis_id, hypothesis in hypotheses.items():
        localized(hypothesis.get("label"), f"{prefix}.hypotheses[{hypothesis_id}].label", errors)
        localized(hypothesis.get("claim"), f"{prefix}.hypotheses[{hypothesis_id}].claim", errors)

    sources = unique_ids(case.get("sources"), "source_ref", f"{prefix}.sources", errors)
    source_kinds: Set[str] = set()
    source_groups: Dict[str, str] = {}
    valid_runtime_refs = 0
    for source_ref, source in sources.items():
        if source_ref in global_source_refs:
            errors.append(f"{prefix}.sources: source_ref is duplicated across case definitions: {source_ref}")
        global_source_refs.add(source_ref)
        kind = source.get("kind")
        if isinstance(kind, str):
            source_kinds.add(kind)
        runtime_ref_id = source.get("runtime_ref_id")
        if not isinstance(runtime_ref_id, str) or not runtime_ref_id:
            errors.append(f"{prefix}.sources[{source_ref}].runtime_ref_id: missing")
        elif kind not in runtime_registries:
            errors.append(f"{prefix}.sources[{source_ref}]: unknown runtime registry for kind {kind!r}")
        elif runtime_ref_id not in runtime_registries[kind]:
            errors.append(
                f"{prefix}.sources[{source_ref}].runtime_ref_id: {runtime_ref_id!r} "
                f"does not exist in the {kind} canonical registry"
            )
        else:
            valid_runtime_refs += 1
            if kind == "ARTIFACT_OBSERVATION" and runtime_ref_id != artifact.get("spec_id"):
                errors.append(
                    f"{prefix}.sources[{source_ref}].runtime_ref_id: artifact observation "
                    f"must bind case artifact spec {artifact.get('spec_id')!r}"
                )
        # Short source names are optional and fall back to a localized kind
        # label. They are deliberately separate from citation labels.
        if "label" in source:
            localized_presentation(
                source.get("label"),
                f"{prefix}.sources[{source_ref}].label",
                errors,
                (source_ref, runtime_ref_id, source.get("npc_id")),
            )
        if "short_observation" in source:
            localized_presentation(
                source.get("short_observation"),
                f"{prefix}.sources[{source_ref}].short_observation",
                errors,
                (source_ref, runtime_ref_id, source.get("citation_id")),
            )
        localized(source.get("text"), f"{prefix}.sources[{source_ref}].text", errors)
        reliability = source.get("reliability")
        if reliability is not None and reliability not in ALLOWED_RELIABILITY:
            errors.append(
                f"{prefix}.sources[{source_ref}].reliability: expected HIGH, MEDIUM, or LOW"
            )
        public_clue_id = source.get("public_clue_id", "")
        if public_clue_id is not None and not isinstance(public_clue_id, str):
            errors.append(f"{prefix}.sources[{source_ref}].public_clue_id: expected string")
        elif isinstance(public_clue_id, str) and public_clue_id and public_clue_id not in ALLOWED_PUBLIC_CLUE_IDS:
            errors.append(
                f"{prefix}.sources[{source_ref}].public_clue_id: "
                f"expected one of {sorted(ALLOWED_PUBLIC_CLUE_IDS)}"
            )
        unlock = source.get("unlock")
        if not isinstance(unlock, dict) or not unlock.get("action"):
            errors.append(f"{prefix}.sources[{source_ref}].unlock: missing discovery action")
        elif isinstance(unlock, dict):
            presentation_forbidden = (
                source_ref,
                runtime_ref_id,
                unlock.get("action"),
                unlock.get("target"),
            )
            for optional_key in ("action_label", "target_label"):
                if optional_key in unlock:
                    localized_presentation(
                        unlock.get(optional_key),
                        f"{prefix}.sources[{source_ref}].unlock.{optional_key}",
                        errors,
                        presentation_forbidden,
                    )
        if kind == "NPC_STATEMENT" and "npc_id" in source and source.get("npc_id") != runtime_ref_id:
            errors.append(
                f"{prefix}.sources[{source_ref}].npc_id: must match canonical runtime_ref_id"
            )
        risk = source.get("risk")
        if not isinstance(risk, dict) or "destroyed_by" not in risk:
            errors.append(f"{prefix}.sources[{source_ref}].risk: missing evidence-risk definition")
        elif "player_warning" in risk:
            localized(risk.get("player_warning"), f"{prefix}.sources[{source_ref}].risk.player_warning", errors)
        independence = source.get("independence")
        if not isinstance(independence, dict) or not isinstance(independence.get("group"), str) or not independence["group"]:
            errors.append(f"{prefix}.sources[{source_ref}].independence: missing group")
        else:
            source_groups[source_ref] = independence["group"]
            dependencies = independence.get("depends_on")
            if not isinstance(dependencies, list):
                errors.append(f"{prefix}.sources[{source_ref}].independence.depends_on: expected array")
    missing_kinds = REQUIRED_SOURCE_KINDS - source_kinds
    if missing_kinds:
        errors.append(f"{prefix}.sources: missing required kinds {sorted(missing_kinds)}")
    for source_ref, source in sources.items():
        independence = source.get("independence", {})
        for dependency in independence.get("depends_on", []) if isinstance(independence, dict) else []:
            if dependency not in sources:
                errors.append(f"{prefix}.sources[{source_ref}]: unknown independence dependency {dependency}")

    citations = unique_ids(case.get("citations"), "id", f"{prefix}.citations", errors)
    for citation_id, citation in citations.items():
        source_ref = citation.get("source_ref")
        if source_ref not in sources:
            errors.append(f"{prefix}.citations[{citation_id}]: unknown source_ref {source_ref!r}")
        localized(citation.get("label"), f"{prefix}.citations[{citation_id}].label", errors)
        if "locator" in citation:
            localized_presentation(
                citation.get("locator"),
                f"{prefix}.citations[{citation_id}].locator",
                errors,
                (citation_id, source_ref),
            )
    for source_ref, source in sources.items():
        citation_id = source.get("citation_id")
        if citation_id not in citations or citations.get(citation_id, {}).get("source_ref") != source_ref:
            errors.append(f"{prefix}.sources[{source_ref}]: citation_id must resolve back to this source")

    links = unique_ids(case.get("evidence_links"), "id", f"{prefix}.evidence_links", errors)
    relations: Set[str] = set()
    linked_hypotheses: Set[str] = set()
    for link_id, link in links.items():
        source_ref = link.get("source_ref")
        hypothesis_id = link.get("hypothesis_id")
        relation = link.get("relation")
        citation_id = link.get("citation_id")
        if source_ref not in sources:
            errors.append(f"{prefix}.evidence_links[{link_id}]: unknown source_ref {source_ref!r}")
        if hypothesis_id not in hypotheses:
            errors.append(f"{prefix}.evidence_links[{link_id}]: unknown hypothesis_id {hypothesis_id!r}")
        else:
            linked_hypotheses.add(hypothesis_id)
        if relation not in ALLOWED_RELATIONS:
            errors.append(f"{prefix}.evidence_links[{link_id}]: relation must be SUPPORT or REFUTE")
        else:
            relations.add(relation)
        if citation_id not in citations or citations.get(citation_id, {}).get("source_ref") != source_ref:
            errors.append(f"{prefix}.evidence_links[{link_id}]: citation does not match source")
        if link.get("independence_group") != source_groups.get(source_ref):
            errors.append(f"{prefix}.evidence_links[{link_id}]: independence_group does not match source")
        weight = link.get("weight")
        if not isinstance(weight, (int, float)) or isinstance(weight, bool) or not 0.0 <= float(weight) <= 1.0:
            errors.append(f"{prefix}.evidence_links[{link_id}].weight: expected number in [0, 1]")
    if relations != ALLOWED_RELATIONS:
        errors.append(f"{prefix}.evidence_links: both SUPPORT and REFUTE relations are required")
    for hypothesis_id in sorted(set(hypotheses) - linked_hypotheses):
        errors.append(f"{prefix}.hypotheses[{hypothesis_id}]: has no evidence link")

    resolution = case.get("resolution")
    if not isinstance(resolution, dict):
        errors.append(f"{prefix}.resolution: missing")
        resolution = {}
    winning = resolution.get("winning_hypothesis_id")
    if winning not in hypotheses or artifact.get("authoring_truth_hypothesis_id") != winning:
        errors.append(f"{prefix}.resolution: winning hypothesis must match artifact authoring truth")
    required_sources = resolution.get("required_source_refs")
    if not isinstance(required_sources, list) or not required_sources:
        errors.append(f"{prefix}.resolution.required_source_refs: expected non-empty array")
        required_sources = []
    for source_ref in required_sources:
        if source_ref not in sources:
            errors.append(f"{prefix}.resolution.required_source_refs: unknown source {source_ref!r}")
    minimum_groups = resolution.get("minimum_independent_groups")
    if not isinstance(minimum_groups, int) or isinstance(minimum_groups, bool) or minimum_groups < 2:
        errors.append(f"{prefix}.resolution.minimum_independent_groups: expected integer >= 2")
    elif minimum_groups > len(set(source_groups.values())):
        errors.append(f"{prefix}.resolution.minimum_independent_groups: exceeds available groups")
    minimum_citations = resolution.get("minimum_citations")
    if not isinstance(minimum_citations, int) or isinstance(minimum_citations, bool) or minimum_citations < 2:
        errors.append(f"{prefix}.resolution.minimum_citations: expected integer >= 2")
    elif minimum_citations > len(citations):
        errors.append(f"{prefix}.resolution.minimum_citations: exceeds available citations")
    validate_outcome_rules(
        resolution.get("outcome_rules"),
        f"{prefix}.resolution.outcome_rules",
        len(set(source_groups.values())),
        len(citations),
        errors,
    )
    localized(resolution.get("report_prompt"), f"{prefix}.resolution.report_prompt", errors)

    return {
        "hypotheses": len(hypotheses),
        "sources": len(sources),
        "citations": len(citations),
        "evidence_links": len(links),
        "independence_groups": len(set(source_groups.values())),
        "valid_runtime_refs": valid_runtime_refs,
    }


def main() -> int:
    errors: List[str] = []
    authored_files = sorted(AUTHORED_ROOT.glob("*.json")) if AUTHORED_ROOT.is_dir() else []
    if not authored_files:
        errors.append("data/cases/authored_v2: no authored case files")
    lock_entries = validate_lock(authored_files, errors)

    campaign = load_json(CAMPAIGN_PATH, errors)
    runtime_registries = load_runtime_registries(errors)
    metadata_counts: Dict[str, int] = {}
    if isinstance(campaign, dict) and isinstance(campaign.get("cases"), list):
        for row in campaign["cases"]:
            if isinstance(row, dict) and isinstance(row.get("id"), str):
                metadata_counts[row["id"]] = metadata_counts.get(row["id"], 0) + 1
    else:
        errors.append("data/campaign/campaign.json: cases metadata array is missing")

    definition_files = list(authored_files)
    if GENERATED_V1_ROOT.is_dir():
        definition_files.extend(sorted(GENERATED_V1_ROOT.glob("*.json")))
    seen_case_ids: Dict[str, str] = {}
    global_source_refs: Set[str] = set()
    authored_metrics: Dict[str, Dict[str, int]] = {}

    for path in definition_files:
        for _, case in iter_case_definitions(path, errors):
            relative = path.relative_to(PROJECT_ROOT).as_posix()
            case_id = case.get("case_id") or case.get("id")
            if not isinstance(case_id, str) or not case_id:
                errors.append(f"{relative}: case definition has no case_id")
                continue
            if case_id in seen_case_ids:
                errors.append(
                    f"{relative}: duplicate case_id {case_id!r}; first defined by {seen_case_ids[case_id]}"
                )
            else:
                seen_case_ids[case_id] = relative
            if path.parent.resolve() == AUTHORED_ROOT.resolve():
                metrics = validate_authored_case(
                    case,
                    relative,
                    global_source_refs,
                    runtime_registries,
                    errors,
                )
                authored_metrics[case_id] = metrics
                if metadata_counts.get(case_id, 0) != 1:
                    errors.append(
                        f"{relative}: expected exactly one campaign metadata row for {case_id!r}, "
                        f"found {metadata_counts.get(case_id, 0)}"
                    )
                lock_entry = lock_entries.get(relative)
                if isinstance(lock_entry, dict) and lock_entry.get("case_id") != case_id:
                    errors.append(f"{relative}: hash lock case_id does not match file")
            else:
                sources = case.get("sources", [])
                if isinstance(sources, list):
                    for source in sources:
                        if not isinstance(source, dict):
                            continue
                        source_ref = source.get("source_ref")
                        if not isinstance(source_ref, str) or not source_ref:
                            continue
                        if source_ref in global_source_refs:
                            errors.append(f"{relative}: duplicate source_ref across case definitions: {source_ref}")
                        global_source_refs.add(source_ref)

    report = {
        "validator": "authored-v2-cases",
        "project_root": str(PROJECT_ROOT),
        "authored_files": len(authored_files),
        "case_definitions": len(seen_case_ids),
        "campaign_metadata_rows": sum(metadata_counts.values()),
        "runtime_registry_counts": {
            kind: len(rows) for kind, rows in runtime_registries.items()
        },
        "authored_metrics": authored_metrics,
        "hash_lock": "PASS" if lock_entries and not any("SHA-256" in error or "hash" in error.lower() for error in errors) else "FAIL",
        "errors": errors,
        "status": "PASS" if not errors else "FAIL",
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
