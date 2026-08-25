extends SceneTree

## Stage 2 authored-v2 integration contract.
##
## The suite exercises the generic RuntimeRegistry/GameState/Main public paths.
## It never patches production data and writes only its isolated QA report/save.

const CASE_IDS := ["leave_patina", "estate_compass", "pawn_watch"]
const EXPECTED_TEST_COUNT := 10
const REPORT_PATH := "res://qa/R3_STAGE2_AUTHORED_CASES_TESTS.json"
const SAVE_PATH := "user://r3_stage2_authored_cases_save.json"

const EXPECTED_RISKS := {
	"leave_patina": {"LOW": 1, "HIGH": 0},
	"estate_compass": {"LOW": 1, "HIGH": 0},
	"pawn_watch": {"LOW": 1, "HIGH": 1}
}

const EXPECTED_CAMPAIGN := {
	"leave_patina": {
		"npcId": "iris_bell", "documentIds": ["document_07", "document_08"],
		"rewardSpecId": "artifact_005", "storyArtifactId": "story_artifact_04",
		"storyBaseSpecId": "artifact_005",
		"rewards": {"money": 126, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1}
	},
	"estate_compass": {
		"npcId": "lena_falk", "documentIds": ["document_09", "document_10"],
		"rewardSpecId": "artifact_011", "storyArtifactId": "story_artifact_05",
		"storyBaseSpecId": "artifact_011",
		"rewards": {"money": 138, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1}
	},
	"pawn_watch": {
		"npcId": "lena_falk", "documentIds": ["document_11", "document_12"],
		"rewardSpecId": "artifact_002", "storyArtifactId": "story_artifact_06",
		"storyBaseSpecId": "artifact_002",
		"rewards": {"money": 150, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1}
	}
}

const PROTECTED_AUTHORED_SNAPSHOTS := {
	"prologue_clock": {
		"path": "res://data/cases/authored_v2/prologue.json",
		"sha256": "5a3bd4378fe982e4552bfcc917b2c63bcf7c63b315aa9348790fadcf276c5e59",
		"canonical": "hyp.period_repair", "evidenceCount": 5
	},
	"false_invoice": {
		"path": "res://data/cases/authored_v2/false_invoice.json",
		"sha256": "b6c8086791ae7f1dbd3adba41dfa80d044b242477d8a9a3efe663d355ae3bf41",
		"canonical": "hyp.authentic_box_false_invoice", "evidenceCount": 6
	},
	"shadow_camera": {
		"path": "res://data/cases/authored_v2/shadow_camera.json",
		"sha256": "09fd2bc681ae4897b1d2cac324996bda80f4f21d07f0d5d0823a1cb07acf0664",
		"canonical": "hyp.late_composite", "evidenceCount": 6
	}
}

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func settle_frames(count: int = 5) -> void:
	for _frame: int in range(count):
		await process_frame


func write_report_and_quit() -> void:
	var passed: int = results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report: Dictionary = {
		"suite": "R3 Stage 2 Authored Cases",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"expectedCount": EXPECTED_TEST_COUNT,
		"tests": results
	}
	var output: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	quit(0 if passed == EXPECTED_TEST_COUNT and results.size() == EXPECTED_TEST_COUNT else 1)


func blocked_remaining(code: String) -> void:
	var rows := [
		["S2-AUTHORED-STRUCTURE-01", "Stage 2 authored graph structure and runtime locks"],
		["S2-AUTHORED-CAMPAIGN-01", "Campaign identities, rewards, and Estate Compass spec correction"],
		["S2-AUTHORED-ISSUANCE-01", "Fresh and pre-patch Estate Compass issuance compatibility"],
		["S2-AUTHORED-RISK-01", "Stage 2 risk, tools, duplicate telemetry, and RNG"],
		["S2-AUTHORED-REPORT-01", "Citation rejection and evidence evaluation"],
		["S2-AUTHORED-RESOLUTION-01", "Exactly-once case rewards and relationships"],
		["S2-AUTHORED-BRIDGE-01", "Authored provenance bridge and exact reload"],
		["S2-AUTHORED-LOCALE-01", "Bilingual public copy and privacy"],
		["S2-AUTHORED-GENERIC-01", "Generic renderer and resolver implementation"]
	]
	for row: Array in rows:
		record(String(row[0]), String(row[1]), false, {"code": code})


func stage_two_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	profile["highestUnlockedStage"] = 2
	profile["clearedStages"] = [1]
	profile["stageBest"] = {"1": 55.0}
	return profile


