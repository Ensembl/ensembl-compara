/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#ifndef NJ_H
#define NJ_H

#include "utilities.h"
#include "optimiz.h"
/*#include "tools.h"*/

void   Bionj(matrix *mat);
void   Finish(matrix *mat);
void   Bionj_Scores(matrix *mat);
void   Compute_Sx(matrix *mat);
double Sum_S(matrix *mat, int i);
double Dist(matrix *mat, int x, int y);
double Q_Agglo(matrix *mat, int x, int y);
double Variance(matrix *mat, int x, int y);
double Br_Length(matrix *mat, int x, int y);
void   Update_Dist(matrix *mat, int x, int y);
double Lamda(matrix *mat, int x, int y, double vxy);
void   Best_Pair(matrix *mat, int *x, int *y, double *score);
double Var_Red(matrix *mat, int x, int y, int i, double lamda, double vxy);
void   Update_Tree(matrix *mat, int x, int y, double lx, double ly, double score);
void   Update_Mat(matrix *mat, int x, int y, 
		  double lx, double ly, double vxy, double lamda);
double Dist_Red(matrix *mat, int x, double lx, int y, 
		double ly, int i, double lamda);
int    Bionj_Br_Length_Post(node *a, node *d, matrix *mat);
void   Bionj_Br_Length(matrix *mat);

#endif
