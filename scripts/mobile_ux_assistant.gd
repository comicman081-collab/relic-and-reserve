extends Node

# Compatibility autoload kept for the mobile UX contract. The actual portrait
# case/tutor presentation now lives in MobileCaseTutorialUX so this node stays
# deliberately small and cannot destabilize the existing mobile shell.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