func start_stage_two(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.player_profile = stage_two_profile(gs)
	var started: Dictionary = gs.new_game(2)
	gs.persistence_enabled = false
	return started


func begin_stage_two_case(gs: Node, case_id: String) -> Dictionary:
	var started: Dictionary = start_stage_two(gs)
	var artifact: Dictionary = gs.begin_case(case_id) if bool(started.get("ok", false)) else {}
	return {"start": started, "artifact": artifact}


func evidence_by_id(definition: Dictionary, evidence_id: String) -> Dictionary:
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary and String((evidence_value as Dictionary).get("id", "")) == evidence_id:
			return (evidence_value as Dictionary)
	return {}


func unique_strings(values: Array) -> Array:
	var output: Array = []
	for value: Variant in values:
		var text: String = String(value)
		if not output.has(text):
			output.append(text)
	return output


func source_kinds(definition: Dictionary) -> Array:
	var kinds: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary:
			kinds.append(String((evidence_value as Dictionary).get("source", {}).get("kind", "")))
	kinds = unique_strings(kinds)
	kinds.sort()
	return kinds


func independence_groups(definition: Dictionary) -> Array:
	var groups: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary:
			groups.append(String((evidence_value as Dictionary).get("independence_key", "")))
	return unique_strings(groups)


func hypothesis_relation_matrix(definition: Dictionary) -> Dictionary:
	var matrix: Dictionary = {}
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		if hypothesis_value is Dictionary:
			matrix[String((hypothesis_value as Dictionary).get("id", ""))] = []
	for evidence_value: Variant in definition.get("evidence", []):
		if not evidence_value is Dictionary:
			continue
		for relation_value: Variant in (evidence_value as Dictionary).get("relations", []):
			if not relation_value is Dictionary:
				continue
			var hypothesis_id: String = String((relation_value as Dictionary).get("hypothesis_id", ""))
			var stance: String = String((relation_value as Dictionary).get("stance", ""))
			if matrix.has(hypothesis_id) and not (matrix[hypothesis_id] as Array).has(stance):
				(matrix[hypothesis_id] as Array).append(stance)
	return matrix


func satisfy_requirements(gs: Node, case_id: String, definition: Dictionary, evidence_id: String, visiting: Dictionary = {}) -> bool:
	if visiting.has(evidence_id):
		return false
	visiting[evidence_id] = true
	var evidence: Dictionary = evidence_by_id(definition, evidence_id)
	if evidence.is_empty():
		return false
	for requirement_value: Variant in evidence.get("unlock", {}).get("requires_all", []):
		var requirement_id: String = String(requirement_value)
		var state: Dictionary = gs.get_case_public_state(case_id)
		var discovered_ids: Array = state.get("discoveredEvidence", []).map(
			func(row: Dictionary): return String(row.get("id", ""))
		)
		if discovered_ids.has(requirement_id):
			continue
		if not satisfy_requirements(gs, case_id, definition, requirement_id, visiting):
			return false
		var requirement: Dictionary = evidence_by_id(definition, requirement_id)
		var tools: Array = requirement.get("unlock", {}).get("requires_tools", [])
		if not tools.is_empty():
			gs.select_tool(String(tools[0]))
		var discovered: Dictionary = gs.discover_case_evidence(case_id, requirement_id)
		if not bool(discovered.get("ok", false)) or not String(discovered.get("code", "")) in ["DISCOVERED", "ALREADY_DISCOVERED"]:
			return false
	visiting.erase(evidence_id)
	return true


func discover_all(gs: Node, case_id: String) -> Array:
	var discovered_ids: Array = []
	for _pass: int in range(20):
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var progressed: bool = false
		for row_value: Variant in public_state.get("availableEvidence", []):
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value as Dictionary
			var required_tools: Array = row.get("requiredTools", [])
			if not required_tools.is_empty():
				gs.select_tool(String(required_tools[0]))
			var result: Dictionary = gs.discover_case_evidence(case_id, String(row.get("id", "")))
			if bool(result.get("ok", false)) and String(result.get("code", "")) == "DISCOVERED":
				discovered_ids.append(String(row.get("id", "")))
				progressed = true
		if not progressed:
			break
	return discovered_ids


func state_signature(gs: Node) -> String:
	return JSON.stringify(gs.save_payload())


func semantic_exact(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return is_equal_approx(float(left), float(right))
	if left is Dictionary and right is Dictionary:
		var left_dictionary: Dictionary = left
		var right_dictionary: Dictionary = right
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key: Variant in left_dictionary.keys():
			if not right_dictionary.has(key) or not semantic_exact(left_dictionary[key], right_dictionary[key]):
				return false
		return true
	if left is Array and right is Array:
		var left_array: Array = left
		var right_array: Array = right
		if left_array.size() != right_array.size():
			return false
		for index: int in range(left_array.size()):
			if not semantic_exact(left_array[index], right_array[index]):
				return false
		return true
	return left == right


func locale_neutral_signature(gs: Node) -> String:
	var payload: Dictionary = gs.save_payload().duplicate(true)
	payload["language"] = "<locale>"
	return JSON.stringify({"run": payload, "profile": gs.profile_payload()})


func cleanup_save(gs: Node, path: String) -> void:
	for candidate: String in [path, path + gs.SAVE_TEMP_SUFFIX, path + gs.SAVE_BACKUP_SUFFIX]:
		gs.remove_save_file(candidate)


func reason_has(tags: Array, code: String) -> bool:
	for tag_value: Variant in tags:
		if tag_value is Dictionary and String((tag_value as Dictionary).get("code", "")) == code:
			return true
	return false


func public_clue_rows(definition: Dictionary, clue_id: String = "PROVENANCE") -> Array:
	var rows: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary and String((evidence_value as Dictionary).get("public_clue_id", "")) == clue_id:
			rows.append(evidence_value)
	return rows


func dependency_contains_public_clue(definition: Dictionary, evidence_id: String, visiting: Dictionary = {}) -> bool:
	if visiting.has(evidence_id):
		return false
	visiting[evidence_id] = true
	var evidence: Dictionary = evidence_by_id(definition, evidence_id)
	if String(evidence.get("public_clue_id", "")) == "PROVENANCE":
		return true
	for requirement_value: Variant in evidence.get("unlock", {}).get("requires_all", []):
		if dependency_contains_public_clue(definition, String(requirement_value), visiting):
			return true
	return false


func bilingual_complete(value: Variant) -> bool:
	return value is Dictionary and not String((value as Dictionary).get("en", "")).strip_edges().is_empty() \
		and not String((value as Dictionary).get("ko", "")).strip_edges().is_empty()


func numeric_rewards_exact(actual: Variant, expected: Dictionary) -> bool:
	if not actual is Dictionary or (actual as Dictionary).size() != expected.size():
		return false
	for key: String in expected.keys():
		var actual_value: Variant = (actual as Dictionary).get(key, null)
		if (not actual_value is int and not actual_value is float) \
			or not is_equal_approx(float(actual_value), float(expected.get(key, 0))):
			return false
	return true


func authored_copy_complete(definition: Dictionary) -> bool:
	for key: String in ["title", "briefing", "central_question", "fiction_notice", "success", "failure"]:
		if not bilingual_complete(definition.get(key, {})):
			return false
	if not bilingual_complete(definition.get("resolution", {}).get("report_prompt", {})):
		return false
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		if not hypothesis_value is Dictionary:
			return false
		if not bilingual_complete((hypothesis_value as Dictionary).get("label", {})) \
			or not bilingual_complete((hypothesis_value as Dictionary).get("claim", {})):
			return false
	for evidence_value: Variant in definition.get("evidence", []):
		if not evidence_value is Dictionary:
			return false
		var evidence: Dictionary = evidence_value as Dictionary
		if not bilingual_complete(evidence.get("text", {})) or not bilingual_complete(evidence.get("citation", {}).get("label", {})):
			return false
		if String(evidence.get("risk", {}).get("level", "NONE")) != "NONE" \
			and not bilingual_complete(evidence.get("risk", {}).get("warning", {})):
			return false
	return true


func visible_copy(root: Node) -> String:
	var copy: String = ""
	for label_value: Node in root.find_children("*", "Label", true, false):
		if (label_value as Label).is_visible_in_tree():
			copy += String((label_value as Label).text) + "\n"
	for button_value: Node in root.find_children("*", "Button", true, false):
		if (button_value as Button).is_visible_in_tree():
			copy += String((button_value as Button).text) + "\n"
	return copy


func raw_copy_leaks(copy: String, definition: Dictionary, case_id: String) -> Array:
	var tokens: Array = [
		case_id, "public_clue_id", "canonical_hypothesis", "winning_hypothesis",
		"authoring_truth", "authenticityTruth", "trueMarket", "trueRarity",
		"inspection recorded for the case file", "조사 결과를 사건 기록에 남겼습니다",
		"{\"en\"", "{ en", "Dictionary"
	]
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary:
			tokens.append(String((evidence_value as Dictionary).get("id", "")))
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		if hypothesis_value is Dictionary:
			tokens.append(String((hypothesis_value as Dictionary).get("id", "")))
	var leaks: Array = []
	for token_value: Variant in tokens:
		var token: String = String(token_value)
		if not token.is_empty() and copy.contains(token) and not leaks.has(token):
			leaks.append(token)
	return leaks


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false

	var required_game_state_methods := [
		"new_game", "begin_case", "case_definition", "discover_case_evidence",
		"get_case_public_state", "evaluate_case_submission", "resolve_case_v2",
		"listing_public_status_tags", "auction_public_reason_tags", "save_game", "load_game"
	]
	var missing_methods: Array = []
	for method_name: String in required_game_state_methods:
		if not gs.has_method(method_name):
			missing_methods.append(method_name)
	var definitions: Dictionary = {}
	var fallback_count: int = 0
	for case_id: String in CASE_IDS:
		var definition: Dictionary = registry.get_case_v2(case_id)
		definitions[case_id] = definition
		if definition.is_empty() or int(gs.case_definition(case_id).get("schema_version", 0)) != 2:
			fallback_count += 1
	var stage_definition: Dictionary = registry.get_stage_definition(2)
	var protected_snapshots_ok: bool = true
	var protected_snapshot_evidence: Dictionary = {}
	for protected_id: String in PROTECTED_AUTHORED_SNAPSHOTS.keys():
		var expected: Dictionary = PROTECTED_AUTHORED_SNAPSHOTS[protected_id]
		var protected_definition: Dictionary = registry.get_case_v2(protected_id)
		var actual_hash: String = FileAccess.get_sha256(String(expected.get("path", "")))
		var row_ok: bool = actual_hash == String(expected.get("sha256", "")) \
			and String(protected_definition.get("canonical_hypothesis_id", "")) == String(expected.get("canonical", "")) \
			and protected_definition.get("evidence", []).size() == int(expected.get("evidenceCount", -1))
		protected_snapshots_ok = protected_snapshots_ok and row_ok
		protected_snapshot_evidence[protected_id] = {"sha256": actual_hash, "canonical": protected_definition.get("canonical_hypothesis_id", ""), "evidenceCount": protected_definition.get("evidence", []).size(), "ok": row_ok}
	var data_ready: bool = missing_methods.is_empty() and fallback_count == 0
	var data_ok: bool = data_ready and registry.authored_case_errors.is_empty() \
		and registry.authored_cases_v2.size() >= 6 \
		and stage_definition.get("case_ids", []) == CASE_IDS \
		and is_equal_approx(float(registry.stage_difficulty_multiplier(2)), 1.07) \
		and protected_snapshots_ok
	record(
		"S2-AUTHORED-DATA-01",
		"Stage 2 resolves exactly three authored-v2 cases in order with no fallback while the three protected authored results remain exact",
		data_ok,
		{"missingMethods": missing_methods, "registryErrors": registry.authored_case_errors, "authoredCount": registry.authored_cases_v2.size(), "caseOrder": stage_definition.get("case_ids", []), "fallbackCount": fallback_count, "multiplier": registry.stage_difficulty_multiplier(2), "protected": protected_snapshot_evidence}
	)
	if not data_ready:
		blocked_remaining("STAGE2_AUTHORED_DATA_NOT_READY")
		write_report_and_quit()
		return

	# Structural/data graph plus a real precondition rejection for every case.
	var structure_ok: bool = true
	var structure_evidence: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var matrix: Dictionary = hypothesis_relation_matrix(definition)
		var collective_stances: Array = []
		var every_hypothesis_linked: bool = true
		for hypothesis_id: String in matrix.keys():
			var hypothesis_stances: Array = matrix[hypothesis_id]
			every_hypothesis_linked = every_hypothesis_linked and not hypothesis_stances.is_empty()
			for stance_value: Variant in hypothesis_stances:
				if not collective_stances.has(String(stance_value)):
					collective_stances.append(String(stance_value))
		var relation_complete: bool = every_hypothesis_linked \
			and collective_stances.has("SUPPORT") and collective_stances.has("REFUTE")
		var dependency_rows: Array = definition.get("evidence", []).filter(
			func(row: Dictionary): return not row.get("unlock", {}).get("requires_all", []).is_empty()
		)
		var strong_rules: Dictionary = definition.get("resolution", {})
		var static_one_source_impossible: bool = int(strong_rules.get("strong_min_independent_support", 0)) >= 2 \
			and int(strong_rules.get("strong_min_citations", 0)) >= 2
		var fixture: Dictionary = begin_stage_two_case(gs, case_id)
		var locked_result: Dictionary = {}
		if not dependency_rows.is_empty() and not (fixture.get("artifact", {}) as Dictionary).is_empty():
			locked_result = gs.discover_case_evidence(case_id, String((dependency_rows[0] as Dictionary).get("id", "")))
		var case_ok: bool = int(definition.get("schema_version", 0)) == 2 \
			and definition.get("hypotheses", []).size() == 3 \
			and source_kinds(definition) == ["ARTIFACT", "DOCUMENT", "NPC", "REFERENCE"] \
			and relation_complete and independence_groups(definition).size() >= 3 \
			and dependency_rows.size() >= 1 and static_one_source_impossible \
			and not bool(locked_result.get("ok", true)) and String(locked_result.get("code", "")) == "EVIDENCE_LOCKED"
		structure_ok = structure_ok and case_ok
		structure_evidence[case_id] = {"sourceKinds": source_kinds(definition), "hypotheses": definition.get("hypotheses", []).size(), "relations": matrix, "collectiveStances": collective_stances, "everyHypothesisLinked": every_hypothesis_linked, "groups": independence_groups(definition), "dependencyRows": dependency_rows.map(func(row: Dictionary): return row.get("id", "")), "lockedResult": locked_result, "oneSourceStrongImpossible": static_one_source_impossible, "ok": case_ok}
	record(
		"S2-AUTHORED-STRUCTURE-01",
		"Every Stage 2 case has four source kinds, three contested hypotheses, independent groups, a runtime dependency, and no one-source STRONG path",
		structure_ok,
		structure_evidence
	)

	# Existing campaign identity/reward content is frozen except the approved
	# Estate Compass artifact correction to spec/model 011.
	var campaign_ok: bool = true
	var campaign_evidence: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED_CAMPAIGN[case_id]
		var story_case: Dictionary = registry.get_case(case_id)
		var story_artifact: Dictionary = registry.story_artifacts.get(String(story_case.get("storyArtifactId", "")), {})
		var case_ok: bool = String(story_case.get("npcId", "")) == String(expected.get("npcId", "")) \
			and story_case.get("documentIds", []) == expected.get("documentIds", []) \
			and numeric_rewards_exact(story_case.get("rewards", {}), expected.get("rewards", {})) \
			and String(story_case.get("rewardSpecId", "")) == String(expected.get("rewardSpecId", "")) \
			and String(story_case.get("storyArtifactId", "")) == String(expected.get("storyArtifactId", "")) \
			and String(story_artifact.get("baseSpecId", "")) == String(expected.get("storyBaseSpecId", ""))
		campaign_ok = campaign_ok and case_ok
		campaign_evidence[case_id] = {"npcId": story_case.get("npcId", ""), "documentIds": story_case.get("documentIds", []), "rewards": story_case.get("rewards", {}), "rewardSpecId": story_case.get("rewardSpecId", ""), "storyArtifactId": story_case.get("storyArtifactId", ""), "storyBaseSpecId": story_artifact.get("baseSpecId", ""), "ok": case_ok}
	record(
		"S2-AUTHORED-CAMPAIGN-01",
		"Stage 2 keeps exact NPC, document and reward arrays; only Estate Compass moves to reward/story base spec 011",
		campaign_ok,
		campaign_evidence
	)

	# Fresh issue uses the corrected compass, while an already-issued legacy vase
	# is a durable ledger identity and must never be silently replaced.
	var fresh_fixture: Dictionary = begin_stage_two_case(gs, "estate_compass")
	var fresh_artifact: Dictionary = fresh_fixture.get("artifact", {})
	var fresh_spec: Dictionary = registry.get_spec(String(fresh_artifact.get("artifactSpecId", "")))
	var fresh_ok: bool = bool(fresh_fixture.get("start", {}).get("ok", false)) \
		and String(fresh_artifact.get("artifactSpecId", "")) == "artifact_011" \
		and int(fresh_artifact.get("baseValue", -1)) == 300 \
		and String(fresh_artifact.get("baseModel", "")) == "model_11.obj" \
		and int(fresh_spec.get("baseValue", -1)) == 300 and String(fresh_spec.get("baseModel", "")) == "model_11.obj"
	var legacy_started: Dictionary = start_stage_two(gs)
	var legacy_artifact: Dictionary = gs.new_artifact("artifact_009", 920009, "case_estate_compass")
	legacy_artifact["caseId"] = "estate_compass"
	legacy_artifact["storyArtifactId"] = "story_artifact_05"
	legacy_artifact["historicalIntegrity"] = 63.5
	gs.inventory = [legacy_artifact]
	gs.campaign_state.activeCaseId = "estate_compass"
	gs.campaign_state.caseArtifactLedger["estate_compass"] = {
		"issued": true, "artifactUid": "case_estate_compass", "disposition": "INVENTORY",
		"saleTransactionId": "", "publicConditionSnapshot": {}, "publicAppraisalSnapshot": 0
	}
	var legacy_runtime_state: Dictionary = gs.ensure_case_runtime_state("estate_compass")
	legacy_runtime_state["selectedHypothesisId"] = String(definitions["estate_compass"].get("canonical_hypothesis_id", ""))
	var legacy_payload_before: String = state_signature(gs)
	var legacy_ledger_before: Dictionary = gs.campaign_state.caseArtifactLedger["estate_compass"].duplicate(true)
	var legacy_case_state_before: Dictionary = legacy_runtime_state.duplicate(true)
	var legacy_rng_before: int = int(gs.rng.state)
	var legacy_returned: Dictionary = gs.begin_case("estate_compass")
	var legacy_ok: bool = bool(legacy_started.get("ok", false)) \
		and String(legacy_returned.get("uniqueId", "")) == "case_estate_compass" \
		and String(legacy_returned.get("artifactSpecId", "")) == "artifact_009" \
		and gs.inventory.size() == 1 \
		and gs.campaign_state.caseArtifactLedger["estate_compass"] == legacy_ledger_before \
		and gs.campaign_state.caseStates["estate_compass"] == legacy_case_state_before \
		and state_signature(gs) == legacy_payload_before and int(gs.rng.state) == legacy_rng_before
	record(
		"S2-AUTHORED-ISSUANCE-01",
		"Fresh Estate Compass issues artifact 011/model 11/value 300, while a simulated pre-patch artifact 009 ledger, UID and case state are preserved exactly",
		fresh_ok and legacy_ok,
		{"fresh": {"artifactSpecId": fresh_artifact.get("artifactSpecId", ""), "baseValue": fresh_artifact.get("baseValue", -1), "baseModel": fresh_artifact.get("baseModel", ""), "ok": fresh_ok}, "legacy": {"uid": legacy_returned.get("uniqueId", ""), "artifactSpecId": legacy_returned.get("artifactSpecId", ""), "inventoryCount": gs.inventory.size(), "ledgerExact": gs.campaign_state.caseArtifactLedger["estate_compass"] == legacy_ledger_before, "caseStateExact": gs.campaign_state.caseStates["estate_compass"] == legacy_case_state_before, "stateMutation0": state_signature(gs) == legacy_payload_before, "rngMutation0": int(gs.rng.state) == legacy_rng_before, "ok": legacy_ok}}
	)

	# Risk/tool/runtime telemetry gate.
	var risk_ok: bool = true
	var risk_evidence: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var counts: Dictionary = {"LOW": 0, "HIGH": 0}
		var risky_rows: Array = []
		var tool_rows: Array = []
		for evidence_value: Variant in definition.get("evidence", []):
			if not evidence_value is Dictionary:
				continue
			var evidence: Dictionary = evidence_value as Dictionary
			var risk_level: String = String(evidence.get("risk", {}).get("level", "NONE"))
			if risk_level in ["LOW", "HIGH"]:
				counts[risk_level] = int(counts.get(risk_level, 0)) + 1
				risky_rows.append(evidence)
			if not evidence.get("unlock", {}).get("requires_tools", []).is_empty():
				tool_rows.append(evidence)
		var case_risk_ok: bool = counts == EXPECTED_RISKS[case_id]
		var tool_gate_rows: Array = []
		if tool_rows.is_empty():
			case_risk_ok = false
		else:
			var tool_fixture: Dictionary = begin_stage_two_case(gs, case_id)
			var tool_target: Dictionary = tool_rows[0]
			var tool_target_id: String = String(tool_target.get("id", ""))
			var prerequisites_ok: bool = not (tool_fixture.get("artifact", {}) as Dictionary).is_empty() \
				and satisfy_requirements(gs, case_id, definition, tool_target_id)
			var required_tools: Array = tool_target.get("unlock", {}).get("requires_tools", [])
			var wrong_tool: String = "soft_brush" if not required_tools.has("soft_brush") else "uv_lamp"
			var wrong_selected: bool = bool(gs.select_tool(wrong_tool))
			var wrong_state_before: String = state_signature(gs)
			var wrong_rng_before: int = int(gs.rng.state)
			var wrong_result: Dictionary = gs.discover_case_evidence(case_id, tool_target_id)
			var wrong_ok: bool = prerequisites_ok and wrong_selected \
				and not bool(wrong_result.get("ok", true)) and String(wrong_result.get("code", "")) == "TOOL_REQUIRED" \
				and state_signature(gs) == wrong_state_before and int(gs.rng.state) == wrong_rng_before
			case_risk_ok = case_risk_ok and wrong_ok
			tool_gate_rows.append({"evidenceId": tool_target_id, "required": required_tools, "wrongTool": wrong_tool, "result": wrong_result, "stateMutation0": state_signature(gs) == wrong_state_before, "rngMutation0": int(gs.rng.state) == wrong_rng_before, "ok": wrong_ok})
		var runtime_rows: Array = []
		for risk_row_value: Variant in risky_rows:
			var risk_row: Dictionary = risk_row_value as Dictionary
			var fixture: Dictionary = begin_stage_two_case(gs, case_id)
			var artifact: Dictionary = fixture.get("artifact", {})
			var evidence_id: String = String(risk_row.get("id", ""))
			var prereqs_ok: bool = not artifact.is_empty() and satisfy_requirements(gs, case_id, definition, evidence_id)
			var tools: Array = risk_row.get("unlock", {}).get("requires_tools", [])
			if not tools.is_empty():
				gs.select_tool(String(tools[0]))
			var integrity_before: float = float(artifact.get("historicalIntegrity", 0.0))
			var telemetry_before: Dictionary = gs.stage_run_state.get("telemetry", {}).duplicate(true)
			var discovery: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var risk_level: String = String(risk_row.get("risk", {}).get("level", "NONE"))
			var expected_penalty: float = 1.07 if risk_level == "LOW" else 3.21
			var integrity_after: float = float(artifact.get("historicalIntegrity", 0.0))
			var first_ok: bool = prereqs_ok and bool(discovery.get("ok", false)) and String(discovery.get("code", "")) == "DISCOVERED" \
				and is_equal_approx(float(discovery.get("appliedRiskPenalty", -1.0)), expected_penalty) \
				and is_equal_approx(integrity_before - integrity_after, expected_penalty) \
				and gs.stage_run_state.get("telemetry", {}) != telemetry_before
			var duplicate_state_before: String = state_signature(gs)
			var duplicate_telemetry_before: Dictionary = gs.stage_run_state.get("telemetry", {}).duplicate(true)
			var duplicate_rng_before: int = int(gs.rng.state)
			var duplicate: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var duplicate_ok: bool = bool(duplicate.get("ok", false)) and String(duplicate.get("code", "")) == "ALREADY_DISCOVERED" \
				and state_signature(gs) == duplicate_state_before \
				and gs.stage_run_state.get("telemetry", {}) == duplicate_telemetry_before \
				and int(gs.rng.state) == duplicate_rng_before
			case_risk_ok = case_risk_ok and first_ok and duplicate_ok
			runtime_rows.append({"evidenceId": evidence_id, "level": risk_level, "expectedPenalty": expected_penalty, "actualPenalty": discovery.get("appliedRiskPenalty", null), "integrity": [integrity_before, integrity_after], "firstOk": first_ok, "duplicate": duplicate, "duplicateStateMutation0": state_signature(gs) == duplicate_state_before, "duplicateTelemetryMutation0": gs.stage_run_state.get("telemetry", {}) == duplicate_telemetry_before, "duplicateRngMutation0": int(gs.rng.state) == duplicate_rng_before, "ok": first_ok and duplicate_ok})
		risk_ok = risk_ok and case_risk_ok
		risk_evidence[case_id] = {"counts": counts, "expected": EXPECTED_RISKS[case_id], "toolGates": tool_gate_rows, "runtime": runtime_rows, "ok": case_risk_ok}
	record(
		"S2-AUTHORED-RISK-01",
		"Stage 2 applies exact 1.07/3.21 LOW/HIGH pressure behind selected-tool gates and duplicate discovery is state, telemetry and RNG zero",
		risk_ok,
		risk_evidence
	)

	# Read-only submission evaluation: reject unavailable foreign evidence, accept
	# sufficient independent evidence, and keep a wrong claim mistaken.
	var report_ok: bool = true
	var report_evidence: Dictionary = {}
	for case_index: int in range(CASE_IDS.size()):
		var case_id: String = CASE_IDS[case_index]
		var definition: Dictionary = definitions[case_id]
		var fixture: Dictionary = begin_stage_two_case(gs, case_id)
		var canonical: String = String(definition.get("canonical_hypothesis_id", ""))
		var all_rows: Array = definition.get("evidence", [])
		var own_id: String = String((all_rows[0] as Dictionary).get("id", "")) if not all_rows.is_empty() else ""
		var other_definition: Dictionary = definitions[String(CASE_IDS[(case_index + 1) % CASE_IDS.size()])]
		var other_rows: Array = other_definition.get("evidence", [])
		var foreign_id: String = String((other_rows[0] as Dictionary).get("id", "")) if not other_rows.is_empty() else ""
		var reject_state_before: String = state_signature(gs)
		var reject_rng_before: int = int(gs.rng.state)
		var unseen: Dictionary = gs.evaluate_case_submission(case_id, canonical, [own_id])
		var foreign: Dictionary = gs.evaluate_case_submission(case_id, canonical, [foreign_id])
		var rejection_ok: bool = not (fixture.get("artifact", {}) as Dictionary).is_empty() \
			and not bool(unseen.get("ok", true)) and String(unseen.get("code", "")) == "EVIDENCE_NOT_DISCOVERED" \
			and not bool(foreign.get("ok", true)) and String(foreign.get("code", "")) == "CROSS_CASE_EVIDENCE" \
			and state_signature(gs) == reject_state_before and int(gs.rng.state) == reject_rng_before
		var discovered: Array = discover_all(gs, case_id)
		var evaluation_state_before: String = state_signature(gs)
		var evaluation_rng_before: int = int(gs.rng.state)
		var intended: Dictionary = gs.evaluate_case_submission(case_id, canonical, discovered)
		var wrong_hypothesis: String = ""
		for hypothesis_value: Variant in definition.get("hypotheses", []):
			if hypothesis_value is Dictionary and String((hypothesis_value as Dictionary).get("id", "")) != canonical:
				wrong_hypothesis = String((hypothesis_value as Dictionary).get("id", ""))
				break
		var wrong: Dictionary = gs.evaluate_case_submission(case_id, wrong_hypothesis, discovered)
		var one_group_strong: Array = []
		for group_id: String in independence_groups(definition):
			var group_citations: Array = []
			for evidence_value: Variant in definition.get("evidence", []):
				if evidence_value is Dictionary and String((evidence_value as Dictionary).get("independence_key", "")) == group_id:
					group_citations.append(String((evidence_value as Dictionary).get("id", "")))
			for hypothesis_value: Variant in definition.get("hypotheses", []):
				if hypothesis_value is Dictionary:
					var hypothesis_id: String = String((hypothesis_value as Dictionary).get("id", ""))
					var single_group: Dictionary = gs.evaluate_case_submission(case_id, hypothesis_id, group_citations)
					if String(single_group.get("substantiation", "")) == "STRONG":
						one_group_strong.append({"group": group_id, "hypothesis": hypothesis_id, "result": single_group})
		var case_ok: bool = rejection_ok and discovered.size() == all_rows.size() \
			and bool(intended.get("ok", false)) and bool(intended.get("conclusionAccurate", false)) \
			and bool(intended.get("substantiated", false)) and String(intended.get("outcome", "")) == "masterful" \
			and int(intended.get("independentSourceCount", 0)) >= 3 \
			and bool(wrong.get("ok", false)) and not bool(wrong.get("conclusionAccurate", true)) \
			and String(wrong.get("outcome", "")) == "mistaken" and one_group_strong.is_empty() \
			and state_signature(gs) == evaluation_state_before and int(gs.rng.state) == evaluation_rng_before
		report_ok = report_ok and case_ok
		report_evidence[case_id] = {"unseen": unseen, "foreign": foreign, "rejectionMutation0": state_signature(gs) == evaluation_state_before, "discovered": discovered, "intended": intended, "wrong": wrong, "oneGroupStrong": one_group_strong, "evaluationStateMutation0": state_signature(gs) == evaluation_state_before, "evaluationRngMutation0": int(gs.rng.state) == evaluation_rng_before, "ok": case_ok}
	record(
		"S2-AUTHORED-REPORT-01",
		"Unseen and cross-case citations fail closed; sufficient independent citations are masterful, wrong claims stay mistaken, and one source never becomes STRONG",
		report_ok,
		report_evidence
	)

	# Authoritative resolution and exact reward/relationship boundaries.
	var resolution_ok: bool = true
	var resolution_evidence: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var fixture: Dictionary = begin_stage_two_case(gs, case_id)
		var artifact: Dictionary = fixture.get("artifact", {})
		var citations: Array = discover_all(gs, case_id)
		var story_case: Dictionary = registry.get_case(case_id)
		var rewards: Dictionary = story_case.get("rewards", {})
		var canonical: String = String(definition.get("canonical_hypothesis_id", ""))
		var npc_id: String = String(story_case.get("npcId", ""))
		var domain: String = String(gs.mastery_domain_for_spec(String(story_case.get("rewardSpecId", ""))))
		var before: Dictionary = {
			"money": int(gs.money), "reputation": int(gs.reputation),
			"museumTrust": int(gs.campaign_state.museumTrust), "historicalIntegrity": int(gs.campaign_state.historicalIntegrity),
			"collectorNetwork": int(gs.campaign_state.collectorNetwork), "mastery": int(gs.campaign_state.mastery.get(domain, 0)),
			"relationship": int(gs.campaign_state.relationships.get(npc_id, {}).get("relationship", 0)),
			"trust": int(gs.campaign_state.relationships.get(npc_id, {}).get("trust", 0)),
			"attempts": int(gs.statistics.get("authentication_attempts", 0)),
			"correct": int(gs.statistics.get("authentication_correct", 0)),
			"forgeries": int(gs.statistics.get("forgeries_detected", 0))
		}
		var resolved: Dictionary = gs.resolve_case_v2(case_id, canonical, citations)
		var expected_money: int = roundi(float(rewards.get("money", 0)) * 1.20)
		var expected_reputation: int = roundi(float(rewards.get("reputation", 0)) * 1.20)
		var expected_mastery: int = roundi(float(rewards.get("mastery", 0)) * 1.20)
		var expected_trust_reward: int = roundi(float(rewards.get("museumTrust", 0)) * 1.20)
		var expected_integrity: int = clampi(int(before.historicalIntegrity) + roundi(float(rewards.get("historicalIntegrity", 0)) * 1.20), 0, 100)
		var first_exact: bool = not artifact.is_empty() and bool(resolved.get("ok", false)) \
			and String(resolved.get("outcome", "")) == "masterful" and bool(resolved.get("conclusionAccurate", false)) \
			and int(gs.money) == int(before.money) + expected_money \
			and int(gs.reputation) == int(before.reputation) + expected_reputation \
			and int(gs.campaign_state.museumTrust) == int(before.museumTrust) + expected_trust_reward \
			and int(gs.campaign_state.historicalIntegrity) == expected_integrity \
			and int(gs.campaign_state.collectorNetwork) == int(before.collectorNetwork) + 1 \
			and int(gs.campaign_state.mastery.get(domain, 0)) == int(before.mastery) + expected_mastery \
			and int(gs.campaign_state.relationships.get(npc_id, {}).get("relationship", 0)) == int(before.relationship) + 2 \
			and int(gs.campaign_state.relationships.get(npc_id, {}).get("trust", 0)) == int(before.trust) + 2 \
			and int(gs.statistics.get("authentication_attempts", 0)) == int(before.attempts) + 1 \
			and int(gs.statistics.get("authentication_correct", 0)) == int(before.correct) + 1 \
			and int(gs.statistics.get("forgeries_detected", 0)) == int(before.forgeries) + (1 if canonical == "FORGERY" else 0) \
			and bool(gs.campaign_state.completedCases.get(case_id, false)) and bool(artifact.get("caseResolved", false))
		var once_state_before: String = state_signature(gs)
		var once_rng_before: int = int(gs.rng.state)
		var second: Dictionary = gs.resolve_case_v2(case_id, canonical, citations)
		var once_ok: bool = not bool(second.get("ok", true)) and String(second.get("code", "")) == "CASE_ALREADY_RESOLVED" \
			and state_signature(gs) == once_state_before and int(gs.rng.state) == once_rng_before
		var case_ok: bool = first_exact and once_ok
		resolution_ok = resolution_ok and case_ok
		resolution_evidence[case_id] = {"before": before, "rewardData": rewards, "expectedDeltas": {"money": expected_money, "reputation": expected_reputation, "mastery": expected_mastery, "museumTrust": expected_trust_reward}, "resolved": resolved, "second": second, "onceStateMutation0": state_signature(gs) == once_state_before, "onceRngMutation0": int(gs.rng.state) == once_rng_before, "ok": case_ok}
	record(
		"S2-AUTHORED-RESOLUTION-01",
		"Each intended report resolves once with exact authored rewards, mastery, relationship, trust and authentication boundaries; repeat resolution is mutation-zero",
		resolution_ok,
		resolution_evidence
	)

	# Generic authored public-clue bridge and isolated exact reload.
	var bridge_ok: bool = true
	var bridge_evidence: Dictionary = {}
	var reload_executed: bool = false
	cleanup_save(gs, SAVE_PATH)
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var tagged: Array = public_clue_rows(definition)
		var case_ok: bool = tagged.size() == 1
		var non_tagged_rows: Array = []
		for evidence_value: Variant in definition.get("evidence", []):
			if not evidence_value is Dictionary:
				continue
			var evidence: Dictionary = evidence_value as Dictionary
			var kind: String = String(evidence.get("source", {}).get("kind", ""))
			if String(evidence.get("public_clue_id", "")) != "PROVENANCE" and kind in ["DOCUMENT", "NPC", "REFERENCE"]:
				non_tagged_rows.append(evidence)
		var non_tagged_ok: bool = not non_tagged_rows.is_empty()
		var non_tagged_evidence: Array = []
		for non_tag_value: Variant in non_tagged_rows:
			var non_tagged_row: Dictionary = non_tag_value as Dictionary
			var non_tag_fixture: Dictionary = begin_stage_two_case(gs, case_id)
			var non_tag_artifact: Dictionary = non_tag_fixture.get("artifact", {})
			var non_tag_id: String = String(non_tagged_row.get("id", ""))
			var row_ok: bool = not non_tag_artifact.is_empty() and satisfy_requirements(gs, case_id, definition, non_tag_id)
			var known_before: int = non_tag_artifact.get("knownClues", []).count("PROVENANCE") if not non_tag_artifact.is_empty() else -1
			var non_tag_tools: Array = non_tagged_row.get("unlock", {}).get("requires_tools", [])
			if not non_tag_tools.is_empty():
				gs.select_tool(String(non_tag_tools[0]))
			var non_tag_result: Dictionary = gs.discover_case_evidence(case_id, non_tag_id) if row_ok else {}
			var known_after: int = non_tag_artifact.get("knownClues", []).count("PROVENANCE") if not non_tag_artifact.is_empty() else -1
			row_ok = row_ok and bool(non_tag_result.get("ok", false)) and known_after == known_before
			non_tagged_ok = non_tagged_ok and row_ok
			non_tagged_evidence.append({"id": non_tag_id, "sourceKind": non_tagged_row.get("source", {}).get("kind", ""), "dependencyIncludesProvenance": dependency_contains_public_clue(definition, non_tag_id), "knownBefore": known_before, "knownAfter": known_after, "result": non_tag_result, "ok": row_ok})
		var tagged_fixture: Dictionary = begin_stage_two_case(gs, case_id)
		var artifact: Dictionary = tagged_fixture.get("artifact", {})
		var tagged_row: Dictionary = tagged[0] if tagged.size() == 1 and tagged[0] is Dictionary else {}
		var tagged_id: String = String(tagged_row.get("id", ""))
		var before_listing_tags: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN") if not artifact.is_empty() else []
		var before_reason_tags: Array = gs.auction_public_reason_tags(artifact, {}, "NO_SALE", {"reserve": 100, "hammer": 0, "reserve_met": false}) if not artifact.is_empty() else []
		var prerequisites_ok: bool = not artifact.is_empty() and not tagged_row.is_empty() \
			and satisfy_requirements(gs, case_id, definition, tagged_id)
		var tagged_tools: Array = tagged_row.get("unlock", {}).get("requires_tools", [])
		if not tagged_tools.is_empty():
			gs.select_tool(String(tagged_tools[0]))
		var discovered: Dictionary = gs.discover_case_evidence(case_id, tagged_id) if prerequisites_ok else {}
		var after_listing_tags: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN") if not artifact.is_empty() else []
		var after_reason_tags: Array = gs.auction_public_reason_tags(artifact, {}, "BID", {}) if not artifact.is_empty() else []
		var bridge_transition_ok: bool = reason_has(before_listing_tags, "PROVENANCE_UNCERTAIN") \
			and reason_has(before_reason_tags, "PROVENANCE_UNCERTAIN") \
			and bool(discovered.get("ok", false)) and String(discovered.get("code", "")) == "DISCOVERED" \
			and artifact.get("knownClues", []).count("PROVENANCE") == 1 \
			and reason_has(after_listing_tags, "PROVENANCE_STRONG") and reason_has(after_reason_tags, "PROVENANCE_STRONG")
		var duplicate_state_before: String = state_signature(gs)
		var duplicate_telemetry_before: Dictionary = gs.stage_run_state.get("telemetry", {}).duplicate(true)
		var duplicate_rng_before: int = int(gs.rng.state)
		var duplicate: Dictionary = gs.discover_case_evidence(case_id, tagged_id) if not tagged_id.is_empty() else {}
		var duplicate_ok: bool = bool(duplicate.get("ok", false)) and String(duplicate.get("code", "")) == "ALREADY_DISCOVERED" \
			and artifact.get("knownClues", []).count("PROVENANCE") == 1 \
			and state_signature(gs) == duplicate_state_before \
			and gs.stage_run_state.get("telemetry", {}) == duplicate_telemetry_before \
			and int(gs.rng.state) == duplicate_rng_before
		var hidden_variant: Dictionary = artifact.duplicate(true)
		hidden_variant["authenticityTruth"] = "FORGERY" if String(artifact.get("authenticityTruth", "")) != "FORGERY" else "GENUINE"
		hidden_variant["trueRarity"] = 99.0
		hidden_variant["trueHistoricalSignificance"] = 77.0
		hidden_variant["trueMarketBaseline"] = 999999
		hidden_variant["originalParts"] = 0
		hidden_variant["replacementParts"] = 99
		var hidden_invariant: bool = gs.listing_public_status_tags(hidden_variant, "UNCERTAIN") == after_listing_tags \
			and gs.auction_public_reason_tags(hidden_variant, {}, "BID", {}) == after_reason_tags
		var public_payload: Dictionary = gs.get_case_public_state(case_id)
		var raw_field_hidden: bool = not JSON.stringify(public_payload).contains("public_clue_id")
		var reload_ok: bool = true
		var reload_details: Dictionary = {"executed": false}
		if not reload_executed:
			reload_executed = true
			var payload_before_save: Dictionary = gs.save_payload().duplicate(true)
			var public_before_save: Dictionary = public_payload.duplicate(true)
			var telemetry_before_save: Dictionary = gs.stage_run_state.get("telemetry", {}).duplicate(true)
			var rng_before_save: int = int(gs.rng.state)
			var profile_before_save: Dictionary = gs.profile_payload().duplicate(true)
			var uid_before_save: String = String(artifact.get("uniqueId", ""))
			var ledger_before_save: Dictionary = gs.campaign_state.caseArtifactLedger.get(case_id, {}).duplicate(true)
			gs.persistence_enabled = true
			var saved: bool = bool(gs.save_game(SAVE_PATH))
			gs.persistence_enabled = false
			artifact.knownClues.erase("PROVENANCE")
			gs.stage_run_state.telemetry = gs.default_stage_telemetry(1)
			gs.rng.state = int(gs.rng.state) + 7
			var loaded: bool = bool(gs.load_game(SAVE_PATH))
			var restored_artifact: Dictionary = gs.find_case_artifact(case_id)
			var uid_exact: bool = String(restored_artifact.get("uniqueId", "")) == uid_before_save
			var clue_exact: bool = restored_artifact.get("knownClues", []).count("PROVENANCE") == 1
			var ledger_exact: bool = semantic_exact(gs.campaign_state.caseArtifactLedger.get(case_id, {}), ledger_before_save)
			var public_exact: bool = semantic_exact(gs.get_case_public_state(case_id), public_before_save)
			var telemetry_exact: bool = semantic_exact(gs.stage_run_state.get("telemetry", {}), telemetry_before_save)
			var rng_exact: bool = int(gs.rng.state) == rng_before_save
			var payload_exact: bool = semantic_exact(gs.save_payload(), payload_before_save)
			var profile_exact: bool = semantic_exact(gs.profile_payload(), profile_before_save)
			reload_ok = saved and loaded and uid_exact and clue_exact and ledger_exact \
				and public_exact and telemetry_exact and rng_exact and payload_exact and profile_exact
			reload_details = {"executed": true, "saved": saved, "loaded": loaded, "uidExact": uid_exact, "clueExact": clue_exact, "ledgerExact": ledger_exact, "publicExact": public_exact, "telemetryExact": telemetry_exact, "rngExact": rng_exact, "payloadExact": payload_exact, "profileExact": profile_exact, "loadError": gs.last_load_error}
		case_ok = case_ok and non_tagged_ok and bridge_transition_ok and duplicate_ok and hidden_invariant and raw_field_hidden and reload_ok
		bridge_ok = bridge_ok and case_ok
		var current_artifact: Dictionary = gs.find_case_artifact(case_id)
		bridge_evidence[case_id] = {"taggedRows": tagged.map(func(row: Dictionary): return {"id": row.get("id", ""), "sourceKind": row.get("source", {}).get("kind", ""), "publicClueId": row.get("public_clue_id", "")}), "nonTaggedRows": non_tagged_evidence, "nonTaggedNoAdditionalProvenance": non_tagged_ok, "beforeListingTags": before_listing_tags, "beforeReasonTags": before_reason_tags, "discovery": discovered, "knownClueCount": current_artifact.get("knownClues", []).count("PROVENANCE") if not current_artifact.is_empty() else -1, "afterListingTags": after_listing_tags, "afterReasonTags": after_reason_tags, "duplicate": duplicate, "duplicateMutation0": duplicate_ok, "hiddenTruthReasonInvariant": hidden_invariant, "rawPublicFieldHidden": raw_field_hidden, "reloadExact": reload_ok, "reload": reload_details, "ok": case_ok}
	cleanup_save(gs, SAVE_PATH)
	record(
		"S2-AUTHORED-BRIDGE-01",
		"Designated provenance discovery bridges once to public listing/auction reasons, non-tagged sources do not, hidden truth is irrelevant, and exact save/reload preserves the issued case",
		bridge_ok and reload_executed,
		{"cases": bridge_evidence, "reloadExecuted": reload_executed}
	)

	# Bilingual authored copy through the generic public UI, with no raw template,
	# identifier, bridge field, or hidden truth leakage.
	var main_value: Variant = load("res://scenes/Main.tscn")
	var main: Node = (main_value as PackedScene).instantiate() if main_value is PackedScene else null
	var locale_ok: bool = main != null
	var locale_evidence: Dictionary = {}
	if main != null:
		get_root().add_child(main)
		await settle_frames(5)
		for case_id: String in CASE_IDS:
			var definition: Dictionary = definitions[case_id]
			var fixture: Dictionary = begin_stage_two_case(gs, case_id)
			var artifact: Dictionary = fixture.get("artifact", {})
			gs.language = "ko"
			main.set("language", "ko")
			main.call("load_artifact", artifact)
			main.call("show_case_dossier", case_id)
			await settle_frames(6)
			var ko_copy: String = visible_copy(main)
			var ko_leaks: Array = raw_copy_leaks(ko_copy, definition, case_id)
			var public_state: Dictionary = gs.get_case_public_state(case_id)
			var public_json: String = JSON.stringify(public_state)
			var public_private_hidden: bool = not public_json.contains("canonical_hypothesis") \
				and not public_json.contains("winning_hypothesis") and not public_json.contains("authoring_truth") \
				and not public_json.contains("authenticityTruth") and not public_json.contains("trueMarket") \
				and not public_json.contains("public_clue_id")
			main.call("sync_public_interaction_state")
			var locale_state_before: String = locale_neutral_signature(gs)
			var locale_rng_before: int = int(gs.rng.state)
			main.call("toggle_language")
			await settle_frames(6)
			var en_copy: String = visible_copy(main)
			var en_leaks: Array = raw_copy_leaks(en_copy, definition, case_id)
			var case_ok: bool = authored_copy_complete(definition) \
				and not artifact.is_empty() and not ko_copy.is_empty() and not en_copy.is_empty() \
				and ko_copy != en_copy and ko_leaks.is_empty() and en_leaks.is_empty() \
				and public_private_hidden and String(main.get("screen")) == "case_dossier" \
				and locale_neutral_signature(gs) == locale_state_before and int(gs.rng.state) == locale_rng_before
			locale_ok = locale_ok and case_ok
			locale_evidence[case_id] = {"copyComplete": authored_copy_complete(definition), "koCharacters": ko_copy.length(), "enCharacters": en_copy.length(), "copyChanged": ko_copy != en_copy, "koLeaks": ko_leaks, "enLeaks": en_leaks, "publicPrivateHidden": public_private_hidden, "screen": main.get("screen"), "stateMutation0": locale_neutral_signature(gs) == locale_state_before, "rngMutation0": int(gs.rng.state) == locale_rng_before, "ok": case_ok}
		main.queue_free()
	record(
		"S2-AUTHORED-LOCALE-01",
		"All Stage 2 authored copy is complete in Korean and English through the public dossier without raw templates, IDs, bridge metadata, or hidden truth",
		locale_ok,
		locale_evidence
	)

	# Production implementation remains entirely generic: data names belong only
	# in authored files/tests, never in the gameplay resolver or renderer.
	var game_state_source: String = FileAccess.get_file_as_string("res://scripts/game_state.gd")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main3d.gd")
	var runtime_registry_source: String = FileAccess.get_file_as_string("res://scripts/runtime_registry.gd")
	var source_hits: Dictionary = {}
	var generic_ok: bool = game_state_source.contains("public_clue_id") and runtime_registry_source.contains("public_clue_id")
	for case_id: String in CASE_IDS:
		var hits: Dictionary = {
			"gameState": game_state_source.contains(case_id),
			"main3d": main_source.contains(case_id)
		}
		source_hits[case_id] = hits
		generic_ok = generic_ok and not bool(hits.gameState) and not bool(hits.main3d)
	generic_ok = generic_ok and gs.has_method("case_definition") and gs.has_method("get_case_public_state") \
		and gs.has_method("resolve_case_v2") and main != null
	record(
		"S2-AUTHORED-GENERIC-01",
		"Stage 2 authored cases use the generic registry, public dossier and resolver with no case-id branches in GameState or Main",
		generic_ok,
		{"caseIdHits": source_hits, "gameStatePublicClueAdapter": game_state_source.contains("public_clue_id"), "registryPublicClueNormalization": runtime_registry_source.contains("public_clue_id"), "genericMethods": {"caseDefinition": gs.has_method("case_definition"), "publicState": gs.has_method("get_case_public_state"), "resolve": gs.has_method("resolve_case_v2"), "rendererScene": main != null}}
	)

	gs.persistence_enabled = false
	write_report_and_quit()
