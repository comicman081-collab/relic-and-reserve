extends SceneTree

## Commission contract and compact UI acceptance.  This is a deterministic
## headless test; it never writes a player save and does not expose hidden truth
## to the UI projection.

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Dictionary) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func settle_ui(frame_count: int = 4) -> void:
	for _frame: int in range(frame_count):
		await process_frame


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.reset_game()
	gs.persistence_enabled = false
	var artifact: Dictionary = gs.new_artifact("artifact_001", 991001, "commission_contract_lot")
	artifact.inspected = true
	artifact.confidence = 0.92
	artifact.knownClues = ["MATERIAL", "PATINA", "REPAIR_TRACE"]
	artifact.cleanliness = 100.0
	artifact.surfaceCondition = 100.0
	artifact.structuralCondition = 100.0
	artifact.mechanicalCondition = 100.0
	artifact.historicalIntegrity = 100.0
	gs.inventory.append(artifact)
	var before_money: int = gs.money
	var before_transactions: int = gs.transactions.size()
	var public_rows: Array = gs.get_commission_public_state()
	var first_row: Dictionary = public_rows[0] if not public_rows.is_empty() else {}
	var eligible: Array = first_row.get("eligibleArtifacts", []) if first_row.get("eligibleArtifacts", []) is Array else []
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()
	main.language = "ko"
	main.show_commissions()
	await settle_ui()
	var grid: Control = main.find_child("CommissionGrid", true, false)
	var cards := main.find_children("CommissionCard_*", "PanelContainer", true, false)
	var use_button: Button = main.find_child("CommissionUse_commission_01_commission_contract_lot", true, false)
	var surface := ""
	for label: Label in main.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			surface += label.text + "\n"
	var first_result: Dictionary = gs.complete_commission_from_artifact("commission_01", artifact.uniqueId)
	var reuse_result: Dictionary = gs.complete_commission_from_artifact("commission_02", artifact.uniqueId)
	var commission_transactions: Array = gs.transactions.filter(func(row: Dictionary): return String(row.get("type", "")) == "commission")
	record(
		"COMMISSION-CONTRACT-01",
		"One eligible lot completes one commission exactly once and cannot be reused for a second commission",
		bool(first_result.get("ok", false)) and int(gs.money) > before_money and gs.transactions.size() == before_transactions + 1 \
			and commission_transactions.size() == 1 and String(reuse_result.get("code", "")) == "ARTIFACT_ALREADY_COMMISSIONED" \
			and String(gs.campaign_state.commissionArtifactUses.get(artifact.uniqueId, "")) == "commission_01",
		{"first": first_result, "reuse": reuse_result, "moneyBefore": before_money, "moneyAfter": gs.money, "transactions": commission_transactions, "eligibleBefore": eligible}
	)
	record(
		"COMMISSION-UI-02",
		"The Korean service board exposes five compact cards and a primary Use button for an eligible lot without raw identifiers",
		grid != null and cards.size() == 5 and use_button != null and not surface.contains("commission_01") and not surface.contains("commission_contract_lot"),
		{"grid": grid != null, "cards": cards.size(), "useButton": use_button != null, "rawIdLeak": surface.contains("commission_01") or surface.contains("commission_contract_lot")}
	)
	main.queue_free()
	await process_frame
	var passed := results.all(func(row: Dictionary): return bool(row.get("passed", false)))
	var report := {"suite": "R3 Commission Contract", "executed": results.size(), "passed": results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size(), "failed": results.filter(func(row: Dictionary): return not bool(row.get("passed", false))).size(), "tests": results}
	var file := FileAccess.open("res://qa/R3_COMMISSION_CONTRACT_TESTS.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = true
	quit(0 if passed else 1)
