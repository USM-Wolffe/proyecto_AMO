/* Evaluacion de individuos: llama a test_problem y agrega la violacion de
   restricciones (convencion de Deb: constr[j] < 0 => violacion). */
# include <stdio.h>
# include <stdlib.h>
# include <math.h>
# include "global.h"
# include "rand.h"
void evaluate_pop (population *pop)
{
    int i;
    for (i=0; i<popsize; i++)
        evaluate_ind (&(pop->ind[i]));
    return;
}
void evaluate_ind (individual *ind)
{
    int j;
    test_problem (ind->xreal, ind->xbin, ind->gene, ind->obj, ind->constr);
    if (ncon==0)
    {
        ind->constr_violation = 0.0;
    }
    else
    {
        ind->constr_violation = 0.0;
        for (j=0; j<ncon; j++)
            if (ind->constr[j] < 0.0)
                ind->constr_violation += ind->constr[j];
    }
    return;
}
