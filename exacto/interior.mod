# =============================================================================
#   interior.mod
#   Modelo AMPL para optimizacion multiobjetivo de layouts de interiores.
#
#   Variables de decision:
#       z[i]      seleccion del mueble i (binaria)
#       X[i],Y[i] esquina inferior izquierda del bounding box (continua, cm)
#       r[i]      orientacion: 0 = natural, 1 = girado 90 grados (binaria)
#
#   Tres objetivos NO escalarizados:
#       gc  violaciones de clearance (interferencia espacial suave)
#       gr  proxy lineal de circulacion (distancia promedio a la puerta)
#       gf  adecuacion funcional (desviacion respecto al perfil del recinto)
#
#   La no superposicion es restriccion DURA (linealizada con big-M).
#   El clearance es objetivo SUAVE (lo penaliza gc).
# =============================================================================

# ----------------------- CONJUNTOS Y PARAMETROS ------------------------------

set MUEBLES ordered;                          # catalogo F (ordenado para usar ord())
set CATEGORIAS;                               # categorias funcionales

param ancho   {MUEBLES} > 0;                  # ancho original del mueble (cm)
param largo   {MUEBLES} > 0;                  # largo original del mueble (cm)
param clear   {MUEBLES} >= 0;                 # holgura de clearance (cm)
param cat     {MUEBLES} symbolic in CATEGORIAS;

# Recinto (rectangular, axis-aligned)
param Wroom > 0;                              # ancho del recinto (cm)
param Hroom > 0;                              # largo del recinto (cm)

# Puerta como segmento; uso su punto medio para la proxy de circulacion
param Px;                                     # x del punto medio de la puerta
param Py;                                     # y del punto medio de la puerta

# Perfil funcional del recinto
param desea  {CATEGORIAS} >= 0;               # cantidad deseada por categoria
param peso   {CATEGORIAS} >= 0;               # importancia por categoria (en [0,1])

# Big-M para linealizacion de no superposicion y clearance.
# El valor minimo VALIDO para los rows geometricos (no-superp. + clearance en un
# eje) es max(W,H) + lado_max + 2*clear_max. El M anterior sumaba W Y H, lo que lo
# dejaba ~2x mas grande de lo necesario y degradaba la relajacion lineal de CBC.
param lado_max  := max {i in MUEBLES} max(ancho[i], largo[i]);
param clear_max := max {i in MUEBLES} clear[i];
param M := max(Wroom, Hroom) + lado_max + 2*clear_max;

# ----------------------- VARIABLES DE DECISION -------------------------------

var z {MUEBLES} binary;                       # seleccion
var r {MUEBLES} binary;                       # orientacion (0=natural, 1=girado)
var X {MUEBLES} >= 0, <= Wroom;               # esquina inferior izquierda x (acotada)
var Y {MUEBLES} >= 0, <= Hroom;               # esquina inferior izquierda y (acotada)

# Anchos y altos efectivos: dependen de r
# w_eff[i] = ancho[i]*(1-r[i]) + largo[i]*r[i]
# h_eff[i] = largo[i]*(1-r[i]) + ancho[i]*r[i]
# (no se declaran como variables; se sustituyen donde haga falta)

# Binarias de no superposicion: para cada par (i<j) hay 4 disyunciones
set PARES := {i in MUEBLES, j in MUEBLES: ord(i) < ord(j)};
var d1 {PARES} binary;   # j a la derecha de i
var d2 {PARES} binary;   # i a la derecha de j
var d3 {PARES} binary;   # j arriba de i
var d4 {PARES} binary;   # i arriba de j

# Binarias de respeto de clearance (par cumple separacion >= c_i + c_j en algun lado)
var a1 {PARES} binary;
var a2 {PARES} binary;
var a3 {PARES} binary;
var a4 {PARES} binary;

# v[i,j] = 1 si el par (i,j) viola clearance (estando ambos seleccionados)
var v {PARES} >= 0, <= 1;

# Holguras para g_f (desviacion entre cantidad seleccionada y deseada)
var dpos {CATEGORIAS} >= 0;                   # exceso  (sel > desea)
var dneg {CATEGORIAS} >= 0;                   # deficit (sel < desea)

# ----------------------- RESTRICCIONES GEOMETRICAS ---------------------------

# (R1) Si el mueble se selecciona, debe quedar dentro del recinto
#      Si no se selecciona, la posicion no importa pero la acotamos en [0, Wroom-w]
#      Aqui modelamos la cota directa sustituyendo w_eff y h_eff:

