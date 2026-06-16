# Optimización multiobjetivo de diseño interior automatizado

Proyecto del curso **INF-446 Algoritmos Multiobjetivo** (UTFSM). Dado un recinto y un
catálogo finito de muebles, se generan distribuciones que optimizan simultáneamente tres
objetivos en conflicto, todos a minimizar y normalizados en `[0,1]`:

- **g_c** — interferencia espacial (despeje entre muebles).
- **g_r** — circulación (lejanía a la puerta y adyacencia a paredes).
- **g_f** — adecuación funcional (ajuste al perfil deseado del recinto).

El problema se resuelve con dos acercamientos que se comparan entre sí:

1. **Exacto** — modelo de programación lineal entera mixta (MILP) en AMPL, resuelto con CBC
   mediante el método ε-constraint. Garantiza optimalidad, pero no escala más allá de
   instancias pequeñas.
2. **Heurístico** — algoritmo evolutivo multiobjetivo (NSGA-II) que aproxima el frente de
   Pareto completo en una sola ejecución y escala a instancias grandes.

## Estructura

| Carpeta | Contenido |
|---|---|
| `heuristico/` | Código C del NSGA-II. El motor evolutivo proviene del código base de Deb (2002); las componentes propias del problema están en `problem_instance.c`, `reader.c`, `global.h` e `initialize.c`. |
| `exacto/` | Modelo AMPL (`interior.mod`), scripts de barrido ε-constraint y las instancias `.dat`. |
| `dataset/` | Generador del conjunto común de instancias (`generar_dataset.py`), `manifest.csv` y las instancias `p04`–`p26` en formato AMPL (`.dat`) y heurístico (`.txt`). |
| `experimentos/` | Scripts para reproducir comparación, escalabilidad y sensibilidad. |

## Uso

### Heurístico (C)

```bash
cd heuristico
make
./nsga2r <semilla> <instancia.txt> <poblacion> <generaciones> 3 <p_cruce> <p_mutacion>
# ejemplo:
./nsga2r 0.42 instancias/dormitorio.txt 100 800 3 0.9 0.05
```

Formato de instancia (`.txt`):

```
W H Px Py        # recinto y puerta
nf               # numero de muebles
ancho largo clear cat   (x nf)
ncat
desea peso       (x ncat)
```

### Exacto (AMPL + CBC)

```
ampl
include exacto/sweep_lex_noche.run;   # barrido sobre una instancia cargada
```

## Indicadores

La calidad de los frentes se evalúa con **hipervolumen** (referencia `(1,1,1)`) y
**cobertura de conjuntos** (two-set coverage), tratando la naturaleza estocástica del
heurístico con 10 semillas y un frente agregado.

## Créditos

El motor NSGA-II se basa en la implementación de referencia de K. Deb et al.,
*A fast and elitist multiobjective genetic algorithm: NSGA-II* (IEEE TEC, 2002).
