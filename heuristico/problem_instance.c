/* test_problem: decodifica un individuo a una distribucion y calcula los tres
   objetivos (g_c, g_r, g_f) y las restricciones de factibilidad (constr).
   Mismos objetivos que el MILP de E2, evaluados directamente. */
# include <stdio.h>
# include <stdlib.h>
# include <math.h>
# include "global.h"
# include "rand.h"

static void efectivas (int i, int theta, double *w, double *h)
{
    if (theta == 0) { *w = inst.muebles[i].ancho; *h = inst.muebles[i].largo; }
    else            { *w = inst.muebles[i].largo; *h = inst.muebles[i].ancho; }
}

void test_problem (double *xreal, double *xbin, int **gene, double *obj, double *constr)
{
    int i, j, c, nf = inst.nf, nsel = 0;
    int *z   = (int*)    malloc(nf*sizeof(int));
    int *th  = (int*)    malloc(nf*sizeof(int));
    double *X = (double*) malloc(nf*sizeof(double));
    double *Y = (double*) malloc(nf*sizeof(double));
    double *w = (double*) malloc(nf*sizeof(double));
    double *h = (double*) malloc(nf*sizeof(double));

    for (i=0; i<nf; i++) {
        z[i]  = (xbin[2*i]   >= 0.5) ? 1 : 0;
        th[i] = (xbin[2*i+1] >= 0.5) ? 1 : 0;
        X[i] = xreal[2*i]; Y[i] = xreal[2*i+1];
        efectivas(i, th[i], &w[i], &h[i]);
        if (z[i]) nsel++;
    }

    /* ---- factibilidad ---- */
    double oob = 0.0, overlap = 0.0;
    for (i=0; i<nf; i++) if (z[i]) {
        if (X[i] < 0.0)            oob += -X[i];
        if (Y[i] < 0.0)            oob += -Y[i];
        if (X[i]+w[i] > inst.W)    oob += (X[i]+w[i]-inst.W);
        if (Y[i]+h[i] > inst.H)    oob += (Y[i]+h[i]-inst.H);
    }
    for (i=0; i<nf; i++) for (j=i+1; j<nf; j++) if (z[i] && z[j]) {
        double ox = minimum(X[i]+w[i], X[j]+w[j]) - maximum(X[i], X[j]);
        double oy = minimum(Y[i]+h[i], Y[j]+h[j]) - maximum(Y[i], Y[j]);
        if (ox > 0.0 && oy > 0.0) overlap += ox*oy;
    }
    constr[0] = (overlap > 0.0) ? -(overlap/(inst.W*inst.H)) : 0.0;  /* no superposicion */
    constr[1] = (oob > 0.0)     ? -(oob/(inst.W+inst.H))     : 0.0;  /* dentro del recinto */
    constr[2] = (double)(nsel - 2);                                  /* >= 2 muebles */

    /* ---- g_c: proporcion de pares seleccionados que violan despeje ---- */
    int viol = 0;
    for (i=0; i<nf; i++) for (j=i+1; j<nf; j++) if (z[i] && z[j]) {
        double need = inst.muebles[i].clear + inst.muebles[j].clear;
        int ok = (X[j] >= X[i]+w[i]+need) || (X[i] >= X[j]+w[j]+need)
              || (Y[j] >= Y[i]+h[i]+need) || (Y[i] >= Y[j]+h[j]+need);
        if (!ok) viol++;
    }
    obj[0] = (double)viol / inst.Npares;

    /* ---- g_r: 1 - [ (alpha/Dman)*sum dist + (1-alpha)*sum wmet ] / nsel ---- */
    if (nsel == 0) {
        obj[1] = 1.0;
    } else {
        double sumdist = 0.0; int wmet = 0;
        for (i=0; i<nf; i++) if (z[i]) {
            double cx = X[i]+w[i]/2.0, cy = Y[i]+h[i]/2.0;
            sumdist += fabs(cx-inst.Px) + fabs(cy-inst.Py);
            double dl=X[i], dr=inst.W-(X[i]+w[i]), db=Y[i], dt=inst.H-(Y[i]+h[i]);
            double dwall = minimum(minimum(dl,dr), minimum(db,dt));
            if (dwall <= WALL_TOL) wmet++;
        }
        double num = (ALPHA_GR/inst.Dman)*sumdist + (1.0-ALPHA_GR)*(double)wmet;
        obj[1] = 1.0 - num/(double)nsel;
    }

    /* ---- g_f: desviacion ponderada respecto al perfil ---- */
    {
        int *cnt = (int*) calloc(inst.ncat, sizeof(int));
        double s = 0.0;
        for (i=0; i<nf; i++) if (z[i]) cnt[inst.muebles[i].cat]++;
        for (c=0; c<inst.ncat; c++)
            s += inst.peso[c]*fabs((double)cnt[c]-(double)inst.desea[c]);
        obj[2] = s/inst.Fmax;
        free(cnt);
    }

    free(z); free(th); free(X); free(Y); free(w); free(h);
    return;
}