subject to dentro_x_natural {i in MUEBLES}:
    X[i] + ancho[i]*(1 - r[i]) + largo[i]*r[i] <= Wroom + M*(1 - z[i]);

subject to dentro_y_natural {i in MUEBLES}:
    Y[i] + largo[i]*(1 - r[i]) + ancho[i]*r[i] <= Hroom + M*(1 - z[i]);

# (R2) Minimo 2 muebles seleccionados (restriccion 8 del paper)
subject to min_dos_muebles:
    sum {i in MUEBLES} z[i] >= 2;

# (C2) ROMPER SIMETRIA entre piezas IDENTICAS (misma categoria y dimensiones).
# Son intercambiables: toda solucion tiene una gemela con ellas permutadas, lo que
# duplica el arbol de branch-and-bound. Se fija un orden de seleccion (si se elige
# una, la de menor indice) y de posicion en X. Valido: para piezas identicas el
# intercambio no cambia el valor de ningun objetivo, asi que el corte siempre deja
# un representante optimo. IDENT queda vacio si no hay piezas repetidas (toy).
set IDENT := {i in MUEBLES, j in MUEBLES:
    ord(i) < ord(j) and cat[i] = cat[j] and ancho[i] = ancho[j]
    and largo[i] = largo[j] and clear[i] = clear[j]};
subject to sim_seleccion {(i,j) in IDENT}:  z[i] >= z[j];
subject to sim_posicion  {(i,j) in IDENT}:  X[i] <= X[j];

# (R3) No superposicion (restriccion 7): solo si z_i = z_j = 1
#      Disyuncion: al menos UNA de las 4 separaciones debe cumplirse

subject to nosup_d1 {(i,j) in PARES}:
    X[j] >= X[i] + ancho[i]*(1 - r[i]) + largo[i]*r[i] - M*(1 - d1[i,j]);

subject to nosup_d2 {(i,j) in PARES}:
    X[i] >= X[j] + ancho[j]*(1 - r[j]) + largo[j]*r[j] - M*(1 - d2[i,j]);

subject to nosup_d3 {(i,j) in PARES}:
    Y[j] >= Y[i] + largo[i]*(1 - r[i]) + ancho[i]*r[i] - M*(1 - d3[i,j]);

subject to nosup_d4 {(i,j) in PARES}:
    Y[i] >= Y[j] + largo[j]*(1 - r[j]) + ancho[j]*r[j] - M*(1 - d4[i,j]);

# Si ambos muebles estan seleccionados, al menos una disyuncion activa
subject to nosup_or {(i,j) in PARES}:
    d1[i,j] + d2[i,j] + d3[i,j] + d4[i,j] >= z[i] + z[j] - 1;

# ----------------------- RESTRICCIONES DE CLEARANCE (SUAVE) ------------------

# a_k = 1 SOLO si la separacion en ese lado supera c_i + c_j
# (mismo patron que d_k pero con clearance sumado)

subject to clr_a1 {(i,j) in PARES}:
    X[j] >= X[i] + ancho[i]*(1 - r[i]) + largo[i]*r[i]
                + clear[i] + clear[j] - M*(1 - a1[i,j]);

subject to clr_a2 {(i,j) in PARES}:
    X[i] >= X[j] + ancho[j]*(1 - r[j]) + largo[j]*r[j]
                + clear[i] + clear[j] - M*(1 - a2[i,j]);

subject to clr_a3 {(i,j) in PARES}:
    Y[j] >= Y[i] + largo[i]*(1 - r[i]) + ancho[i]*r[i]
                + clear[i] + clear[j] - M*(1 - a3[i,j]);

subject to clr_a4 {(i,j) in PARES}:
    Y[i] >= Y[j] + largo[j]*(1 - r[j]) + ancho[j]*r[j]
                + clear[i] + clear[j] - M*(1 - a4[i,j]);

# v[i,j] = 1 si el par esta seleccionado y NO cumple clearance en ningun lado
subject to clr_violacion {(i,j) in PARES}:
    v[i,j] >= z[i] + z[j] - 1 - (a1[i,j] + a2[i,j] + a3[i,j] + a4[i,j]);

# ----------------------- HOLGURAS DE g_f -------------------------------------

subject to def_holguras {c in CATEGORIAS}:
    (sum {i in MUEBLES: cat[i] = c} z[i]) - desea[c] = dpos[c] - dneg[c];

# ----------------------- DEFINICION DE LOS TRES OBJETIVOS --------------------

