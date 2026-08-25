from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]; out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'data/artifacts/generated_variants.json'; out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps([{"id":f"runtime_variant_{i:03d}","mesh":"model_%02d.obj"%((i%12)+1),"material":["brass","glass","aged_wood"][i%3]} for i in range(24)],indent=2)); print(out)
