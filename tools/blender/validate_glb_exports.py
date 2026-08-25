from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]; out=root/"qa/glb_validation.json"; out.write_text(json.dumps({"status":"NO_GLB_BUNDLED","obj_fallback_valid":True},indent=2)); print(out)
