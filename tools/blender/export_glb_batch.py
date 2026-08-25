from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]; out=root/"qa/glb_export_manifest.json"; out.write_text(json.dumps({"status":"GLB_EXPORT_UNAVAILABLE","fallback":"OBJ","files":[str(p.relative_to(root)) for p in (root/"assets/artifacts").glob("*.obj")]},indent=2)); print(out)
