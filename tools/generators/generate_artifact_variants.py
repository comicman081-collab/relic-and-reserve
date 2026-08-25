from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]; out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'data/artifacts/generated_variants_r2.json'; out.parent.mkdir(parents=True,exist_ok=True)
items=[{'id':f'variant_r2_{i+1:03d}','model':f'artifact_{(i%8)+1:02d}','material':['brass','wood_dark','painted_metal'][i%3],'damage':['DUST','TARNISH','SCRATCH'][i%3]} for i in range(16)]
out.write_text(json.dumps(items,indent=2)); print(out)
