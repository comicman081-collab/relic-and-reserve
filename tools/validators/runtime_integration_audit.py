from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
main=(root/'scripts/main3d.gd').read_text(); reg=(root/'scripts/runtime_registry.gd').read_text(); gs=(root/'scripts/game_state.gd').read_text()
checks={'ArtifactSpecs':'index.json' in reg and 'runtime_model_paths' in reg,'Makers':'makers.json' in reg,'Tools':'tools.json' in reg,'Bidders':'bidders.json' in reg and 'get_bidder' in reg,'Events':'events.json' in reg and 'execute_event' in gs,'Upgrades':'upgrades.json' in reg and 'buy_upgrade' in gs,'Localization':'localization' in reg,'Audio':len(list((root/'audio').glob('*.wav')))>=10,'Materials':len(list((root/'assets/materials').glob('*.tres')))>=15,'Node3D':'extends Node3D' in main,'ModelLoading':'load(path)' in main}
(root/'qa/R2_RUNTIME_INTEGRATION_AUDIT.json').write_text(json.dumps(checks,indent=2)); print(json.dumps(checks,indent=2)); raise SystemExit(0 if all(checks.values()) else 1)
