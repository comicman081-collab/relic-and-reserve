extends "res://scripts/runtime_registry.gd"

## Test-only RuntimeRegistry seam for exercising required-pair fail-closed
## behavior. Production constants remain read-only and untouched.

var injected_story_artifact_id := ""
var injected_spec_id := ""
var injected_override: Dictionary = {}


func configure_pair_override(story_artifact_id: String, spec_id: String, override_value: Dictionary) -> void:
	injected_story_artifact_id = story_artifact_id
	injected_spec_id = spec_id
	injected_override = override_value.duplicate(true)


func get_story_artifact_render_override(story_artifact_id: String, spec_id: String) -> Dictionary:
	if story_artifact_id == injected_story_artifact_id and spec_id == injected_spec_id:
		return injected_override.duplicate(true)
	return {}
