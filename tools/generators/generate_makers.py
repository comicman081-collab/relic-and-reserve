from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]; out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'data/makers/generated_r2.json'; out.parent.mkdir(parents=True,exist_ok=True)
items=[{"makerId":f"generated_maker_{i+1:02d}","name":f"R2 Workshop Maker {i+1}","specialty":["horology","optics","audio"][i%3],"collectorReputation":50+i} for i in range(8)]
out.write_text(json.dumps(items,indent=2)); print(out)
