from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]; out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'data/upgrades/generated_r2.json'; out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps([{"id":f"generated_upgrade_{i+1:02d}","name":f"Generated Upgrade {i+1}","cost":150+i*25,"effect":"quality_bonus"} for i in range(10)],indent=2)); print(out)
