from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]; errors=[]; ids=set(); files=0
for p in root.glob('data/**/*.json'):
    if p.name=='index.json': continue
    files+=1
    try: d=json.loads(p.read_text(encoding='utf-8'))
    except Exception as e: errors.append(f'{p}: {e}'); continue
    items=d if isinstance(d,list) else [d]
    for x in items:
        if isinstance(x,dict) and 'id' in x:
            if x['id'] in ids: errors.append('duplicate '+x['id'])
            ids.add(x['id'])
            if 'price' in x and x['price']<0: errors.append('negative price '+x['id'])
            if 'cost' in x and x['cost']<0: errors.append('negative cost '+x['id'])
print(json.dumps({'files':files,'unique_ids':len(ids),'errors':errors},indent=2))
raise SystemExit(1 if errors else 0)
