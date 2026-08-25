from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'assets/icons_r2'
out.mkdir(parents=True,exist_ok=True)
shapes=[
'<rect x="18" y="25" width="68" height="55" rx="7"/><circle cx="52" cy="52" r="18" fill="#d6b36a"/>',
'<rect x="15" y="35" width="74" height="35" rx="6"/><circle cx="34" cy="52" r="12"/><circle cx="70" cy="52" r="12"/>',
'<path d="M18 72h70V34H18zM26 28h54"/><circle cx="52" cy="52" r="10" fill="#d6b36a"/>',
'<path d="M22 78V35l30-15 30 15v43z"/><path d="M52 20v58M28 46h48"/>',
'<path d="M20 68h64M26 62V30h52v32"/><path d="M35 30v-9h34v9"/>',
'<circle cx="52" cy="52" r="28"/><path d="M52 52l17-10M52 52l-9 17"/><circle cx="52" cy="52" r="4" fill="#d6b36a"/>',
'<path d="M18 75l15-48h38l15 48z"/><path d="M32 27h36M36 45h32"/>',
'<rect x="20" y="30" width="64" height="45" rx="9"/><path d="M30 39h44M30 51h44M30 63h24"/>',
'<path d="M20 72h64M28 72V36h48v36"/><circle cx="38" cy="50" r="5" fill="#d6b36a"/><circle cx="66" cy="50" r="5" fill="#d6b36a"/>',
'<path d="M23 72h58M28 65V28h42v37M38 28v-8h22v8"/><path d="M36 44h26"/>',
'<path d="M25 70h54L68 30H36z"/><path d="M36 30h32M42 48h20"/>',
'<circle cx="52" cy="52" r="27"/><path d="M52 28v48M28 52h48"/><path d="M52 52l14-14"/>',
'<path d="M22 72V34h60v38z"/><path d="M30 44h44M30 56h44M30 65h20"/>',
'<path d="M52 18l10 23 25 2-19 16 6 24-22-13-22 13 6-24-19-16 25-2z"/>',
'<path d="M28 72V30h48v42M38 30V18h28v12"/><circle cx="52" cy="51" r="12"/>',
'<rect x="25" y="30" width="54" height="44" rx="5"/><path d="M34 40h36M34 52h36M34 64h20"/>',
'<path d="M25 75h54M32 75V38h40v37M40 38v-9h24v9"/><circle cx="52" cy="52" r="10" fill="#d6b36a"/>',
'<path d="M19 70l17-38h32l17 38z"/><path d="M36 32v38M68 32v38"/>',
'<circle cx="52" cy="52" r="28"/><path d="M52 25v54M25 52h54M33 33l38 38M71 33L33 71"/>',
'<path d="M20 70h64M27 70V31h50v39M36 31v-8h32v8"/><path d="M39 47h26v14H39z"/>',
]
for i in range(40):
    shape=shapes[i%len(shapes)]
    col=['#b98c4a','#8aa2a5','#d6b36a','#9b5d3f','#76906d'][i%5]
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 104 104"><rect width="104" height="104" rx="18" fill="#252a2e"/><g fill="{col}" stroke="#f2e8cf" stroke-width="3" stroke-linejoin="round">{shape}<path d="M {10+i} 92h{5+(i%7)}" stroke="#d6b36a"/></g></svg>'
    (out/f'icon_r2_{i+1:02d}.svg').write_text(svg)
print(f'generated {len(shapes)*2} distinct-silhouette R2 icon outputs in {out}')
