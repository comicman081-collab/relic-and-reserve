from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]; files=sorted(str(p.relative_to(root)) for p in (root/"assets/materials").glob("*.tres")); (root/"qa/material_generation.json").write_text(json.dumps({"generated":files},indent=2)); print(len(files))
