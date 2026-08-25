from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]; out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'data/markets/generated_profiles.json'; out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps([{"id":f"generated_market_{i+1:02d}","category":c,"trend":i-3} for i,c in enumerate(["mechanical_instruments","vintage_audio","optical_devices","ceramics","office_machines","scientific_instruments"])],indent=2)); print(out)
