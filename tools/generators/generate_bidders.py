from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]; out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'data/bidders/generated_r2.json'; out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps([{"id":f"generated_bidder_{i+1:02d}","name":f"Generated Bidder {i+1}","budget":500+i*50,"riskTolerance":0.3+i*0.04} for i in range(8)],indent=2)); print(out)
