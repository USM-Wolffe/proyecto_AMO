/* Lectura de instancia de diseño interior y configuracion de la representacion.
   Formato del archivo:
     W H Px Py
     nf
     ancho largo clear cat      (x nf)
     ncat
     desea peso                 (x ncat)
   Representacion mixta: por mueble -> 2 reales (x,y) + 2 binarias (z, theta). */
# include <stdio.h>
# include <stdlib.h>
# include <math.h>
# include "global.h"
# include "rand.h"

instancia_t inst;   /* definicion de la instancia global */

int readInputFile (char* filePath)
{
    int i;
    FILE *f = fopen(filePath, "r");
    if (f == NULL) { printf("\n No se pudo abrir la instancia: %s\n", filePath); exit(1); }

    if (fscanf(f, "%lf %lf %lf %lf", &inst.W, &inst.H, &inst.Px, &inst.Py) != 4)
        { printf("\n Error leyendo recinto/puerta\n"); exit(1); }
    if (fscanf(f, "%d", &inst.nf) != 1 || inst.nf < 2)
        { printf("\n Error leyendo nf\n"); exit(1); }
    inst.muebles = (mueble_t*) malloc(inst.nf*sizeof(mueble_t));
    for (i=0; i<inst.nf; i++)
        if (fscanf(f, "%lf %lf %lf %d", &inst.muebles[i].ancho, &inst.muebles[i].largo,
                   &inst.muebles[i].clear, &inst.muebles[i].cat) != 4)
            { printf("\n Error leyendo mueble %d\n", i); exit(1); }
    if (fscanf(f, "%d", &inst.ncat) != 1 || inst.ncat < 1)
        { printf("\n Error leyendo ncat\n"); exit(1); }
    inst.desea = (int*)    malloc(inst.ncat*sizeof(int));
    inst.peso  = (double*) malloc(inst.ncat*sizeof(double));
    for (i=0; i<inst.ncat; i++)
        if (fscanf(f, "%d %lf", &inst.desea[i], &inst.peso[i]) != 2)
            { printf("\n Error leyendo perfil %d\n", i); exit(1); }
    fclose(f);

    /* precomputos para normalizar */
    inst.Dman = maximum(inst.Px, inst.W-inst.Px) + maximum(inst.Py, inst.H-inst.Py);
    inst.Fmax = 0.0;
    for (i=0; i<inst.ncat; i++) inst.Fmax += inst.peso[i]*(double)inst.desea[i];
    if (inst.Fmax <= 0.0) inst.Fmax = 1e-6;
    inst.Npares = inst.nf*(inst.nf-1)/2.0;
    if (inst.Npares <= 0.0) inst.Npares = 1.0;

    /* ---- configurar la representacion del NSGA-II ---- */
    nreal = 2*inst.nf;     /* x_i, y_i */
    nbin  = 2*inst.nf;     /* z_i, theta_i */
    nobj  = 3;
    ncon  = 3;             /* no-superposicion, dentro-recinto, cardinalidad>=2 */

    min_realvar = (double*) malloc(nreal*sizeof(double));
    max_realvar = (double*) malloc(nreal*sizeof(double));
    for (i=0; i<inst.nf; i++) {
        min_realvar[2*i]   = 0.0; max_realvar[2*i]   = inst.W;   /* x */
        min_realvar[2*i+1] = 0.0; max_realvar[2*i+1] = inst.H;   /* y */
    }
    nbits      = (int*)    malloc(nbin*sizeof(int));
    min_binvar = (double*) malloc(nbin*sizeof(double));
    max_binvar = (double*) malloc(nbin*sizeof(double));
    for (i=0; i<nbin; i++) { nbits[i]=1; min_binvar[i]=0.0; max_binvar[i]=1.0; }

    printf("\n Instancia leida: recinto %gx%g, puerta (%g,%g), %d muebles, %d categorias\n",
           inst.W, inst.H, inst.Px, inst.Py, inst.nf, inst.ncat);
    return 0;
}
