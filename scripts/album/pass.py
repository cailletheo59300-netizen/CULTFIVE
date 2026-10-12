"""Maquette du pass de saison : python3 scripts/album/pass.py [sortie.html]
Injecte les dos de cartes (dos.js) dans pass-template.html."""
import sys,os
ICI=os.path.dirname(os.path.abspath(__file__))
out=open(os.path.join(ICI,'pass-template.html')).read().replace('/*DOS*/',open(os.path.join(ICI,'dos.js')).read())
open(sys.argv[1] if len(sys.argv)>1 else 'pass.html','w').write(out); print(len(out)//1024,'Ko')
