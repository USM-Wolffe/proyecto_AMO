#!/bin/bash
# ==========================================================================
#  MAESTRO HEURISTICO (NSGA-II) - corre TODO el lado heuristico de la E3:
#   1) Comparacion: 10 semillas x cada instancia del dataset -> frente agregado (Apf)
#      + HV por semilla (media/desv) + frente agregado.
#   2) Escalabilidad: instancias 4..300 muebles, tiempo y HV vs tamaño.
#   3) Sensibilidad de parametros: grilla pop x pcross x pmut x semillas.
#   4) Analisis automatico de los CSV.
#  Uso:  bash CORRER_TODO_HEUR.sh [validacion|completo]
#  Los CSV se escriben incrementalmente (puedes cortar cuando quieras).
# ==========================================================================
set -e
MODE="${1:-validacion}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/.."; HVSRC="$HERE/../../material_profe/ComputoIndicadores/hv-1.3-src"; DATASET="$HERE/../../dataset"
WORK="$HERE/work"; RES="$HERE/resultados"; mkdir -p "$WORK" "$RES"
echo ">> Compilando NSGA-II y hv ..."
cp "$SRC"/*.c "$SRC"/*.h "$SRC/Makefile" "$WORK"/; ( cd "$WORK" && make >/dev/null 2>&1 )
cp -r "$HVSRC" "$WORK/hvsrc"; ( cd "$WORK/hvsrc" && make >/dev/null 2>&1 ); HV="$WORK/hvsrc/hv"
cp "$DATASET"/*.txt "$WORK"/ 2>/dev/null || true
cp "$SRC/instancias"/*.txt "$WORK"/ 2>/dev/null || true
cp "$SRC/comparacion"/Solver_*.dat "$RES"/ 2>/dev/null || true
if [ "$MODE" = "completo" ]; then
  DSEEDS="0.05 0.15 0.25 0.35 0.45 0.55 0.65 0.75 0.85 0.95"; DGEN=800
  SIZES="4 8 16 32 64 100 150 200 300"; SSEEDS="0.03 0.08 0.13 0.18 0.23 0.28 0.33 0.38 0.43 0.48 0.53 0.58 0.63 0.68 0.73 0.78 0.83 0.88 0.93 0.97"; SGEN=800
  POPS="20 40 80 100"; PCS="0.5 0.7 0.9 1.0"; PMS="0.02 0.05 0.1 0.2"; KSEEDS="$SSEEDS"; KINST="p06 p10 p16 p20"; BUDGET=100000
  DINST="toy dormitorio dificil p04 p05 p06 p08 p10 p12 p16 p20 p26"
else
  DSEEDS="0.2 0.6"; DGEN=300; SIZES="4 8 16"; SSEEDS="0.2 0.6"; SGEN=200
  POPS="20 100"; PCS="1.0"; PMS="0.05"; KSEEDS="0.2"; KINST="p06"; BUDGET=20000; DINST="toy dormitorio p04"
fi
python3 "$HERE/gen_escalabilidad.py" "$WORK" $SIZES >/dev/null
cd "$WORK"
# ---------- 1) COMPARACION: frente agregado del heuristico por instancia ----------
echo ">> [1/3] Comparacion: frente agregado por instancia (Apf)"
echo "instancia,muebles,hv_medio,hv_desv,hv_agregado,front_agregado,t_medio_s" > "$RES/heuristico_dataset.csv"
for inst in $DINST; do
  nf=$(sed -n '2p' $inst.txt); : > pool.txt; : > hvs.txt; : > ts.txt
  for s in $DSEEDS; do
    t0=$(date +%s.%N); ./nsga2r $s $inst.txt 100 $DGEN 3 0.9 0.05 </dev/null >/dev/null 2>&1; t1=$(date +%s.%N)
    awk "BEGIN{printf \"%.2f\",$t1-$t0}" >> ts.txt; echo >> ts.txt
    grep -v '^#' best_pop.out | awk 'NF>=3{print $1,$2,$3}' > q.dat
    "$HV" -r "1 1 1" q.dat 2>/dev/null | tail -1 >> hvs.txt
    cat q.dat >> pool.txt
  done
  python3 - "$inst" "$nf" "$HV" "$RES" <<'PY'
import sys,statistics as st,subprocess
inst,nf,hv,RES=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
def dom(a,b): return all(x<=y for x,y in zip(a,b)) and any(x<y for x,y in zip(a,b))
P=[tuple(round(float(v),5) for v in l.split()[:3]) for l in open('pool.txt') if l.strip()]
U=sorted(set(P)); F=[p for p in U if not any(dom(q,p) for q in U if q!=p)]
open(f"{RES}/Apf_{inst}.dat","w").write("\n".join("%.6f %.6f %.6f"%p for p in F)+"\n")
hva=float(subprocess.run([hv,'-r','1 1 1',f"{RES}/Apf_{inst}.dat"],capture_output=True,text=True).stdout.split()[-1])
hvs=[float(x) for x in open('hvs.txt') if x.strip()]; ts=[float(x) for x in open('ts.txt') if x.strip()]
open(f"{RES}/heuristico_dataset.csv","a").write(f"{inst},{nf},{st.mean(hvs):.4f},{st.pstdev(hvs):.4f},{hva:.4f},{len(F)},{st.mean(ts):.2f}\n")
print(f"   {inst}: HV {st.mean(hvs):.4f}+/-{st.pstdev(hvs):.4f}, agregado {hva:.4f}, front {len(F)}, t {st.mean(ts):.2f}s")
PY
done
# ---------- 2) ESCALABILIDAD ----------
echo ">> [2/3] Escalabilidad (4..max muebles)"
echo "nf,W,H,seed,tiempo_s,hv,front" > "$RES/escalabilidad.csv"
for nf in $SIZES; do read W H _ < esc_$nf.txt
  for s in $SSEEDS; do
    t0=$(date +%s.%N); ./nsga2r $s esc_$nf.txt 100 $SGEN 3 0.9 0.05 </dev/null >/dev/null 2>&1; t1=$(date +%s.%N)
    dt=$(awk "BEGIN{printf \"%.2f\",$t1-$t0}"); grep -v '^#' best_pop.out|awk 'NF>=3{print $1,$2,$3}'>q.dat
    hv=$("$HV" -r "1 1 1" q.dat 2>/dev/null|tail -1); echo "$nf,$W,$H,$s,$dt,$hv,$(wc -l<q.dat)" >> "$RES/escalabilidad.csv"
  done; echo "   nf=$nf ok"
done
# ---------- 3) SENSIBILIDAD ----------
echo ">> [3/3] Sensibilidad de parametros"
echo "instancia,pop,pcross,pmut,gen,seed,hv,front,tiempo_s" > "$RES/sensibilidad.csv"
for inst in $KINST; do
  for pop in $POPS; do
    gen=$((BUDGET/pop))
    for pc in $PCS; do for pm in $PMS; do for s in $KSEEDS; do
      t0=$(date +%s.%N); ./nsga2r $s $inst.txt $pop $gen 3 $pc $pm </dev/null >/dev/null 2>&1; t1=$(date +%s.%N)
      dt=$(awk "BEGIN{printf \"%.2f\",$t1-$t0}"); grep -v '^#' best_pop.out|awk 'NF>=3{print $1,$2,$3}'>q.dat
      hv=$("$HV" -r "1 1 1" q.dat 2>/dev/null|tail -1); echo "$inst,$pop,$pc,$pm,$gen,$s,$hv,$(wc -l<q.dat),$dt" >> "$RES/sensibilidad.csv"
    done; done; done
  done
  echo "   $inst ok"
done
echo ">> Analisis:"; HVBIN="$WORK/hvsrc/hv" python3 "$HERE/analizar.py" "$RES" || true
echo ">> LISTO. Todos los CSV en: $RES"
