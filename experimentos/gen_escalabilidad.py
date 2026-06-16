#!/usr/bin/env python3
# Genera una escalera de instancias (.txt para el heuristico) de tamaño creciente,
# con el recinto escalado para mantener densidad ~25%. Uso: gen_escalabilidad.py OUT n1 n2 ...
import sys, os, math, random
OUT=sys.argv[1]; sizes=[int(x) for x in sys.argv[2:]]
LIB=[ # (ancho,largo,clear) de una biblioteca de mobiliario realista
 (140,200,30),(45,40,10),(180,60,60),(210,90,40),(88,88,30),(120,70,30),
 (190,45,55),(110,40,30),(100,50,30),(150,95,55),(45,45,30),(140,70,50),
 (50,50,30),(90,40,40),(50,60,30),(200,100,60),(40,40,20)]
rng=random.Random(2024)
for nf in sizes:
    # recinto escalado: area ~ nf*28000 cm^2, aspecto ~1.3
    area=nf*28000.0; W=int(math.sqrt(area*1.3)); H=int(area/W)
    Px=int(W*0.2); Py=0
    items=[rng.randrange(len(LIB)) for _ in range(nf)]   # categoria = indice en LIB
    cats=sorted(set(items)); ci={c:i for i,c in enumerate(cats)}
    desea={}; peso={}
    for c in cats:
        avail=items.count(c)
        desea[c]= avail if rng.random()<0.6 else max(1,avail-1)
        peso[c]= round(rng.choice([0.3,0.5,0.7,0.9,1.0]),1)
    with open(os.path.join(OUT,f"esc_{nf}.txt"),"w") as f:
        f.write(f"{W} {H} {Px} {Py}\n{nf}\n")
        for c in items:
            a,l,cl=LIB[c]; f.write(f"{a} {l} {cl} {ci[c]}\n")
        f.write(f"{len(cats)}\n")
        for c in cats: f.write(f"{desea[c]} {peso[c]}\n")
    print(f"esc_{nf}.txt: {nf} muebles, {len(cats)} cat, recinto {W}x{H}")
