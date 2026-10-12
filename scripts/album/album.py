"""Maquette de l'album : python3 scripts/album/album.py <dépôt> [sortie.html]
Reprend le style des cartes (cartes-template.html) et tous les dessins (sujets/), avec les 49 pages."""
import json,sys,os
ICI=os.path.dirname(os.path.abspath(__file__)); SUJ=os.path.join(ICI,'sujets'); repo=sys.argv[1]
data=[]
for f in sorted(os.listdir(f'{repo}/content/album')):
    if not f.endswith('.json'):continue
    d=json.load(open(f'{repo}/content/album/{f}'))
    data.append({'key':d['page'],'title':d['title'],'dom':d['domain'],'cards':[[c['n'],c['name'],c['figure'],c['unit'],c['phrase'],c['rarity'] or 'common'] for c in d['cards']]})
t2=open(os.path.join(ICI,'cartes-template.html')).read()
css=t2[t2.index('/* ===== la carte ===== */'):t2.index('</style>')]
js=t2[t2.index('const RNAME'):t2.index('let cur=0')]
subj=''.join(open(os.path.join(SUJ,f)).read()+'\n' for f in sorted(os.listdir(SUJ)) if f.endswith('.js'))
out=open(os.path.join(ICI,'album-template.html')).read().replace('/*SUBJ*/','').replace('/*CARDCSS*/',css).replace('/*CARDJS*/',js.replace('/*SUBJ*/',subj)).replace('/*DATA*/',json.dumps(data,ensure_ascii=False))
open(sys.argv[2] if len(sys.argv)>2 else 'album.html','w').write(out); print(len(out)//1024,'Ko')
