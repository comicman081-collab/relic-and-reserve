"""Read-only validation for the 10-stage MVP content expansion.

This validator never generates, rewrites, or normalizes project data. It checks
the authored stage plan, artifact specs, and local visual recipes in place.
"""

from __future__ import annotations

import json
import math
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
STAGES_PATH = ROOT / "data" / "stages" / "stages.json"
EXPANSION_PATH = ROOT / "data" / "artifacts" / "stage_expansion.json"
VARIANTS_PATH = ROOT / "data" / "stage_visual_variants.json"
CAMPAIGN_PATH = ROOT / "data" / "campaign" / "campaign.json"
BASE_INDEX_PATH = ROOT / "data" / "artifacts" / "index.json"
TOOLS_PATH = ROOT / "data" / "tools" / "tools.json"
MAKERS_PATH = ROOT / "data" / "makers" / "makers.json"
MATERIALS_PATH = ROOT / "data" / "materials" / "materials.json"
DAMAGES_PATH = ROOT / "data" / "damages" / "damages.json"
GAME_STATE_PATH = ROOT / "scripts" / "game_state.gd"

EXPECTED_ARTIFACT_IDS = [f"artifact_{number:03d}" for number in range(61, 81)]
EXPECTED_VARIANT_IDS = [f"stage_variant_{number:03d}" for number in range(61, 81)]
VALID_RARITIES = {"common", "uncommon", "rare", "very_rare"}
ALLOWED_RENDER_RECIPES = {"DEFAULT", "TYPEWRITER_CIPHER", "SEXTANT", "GAUGE", "MUSIC_BOX", "OPTIC", "COMPOSITE"}
EXPECTED_SIGNATURE_RENDERING = {
    "artifact_069": {
        "baseModel": "typewriter.obj",
        "recipe": "TYPEWRITER_CIPHER",
        "trim": "cipher_keyline",
        "motif": "paired_glyphs",
        "placement": "third_key_row",
        "wearMask": "filed_stops",
    },
    "artifact_070": {
        "baseModel": "sextant.obj",
        "recipe": "SEXTANT",
        "trim": "sextant_arc",
        "motif": "degree_vernier",
        "placement": "outer_arc",
        "wearMask": "thirty_degree_sector",
    },
}
HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
FORBIDDEN_ALIAS_KEYS = {"alias", "aliases", "idAlias", "idAliases", "legacyId", "canonicalId"}
EXPECTED_PERFORMANCE_TARGETS = list(range(55, 65))
EXPECTED_GRADE_IDS = ["DEVELOPING", "TARGET", "EXPERT", "MASTER"]
EXPECTED_PUBLIC_INPUTS = ["caseOutcomeTierCounts", "scopedCaseCount", "grandReserveBalancedScore"]
EXPECTED_TUTORIAL_STEPS = ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]
EXPECTED_TUTORIAL_COMPLETIONS = [
    "EVIDENCE_DISCOVERED", "EVIDENCE_CITED", "CASE_REPORT_RESOLVED",
    "REPAIR_COMPLETED", "AUCTION_LISTED", "AUCTION_RECORDED",
]
EXPECTED_EVIDENCE_RISKS = {
    "collector_promise": {"REPAIR_TRACE": "LOW"},
    "three_cameras": {"REPAIR_TRACE": "LOW"},
    "master_camera": {"CONSTRUCTION_METHOD": "LOW"},
    "master_mechanism": {"MATERIAL": "LOW", "MECHANISM": "HIGH"},
}
EXPECTED_PRESSURE_TOOL_ROUTES = {
    "artifact_069": ["precision_screwdriver", "reference_database"],
    "artifact_070": ["cleaning_cloth", "precision_scale", "repair_toolkit"],
    "artifact_079": ["material_scanner", "uv_lamp"],
    "artifact_080": ["precision_scale", "precision_screwdriver", "reference_database"],
}
TUTORIAL_ICONS = {"artifact", "citation", "clue_generic", "objective", "report", "tool"}
PLAYER_TEXT_FIELDS = ("completion_label", "goal_label", "failure_label", "advice_label")
RAW_PLAYER_TOKEN = re.compile(r"(?:artifact|case|stage|event|bidder)_\d+|\b[A-Z]{2,}_[A-Z0-9_]+\b", re.IGNORECASE)
FORBIDDEN_TRUTH_TEXT = re.compile(r"hidden\s+truth|canonical\s+truth|authenticityTruth|correct\s+hypothesis", re.IGNORECASE)
FORBIDDEN_EXECUTION_KEYS = {"code", "script", "handler", "callback", "evaluator", "stage_override", "case_override"}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def validate() -> list[str]:
    errors: list[str] = []

    def require(condition: bool, message: str) -> None:
        if not condition:
            errors.append(message)

    for path in (
        STAGES_PATH, EXPANSION_PATH, VARIANTS_PATH, CAMPAIGN_PATH, BASE_INDEX_PATH,
        TOOLS_PATH, MAKERS_PATH, MATERIALS_PATH, DAMAGES_PATH, GAME_STATE_PATH,
    ):
        require(path.is_file(), f"missing required data file: {path.relative_to(ROOT)}")
    if errors:
        return errors

    stage_doc = load_json(STAGES_PATH)
    expansion = load_json(EXPANSION_PATH)
    variants = load_json(VARIANTS_PATH)
    campaign = load_json(CAMPAIGN_PATH)
    base_specs = load_json(BASE_INDEX_PATH)
    tools = load_json(TOOLS_PATH)
    makers = load_json(MAKERS_PATH)
    materials = load_json(MATERIALS_PATH)
    damages = load_json(DAMAGES_PATH)
    game_state_source = GAME_STATE_PATH.read_text(encoding="utf-8")

    stages = stage_doc.get("stages", []) if isinstance(stage_doc, dict) else []
    require(stage_doc.get("schemaVersion") == 1, "stages schemaVersion must be 1")
    require(len(stages) == 10, f"expected 10 stages, found {len(stages)}")
    require([row.get("stage_id") for row in stages] == list(range(1, 11)), "stage_id values must be contiguous integers 1..10")
    progression = stage_doc.get("progression", {})
    require(progression.get("stageCount") == 10, "progression.stageCount must be 10")
    require(math.isclose(float(progression.get("difficultyGrowthRate", -1)), 0.07, abs_tol=1e-12), "difficulty growth rate must be 0.07")
    require(progression.get("replayPolicy") == "cleared_stage_replay_only", "cleared stages must be replay-only from the progress screen")
    require(progression.get("progressionPolicy") == "CLEAR_CURRENT_STAGE_BEFORE_NEXT_STAGE", "next stage must require clearing the current stage")
    require(progression.get("highestClearedStagePersists") is True, "highest cleared stage must persist")
    require(progression.get("clearedStagesRemainReplayable") is True, "cleared stages must remain replayable")
    require(progression.get("finalStageEvent") == "GRAND_RESERVE", "final stage event must be GRAND_RESERVE")

    performance_contract = stage_doc.get("performance_contract", {})
    require(performance_contract.get("schema_version") == 1, "performance contract schema_version must be 1")
    require(performance_contract.get("public_score_api") == "publicStageScore", "performance contract must consume publicStageScore")
    require(performance_contract.get("score_range") == [0, 100], "performance score range must be 0..100")
    require(performance_contract.get("public_inputs") == EXPECTED_PUBLIC_INPUTS, "performance inputs must be the fixed public run-stat list")
    require(performance_contract.get("operator") == "GTE", "performance target comparison must be declarative GTE")
    require(performance_contract.get("completion_relation") == "ADVISORY_ONLY", "performance cannot become a completion/relock gate")
    grade_labels = performance_contract.get("grade_labels", {})
    require(list(grade_labels) == EXPECTED_GRADE_IDS, "grade labels must be ordered DEVELOPING/TARGET/EXPERT/MASTER")
    for grade_id in EXPECTED_GRADE_IDS:
        localized = grade_labels.get(grade_id, {})
        require(bool(localized.get("en")) and bool(localized.get("ko")), f"grade {grade_id} needs KO/EN labels")

    tutorial = stage_doc.get("tutorial_contract", {})
    require(tutorial.get("schema_version") == 1, "tutorial contract schema_version must be 1")
    require(tutorial.get("stage_id") == 1, "contextual tutorial must be scoped to Stage 1")
    require(tutorial.get("max_steps") == 6, "contextual tutorial must contain at most six steps")
    require(tutorial.get("replay_policy") == "EXPLICIT_HELP_RESET", "tutorial replay must require an explicit help reset")
    tutorial_steps = tutorial.get("steps", [])
    require(isinstance(tutorial_steps, list) and len(tutorial_steps) == 6, "tutorial must contain exactly six compact steps")
    if isinstance(tutorial_steps, list):
        require([row.get("step_id") for row in tutorial_steps if isinstance(row, dict)] == EXPECTED_TUTORIAL_STEPS, "tutorial step IDs/order are invalid")
        require([row.get("order") for row in tutorial_steps if isinstance(row, dict)] == list(range(1, 7)), "tutorial order must be contiguous 1..6")
        require([row.get("complete_when") for row in tutorial_steps if isinstance(row, dict)] == EXPECTED_TUTORIAL_COMPLETIONS, "tutorial completion events are invalid")
        for index, step in enumerate(tutorial_steps):
            if not isinstance(step, dict):
                continue
            require(
                set(step) == {"step_id", "order", "trigger", "target_ui_id", "route_ui_ids", "complete_when", "icon", "title", "text"},
                f"tutorial step {index + 1} has wrong keys",
            )
            expected_trigger = "CASE_DOSSIER_READY" if index == 0 else EXPECTED_TUTORIAL_COMPLETIONS[index - 1]
            require(step.get("trigger") == expected_trigger, f"tutorial step {index + 1} does not chain from the prior authoritative event")
            require(bool(step.get("target_ui_id")), f"tutorial step {index + 1} needs a target UI id")
            route_ui_ids = step.get("route_ui_ids", [])
            require(isinstance(route_ui_ids, list) and bool(route_ui_ids), f"tutorial step {index + 1} needs at least one UI route target")
            require(len(route_ui_ids) == len(set(route_ui_ids)), f"tutorial step {index + 1} UI route targets must be unique")
            require(step.get("target_ui_id") in route_ui_ids, f"tutorial step {index + 1} primary target must be included in its UI route")
            require(all(isinstance(target, str) and target.strip() and " " not in target for target in route_ui_ids), f"tutorial step {index + 1} has an invalid UI route target")
            require(step.get("icon") in TUTORIAL_ICONS, f"tutorial step {index + 1} uses an unknown illustrated icon")
            for field_name, maximum in (("title", 40), ("text", 90)):
                localized = step.get(field_name, {})
                require(isinstance(localized, dict), f"tutorial step {index + 1}.{field_name} must be localized")
                for locale in ("en", "ko"):
                    copy = str(localized.get(locale, ""))
                    require(bool(copy.strip()), f"tutorial step {index + 1}.{field_name}.{locale} is empty")
                    require(len(copy) <= maximum, f"tutorial step {index + 1}.{field_name}.{locale} is not compact")
                    require(not RAW_PLAYER_TOKEN.search(copy) and "_" not in copy and not FORBIDDEN_TRUTH_TEXT.search(copy), f"tutorial step {index + 1}.{field_name}.{locale} leaks a raw/private token")

    campaign_cases = campaign.get("cases", [])
    canonical_case_ids = [row.get("id") for row in campaign_cases]
    staged_case_ids = [case_id for stage in stages for case_id in stage.get("case_ids", [])]
    require(len(canonical_case_ids) == 26, f"campaign must retain 26 canonical cases, found {len(canonical_case_ids)}")
    require(staged_case_ids == canonical_case_ids, "stage case assignments must be one canonical, contiguous, order-preserving partition")
    require(len(set(staged_case_ids)) == 26, "every campaign case must be assigned exactly once")
    campaign_act_by_case = {row.get("id"): row.get("act") for row in campaign_cases}
    require(all(campaign_act_by_case.get(case_id) for case_id in staged_case_ids), "stage assignment cannot replace or erase campaign act membership")
    campaign_case_by_id = {row.get("id"): row for row in campaign_cases}
    authored_risk_case_ids = {row.get("id") for row in campaign_cases if "evidenceRisks" in row}
    require(authored_risk_case_ids == set(EXPECTED_EVIDENCE_RISKS), "only the contracted Stage 5/10 fallback cases may author evidenceRisks")
    for case_id, expected_risks in EXPECTED_EVIDENCE_RISKS.items():
        profile = campaign_case_by_id.get(case_id, {}).get("evidenceRisks", {})
        require(isinstance(profile, dict), f"{case_id}.evidenceRisks must be an object")
        if not isinstance(profile, dict):
            continue
        require(set(profile) == set(expected_risks), f"{case_id}.evidenceRisks must keep the sparse contracted evidence IDs")
        for evidence_key, expected_level in expected_risks.items():
            risk = profile.get(evidence_key, {})
            require(isinstance(risk, dict) and set(risk) == {"level", "warning"}, f"{case_id}.{evidence_key} risk needs only level and localized warning")
            if not isinstance(risk, dict):
                continue
            require(risk.get("level") == expected_level, f"{case_id}.{evidence_key} risk must remain {expected_level}")
            warning = risk.get("warning", {})
            require(isinstance(warning, dict) and set(warning) == {"en", "ko"}, f"{case_id}.{evidence_key} warning must contain exact EN/KO keys")
            if isinstance(warning, dict):
                for locale in ("en", "ko"):
                    copy = str(warning.get(locale, ""))
                    require(bool(copy.strip()) and len(copy) <= 80, f"{case_id}.{evidence_key}.{locale} warning must be compact and non-empty")
                    require(not RAW_PLAYER_TOKEN.search(copy) and "_" not in copy and not FORBIDDEN_TRUTH_TEXT.search(copy), f"{case_id}.{evidence_key}.{locale} warning leaks a raw/private token")
    require('story_case.get("evidenceRisks", {})' in game_state_source, "fallback case runtime must consume the generic evidenceRisks authoring contract")

    introduced_ids: list[str] = []
    performance_targets: list[int] = []
    player_text_leaks: list[str] = []
    per_stage_execution_keys: list[str] = []
    for stage_number, stage in enumerate(stages, start=1):
        stage_artifacts = stage.get("introduced_artifact_ids", [])
        require(len(stage_artifacts) == 2, f"stage {stage_number} must introduce exactly two artifacts")
        introduced_ids.extend(stage_artifacts)
        expected_multiplier = math.pow(1.07, stage_number - 1)
        actual_multiplier = float(stage.get("difficulty_multiplier", -1.0))
        require(
            math.isclose(actual_multiplier, expected_multiplier, rel_tol=1e-12, abs_tol=1e-12),
            f"stage {stage_number} multiplier {actual_multiplier} != pow(1.07, {stage_number - 1})",
        )
        require(
            bool(stage.get("includes_grand_reserve", False)) == (stage_number == 10),
            f"only stage 10 may include Grand Reserve (stage {stage_number})",
        )
        title = stage.get("title", {})
        require(bool(title.get("en")) and bool(title.get("ko")), f"stage {stage_number} needs localized title text")
        completion = stage.get("completion_contract", {})
        require(
            set(completion) == {"case_scope", "grand_reserve_rule", "unlock_on_completion", "performance_affects_unlock", "completion_label"},
            f"stage {stage_number} completion contract has wrong keys",
        )
        require(completion.get("case_scope") == "ALL_STAGE_CASES", f"stage {stage_number} must complete all scoped cases")
        require(completion.get("grand_reserve_rule") == "FOLLOW_STAGE_FLAG", f"stage {stage_number} must follow the existing Grand Reserve flag")
        require(completion.get("unlock_on_completion") is True, f"stage {stage_number} completion must unlock progression")
        require(completion.get("performance_affects_unlock") is False, f"stage {stage_number} performance must not gate or relock progression")

        performance = stage.get("performance_target", {})
        require(
            set(performance) == {"metric_id", "operator", "target_score", "goal_label", "failure_label", "advice_label", "grade_thresholds"},
            f"stage {stage_number} performance target has wrong keys",
        )
        require(performance.get("metric_id") == "public_stage_score", f"stage {stage_number} must use the generic public stage score")
        require(performance.get("operator") == "GTE", f"stage {stage_number} target must use the generic GTE comparator")
        target_score = performance.get("target_score")
        require(isinstance(target_score, int), f"stage {stage_number} target_score must be an integer")
        if isinstance(target_score, int):
            performance_targets.append(target_score)
            require(0 <= target_score <= 78, f"stage {stage_number} target must be achievable without a perfect run")

        for field_name in PLAYER_TEXT_FIELDS:
            localized = completion.get(field_name, {}) if field_name == "completion_label" else performance.get(field_name, {})
            require(isinstance(localized, dict), f"stage {stage_number}.{field_name} must be localized")
            for locale in ("en", "ko"):
                text = str(localized.get(locale, ""))
                require(bool(text.strip()), f"stage {stage_number}.{field_name}.{locale} is empty")
                require(len(text) <= 80, f"stage {stage_number}.{field_name}.{locale} is not compact")
                if RAW_PLAYER_TOKEN.search(text) or "_" in text or FORBIDDEN_TRUTH_TEXT.search(text):
                    player_text_leaks.append(f"stage {stage_number}.{field_name}.{locale}")

        thresholds = performance.get("grade_thresholds", [])
        require(isinstance(thresholds, list) and len(thresholds) == 4, f"stage {stage_number} needs exactly four grade thresholds")
        grade_ids = [row.get("grade_id") for row in thresholds if isinstance(row, dict)]
        grade_scores = [row.get("min_score") for row in thresholds if isinstance(row, dict)]
        require(grade_ids == EXPECTED_GRADE_IDS, f"stage {stage_number} grade threshold IDs/order are invalid")
        require(all(isinstance(value, int) for value in grade_scores), f"stage {stage_number} grade scores must be integers")
        if len(grade_scores) == 4 and all(isinstance(value, int) for value in grade_scores):
            require(grade_scores == sorted(set(grade_scores)), f"stage {stage_number} grade thresholds must be unique ascending values")
            require(grade_scores[0] == 0 and grade_scores[-1] <= 100, f"stage {stage_number} grade thresholds must cover a valid 0..100 score")
            require(isinstance(target_score, int) and grade_scores[1] == target_score, f"stage {stage_number} TARGET grade must equal target_score")

        def find_execution_keys(value: Any, path: str) -> None:
            if isinstance(value, dict):
                for key, child in value.items():
                    if key in FORBIDDEN_EXECUTION_KEYS:
                        per_stage_execution_keys.append(f"{path}.{key}")
                    find_execution_keys(child, f"{path}.{key}")
            elif isinstance(value, list):
                for index, child in enumerate(value):
                    find_execution_keys(child, f"{path}[{index}]")

        find_execution_keys({"completion": completion, "performance": performance}, f"stage[{stage_number}]")
    require(performance_targets == EXPECTED_PERFORMANCE_TARGETS, "performance targets must be exact, strictly increasing 55..64")
    require(not player_text_leaks, f"player-facing performance text leaks raw IDs/tokens or truth data: {player_text_leaks}")
    require(not per_stage_execution_keys, f"per-stage executable/code override keys are forbidden: {per_stage_execution_keys}")
    require(introduced_ids == EXPECTED_ARTIFACT_IDS, "stage artifact assignments must be exact ordered IDs artifact_061..artifact_080")
    require(len(set(introduced_ids)) == 20, "introduced artifact IDs must not repeat")

    require(isinstance(expansion, list), "stage_expansion.json must be an array")
    require(len(expansion) == 20, f"expected 20 expansion artifact specs, found {len(expansion)}")
    expansion_ids = [row.get("id") for row in expansion]
    require(expansion_ids == EXPECTED_ARTIFACT_IDS, "expansion IDs must be exact ordered IDs artifact_061..artifact_080")
    base_ids = {row.get("id") for row in base_specs}
    require(base_ids.isdisjoint(expansion_ids), "expansion IDs must not alias or collide with the original artifact catalog")
    expansion_by_id = {row.get("id"): row for row in expansion}
    for artifact_id, expected_tools in EXPECTED_PRESSURE_TOOL_ROUTES.items():
        actual_tools = expansion_by_id.get(artifact_id, {}).get("repairProfile", {}).get("requiredTools", [])
        require(actual_tools == expected_tools, f"{artifact_id} must keep the contracted repair-tool route {expected_tools}")
    require(
        set(EXPECTED_PRESSURE_TOOL_ROUTES["artifact_069"]).isdisjoint(EXPECTED_PRESSURE_TOOL_ROUTES["artifact_070"]),
        "Stage 5 contracted repair-tool routes must be disjoint",
    )
    require(
        set(EXPECTED_PRESSURE_TOOL_ROUTES["artifact_079"]).isdisjoint(EXPECTED_PRESSURE_TOOL_ROUTES["artifact_080"]),
        "Stage 10 contracted repair-tool routes must be disjoint",
    )

    required_spec_fields = {
        "id", "displayName", "category", "maker", "model", "modelName", "era", "baseValue", "rarity",
        "materialSet", "compatibleDamages", "possibleFaults", "possibleClues", "restorationProfile",
        "collectorTags", "visualVariant", "baseModel", "inspectionObservable", "repairProfile", "auctionProfile",
    }
    installed_tool_ids = {row.get("id") for row in tools}
    maker_ids = {row.get("makerId") for row in makers}
    material_ids = {row.get("id") for row in materials}
    damage_ids = {row.get("id") for row in damages}
    uniqueness_fields = [
        "displayName", "category", "maker", "model", "era", "baseValue", "materialSet", "compatibleDamages",
        "possibleFaults", "possibleClues", "restorationProfile", "collectorTags", "visualVariant", "baseModel",
        "inspectionObservable", "repairProfile", "auctionProfile",
    ]
    for field in uniqueness_fields:
        values = [canonical(row.get(field)) for row in expansion]
        require(len(values) == len(set(values)), f"artifact field/profile must be distinct across all 20 specs: {field}")

    complete_profile_blobs: list[str] = []
    require("func repairable_damage_types(artifact: Dictionary) -> Array:" in game_state_source, "runtime must expose the generic repairable damage contract")
    require('profile.get("repairableDamages", [])' in game_state_source, "runtime repair contract must honor explicit repairableDamages")
    require('return artifact.get("possibleFaults", []).duplicate()' in game_state_source, "runtime repair contract must fall back to authored possibleFaults")
    require("authored_repair_types := repairable_damage_types(artifact)" in game_state_source, "Repair action must consume the generic repairable damage contract")
    repair_reachable_artifact_count = 0
    for spec in expansion:
        artifact_id = str(spec.get("id", "<missing>"))
        require(required_spec_fields.issubset(spec), f"{artifact_id} missing fields: {sorted(required_spec_fields - set(spec))}")
        require(not (FORBIDDEN_ALIAS_KEYS & set(spec)), f"{artifact_id} contains a forbidden ID alias key")
        require(spec.get("model") == spec.get("modelName"), f"{artifact_id} compatibility modelName must mirror authored model")
        require(spec.get("maker") in maker_ids, f"{artifact_id} references an unknown maker")
        require(spec.get("rarity") in VALID_RARITIES, f"{artifact_id} has unsupported rarity {spec.get('rarity')}")
        require(isinstance(spec.get("baseValue"), int) and spec.get("baseValue", 0) > 0, f"{artifact_id} needs a positive integer baseValue")
        for field in ("materialSet", "compatibleDamages", "possibleFaults", "possibleClues", "collectorTags"):
            value = spec.get(field, [])
            require(isinstance(value, list) and bool(value), f"{artifact_id}.{field} must be a non-empty array")
            require(len(value) == len(set(value)), f"{artifact_id}.{field} cannot contain duplicates")
        require(set(spec.get("materialSet", [])).issubset(material_ids), f"{artifact_id} references an unknown material")
        require(set(spec.get("compatibleDamages", [])).issubset(damage_ids), f"{artifact_id} references an unknown damage type")
        require(set(spec.get("possibleFaults", [])).issubset(set(spec.get("compatibleDamages", []))), f"{artifact_id} possible faults must be compatible damages")

        observable = spec.get("inspectionObservable", {})
        require(len(str(observable.get("en", ""))) >= 60, f"{artifact_id} needs a meaningful English inspection observable")
        require(len(str(observable.get("ko", ""))) >= 30, f"{artifact_id} needs a meaningful Korean inspection observable")

        restoration = spec.get("restorationProfile", {})
        require(set(restoration) == {"cleaning", "repair", "patinaRisk"}, f"{artifact_id} restorationProfile has wrong keys")
        require(all(0.0 <= float(restoration.get(key, -1)) <= 1.0 for key in restoration), f"{artifact_id} restoration values must be within 0..1")

        repair = spec.get("repairProfile", {})
        repair_tools = repair.get("requiredTools", [])
        require(bool(repair_tools) and set(repair_tools).issubset(installed_tool_ids), f"{artifact_id} repairProfile references unavailable tools")
        explicit_repairables = repair.get("repairableDamages", [])
        require(isinstance(explicit_repairables, list), f"{artifact_id}.repairableDamages must be an array when present")
        if explicit_repairables:
            require(set(explicit_repairables).issubset(damage_ids), f"{artifact_id}.repairableDamages references an unknown damage type")
            require(set(explicit_repairables).issubset(set(spec.get("compatibleDamages", []))), f"{artifact_id}.repairableDamages must be compatible damages")
        runtime_repairables = explicit_repairables if explicit_repairables else spec.get("possibleFaults", [])
        reachable_faults = set(spec.get("possibleFaults", [])) & set(runtime_repairables)
        require(bool(reachable_faults), f"{artifact_id} has no possible fault reachable by the runtime Repair action")
        if reachable_faults:
            repair_reachable_artifact_count += 1
        require(float(repair.get("toleranceMm", 0.0)) > 0.0, f"{artifact_id} repair tolerance must be positive")
        require(float(repair.get("costPressure", 0.0)) >= 1.0, f"{artifact_id} repair cost pressure must be at least 1.0")
        tradeoff = repair.get("interventionTradeoff", {})
        require(len(str(tradeoff.get("en", ""))) >= 60 and len(str(tradeoff.get("ko", ""))) >= 30, f"{artifact_id} needs a meaningful localized intervention tradeoff")

        auction = spec.get("auctionProfile", {})
        require(bool(auction.get("preferredBidderTags")), f"{artifact_id} needs preferred bidder tags")
        for field in ("conditionSensitivity", "disclosureScrutiny", "provenanceScrutiny"):
            require(0.0 <= float(auction.get(field, -1.0)) <= 1.0, f"{artifact_id}.{field} must be within 0..1")
        strategy = auction.get("reserveStrategy", {})
        require(bool(strategy.get("mode")), f"{artifact_id} needs a named reserve strategy")
        require(0.0 < float(strategy.get("appraisalRatio", 0.0)) <= 1.0, f"{artifact_id} reserve appraisal ratio must be within 0..1")
        complete_profile_blobs.append(canonical({"restoration": restoration, "repair": repair, "auction": auction}))
    require(len(complete_profile_blobs) == len(set(complete_profile_blobs)), "no two artifacts may share an identical restoration/repair/auction profile blob")

    require(isinstance(variants, list), "stage_visual_variants.json must be an array")
    require(len(variants) == 20, f"expected 20 stage visual variants, found {len(variants)}")
    variant_ids = [row.get("id") for row in variants]
    require(variant_ids == EXPECTED_VARIANT_IDS, "visual variant IDs must be exact ordered IDs stage_variant_061..stage_variant_080")
    require([row.get("artifactId") for row in variants] == EXPECTED_ARTIFACT_IDS, "visual variants must map one-to-one to expansion artifacts")
    require([row.get("visualVariant") for row in expansion] == variant_ids, "artifact visualVariant references must match visual variant rows")

    for field in ("signature", "baseMesh", "palette", "scale", "trim", "detail"):
        values = [canonical(row.get(field)) for row in variants]
        require(len(values) == len(set(values)), f"every visual variant must have a distinct {field}")
    for variant, spec in zip(variants, expansion, strict=True):
        variant_id = str(variant.get("id", "<missing>"))
        require(not (FORBIDDEN_ALIAS_KEYS & set(variant)), f"{variant_id} contains a forbidden ID alias key")
        expected_mesh = f"res://assets/artifacts/{spec.get('baseModel', '')}"
        require(variant.get("baseMesh") == expected_mesh, f"{variant_id} baseMesh must match its artifact baseModel")
        for path_field in ("baseMesh", "materialPath"):
            resource_path = str(variant.get(path_field, ""))
            require(resource_path.startswith("res://"), f"{variant_id}.{path_field} must be a local res:// path")
            require((ROOT / resource_path.removeprefix("res://")).is_file(), f"{variant_id}.{path_field} does not exist locally")
        trim_path = str(variant.get("trim", {}).get("materialPath", ""))
        require(trim_path.startswith("res://") and (ROOT / trim_path.removeprefix("res://")).is_file(), f"{variant_id} trim material does not exist locally")
        palette = variant.get("palette", {})
        require(set(palette) == {"primary", "secondary", "accent"}, f"{variant_id} palette must have primary, secondary, and accent")
        require(all(HEX_COLOR.fullmatch(str(color)) for color in palette.values()), f"{variant_id} palette colors must be #RRGGBB")
        scale = variant.get("scale", [])
        require(len(scale) == 3 and all(float(axis) > 0.0 for axis in scale), f"{variant_id} needs a positive three-axis scale")
        require(set(variant.get("trim", {})) == {"shape", "color", "materialPath"}, f"{variant_id} trim recipe has wrong keys")
        require(set(variant.get("detail", {})) == {"motif", "placement", "wearMask"}, f"{variant_id} detail recipe has wrong keys")
        render_recipe = str(variant.get("renderRecipe", "DEFAULT")).strip().upper() or "DEFAULT"
        require(render_recipe in ALLOWED_RENDER_RECIPES, f"{variant_id} uses unknown renderRecipe {render_recipe}")

        artifact_id = str(spec.get("id", ""))
        if artifact_id in EXPECTED_SIGNATURE_RENDERING:
            expected = EXPECTED_SIGNATURE_RENDERING[artifact_id]
            require(spec.get("baseModel") == expected["baseModel"], f"{artifact_id} must use its recognizable {expected['baseModel']} silhouette")
            require(render_recipe == expected["recipe"], f"{variant_id} must use explicit {expected['recipe']} rendering")
            require(variant.get("trim", {}).get("shape") == expected["trim"], f"{variant_id} signature trim must remain visible")
            require(variant.get("detail", {}).get("motif") == expected["motif"], f"{variant_id} signature motif must remain visible")
            require(variant.get("detail", {}).get("placement") == expected["placement"], f"{variant_id} signature placement must remain visible")
            require(variant.get("detail", {}).get("wearMask") == expected["wearMask"], f"{variant_id} signature wear mask must remain visible")

    require(expansion_by_id["artifact_070"].get("baseModel") != "compass.obj", "artifact_070 must not regress to a compass silhouette")

    return errors


def main() -> int:
    errors = validate()
    summary = {
        "validator": "R3 10-stage MVP content",
        "readOnly": True,
        "stageCount": 10,
        "campaignCaseCount": 26,
        "expansionArtifactCount": 20,
        "visualVariantCount": 20,
        "performanceTargetCount": 10,
        "performanceTargets": EXPECTED_PERFORMANCE_TARGETS,
        "performanceUnlockPolicy": "ADVISORY_ONLY",
        "contextualTutorialStepCount": len(EXPECTED_TUTORIAL_STEPS),
        "tutorialReplayPolicy": "EXPLICIT_HELP_RESET",
        "playerFacingRawIdLeaks": 0,
        "perStageCodeOverrides": 0,
        "repairReachableArtifactCount": 20,
        "authoredEvidenceRiskCaseCount": len(EXPECTED_EVIDENCE_RISKS),
        "pressureToolIntersectionCount": 0,
        "errors": errors,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
