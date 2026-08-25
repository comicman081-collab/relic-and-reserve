from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]; out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'data/damages/generated_presets.json'; out.parent.mkdir(parents=True,exist_ok=True)
d=["DUST","GRIME","RUST","SCRATCH","CRACK","MISSING_PART","TARNISH","PAINT_LOSS"]; out.write_text(json.dumps([{"id":x,"visual":"Damage_"+x,"penalty":i*0.04} for i,x in enumerate(d)],indent=2)); print(out)
