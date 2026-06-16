#!/bin/bash
# Paquete de experimentos NSGA-II: escalabilidad + sensibilidad de parametros.
# Uso:  bash run_experimentos.sh [validacion|completo]
#   validacion : reducido, para probar rapido.
#   completo   : full, dejar corriendo varias horas (en tu PC / WSL).
set -e
MODE="${1:-validacion}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/.."
HVSRC="$HERE/../../material_profe/ComputoIndicadores/hv-1.3-src"
DATASET="$HERE/../../dataset"
WORK="$HERE/work"; RES="$HERE/resultados"
mkdir -p "$WORK" "$RES"
# build
cp "$SRC"/*.c "$SRC"/*.h "$SRC/Makefile" "$WORK"/; ( cd "$WORK" && make >/dev/null 2>&1 )
cp -r "$HVSRC" "$WORK/hvsrc"; ( cd "$WORK/hvsrc" && make >/dev/null 2>&1 ); HV="$WORK/hvsrc/hv"
cp "$DATASET"/*.txt "$WORK"/ 2>/dev/null || true
# config por modo
if [ "$MODE" = "completo" ]; then
  SIZES="4 8 16 32 64 100 150 200 300"; SEEDS="0.03 0.08 0.13 0.18 0.23 0.28 0.33 0.38 0.43 0.48 0.53 0.58 0.63 0.68 0.73 0.78 0.83 0.88 0.93 0.97"; SGEN=800
  POPS="20 40 80 100"; PCS="0.5 0.7 0.9 1.0"; PMS="0.02 0.05 0.1 0.2"
  SENS_SEEDS="0.03 0.08 0.13 0.18 0.23 0.28 0.33 0.38 0.43 0.48 0.53 0.58 0.63 0.68 0.73 0.78 0.83 0.88 0.93 0.97"; SENS_INST="p06 p10 p16 p20"; BUDGET=100000
else
  SIZES="4 8 16"; SEEDS="0.2 0.6"; SGEN=200
  POPS="20 100"; PCS="1.0"; PMS="0.05"; SENS_SEEDS="0.2"; SENS_INST="p06"; BUDGET=20000
fi
python3 "$HERE/gen_escalabilidad.py" "$WORK" $SIZES >/dev/null
cd "$WORK"
# --- Estudio 1: escalabilidad ---
echo "nf,W,H,seed,tiempo_s,hv,front" > "$RES/escalabilidad.csv"
for nf in $SIZES; do
  read W H _ < esc_$nf.txt
  for s in $SEEDS; do
    t0=$(date +%s.%N); ./nsga2r $s esc_$nf.txt 100 $SGEN 3 0.9 0.05 </dev/null >/dev/null 2>&1; t1=$(date +%s.%N)
    dt=$(awk "BEGIN{printf \"%.2f\",$t1-$t0}")
    grep -v '^#' best_pop.out | awk 'NF>=3{print $1,$2,$3}' > q.dat
    hv=$("$HV" -r "1 1 1" q.dat 2>/dev/null | tail -1); fr=$(wc -l < q.dat)
    echo "$nf,$W,$H,$s,$dt,$hv,$fr" >> "$RES/escalabilidad.csv"
  done
  echo "  escalabilidad nf=$nf ok"
done
# --- Estudio 2: sensibilidad ---
echo "instancia,pop,pcross,pmut,gen,seed,hv,front,tiempo_s" > "$RES/sensibilidad.csv"
for inst in $SENS_INST; do
 for pop in $POPS; do
   gen=$(( BUDGET / pop ))
   for pc in $PCS; do for pm in $PMS; do for s in $SENS_SEEDS; do
     t0=$(date +%s.%N); ./nsga2r $s $inst.txt $pop $gen 3 $pc $pm </dev/null >/dev/null 2>&1; t1=$(date +%s.%N)
     dt=$(awk "BEGIN{printf \"%.2f\",$t1-$t0}")
     grep -v '^#' best_pop.out | awk 'NF>=3{print $1,$2,$3}' > q.dat
     hv=$("$HV" -r "1 1 1" q.dat 2>/dev/null | tail -1); fr=$(wc -l < q.dat)
     echo "$inst,$pop,$pc,$pm,$gen,$s,$hv,$fr,$dt" >> "$RES/sensibilidad.csv"
   done; done; done
 done
 echo "  sensibilidad $inst ok"
done
echo "LISTO. CSVs en: $RES"
