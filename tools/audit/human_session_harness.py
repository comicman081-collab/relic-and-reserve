#!/usr/bin/env python3
"""Audit-only human-session JSONL validator for RELIC & RESERVE R3.

This tool is deliberately outside the production runtime.  It reads a
public-safe session log, validates the four causal checkpoints (Stages 1, 5,
8, and 10), and writes an audit report under ``qa/human_sessions``.  It never
loads or writes a save, never imports Godot, never consumes RNG, and never
mutates GameState or UI state.

The input format is intentionally categorical.  Human answers are recorded as
public reason/action categories rather than verbatim hidden-state guesses.
That keeps the log useful for causal comprehension without making internal
truth, bidder thresholds, or RNG part of the evidence file.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


PROJECT_ROOT = Path(__file__).resolve().parents[2]
QA_SESSION_ROOT = PROJECT_ROOT / "qa" / "human_sessions"
TARGET_STAGES = (1, 5, 8, 10)
ALLOWED_RECORD_TYPES = {"session_meta", "checkpoint"}
ALLOWED_META_KEYS = {
    "record_type",
    "session_id",
    "locale",
    "fresh_profile",
    "campaign_completed",
    "grand_reserve_completed",
    "ending_postgame_reached",
    "fixture",
}
ALLOWED_CHECKPOINT_KEYS = {
    "record_type",
    "session_id",
    "checkpoint_id",
    "checkpoint_role",
    "stage_id",
    "case_id",
    "investigation_action_count",
    "risk_actions",
    "repair_tool",
    "listing_preset",
    "disclosure",
    "terminal_primary_reason",
    "outcome",
    "scores",
    "stage_retry",
    "retry_changed_choice",
    "player_primary_category",
    "player_next_action",
    "player_difficulty_category",
    "portrait_legible",
    "portrait_repeated_misread",
}

PUBLIC_REASON_CODES = {
    "RESERVE_TOO_HIGH",
    "PROVENANCE_UNCERTAIN",
    "PROVENANCE_STRONG",
    "CONDITION_RISK",
    "CONDITION_GOOD",
    "DISCLOSURE_UNCLEAR",
    "DISCLOSURE_CLEAR",
    "RESERVE_MET",
    "NO_PUBLIC_BID",
}
REASON_CATEGORY = {
    "RESERVE_TOO_HIGH": "PRICE",
    "NO_PUBLIC_BID": "PRICE",
    "RESERVE_MET": "PRICE",
    "PROVENANCE_UNCERTAIN": "PROVENANCE",
    "PROVENANCE_STRONG": "PROVENANCE",
    "CONDITION_RISK": "CONDITION",
    "CONDITION_GOOD": "CONDITION",
    "DISCLOSURE_UNCLEAR": "DISCLOSURE",
    "DISCLOSURE_CLEAR": "DISCLOSURE",
}
REASON_ACTION = {
    "RESERVE_TOO_HIGH": "PRICE_OR_DISCLOSURE",
    "NO_PUBLIC_BID": "PRICE_OR_DISCLOSURE",
    "PROVENANCE_UNCERTAIN": "INVESTIGATE_OR_CITE",
    "PROVENANCE_STRONG": "KEEP_CITATION",
    "CONDITION_RISK": "REPAIR_OR_PRESERVE",
    "CONDITION_GOOD": "PRESERVE",
    "DISCLOSURE_UNCLEAR": "ADJUST_DISCLOSURE",
    "DISCLOSURE_CLEAR": "KEEP_DISCLOSURE",
    "RESERVE_MET": "KEEP_PRICE",
}
PLAYER_PRIMARY_CATEGORIES = {"PRICE", "PROVENANCE", "CONDITION", "DISCLOSURE", "UNKNOWN"}
PLAYER_NEXT_ACTIONS = {
    "PRICE",
    "DISCLOSURE",
    "INVESTIGATION",
    "CITATION",
    "REPAIR",
    "PRESERVE",
    "NONE",
    "UNKNOWN",
}
PLAYER_DIFFICULTY_CATEGORIES = {
    "INVESTIGATION",
    "PRESERVATION",
    "SALE",
    "MONEY",
    "OTHER",
    "UNKNOWN",
}
RETRY_CHOICES = {"INVESTIGATION", "REPAIR", "DISCLOSURE", "PRICE", "NONE"}
RISK_LEVELS = {"NONE", "LOW", "HIGH"}
OUTCOMES = {"SOLD", "NO_SALE"}
PRESETS = {"FAST", "BALANCED", "HIGH"}
DISCLOSURE_ALIASES = {
    "UNCERTAIN": "LIMITED",
    "LIMITED": "LIMITED",
    "LIKELY": "VERIFIED_ONLY",
    "VERIFIED_ONLY": "VERIFIED_ONLY",
    "UNCERTAIN_VERIFIED_ONLY": "VERIFIED_ONLY",
    "CERTAIN": "FULL",
    "FULL": "FULL",
}

# Unknown keys fail closed.  This second guard catches a forbidden internal
# field even if a future contributor accidentally adds it to an allowlist.
FORBIDDEN_KEY_TOKENS = (
    "truth",
    "hidden",
    "rng",
    "random",
    "seed",
    "threshold",
    "private",
    "weight",
    "maxbid",
    "max_bid",
    "undiscovered",
    "canonical",
    "basevalue",
    "truevalue",
    "authenticity",
    "internal",
    "tuning",
    "variance",
    "budget",
    "originalparts",
    "replacementparts",
)
SESSION_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
SAFE_ID_RE = re.compile(r"^[A-Za-z0-9_.-]{1,96}$")


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def error(code: str, message: str, **extra: Any) -> dict[str, Any]:
    payload = {"code": code, "message": message}
    payload.update(extra)
    return payload


def key_has_forbidden_token(key: str) -> bool:
    lowered = key.replace("-", "_").lower()
    return any(token in lowered for token in FORBIDDEN_KEY_TOKENS)


def scan_forbidden_keys(value: Any, path: str = "$", found: list[dict[str, str]] | None = None) -> list[dict[str, str]]:
    if found is None:
        found = []
    if isinstance(value, dict):
        for key, child in value.items():
            key_text = str(key)
            if key_has_forbidden_token(key_text):
                found.append({"path": f"{path}.{key_text}", "key": key_text})
            scan_forbidden_keys(child, f"{path}.{key_text}", found)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            scan_forbidden_keys(child, f"{path}[{index}]", found)
    return found


def exact_keys(record: dict[str, Any], allowed: set[str], label: str, errors: list[dict[str, Any]]) -> None:
    unknown = sorted(set(record) - allowed)
    if unknown:
        errors.append(error("UNKNOWN_FIELD", f"{label} contains non-public or unsupported fields", fields=unknown))


def require(record: dict[str, Any], key: str, label: str, errors: list[dict[str, Any]]) -> Any:
    if key not in record:
        errors.append(error("MISSING_FIELD", f"{label}.{key} is required"))
        return None
    return record[key]


def validate_session_meta(record: dict[str, Any], errors: list[dict[str, Any]], warnings: list[dict[str, Any]]) -> None:
    exact_keys(record, ALLOWED_META_KEYS, "session_meta", errors)
    if record.get("record_type") != "session_meta":
        errors.append(error("RECORD_TYPE", "first record must be session_meta"))
    session_id = require(record, "session_id", "session_meta", errors)
    if not isinstance(session_id, str) or not SESSION_ID_RE.fullmatch(session_id):
        errors.append(error("SESSION_ID", "session_meta.session_id must be a short non-sensitive identifier"))
    locale = require(record, "locale", "session_meta", errors)
    if locale not in {"KO", "EN"}:
        errors.append(error("LOCALE", "session_meta.locale must be KO or EN"))
    for key in ("fresh_profile", "campaign_completed", "grand_reserve_completed", "ending_postgame_reached", "fixture"):
        value = require(record, key, "session_meta", errors)
        if not isinstance(value, bool):
            errors.append(error("BOOLEAN", f"session_meta.{key} must be boolean"))
    if record.get("fixture") is True:
        warnings.append({"code": "FIXTURE_ONLY", "message": "fixture data is schema evidence, not human playtest evidence"})


def validate_score_axes(scores: Any, errors: list[dict[str, Any]], label: str) -> None:
    if not isinstance(scores, dict):
        errors.append(error("SCORES", f"{label}.scores must be an object with three public axes"))
        return
    if set(scores) != {"investigation", "preservation", "sale"}:
        errors.append(error("SCORE_AXES", f"{label}.scores must contain only investigation/preservation/sale"))
        return
    for axis, value in scores.items():
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)) or not 0 <= float(value) <= 100:
            errors.append(error("SCORE_VALUE", f"{label}.scores.{axis} must be finite and within 0..100"))


def validate_checkpoint(record: dict[str, Any], errors: list[dict[str, Any]], label: str) -> None:
    exact_keys(record, ALLOWED_CHECKPOINT_KEYS, label, errors)
    if record.get("record_type") != "checkpoint":
        errors.append(error("RECORD_TYPE", f"{label}.record_type must be checkpoint"))
    for key in ("session_id", "checkpoint_id", "checkpoint_role", "case_id", "repair_tool"):
        value = require(record, key, label, errors)
        if not isinstance(value, str) or not SAFE_ID_RE.fullmatch(value):
            errors.append(error("IDENTIFIER", f"{label}.{key} must be a short public identifier"))
    stage_id = require(record, "stage_id", label, errors)
    if isinstance(stage_id, bool) or not isinstance(stage_id, int) or not 1 <= stage_id <= 10:
        errors.append(error("STAGE", f"{label}.stage_id must be an integer from 1 to 10"))
    if record.get("checkpoint_role") != "causal_representative":
        errors.append(error("CHECKPOINT_ROLE", f"{label}.checkpoint_role must be causal_representative"))
    actions = require(record, "investigation_action_count", label, errors)
    if isinstance(actions, bool) or not isinstance(actions, int) or not 0 <= actions <= 100:
        errors.append(error("INVESTIGATION_COUNT", f"{label}.investigation_action_count must be an integer from 0 to 100"))
    risks = require(record, "risk_actions", label, errors)
    if not isinstance(risks, list) or any(item not in RISK_LEVELS for item in risks):
        errors.append(error("RISK_ACTIONS", f"{label}.risk_actions must be a list of NONE/LOW/HIGH"))
    preset = require(record, "listing_preset", label, errors)
    if preset not in PRESETS:
        errors.append(error("LISTING_PRESET", f"{label}.listing_preset must be FAST/BALANCED/HIGH"))
    disclosure = require(record, "disclosure", label, errors)
    if disclosure not in DISCLOSURE_ALIASES:
        errors.append(error("DISCLOSURE", f"{label}.disclosure must use the public limited/verified/full vocabulary"))
    reason = require(record, "terminal_primary_reason", label, errors)
    if reason not in PUBLIC_REASON_CODES:
        errors.append(error("TERMINAL_REASON", f"{label}.terminal_primary_reason is not in the public reason vocabulary"))
    outcome = require(record, "outcome", label, errors)
    if outcome not in OUTCOMES:
        errors.append(error("OUTCOME", f"{label}.outcome must be SOLD or NO_SALE"))
    validate_score_axes(require(record, "scores", label, errors), errors, label)
    retry = require(record, "stage_retry", label, errors)
    if not isinstance(retry, bool):
        errors.append(error("RETRY", f"{label}.stage_retry must be boolean"))
    changed = require(record, "retry_changed_choice", label, errors)
    if not isinstance(changed, list) or any(item not in RETRY_CHOICES for item in changed):
        errors.append(error("RETRY_CHOICE", f"{label}.retry_changed_choice must be a list of public choice categories"))
    if retry is True and isinstance(changed, list) and not changed:
        errors.append(error("RETRY_CHOICE_EMPTY", f"{label}.stage_retry=true requires at least one changed choice"))
    if retry is False and isinstance(changed, list) and changed:
        errors.append(error("RETRY_CHOICE_FALSE", f"{label}.stage_retry=false must have an empty retry_changed_choice list"))
    primary = require(record, "player_primary_category", label, errors)
    if primary not in PLAYER_PRIMARY_CATEGORIES:
        errors.append(error("PLAYER_CATEGORY", f"{label}.player_primary_category is not a public category"))
    action = require(record, "player_next_action", label, errors)
    if action not in PLAYER_NEXT_ACTIONS:
        errors.append(error("PLAYER_ACTION", f"{label}.player_next_action is not a public action category"))
    difficulty = require(record, "player_difficulty_category", label, errors)
    if difficulty not in PLAYER_DIFFICULTY_CATEGORIES:
        errors.append(error("PLAYER_DIFFICULTY", f"{label}.player_difficulty_category is not a public category"))
    portrait = require(record, "portrait_legible", label, errors)
    if not isinstance(portrait, bool):
        errors.append(error("PORTRAIT_LEGIBILITY", f"{label}.portrait_legible must be boolean"))
    repeated_misread = require(record, "portrait_repeated_misread", label, errors)
    if not isinstance(repeated_misread, bool):
        errors.append(error("PORTRAIT_MISREAD", f"{label}.portrait_repeated_misread must be boolean"))


def action_matches_reason(reason: str, player_action: str) -> bool:
    expected = REASON_ACTION.get(reason)
    if expected == "PRICE_OR_DISCLOSURE":
        return player_action in {"PRICE", "DISCLOSURE"}
    if expected == "INVESTIGATE_OR_CITE":
        return player_action in {"INVESTIGATION", "CITATION"}
    if expected == "KEEP_CITATION":
        return player_action in {"CITATION", "INVESTIGATION"}
    if expected == "REPAIR_OR_PRESERVE":
        return player_action in {"REPAIR", "PRESERVE"}
    if expected == "PRESERVE":
        return player_action == "PRESERVE"
    if expected == "ADJUST_DISCLOSURE":
        return player_action == "DISCLOSURE"
    if expected == "KEEP_DISCLOSURE":
        return player_action == "DISCLOSURE"
    if expected == "KEEP_PRICE":
        return player_action == "PRICE"
    return False


def validate_records(records: list[dict[str, Any]], input_path: Path) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    forbidden_keys = scan_forbidden_keys(records)
    if forbidden_keys:
        errors.append(error("FORBIDDEN_FIELD", "forbidden internal-state keys were found", fields=forbidden_keys))

    by_session: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for index, record in enumerate(records, start=1):
        if not isinstance(record, dict):
            errors.append(error("JSON_OBJECT", f"line {index} must contain a JSON object"))
            continue
        record_type = record.get("record_type")
        if record_type not in ALLOWED_RECORD_TYPES:
            errors.append(error("RECORD_TYPE", f"line {index} has unsupported record_type"))
            continue
        session_id = record.get("session_id")
        if isinstance(session_id, str):
            by_session[session_id].append(record)
        if record_type == "session_meta":
            validate_session_meta(record, errors, warnings)
        else:
            validate_checkpoint(record, errors, f"line {index}")

    session_reports: list[dict[str, Any]] = []
    for session_id, session_records in sorted(by_session.items()):
        meta_rows = [row for row in session_records if row.get("record_type") == "session_meta"]
        checkpoint_rows = [row for row in session_records if row.get("record_type") == "checkpoint"]
        session_errors: list[dict[str, Any]] = []
        if len(meta_rows) != 1:
            session_errors.append(error("META_COUNT", "each session must have exactly one session_meta record", count=len(meta_rows)))
        meta = meta_rows[0] if meta_rows else {}
        checkpoint_ids = [row.get("checkpoint_id") for row in checkpoint_rows]
        duplicate_ids = sorted(item for item, count in Counter(checkpoint_ids).items() if count > 1)
        if duplicate_ids:
            session_errors.append(error("DUPLICATE_CHECKPOINT", "checkpoint_id is duplicated; retry/restart must not duplicate a receipt observation", ids=duplicate_ids))
        target_rows = [row for row in checkpoint_rows if row.get("stage_id") in TARGET_STAGES]
        stage_counts = Counter(int(row["stage_id"]) for row in target_rows if isinstance(row.get("stage_id"), int))
        missing = [stage for stage in TARGET_STAGES if stage_counts[stage] == 0]
        repeated = {str(stage): count for stage, count in stage_counts.items() if count != 1}
        if missing:
            session_errors.append(error("TARGET_MISSING", "Stage 1/5/8/10 causal checkpoints are required exactly once", missing=missing))
        if repeated:
            session_errors.append(error("TARGET_COUNT", "Stage 1/5/8/10 causal checkpoints must occur exactly once", counts=repeated))
        ordered_stages = [row.get("stage_id") for row in target_rows]
        if ordered_stages != sorted(ordered_stages):
            session_errors.append(error("TARGET_ORDER", "causal checkpoints must be ordered Stage 1, 5, 8, 10"))
        if meta and not bool(meta.get("fixture", False)):
            for key in ("fresh_profile", "campaign_completed", "grand_reserve_completed", "ending_postgame_reached"):
                if meta.get(key) is not True:
                    session_errors.append(error("CAMPAIGN_INCOMPLETE", f"human gate requires session_meta.{key}=true", field=key))

        cause_matches = 0
        action_match_count = 0
        portrait_pass = 0
        complete_target_rows = 0
        for row in target_rows:
            reason = row.get("terminal_primary_reason")
            category_ok = row.get("player_primary_category") == REASON_CATEGORY.get(reason)
            action_ok = action_matches_reason(reason, row.get("player_next_action"))
            cause_matches += int(category_ok)
            action_match_count += int(action_ok)
            portrait_ok = row.get("portrait_legible") is True and row.get("portrait_repeated_misread") is False
            portrait_pass += int(portrait_ok)
            complete_target_rows += int(category_ok and action_ok and portrait_ok)
        denominator = len(TARGET_STAGES)
        causal_rate = round(cause_matches / denominator, 4) if denominator else 0.0
        action_rate = round(action_match_count / denominator, 4) if denominator else 0.0
        gate_threshold = math.ceil(denominator * 0.70)
        session_pass = not session_errors and len(target_rows) == denominator and cause_matches >= gate_threshold and action_match_count >= gate_threshold and portrait_pass == denominator
        if not session_pass and (cause_matches or action_match_count or portrait_pass):
            warnings.append({"code": "HUMAN_GATE_NOT_MET", "session_id": session_id, "message": "categorical answers or native portrait checks do not meet the human gate"})
        session_reports.append(
            {
                "session_id": session_id,
                "fixture": bool(meta.get("fixture", False)),
                "records": len(session_records),
                "checkpoints": len(checkpoint_rows),
                "targetStageCounts": {str(stage): stage_counts[stage] for stage in TARGET_STAGES},
                "causeMatches": cause_matches,
                "actionMatches": action_match_count,
                "causalRate": causal_rate,
                "actionRate": action_rate,
                "portraitPass": portrait_pass,
                "completeTargetRows": complete_target_rows,
                "humanCausalGate": "PASS" if cause_matches >= gate_threshold and action_match_count >= gate_threshold else "FAIL",
                "humanPortraitGate": "PASS" if portrait_pass == denominator else "FAIL",
                "sessionErrors": session_errors,
                "passed": session_pass,
            }
        )

    has_real_session = any(not report["fixture"] for report in session_reports)
    passed = not errors and bool(session_reports) and all(report["passed"] for report in session_reports)
    if not has_real_session and passed:
        status = "FIXTURE_PASS_NOT_HUMAN_EVIDENCE"
    elif passed:
        status = "HUMAN_PASS"
    else:
        status = "FAIL"
    return {
        "suite": "R3 audit-only human session harness",
        "status": status,
        "generatedAt": now_utc(),
        "input": str(input_path),
        "recordsRead": len(records),
        "sessions": session_reports,
        "errors": errors,
        "warnings": warnings,
        "publicSafeAllowlist": sorted(ALLOWED_META_KEYS | ALLOWED_CHECKPOINT_KEYS),
        "forbiddenInternalKeyTokens": list(FORBIDDEN_KEY_TOKENS),
        "humanObserved": has_real_session,
        "productionMutations": 0,
        "saveSchemaMutations": 0,
        "gameStateMutations": 0,
        "rngConsumption": 0,
        "uiMutations": 0,
        "transactionDuplicateDetection": "checkpoint_id exact-once",
        "targetStages": list(TARGET_STAGES),
        "causalAcceptance": "cause and next action each >=70% at Stage 1/5/8/10",
        "passed": passed,
    }


def load_jsonl(path: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    records: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, start=1):
            text = raw.strip()
            if not text or text.startswith("#"):
                continue
            try:
                value = json.loads(text)
            except json.JSONDecodeError as exc:
                errors.append(error("JSON_PARSE", f"line {line_number} is not valid JSON", detail=str(exc)))
                continue
            if not isinstance(value, dict):
                errors.append(error("JSON_OBJECT", f"line {line_number} must contain a JSON object"))
                continue
            records.append(value)
    return records, errors


def safe_output_path(path_text: str | None) -> Path:
    destination = (QA_SESSION_ROOT / "latest_human_session_report.json") if not path_text else Path(path_text)
    destination = destination if destination.is_absolute() else PROJECT_ROOT / destination
    resolved = destination.resolve()
    root = QA_SESSION_ROOT.resolve()
    if resolved != root and root not in resolved.parents:
        raise ValueError("output must remain under qa/human_sessions")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="read-only JSONL session file")
    parser.add_argument("--output", help="report path under qa/human_sessions")
    return parser.parse_args(list(argv))


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    input_path = Path(args.input)
    if not input_path.is_absolute():
        input_path = PROJECT_ROOT / input_path
    input_path = input_path.resolve()
    if not input_path.is_file():
        print(json.dumps({"status": "FAIL", "errors": [error("INPUT_MISSING", str(input_path))]}, ensure_ascii=False, indent=2))
        return 2
    try:
        output_path = safe_output_path(args.output)
    except ValueError as exc:
        print(json.dumps({"status": "FAIL", "errors": [error("OUTPUT_PATH", str(exc))]}, ensure_ascii=False, indent=2))
        return 2
    records, parse_errors = load_jsonl(input_path)
    report = validate_records(records, input_path)
    report["errors"] = parse_errors + report["errors"]
    if parse_errors:
        report["passed"] = False
        report["status"] = "FAIL"
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"], "passed": report["passed"], "recordsRead": report["recordsRead"], "output": str(output_path), "errors": len(report["errors"])}, ensure_ascii=False))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
