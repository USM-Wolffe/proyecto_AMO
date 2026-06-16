#!/usr/bin/env python3
# Generador de instancias de diseño interior. Emite, por instancia, AMBOS formatos:
#   <name>.dat  (AMPL, para el modelo MILP de E2)
#   <name>.txt  (para el NSGA-II/heuristico de E3)
# Mismas instancias para ambos => comparacion justa. Reproducible (semilla fija).
import random, os, sys
OUT = sys.argv[1] if len(sys.argv)>1 else "."

# Biblioteca de mobiliario: categoria -> (ancho, largo, clearance)
LIB = {
 "cama":        (140,200,30), "velador":(45,40,10),  "closet":(180,60,60),
 "sofa":        (210,90,40),  "sillon":(88,88,30),   "mesa_centro":(120,70,30),
 "tv_mueble":   (190,45,55),  "librero":(110,40,30), "comoda":(100,50,30),
 "mesa_comedor":(150,95,55),  "silla_com":(45,45,30),"escritorio":(140,70,50),
 "silla_of":    (50,50,30),   "estanteria":(90,40,40),"archivador":(50,60,30),
 "mesa_reunion":(200,100,60), "lampara":(40,40,20),
}
# "ambientes" tipicos: lista de (categoria, cantidad_tipica)
AMBIENTES = {
 "dormitorio": [("cama",1),("velador",2),("closet",1),("comoda",1),("escritorio",1),("silla_of",1)],
 "living":     [("sofa",1),("sillon",2),("mesa_centro",1),("tv_mueble",1),("librero",2),("lampara",2)],
 "comedor":    [("mesa_comedor",1),("silla_com",4),("comoda",1),("estanteria",1)],
 "oficina":    [("escritorio",3),("silla_of",3),("estanteria",2),("archivador",2),("mesa_reunion",1),("sofa",1)],
}

def construir(nf_obj, ambientes, W, H, Px, Py, rng):
    """Arma un catalogo de ~nf_obj muebles combinando ambientes."""
    items=[]   # (categoria)
    # repetir/combinar ambientes hasta acercarse a nf_obj
    pool=[]
    for amb in ambientes:
        for (cat,q) in AMBIENTES[amb]:
            pool += [cat]*q
    rng.shuffle(pool)
    # ajustar tamaño
    while len(pool) < nf_obj:
        pool.append(rng.choice(list(LIB.keys())))
    items = pool[:nf_obj]
    # categorias presentes
    cats = sorted(set(items))
    catidx = {c:i for i,c in enumerate(cats)}
    # perfil: desea por categoria. Mezcla de satisfacible/insatisfacible para dar dificultad.
    desea={}; peso={}
    for c in cats:
        avail = items.count(c)
        # con prob 0.3 pedir mas de lo disponible (perfil insatisfacible -> sube g_f minimo)
        if rng.random()<0.3: d = avail + rng.randint(1,2)
        else:                d = max(1, avail - rng.randint(0,1))
        desea[c]=d
        peso[c]=round(rng.choice([0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0]),1)
    return items, cats, catidx, desea, peso

def escribir(name, W,H,Px,Py, items, cats, catidx, desea, peso):
    # ---- .txt (heuristico) ----
    with open(os.path.join(OUT,name+".txt"),"w") as f:
        f.write(f"{W} {H} {Px} {Py}\n{len(items)}\n")
        for c in items:
            a,l,cl=LIB[c]; f.write(f"{a} {l} {cl} {catidx[c]}\n")
        f.write(f"{len(cats)}\n")
        for c in cats: f.write(f"{desea[c]} {peso[c]}\n")
    # ---- .dat (AMPL) ----
    ids=[f"m{i+1}" for i in range(len(items))]
    with open(os.path.join(OUT,name+".dat"),"w") as f:
        f.write(f"# instancia {name} (generada)\n")
        f.write(f"param Wroom := {W};\nparam Hroom := {H};\nparam Px := {Px};\nparam Py := {Py};\n\n")
        f.write("set MUEBLES := "+" ".join(ids)+";\n")
        f.write("set CATEGORIAS := "+" ".join(cats)+";\n\n")
        f.write("param: ancho largo clear cat :=\n")
        for mid,c in zip(ids,items):
            a,l,cl=LIB[c]; f.write(f"    {mid} {a} {l} {cl} {c}\n")
        f.write(";\n\nparam: desea peso :=\n")
        for c in cats: f.write(f"    {c} {desea[c]} {peso[c]}\n")
        f.write(";\n")

rng=random.Random(12345)
# (name, nf, ambientes, W, H, Px, Py)
PLAN=[
 ("p04", 4,  ["dormitorio"],              220,200, 100,0),
 ("p05", 5,  ["comedor"],                 280,240, 60,0),
 ("p06", 6,  ["living"],                  340,280, 280,0),
 ("p08", 8,  ["dormitorio"],              400,350, 200,0),
 ("p10",10,  ["living"],                  480,400, 120,0),
 ("p12",12,  ["oficina"],                 520,460, 90,0),
 ("p16",16,  ["living","comedor"],        620,500, 150,0),
 ("p20",20,  ["dormitorio","living"],     680,560, 200,0),
 ("p26",26,  ["dormitorio","living","comedor","oficina"], 780,640, 250,0),
]
man=open(os.path.join(OUT,"manifest.csv"),"w"); man.write("nombre,muebles,categorias,W,H,Px,Py,clase\n")
for (name,nf,amb,W,H,Px,Py) in PLAN:
    it,cats,ci,d,p = construir(nf,amb,W,H,Px,Py,rng)
    escribir(name,W,H,Px,Py,it,cats,ci,d,p)
    clase = "pequena" if nf<=6 else ("mediana" if nf<=12 else "grande")
    man.write(f"{name},{len(it)},{len(cats)},{W},{H},{Px},{Py},{clase}\n")
    print(f"{name}: {len(it)} muebles, {len(cats)} cat, {W}x{H}, clase {clase}")
man.close()
print("manifest.csv escrito")
