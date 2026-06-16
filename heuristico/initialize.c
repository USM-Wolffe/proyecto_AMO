/* Inicializacion AD-HOC para diseño interior:
   - orientacion theta aleatoria;
   - posicion pegada a una pared elegida al azar (favorece g_r y reduce solapes);
   - seleccion sesgada al perfil deseado con un nivel de llenado p aleatorio por
     individuo (diversidad: desde pocos muebles hasta perfil casi completo);
   - se garantiza el minimo de 2 muebles. */
# include <stdio.h>
# include <stdlib.h>
# include <math.h>
# include "global.h"
# include "rand.h"

void initialize_pop (population *pop)
{
    int i;
    for (i=0; i<popsize; i++)
        initialize_ind (&(pop->ind[i]));
    return;
}

void initialize_ind (individual *ind)
{
    int i, c, nf = inst.nf;
    double p = randomperc();   /* nivel de llenado de este individuo */

    /* orientacion + posicion pegada a una pared; seleccion en 0 por defecto */
    for (i=0; i<nf; i++) {
        int th = (randomperc() <= 0.5) ? 0 : 1;
        double w = (th==0) ? inst.muebles[i].ancho : inst.muebles[i].largo;
        double h = (th==0) ? inst.muebles[i].largo : inst.muebles[i].ancho;
        if (w > inst.W) w = inst.W;
        if (h > inst.H) h = inst.H;
        int wall = (int)(randomperc()*4.0); if (wall > 3) wall = 3;
        double X, Y;
        if      (wall==0) { X = 0.0;          Y = rndreal(0.0, inst.H - h); }  /* izquierda */
        else if (wall==1) { X = inst.W - w;   Y = rndreal(0.0, inst.H - h); }  /* derecha */
        else if (wall==2) { Y = 0.0;          X = rndreal(0.0, inst.W - w); }  /* abajo */
        else              { Y = inst.H - h;   X = rndreal(0.0, inst.W - w); }  /* arriba */
        ind->xreal[2*i]   = X;
        ind->xreal[2*i+1] = Y;
        ind->gene[2*i+1][0] = th;   /* bit de orientacion */
        ind->gene[2*i][0]   = 0;    /* bit de seleccion (por defecto no) */
    }

    /* seleccion sesgada al perfil: ~ p*desea[c] items por categoria */
    for (c=0; c<inst.ncat; c++) {
        int avail = 0;
        for (i=0; i<nf; i++) if (inst.muebles[i].cat == c) avail++;
        if (avail == 0) continue;
        double prob = (p * (double)inst.desea[c]) / (double)avail;
        if (prob > 1.0) prob = 1.0;
        if (prob < 0.0) prob = 0.0;
        for (i=0; i<nf; i++) if (inst.muebles[i].cat == c)
            ind->gene[2*i][0] = (randomperc() <= prob) ? 1 : 0;
    }

    /* garantizar al menos 2 muebles seleccionados */
    {
        int nsel = 0, guard = 0;
        for (i=0; i<nf; i++) if (ind->gene[2*i][0] == 1) nsel++;
        while (nsel < 2 && guard < 1000) {
            int idx = (int)(randomperc()*(double)nf); if (idx >= nf) idx = nf-1;
            if (ind->gene[2*idx][0] == 0) { ind->gene[2*idx][0] = 1; nsel++; }
            guard++;
        }
    }
    return;
}
