#ifndef EIGEN_H
#define EIGEN_H

int eigen(int job, double *A, int n, double *rr, double *ri,
          double *vr, double *vi, double *w);
void balance(double *mat, int n, int *low, int *hi, double *scale);
void unbalance(int n, double *vr, double *vi, int low, int hi,
               double *scale);
int realeig(int job, double *mat, int n,int low, int hi, double *valr,
            double *vali, double *vr, double *vi);
void elemhess(int job, double *mat, int n, int low, int hi, 
            double *vr, double *vi, int *work);


/* complex functions */

typedef struct { double re, im; } complex;
#define csize(a) (fabs(a.re)+fabs(a.im))

complex compl (double re,double im);
complex _conj (complex a);
complex cplus (complex a, complex b);
complex cminus (complex a, complex b);
complex cby (complex a, complex b);
complex cdiv (complex a,complex b);
/* complex local_cexp (complex a); */
complex cfactor (complex x, double a);
int cxtoy (complex *x, complex *y, int n);
int cmatby (complex *a, complex *b, complex *c, int n,int m,int k);
int cmatout (FILE * fout, complex *x, int n, int m);
int cmatinv( complex *x, int n, int m, double *space);


#endif

