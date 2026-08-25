from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]; out=root/"qa/damage_variant_application.json"; out.write_text(json.dumps({"states":["DIRTY","PARTIALLY_RESTORED","RESTORED"],"artifacts":["clock","camera","radio"]},indent=2)); print(out)
