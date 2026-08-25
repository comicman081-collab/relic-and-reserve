from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]; files=sorted(str(p.relative_to(root)) for p in (root/"assets/artifacts").glob("*.obj")); (root/"qa/artifact_base_generation.json").write_text(json.dumps({"generated":files,"backend":"procedural_obj_fallback"},indent=2)); print(len(files))