# Numero maximo de pares para normalizar
param NPARES := card(MUEBLES) * (card(MUEBLES) - 1) / 2;

# Diagonal del recinto, para normalizar distancias
param Drmax := sqrt(Wroom**2 + Hroom**2);

# Maxima distancia MANHATTAN desde el punto medio de la puerta a una esquina del
# recinto. Es el normalizador correcto para g_r (la distancia es Manhattan, no
# euclidiana): usar Drmax dejaba g_r capaz de salir < 0 para muebles muy lejanos.
param Dman := max(Px, Wroom - Px) + max(Py, Hroom - Py);

# Big-M propio para dist_eff: la distancia Manhattan a la puerta nunca supera Dman,
# asi que Mdist = Dman es el valor mas chico valido (mas apretado que el M general).
param Mdist := Dman;

# Suma de pesos*deseado para normalizar g_f
param Fmax := sum {c in CATEGORIAS} peso[c] * desea[c] + 1e-6;

# Centro aproximado del mueble: esquina + media efectiva
# (para la proxy de circulacion)

# Distancia Manhattan del centro del mueble i al punto medio de la puerta
# centro_x = X[i] + (ancho[i]*(1-r[i]) + largo[i]*r[i])/2
# centro_y = Y[i] + (largo[i]*(1-r[i]) + ancho[i]*r[i])/2
# Para evitar valor absoluto en la distancia, separamos en componentes >= 0:
var ex_pos {MUEBLES} >= 0;
var ex_neg {MUEBLES} >= 0;
var ey_pos {MUEBLES} >= 0;
var ey_neg {MUEBLES} >= 0;

subject to def_ex {i in MUEBLES}:
    X[i] + (ancho[i]*(1 - r[i]) + largo[i]*r[i])/2 - Px = ex_pos[i] - ex_neg[i];

subject to def_ey {i in MUEBLES}:
    Y[i] + (largo[i]*(1 - r[i]) + ancho[i]*r[i])/2 - Py = ey_pos[i] - ey_neg[i];

# Complementariedad: fuerza a que solo UNA de cada par (pos/neg) sea > 0, de modo
# que |dx| = ex_pos+ex_neg y |dy| = ey_pos+ey_neg valga TAMBIEN bajo maximizacion.
# Sin esto, al invertir g_r el solver infla ex_pos y ex_neg a la vez (solo su
# diferencia esta fija) y la distancia se dispara hasta el big-M. Bajo minimizacion
# estas restricciones son redundantes (no cambian el optimo), asi que son seguras
# para el barrido epsilon original tambien.
var sx {MUEBLES} binary;
var sy {MUEBLES} binary;
subject to compl_ex_pos {i in MUEBLES}:  ex_pos[i] <= M * sx[i];
subject to compl_ex_neg {i in MUEBLES}:  ex_neg[i] <= M * (1 - sx[i]);
subject to compl_ey_pos {i in MUEBLES}:  ey_pos[i] <= M * sy[i];
subject to compl_ey_neg {i in MUEBLES}:  ey_neg[i] <= M * (1 - sy[i]);

# ----------------------- ADYACENCIA A PARED (para g_r, penalizacion SUAVE) ---
# t1..t4[i]: el mueble toca el muro izq/der/inf/sup. Cada binaria solo puede ser 1
# si geometricamente se cumple (via big-M); por eso la pared NO es restriccion
# dura: el solver es libre de no pegar un mueble, pero g_r lo penaliza.
# wmet[i] in [0,1] = 1 si el mueble esta SELECCIONADO y toca al menos un muro.
# La penalizacion (seleccionados que NO tocan pared) se funde en g_r mas abajo.
var t1 {MUEBLES} binary;   # toca muro izquierdo  (X = 0)
var t2 {MUEBLES} binary;   # toca muro derecho    (X + w_ef = W)
var t3 {MUEBLES} binary;   # toca muro inferior   (Y = 0)
var t4 {MUEBLES} binary;   # toca muro superior   (Y + h_ef = H)
var wmet {MUEBLES} >= 0, <= 1;

subject to pared_izq {i in MUEBLES}:
    X[i] <= M * (1 - t1[i]);
subject to pared_der {i in MUEBLES}:
    X[i] + ancho[i]*(1 - r[i]) + largo[i]*r[i] >= Wroom - M * (1 - t2[i]);
subject to pared_inf {i in MUEBLES}:
    Y[i] <= M * (1 - t3[i]);
