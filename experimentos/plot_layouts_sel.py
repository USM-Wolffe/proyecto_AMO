#!/usr/bin/env python3
# Decodifica frentes (best_*.out) y dibuja, por instancia, 3 distribuciones:
# la que minimiza g_c (despeje), la que minimiza g_r (circulacion) y la que
# minimiza g_f (funcional). Muestra el compromiso entre objetivos.
# Orden de columnas de best_pop.out (Deb):
#   obj(3) | constr(ncon=3) | xreal(nreal) | xbin(nbin) | constr_violation | rank | crowd
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

ALPHA_GR, WALL_TOL = 0.5, 1.0
HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "work")
DATASET = os.path.join(HERE, "..", "..", "dataset")
SEL = os.path.join(HERE, "layouts_sel")
CATCOL = ["#4C72B0","#DD8452","#55A868","#C44E52","#8172B3",
          "#937860","#DA8BC3","#8C8C8C","#CCB974","#64B5CD",
          "#B07AA1","#76B7B2","#FF9DA7","#9C755F","#BAB0AC"]

def read_inst(path):
    toks = open(path).read().split()
    it = iter(toks); g = lambda: next(it)
    W,H,Px,Py = float(g()),float(g()),float(g()),float(g())
    nf = int(g()); mu=[]
    for _ in range(nf):
        mu.append(dict(ancho=float(g()),largo=float(g()),clear=float(g()),cat=int(g())))
    ncat=int(g()); desea=[];peso=[]
    for _ in range(ncat):
        desea.append(int(g())); peso.append(float(g()))
    return dict(W=W,H=H,Px=Px,Py=Py,nf=nf,mu=mu,ncat=ncat,desea=desea,peso=peso)

def read_front(path, nf):
    nreal=2*nf; nbin=2*nf; ncon=3; off=3+ncon; rows=[]
    for ln in open(path):
        if ln.startswith("#") or not ln.strip(): continue
        v=[float(x) for x in ln.split()]
        if len(v) < off+nreal+nbin+1: continue
        obj=v[0:3]; xreal=v[off:off+nreal]; xbin=v[off+nreal:off+nreal+nbin]
        cv=v[off+nreal+nbin]
        rows.append(dict(obj=obj,xreal=xreal,xbin=xbin,cv=cv))
    return rows

def decode(sol, inst):
    nf=inst["nf"]; items=[]
    for i in range(nf):
        z = sol["xbin"][2*i] >= 0.5
        th= sol["xbin"][2*i+1] >= 0.5
        if not z: continue
        m=inst["mu"][i]
        w,h = (m["ancho"],m["largo"]) if not th else (m["largo"],m["ancho"])
        items.append(dict(x=sol["xreal"][2*i],y=sol["xreal"][2*i+1],
                          w=w,h=h,cat=m["cat"],clear=m["clear"]))
    return items

def pick(rows, k):
    feas=[r for r in rows if r["cv"]>=-1e-9]
    if not feas: feas=rows
    other=[j for j in range(3) if j!=k]
    return min(feas, key=lambda r:(round(r["obj"][k],4), r["obj"][other[0]]+r["obj"][other[1]]))

def draw(ax, inst, items, title):
    W,H=inst["W"],inst["H"]
    ax.add_patch(mpatches.Rectangle((0,0),W,H,fill=False,ec="#333",lw=2))
    Px,Py=inst["Px"],inst["Py"]
    ax.plot([Px-30,Px+30],[Py,Py],color="#2E7D32",lw=5,solid_capstyle="butt")
    ax.annotate("puerta",(Px,Py),xytext=(Px,Py-H*0.07),ha="center",
                fontsize=7,color="#2E7D32")
    for it in items:
        ax.add_patch(mpatches.Rectangle((it["x"],it["y"]),it["w"],it["h"],
                     fc=CATCOL[it["cat"]%len(CATCOL)],ec="#222",lw=0.8,alpha=0.85))
    ax.set_xlim(-W*0.05,W*1.05); ax.set_ylim(-H*0.1,H*1.05)
    ax.set_aspect("equal"); ax.set_title(title,fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])

INSTS=[("dormitorio",os.path.join(WORK,"dormitorio.txt")),
       ("p08",os.path.join(DATASET,"p08.txt")),
       ("p16",os.path.join(DATASET,"p16.txt")),
       ("p26",os.path.join(DATASET,"p26.txt"))]
LABS={0:"Prioriza DESPEJE (g_c)",1:"Prioriza CIRCULACION (g_r)",2:"Prioriza FUNCIONAL (g_f)"}

for name,ipath in INSTS:
    inst=read_inst(ipath)
    rows=read_front(os.path.join(SEL,"best_"+name+".out"), inst["nf"])
    fig,axs=plt.subplots(1,3,figsize=(13,4.6))
    for ax,k in zip(axs,[0,1,2]):
        s=pick(rows,k); items=decode(s,inst)
        gc,gr,gf=s["obj"]
        t="%s\n%d muebles | g_c=%.2f g_r=%.2f g_f=%.2f"%(LABS[k],len(items),gc,gr,gf)
        draw(ax,inst,items,t)
    titulo="Instancia %s (%d muebles del catalogo): misma instancia, 3 puntos del frente"%(name,inst["nf"])
    fig.suptitle(titulo,fontsize=11,y=1.02)
    fig.tight_layout()
    out=os.path.join(SEL,"layouts_"+name+".png")
    fig.savefig(out,dpi=130,bbox_inches="tight"); plt.close(fig)
    print("escrito",out)
print("OK")
