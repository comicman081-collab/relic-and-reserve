from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[2]; report={'meshes':[],'duplicate_svg_hashes':[],'zero_byte':[],'stubs':[]}
for p in root.glob('assets/**/*.obj'):
    text=p.read_text(errors='ignore'); report['meshes'].append({'path':str(p.relative_to(root)),'vertices':text.count('\nv ')+int(text.startswith('v ')),'groups':text.count('\ng ')})
for p in root.glob('assets/**/*.svg'):
    if p.stat().st_size==0: report['zero_byte'].append(str(p))
seen={}
for p in root.glob('assets/**/*.svg'):
    h=hashlib.sha256(p.read_bytes()).hexdigest(); seen.setdefault(h,[]).append(str(p.relative_to(root)))
report['duplicate_svg_hashes']=[v for v in seen.values() if len(v)>1]
(root/'qa/R2_ASSET_AUDIT.json').write_text(json.dumps(report,indent=2)); print(json.dumps(report,indent=2)); raise SystemExit(1 if report['zero_byte'] or report['duplicate_svg_hashes'] else 0)
