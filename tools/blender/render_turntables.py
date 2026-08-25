from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]; out=root/"qa/renders/turntable_manifest.json"; out.write_text(json.dumps({"status":"HEADLESS_RENDER_UNAVAILABLE","targets":["clock","camera","radio"]},indent=2)); print(out)
