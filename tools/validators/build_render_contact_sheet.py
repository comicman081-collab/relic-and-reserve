from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[2]; files=sorted((root/'qa/renders').glob('*.png')); thumbs=[]
for p in files:
    im=Image.open(p).convert('RGB'); im.thumbnail((320,180)); canvas=Image.new('RGB',(340,220),(30,32,35)); canvas.paste(im,((340-im.width)//2,8)); ImageDraw.Draw(canvas).text((10,192),p.stem,fill=(240,230,205)); thumbs.append(canvas)
cols=3; rows=(len(thumbs)+cols-1)//cols; sheet=Image.new('RGB',(cols*340,rows*220),(20,22,24))
for i,im in enumerate(thumbs): sheet.paste(im,((i%cols)*340,(i//cols)*220))
sheet.save(root/'qa/contact_sheets/r2_render_evidence.png'); print(root/'qa/contact_sheets/r2_render_evidence.png')
