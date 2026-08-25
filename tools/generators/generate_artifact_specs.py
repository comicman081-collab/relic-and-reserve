from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]; out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'data/artifacts/generated_r2.json'; out.parent.mkdir(parents=True,exist_ok=True)
items=[]
for i in range(8): items.append({'id':f'generated_r2_{i+1:03d}','displayName':f'Generated R2 Lot {i+1}','baseModel':f'model_{(i%8)+1:02d}.obj','category':'mechanical_instruments','baseValue':180+i*20})
out.write_text(json.dumps(items,indent=2)); print(out)
