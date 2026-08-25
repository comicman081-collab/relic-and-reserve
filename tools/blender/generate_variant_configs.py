from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]; out=root/"qa/variant_configs_r2.json"; out.write_text(json.dumps([{"id":f"v{i:03d}","mesh":"model_%02d.obj"%((i%12)+1)} for i in range(40)],indent=2)); print(out)