subject to pared_sup {i in MUEBLES}:
    Y[i] + largo[i]*(1 - r[i]) + ancho[i]*r[i] >= Hroom - M * (1 - t4[i]);
subject to wmet_sel   {i in MUEBLES}:  wmet[i] <= z[i];
subject to wmet_pared {i in MUEBLES}:  wmet[i] <= t1[i] + t2[i] + t3[i] + t4[i];

# ----------------------- FUNCIONES OBJETIVO ----------------------------------

# gc: proporcion de pares en violacion de clearance, en [0,1]
var gc >= 0;
subject to def_gc:
    gc * NPARES = sum {(i,j) in PARES} v[i,j];

# gr: distancia Manhattan promedio (normalizada) de muebles seleccionados a la puerta
#     gr * (sum z) * Drmax = sum z[i] * (|ex|+|ey|)
#     Pero queremos que sea por mueble seleccionado. Como sum z >= 2, dividimos.
#     Para mantener linealidad, usamos la version SIN normalizar por |sel|:
#     gr_lineal = (1/Drmax) * sum_i z[i] * (ex_pos[i]+ex_neg[i]+ey_pos[i]+ey_neg[i])
#     Como z[i] multiplica una variable continua, linealizamos con:
#     - si z[i]=0, las distancias del mueble no cuentan -> usamos big-M
#     Mas simple: como X,Y de muebles no-seleccionados no aporta al diseno,
#     forzamos X[i]=Y[i]=0 cuando z[i]=0 (ver R1) y las dejamos contar pero ponderadas.
#     En realidad lo limpio es: gr = (1/(NMAX*Drmax)) * sum (ex+ey) ya que
#     muebles no seleccionados naturalmente quedan en una posicion arbitraria.
#     Para evitar artefactos, restringimos posicion de muebles no seleccionados a la puerta:

# Distancia efectiva: solo cuenta cuando el mueble esta seleccionado.
# Linealizamos el producto z[i] * (ex+ey) con una variable auxiliar:
#   dist_eff[i] = z[i] * (ex_pos[i]+ex_neg[i]+ey_pos[i]+ey_neg[i])
var dist_eff {MUEBLES} >= 0;

subject to dist_eff_lo {i in MUEBLES}:
    dist_eff[i] >=
        (ex_pos[i] + ex_neg[i] + ey_pos[i] + ey_neg[i]) - Mdist*(1 - z[i]);

subject to dist_eff_up_dist {i in MUEBLES}:
    dist_eff[i] <= ex_pos[i] + ex_neg[i] + ey_pos[i] + ey_neg[i];

subject to dist_eff_up_z {i in MUEBLES}:
    dist_eff[i] <= Mdist * z[i];

# gr (NUEVA def.): objetivo de circulacion en [0,1], a MINIMIZAR. Por mueble
# seleccionado combina (i) LEJANIA a la puerta (1 - dist/Dman) y (ii) penalizacion
# por NO estar pegado a pared (1 - wmet). Ambos promediados sobre los seleccionados
# (divididos por sum z), balanceados por alpha_gr:
#   gr = alpha*(1 - avg_dist/Dman) + (1-alpha)*(1 - avg_wmet)
#      = 1 - [ (alpha/Dman)*sum dist_eff + (1-alpha)*sum wmet ] / sum z
# Como divide por sum z, gr es FRACCIONAL: de OBJETIVO se resuelve con Dinkelbach
# (obj_dink); de COTA (gr <= eps_gr) es lineal porque eps_gr es constante (ver abajo).
# No se declara 'var gr': su valor se reporta post-hoc en el .run.
param alpha_gr default 0.5;    # peso lejania-puerta vs pared en g_r (TUNEABLE en [0,1])

# gf: desviacion ponderada respecto al perfil deseado, normalizada
var gf >= 0;
subject to def_gf:
    gf * Fmax = sum {c in CATEGORIAS} peso[c] * (dpos[c] + dneg[c]);

# ----------------------- OBJETIVOS PARA EPSILON-CONSTRAINT --------------------

# El script .run define cual minimizar y cuales pasar a restriccion con epsilon

minimize obj_gc: gc;
minimize obj_gf: gf;
# obj_gr eliminado: el extremo de gr (fraccional por la division entre sum z) se
# obtiene con obj_dink (metodo de Dinkelbach), no como objetivo lineal directo.

