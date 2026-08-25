extends SceneTree

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, condition: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": condition, "evidence": evidence})


func begin_false_invoice(gs: Node) -> Dictionary:
	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_state.currentAct = "ACT_2"
	return gs.begin_case("false_invoice")


func discover_all(gs: Node, case_id: String) -> Array:
	var discoveries: Array = []
	for _pass in range(12):
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var progressed := false
		for row: Dictionary in public_state.get("availableEvidence", []):
			if not row.get("requiredTools", []).is_empty():
				gs.select_tool(String(row.requiredTools[0]))
			var result: Dictionary = gs.discover_case_evidence(case_id, row.id)
			if bool(result.get("ok", false)) and result.get("code", "") == "DISCOVERED":
				discoveries.append(row.id)
				progressed = true
		if not progressed:
			break
	return discoveries


func has_relation(row: Dictionary, hypothesis_id: String, stance: String) -> bool:
	for relation: Dictionary in row.get("relations", []):
		if relation.get("hypothesis_id", "") == hypothesis_id and relation.get("stance", "") == stance:
			return true
	return false


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	var definition: Dictionary = registry.get_case_v2("false_invoice")
	var document_rows: Array = definition.get("evidence", []).filter(
		func(row: Dictionary): return row.get("source", {}).get("kind", "") == "DOCUMENT"
	)
	var document_groups: Array = document_rows.map(func(row: Dictionary): return row.get("independence_key", ""))
	var document_reliability: Array = document_rows.map(func(row: Dictionary): return row.get("reliability", ""))
	record(
		"M3-DATA-01",
		"False Invoice authored-v2 definition loads with bilingual reactions and all runtime source indexes",
		registry.authored_case_errors.is_empty()
			and not definition.is_empty()
			and int(definition.get("schema_version", 0)) == 2
			and definition.get("hypotheses", []).size() == 3
			and definition.get("evidence", []).size() == 6
			and not String(definition.get("success", {}).get("en", "")).is_empty()
			and not String(definition.get("success", {}).get("ko", "")).is_empty()
			and registry.document_to_cases.get("document_10", []).count("false_invoice") == 1
			and registry.npc_to_cases.get("noah_stern", []).has("false_invoice")
			and registry.reference_to_cases.get("period_ref_12", []).has("false_invoice"),
		{"errors": registry.authored_case_errors, "hypotheses": definition.get("hypotheses", []).size(), "evidence": definition.get("evidence", []).size()}
	)

	record(
		"M3-PROVENANCE-01",
		"Two entries from the same invoice share one independence group and expose the low-reliability provenance note",
		document_rows.size() == 2
			and document_rows.all(func(row: Dictionary): return row.get("source", {}).get("ref_id", "") == "document_10")
			and document_groups.size() == 2
			and document_groups[0] == document_groups[1]
			and document_reliability.has("LOW"),
		{"groups": document_groups, "reliability": document_reliability}
	)

	var invoice_face: Dictionary = {}
	var noah_ledger: Dictionary = {}
	for evidence: Dictionary in definition.get("evidence", []):
		if evidence.get("id", "") == "src.false_invoice.document.invoice_face":
			invoice_face = evidence
		if evidence.get("id", "") == "src.false_invoice.npc.noah_ledger":
			noah_ledger = evidence
	record(
		"M3-CONFLICT-01",
		"The document claim and archive comparison form an explicit support/refute conflict",
		has_relation(invoice_face, "hyp.genuine_1927_invoice", "SUPPORT")
			and has_relation(invoice_face, "hyp.authentic_box_false_invoice", "REFUTE")
			and has_relation(noah_ledger, "hyp.genuine_1927_invoice", "REFUTE")
			and has_relation(noah_ledger, "hyp.authentic_box_false_invoice", "SUPPORT"),
		{"invoiceRelations": invoice_face.get("relations", []), "noahRelations": noah_ledger.get("relations", [])}
	)

	var artifact := begin_false_invoice(gs)
	var initial_public: Dictionary = gs.get_case_public_state("false_invoice")
	var public_json := JSON.stringify(initial_public)
	var reverse_locked: Dictionary = gs.discover_case_evidence("false_invoice", "src.false_invoice.document.reverse_provenance")
	record(
		"M3-UNLOCK-01",
		"The reverse-side provenance echo is locked until the invoice face is recorded",
		not artifact.is_empty()
			and not bool(reverse_locked.get("ok", true))
			and reverse_locked.get("code", "") == "EVIDENCE_LOCKED",
		reverse_locked
	)
	record(
		"M3-PRIVACY-01",
		"Public dossier shows reliability without leaking the authored answer",
		not public_json.contains("canonical_hypothesis")
			and not public_json.contains("winning_hypothesis")
			and not public_json.contains("authoring_truth")
			and initial_public.get("evidence", []).all(func(row: Dictionary): return row.has("reliability")),
		initial_public.keys()
	)

	artifact = begin_false_invoice(gs)
	gs.discover_case_evidence("false_invoice", "src.false_invoice.document.invoice_face")
	gs.discover_case_evidence("false_invoice", "src.false_invoice.document.reverse_provenance")
	var echoed_claim: Dictionary = gs.evaluate_case_submission(
		"false_invoice",
		"hyp.genuine_1927_invoice",
		[
			"src.false_invoice.document.invoice_face",
			"src.false_invoice.document.reverse_provenance"
		]
	)
	record(
		"M3-INDEPENDENCE-01",
		"Citing both sides of one invoice counts as one source and cannot substantiate the claim",
		bool(echoed_claim.get("ok", false))
			and int(echoed_claim.get("independentSourceCount", -1)) == 1
			and echoed_claim.get("substantiation", "") == "INCONCLUSIVE"
			and not bool(echoed_claim.get("substantiated", true)),
		echoed_claim
	)

	artifact = begin_false_invoice(gs)
	var discoveries := discover_all(gs, "false_invoice")
	var complete_public: Dictionary = gs.get_case_public_state("false_invoice")
	var source_kinds: Array = complete_public.get("discoveredEvidence", []).map(func(row: Dictionary): return row.get("sourceKind", ""))
	var masterful: Dictionary = gs.resolve_case_v2(
		"false_invoice",
		"hyp.authentic_box_false_invoice",
		[
			"src.false_invoice.artifact.box_joinery",
			"src.false_invoice.document.invoice_face",
			"src.false_invoice.npc.noah_ledger",
			"src.false_invoice.reference.reserve_numbering"
		]
	)
	record(
		"M3-REPORT-01",
		"A cross-source report can accept the invoice's conflicting claim and still reach the masterful conclusion",
		discoveries.size() == 6
			and ["ARTIFACT", "DOCUMENT", "NPC", "REFERENCE"].all(func(kind: String): return source_kinds.has(kind))
			and bool(masterful.get("ok", false))
			and bool(masterful.get("conclusionAccurate", false))
			and bool(masterful.get("substantiated", false))
			and masterful.get("outcome", "") == "masterful"
			and bool(masterful.get("requiredSourcesMet", false))
			and int(masterful.get("independentSourceCount", 0)) >= 3,
		{"discoveries": discoveries, "sourceKinds": source_kinds, "result": masterful}
	)

	var passed := 0
	for result: Dictionary in results:
		if result.passed:
			passed += 1
	var report := {
		"suite": "R3 False Invoice Authored Case",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"tests": results
	}
	var output := FileAccess.open("res://qa/R3_FALSE_INVOICE_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
