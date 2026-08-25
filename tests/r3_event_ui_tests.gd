extends SceneTree

## Friendly/localized event presentation regression. Runs headlessly and never
## changes the authoritative event application rules or creates export files.

var results: Array = []
var snake_case_regex := RegEx.new()


func _init() -> void:
	snake_case_regex.compile("[A-Za-z][A-Za-z0-9]*_[A-Za-z0-9_]+")
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func has_raw_snake_case(value: String) -> bool:
	return snake_case_regex.search(value) != null


func player_facing_text(root: Node) -> String:
	var fragments: Array = []
	for control: Control in root.find_children("*", "Control", true, false):
		if control is Label:
			fragments.append(control.text)
		elif control is Button:
			fragments.append(control.text)
		if not control.tooltip_text.is_empty():
			fragments.append(control.tooltip_text)
	return "\n".join(fragments)


func expected_signed_integer(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func expected_effect_value(effect: Dictionary, amount: float) -> String:
	var effect_type := String(effect.get("type", ""))
	var target := String(effect.get("target", ""))
	if effect_type in ["money", "commission_credit"] or target == "money":
		return "¤ %s" % expected_signed_integer(int(amount))
	if effect_type.contains("bonus") or effect_type.contains("discount") or target.contains("bonus") or target.contains("discount"):
		return "%s%%" % expected_signed_integer(roundi(amount * 100.0))
	return expected_signed_integer(int(amount))


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	gs.reset_game()
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame

	var coverage_failures: Array = []
	var percent_formats: Dictionary = {}
	var localized_copy_entries: int = registry.events.filter(func(event: Dictionary): return event.get("localizedName", {}).get("en", "") != "" and event.get("localizedName", {}).get("ko", "") != "" and event.get("localizedDescription", {}).get("en", "") != "" and event.get("localizedDescription", {}).get("ko", "") != "").size()
	for locale: String in ["en", "ko"]:
		main.language = locale
		gs.language = locale
		for event: Dictionary in registry.events:
			var event_id := String(event.get("id", ""))
			var effect: Dictionary = event.get("effect", {})
			var amount := float(effect.get("amount", 0.0))
			var title: String = main.event_public_title(event_id)
			var description: String = main.event_public_description(event_id)
			var label: String = main.event_effect_label(String(effect.get("type", "")))
			var value: String = main.event_effect_value(effect, amount)
			var fact: String = main.event_effect_fact(effect, amount)
			var expected_value := expected_effect_value(effect, amount)
			var friendly: bool = not title.is_empty() \
				and not description.is_empty() \
				and not label.is_empty() \
				and title.length() <= 40 \
				and description.length() <= 80 \
				and value == expected_value \
				and fact == "%s · %s" % [label, value] \
				and not has_raw_snake_case("%s %s %s %s" % [title, description, label, fact]) \
				and not description.contains("Daily effect:") \
				and (locale != "ko" or (title != String(event.get("name", "")) and description != String(event.get("description", ""))))
			if not friendly:
				coverage_failures.append({"locale": locale, "event": event_id, "title": title, "description": description, "label": label, "value": value, "expected": expected_value, "fact": fact})
			if locale == "en" and (String(effect.get("type", "")).contains("bonus") or String(effect.get("type", "")).contains("discount")):
				percent_formats[event_id] = value
	record(
		"EVENT-UI-01",
		"All 25 events have compact KO/EN title, description, friendly effect label and type-correct value formatting",
		registry.events.size() == 25 and localized_copy_entries == 25 and coverage_failures.is_empty() and not FileAccess.get_file_as_string("res://scripts/main3d.gd").contains("EVENT_PUBLIC_COPY"),
		{"events": registry.events.size(), "localizedCopyEntries": localized_copy_entries, "failures": coverage_failures, "percentFormats": percent_formats}
	)

	var render_failures: Array = []
	main.language = "ko"
	gs.language = "ko"
	for event: Dictionary in registry.events:
		var event_id := String(event.get("id", ""))
		var effect: Dictionary = event.get("effect", {})
		var amount := float(effect.get("amount", 0.0))
		var result := {"eventId": event_id, "name": event.get("name", ""), "effect": effect.duplicate(true), "appliedAmount": amount}
		var title: String = main.event_public_title(event_id)
		var description: String = main.event_public_description(event_id)
		var label: String = main.event_effect_label(String(effect.get("type", "")))
		var fact: String = main.event_effect_fact(effect, amount)
		main.event_cue_state = "REQUEST"
		main.show_event_dialogue(result)
		await process_frame
		var request_text := player_facing_text(main)
		var mapping: Dictionary = main.event_character_mapping(event_id)
		main.event_cue_state = "REACTION_NEG" if mapping.get("outcomePolarity", "") == "NEGATIVE" else "REACTION_POS"
		main.show_event_dialogue(result)
		await process_frame
		var resolve_text := player_facing_text(main)
		var request_clean: bool = request_text.contains(title) \
			and request_text.contains(description) \
			and request_text.contains(label) \
			and not request_text.contains(String(event.get("description", ""))) \
			and not request_text.contains(String(event.get("name", ""))) \
			and not has_raw_snake_case(request_text)
		var resolve_clean: bool = resolve_text.contains(title) \
			and resolve_text.contains(description) \
			and resolve_text.contains(fact) \
			and not resolve_text.contains(String(event.get("description", ""))) \
			and not resolve_text.contains(String(event.get("name", ""))) \
			and not has_raw_snake_case(resolve_text)
		if not request_clean or not resolve_clean:
			render_failures.append({"event": event_id, "requestClean": request_clean, "resolveClean": resolve_clean, "title": title, "description": description, "fact": fact, "request": request_text, "resolve": resolve_text})
	record(
		"EVENT-UI-02",
		"REQUEST and RESOLVE render friendly Korean copy for all 25 events with zero raw snake_case tokens",
		render_failures.is_empty(),
		render_failures
	)

	gs.reset_game()
	gs.persistence_enabled = false
	main.language = "ko"
	var money_before := int(gs.money)
	var money_result: Dictionary = gs.execute_event("event_01", false)
	var money_applied := int(gs.money) - money_before
	var money_display: String = main.event_effect_value(money_result.get("effect", {}), float(money_result.get("appliedAmount", 0.0)))

	gs.daily_modifiers = {}
	var percent_result: Dictionary = gs.execute_event("event_09", false)
	var percent_applied := float(gs.daily_modifiers.get("rarity_bonus", 0.0))
	var percent_display: String = main.event_effect_value(percent_result.get("effect", {}), float(percent_result.get("appliedAmount", 0.0)))

	gs.daily_modifiers = {}
	var slots_result: Dictionary = gs.execute_event("event_13", false)
	var slots_applied := int(gs.daily_modifiers.get("market_slots", 0))
	var slots_display: String = main.event_effect_value(slots_result.get("effect", {}), float(slots_result.get("appliedAmount", 0.0)))

	var trust_before := int(gs.campaign_state.museumTrust)
	var trust_result: Dictionary = gs.execute_event("event_04", false)
	var trust_applied := int(gs.campaign_state.museumTrust) - trust_before
	var trust_display: String = main.event_effect_value(trust_result.get("effect", {}), float(trust_result.get("appliedAmount", 0.0)))

	gs.inventory = []
	gs.daily_modifiers = {}
	var damage_result: Dictionary = gs.execute_event("event_08", false)
	var damage_applied := int(gs.daily_modifiers.get("pending_damage", 0))
	var damage_display: String = main.event_effect_value(damage_result.get("effect", {}), float(damage_result.get("appliedAmount", 0.0)))

	var application_ok: bool = money_applied == 120 \
		and money_display == "¤ +120" \
		and absf(percent_applied - 0.12) < 0.000001 \
		and percent_display == "+12%" \
		and not percent_display.contains("+0") \
		and slots_applied == -1 \
		and slots_display == "-1" \
		and trust_applied == 2 \
		and trust_display == "+2" \
		and damage_applied == 1 \
		and damage_display == "+1"
	record(
		"EVENT-UI-03",
		"Representative authoritative event applications match currency, percent, slot, trust and count displays",
		application_ok,
		{"money": [money_applied, money_display], "percent": [percent_applied, percent_display], "slots": [slots_applied, slots_display], "trust": [trust_applied, trust_display], "damage": [damage_applied, damage_display]}
	)

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Event UI", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_EVENT_UI_TESTS.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	main.queue_free()
	quit(0 if passed == results.size() else 1)
