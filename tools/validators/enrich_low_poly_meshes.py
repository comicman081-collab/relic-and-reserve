from pathlib import Path
root=Path(__file__).resolve().parents[2]
def enrich(p:Path,dx:float,dy:float,dz:float):
    text=p.read_text()
    verts=[]; faces=[]
    for line in text.splitlines():
        if line.startswith('v '):
            _,x,y,z=line.split(); verts.append((float(x),float(y),float(z)))
    start=len(verts)+1
    sx=0.18; sy=0.12; sz=0.18
    cx,cy,cz=dx,dy,dz
    verts += [(cx-sx,cy-sy,cz-sz),(cx+sx,cy-sy,cz-sz),(cx+sx,cy+sy,cz-sz),(cx-sx,cy+sy,cz-sz),(cx-sx,cy-sy,cz+sz),(cx+sx,cy-sy,cz+sz),(cx+sx,cy+sy,cz+sz),(cx-sx,cy+sy,cz+sz)]
    faces=[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(4,0,3,7)]
    out=text.rstrip()+"\ng component\nusemtl brass\n"+"\n".join('v %.4f %.4f %.4f'%v for v in verts[-8:])+"\n"
    for a,b,c,d in faces: out += 'f %d %d %d %d\n'%(start+a,start+b,start+c,start+d)
    p.write_text(out)
for p in list((root/'assets/workshop_props').glob('*.obj')):
    verts=sum(1 for l in p.read_text().splitlines() if l.startswith('v '))
    if verts<=8: enrich(p,0.0,0.55,0.0)
for p in list((root/'assets/artifacts/parts').glob('*.obj')):
    verts=sum(1 for l in p.read_text().splitlines() if l.startswith('v '))
    if verts<=8: enrich(p,0.35,0.0,0.0)
print('enriched low-poly secondary meshes')
