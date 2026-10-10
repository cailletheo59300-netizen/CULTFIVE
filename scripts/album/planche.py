"""Planche des cartes : python3 scripts/album/planche.py <dépôt> <page> [<page> …] [sortie.html]"""
import json,sys,os
SUJ=os.path.join(os.path.dirname(os.path.abspath(__file__)),'sujets')
pages=[a for a in sys.argv[2:] if not a.endswith('.html')]; repo=sys.argv[1]
data=[]
for k in pages:
    d=json.load(open(f'{repo}/content/album/{k}.json'))
    data.append({'key':k,'title':d['title'],'dom':d['domain'],'cards':[[c['n'],c['name'],c['figure'],c['unit'],c['phrase'],c['rarity'] or 'common'] for c in d['cards']]})
t=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"cartes-template.html")).read()
subj=''.join(open(f).read()+'\n' for f in sorted(x for x in os.listdir('.') if x.startswith('subj_') and x.endswith('.js')))
out=t.replace('/*DATA*/',json.dumps(data,ensure_ascii=False)).replace('/*SUBJ*/',subj)
open(sys.argv[-1] if sys.argv[-1].endswith(".html") else "album-cartes.html","w").write(out); print(len(out)//1024,'Ko')