# ----------------------- OBJETIVO PARAMETRICO DE DINKELBACH ------------------
# Para el extremo de circulacion con la NUEVA g_r (distancia PROMEDIO de los
# muebles seleccionados a la puerta), hay que maximizar el cociente
#     (sum dist_eff) / (sum z)
# que NO es lineal. Dinkelbach lo resuelve como una secuencia de problemas
# lineales  max [ N(x) - lambda*D(x) ] = max [ sum dist_eff - lambda * sum z ],
# actualizando lambda hasta que F = N - lambda*D ~ 0 (ver dinkelbach_gr.run).
param lambda_dink default 0;                  # tasa lambda (la fija el .run)
maximize obj_dink:
    (alpha_gr/Dman) * sum {i in MUEBLES} dist_eff[i]
    + (1 - alpha_gr) * sum {i in MUEBLES} wmet[i]
    - lambda_dink * sum {i in MUEBLES} z[i];

# Nombre de instancia (para nombrar los CSV de salida desde los .run)
param inst_name symbolic default "inst";

# Parametros de cota epsilon (modificables desde el .run)
param eps_gc default 1e9;
param eps_gr default 1e9;
param eps_gf default 1e9;

subject to cota_gc: gc <= eps_gc;
# cota_gr LINEAL: gr <= eps_gr  <=>  1 - num/sum z <= eps_gr  <=>
#   (1 - eps_gr) * sum z  <=  (alpha/Dman)*sum dist_eff + (1-alpha)*sum wmet.
# Es lineal porque eps_gr es constante en cada solve del barrido.
subject to cota_gr:
    (1 - eps_gr) * sum {i in MUEBLES} z[i]
    <= (alpha_gr/Dman) * sum {i in MUEBLES} dist_eff[i]
       + (1 - alpha_gr) * sum {i in MUEBLES} wmet[i];
subject to cota_gf: gf <= eps_gf;

# ----------------------- AUGMECON (B1) ---------------------------------------
# epsilon-constraint AUMENTADO. Las cotas de g_r y g_f pasan a IGUALDAD con
# holgura no negativa, y el objetivo del barrido suma -delta*(holguras norm.).
# Esto (i) garantiza puntos estrictamente eficientes (no debilmente dominados) y
# (ii) empuja g_r y g_f hacia su cota en cada celda, generando puntos distintos
# que rellenan el frente (clave cuando g_c es trivialmente 0, como en dormitorio).
# Se usan en el barrido AUGMECON en lugar de cota_gr/cota_gf (ver epsilon_*_v3.run).
var sl_gr >= 0;                 # holgura LINEAL de g_r: num - (1-eps_gr)*sum z = (eps_gr-gr)*sum z
var sl_gf >= 0;                 # holgura de g_f: eps_gf - gf
param delta_aug default 1e-3;   # peso del termino aumentado (chico)
param rng_gr default 1;         # rango de g_r (lo fija el .run, para normalizar)
param rng_gf default 1;         # rango de g_f (idem)

subject to aug_gr:
    (alpha_gr/Dman) * sum {i in MUEBLES} dist_eff[i]
    + (1 - alpha_gr) * sum {i in MUEBLES} wmet[i]
    = (1 - eps_gr) * sum {i in MUEBLES} z[i] + sl_gr;

subject to aug_gf:
    gf + sl_gf = eps_gf;

# Objetivo aumentado: minimizar g_c y, en segundo orden, empujar las holguras.
# sl_gr se normaliza por rng_gr*|F| (su cota superior aprox, por el factor sum z).
minimize obj_aug:
    gc - delta_aug * ( sl_gr / (rng_gr * card(MUEBLES)) + sl_gf / rng_gf );

# Objetivo AUGMECON con gf de maestro (para instancias donde g_c es trivialmente 0,
# como dormitorio): minimizar g_f tiene gradiente real -> CBC resuelve rapido, a
# diferencia de minimizar g_c (plano). g_r entra como ε-constraint (aug_gr) y se
# barre en 1D. El termino -delta*sl_gr empuja g_r a su cota (eficiencia); +0.01*gc
# empuja despeje a 0 sin dominar a g_f (que va de 0 a ~0.7).
minimize obj_augf:
    gf + 0.01*gc - delta_aug * sl_gr / (rng_gr * card(MUEBLES));

# Objetivo LIMPIO (sin holgura aumentada) para el barrido lexicografico v5:
# minimizar g_f con un empujon chico a g_c. Sin el termino sl_gr no hay region
# plana => CBC no se cuelga (los "limit" de v3/v4 venian de sl_gr). g_r entra como
# cota normal (cota_gr), y la eficiencia se logra barriendo fino la zona angosta.
minimize obj_gfc:
    gf + 0.01*gc;
