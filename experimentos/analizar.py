#!/usr/bin/env python3
# Analiza los CSV de experimentos y resume conclusiones. Uso: python3 analizar.py resultados/
import sys, csv, statistics as st
from collections import defaultdict
R=sys.argv[1] if len(sys.argv)>1 else "resultados"
def num(x):
    try: return float(x)
    except: return None
# ---- escalabilidad ----
print("="*60,"\nESCALABILIDAD: tiempo y HV vs tamaño\n"+"="*60)
rows=list(csv.DictReader(open(f"{R}/escalabilidad.csv")))
byn=defaultdict(lambda:{"t":[],"hv":[],"fr":[]})
for r in rows:
    n=int(r["nf"]); byn[n]["t"].append(num(r["tiempo_s"])); 
    if num(r["hv"]) is not None: byn[n]["hv"].append(num(r["hv"]))
    byn[n]["fr"].append(num(r["front"]))
print(f"{'nf':>5} {'t_medio(s)':>11} {'HV_medio':>9} {'HV_desv':>8} {'front_medio':>11}")
for n in sorted(byn):
    d=byn[n]
    print(f"{n:>5} {st.mean(d['t']):>11.2f} {st.mean(d['hv']):>9.4f} {st.pstdev(d['hv']):>8.4f} {st.mean(d['fr']):>11.1f}")
# ---- sensibilidad ----
print("\n"+"="*60,"\nSENSIBILIDAD: efecto marginal de cada parámetro (HV medio)\n"+"="*60)
srows=list(csv.DictReader(open(f"{R}/sensibilidad.csv")))
for param in ["pop","pcross","pmut"]:
    g=defaultdict(list)
    for r in srows:
        h=num(r["hv"]); 
        if h is not None: g[r[param]].append(h)
    print(f"\n  {param}:")
    means={k:st.mean(v) for k,v in g.items()}
    for k in sorted(means,key=lambda x:float(x)):
        print(f"     {k:>6} -> HV medio {means[k]:.4f}  (n={len(g[k])})")
    rng=max(means.values())-min(means.values())
    print(f"     >> efecto (rango de medias) = {rng:.4f}")
# mejor config global
best=defaultdict(list)
for r in srows:
    h=num(r["hv"])
    if h is not None: best[(r["pop"],r["pcross"],r["pmut"])].append(h)
bestc=max(best,key=lambda k:st.mean(best[k]))
print(f"\n  MEJOR config (HV medio): pop={bestc[0]}, pcross={bestc[1]}, pmut={bestc[2]} -> {st.mean(best[bestc]):.4f}")

# ---- comparacion exacto (Solver) vs heuristico (Apf) ----
import os, subprocess
print("\n"+"="*60,"\nCOMPARACION exacto vs heuristico (HV ref 1 1 1 + two-sets coverage)\n"+"="*60)
HVBIN=os.environ.get("HVBIN","")
def _hv(f):
    if not HVBIN or not os.path.exists(f): return None
    o=subprocess.run([HVBIN,"-r","1 1 1",f],capture_output=True,text=True).stdout.strip()
    return float(o.split()[-1]) if o else None
def _load(f):
    return [[float(x) for x in l.split()] for l in open(f) if l.strip()] if os.path.exists(f) else []
def _dom(a,b): return all(x<=y for x,y in zip(a,b)) and any(x<y for x,y in zip(a,b))
def _tsc(A,B): return (sum(1 for b in B if any(_dom(a,b) for a in A))/len(B)) if B else float('nan')
print(f"{'inst':>12} {'HV_solver':>9} {'HV_heur':>9} {'SC(H>S)':>8} {'SC(S>H)':>8}")
for f in sorted(os.listdir(R)):
    if not f.startswith("Solver_"): continue
    inst=f[len("Solver_"):-4]
    S=_load(f"{R}/Solver_{inst}.dat"); A=_load(f"{R}/Apf_{inst}.dat")
    if not A: continue
    hs=_hv(f"{R}/Solver_{inst}.dat"); ha=_hv(f"{R}/Apf_{inst}.dat")
    hs="%.4f"%hs if hs is not None else "  n/a"; ha="%.4f"%ha if ha is not None else "  n/a"
    print(f"{inst:>12} {hs:>9} {ha:>9} {_tsc(A,S):>8.2f} {_tsc(S,A):>8.2f}")
