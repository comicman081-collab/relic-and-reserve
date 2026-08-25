from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]; idx=json.loads((root/'data/artifacts/index.json').read_text()); missing=[]
for s in idx:
    p=root/'assets/artifacts'/s['baseModel']
    if not p.exists(): missing.append({'id':s['id'],'path':str(p)})
print(json.dumps({'playable_specs':len(idx),'resolved':len(idx)-len(missing),'missing':missing},indent=2)); raise SystemExit(1 if missing else 0)
