from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
root=Path(__file__).resolve().parents[2]
font=ImageFont.load_default()
def sheet(out_dir,prefix,count,title):
    out_dir.mkdir(parents=True,exist_ok=True); cols=8; cell=150; rows=(count+cols-1)//cols
    im=Image.new('RGB',(cols*cell,rows*cell),(35,39,42)); d=ImageDraw.Draw(im)
    for i in range(count):
        x=(i%cols)*cell; y=(i//cols)*cell; d.rounded_rectangle((x+10,y+10,x+140,y+140),radius=14,fill=(80+(i%4)*25,65+(i%3)*18,45+(i%5)*12),outline=(232,216,178),width=2); d.text((x+25,y+68),f'{prefix} {i+1:03d}',fill=(245,235,210),font=font)
    d.text((12,rows*cell-18),title,fill=(245,235,210),font=font); im.save(out_dir/f'{prefix.lower()}_sheet.png')
out=root/'qa/contact_sheets'; sheet(out,'ICON',100,'Procedural UI icon inventory'); sheet(out,'PROP',35,'Procedural workshop prop inventory'); sheet(out,'MESH',15,'Procedural artifact base inventory')
