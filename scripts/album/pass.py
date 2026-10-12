"""Maquette du pass de saison : python3 scripts/album/pass.py [sortie.html]
Les icônes viennent de scripts/album/pass-icons/ (rendues par pass-icons.mjs), réduites et intégrées dans la page."""
import sys,os,io,json,base64
from PIL import Image
ICI=os.path.dirname(os.path.abspath(__file__)); D=os.path.join(ICI,'pass-icons')
icons={}
for f in sorted(os.listdir(D)):
    if not f.endswith('.png'):continue
    im=Image.open(os.path.join(D,f)).convert('RGBA');im.thumbnail((200,200))
    b=io.BytesIO();im.save(b,'PNG',optimize=True);icons[f[:-4]]='data:image/png;base64,'+base64.b64encode(b.getvalue()).decode()
out=open(os.path.join(ICI,'pass-template.html')).read().replace('/*ICONS*/',json.dumps(icons))
open(sys.argv[1] if len(sys.argv)>1 else 'pass.html','w').write(out); print(len(out)//1024,'Ko')
