/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#include "utilities.h"
#include "models.h"
#include "eigen.h"
#include "free.h"

/*********************************************************/

void PMat_K80(double l,double kappa, double ***Pij)
{
  double Ts,Tv,e1,e2,aux;

  /*0 => A*/
  /*1 => C*/
  /*2 => G*/
  /*3 => T*/

  /* Ts -> transition*/
  /* Tv -> transversion*/
  
  
  aux = -2*l/(kappa+2);
  e1 = exp(aux *2);
  if (1.0!=kappa)
    {
      e2 = exp(aux *(kappa+1));
      Tv = .25*(1-e1);
      Ts = .25*(1+e1-2*e2);
    }
  else
    {
      Ts = Tv = .25*(1-e1);
    }


  (*Pij)[0][1] = (*Pij)[1][0] = Tv;  
  (*Pij)[0][2] = (*Pij)[2][0] = Ts; 
  (*Pij)[0][3] = (*Pij)[3][0] = Tv;

  (*Pij)[1][2] = (*Pij)[2][1] = Tv;  
  (*Pij)[1][3] = (*Pij)[3][1] = Ts; 
  
  (*Pij)[2][3] = (*Pij)[3][2] = Tv;

  (*Pij)[0][0] = (*Pij)[1][1] = 
  (*Pij)[2][2] = (*Pij)[3][3] = 1.-Ts-2.*Tv;
}

/*********************************************************/

void dPMat_K80(double l, double ***dPij, double rr, double k)
{

  double aux,e1,e2;
  double dTsl,dTsk;
  double dTvl,dTvk;

    /* Ts -> transition*/
    /* Tv -> transversion*/

  
  aux = -2.*l*rr/(k+2.);
  e1 = exp(aux *2);
  if (1.0!=k)
    e2 = exp(aux *(k+1));
  else
    e2 = e1;

  dTsl = -rr/(k+2) * e1 + rr*(k+1)/(k+2) * e2;
  dTvl = rr/(k+2) * e1;

  dTsk = l/pow(k+2,2) * (e1 + e2);
  dTvk = l/pow(k+2,2) * e1;


  /*First derivatives*/

  /* branch lengths */

  (*dPij)[0][0] = (*dPij)[1][1] = 
  (*dPij)[2][2] = (*dPij)[3][3] = -dTsl-2*dTvl;

  (*dPij)[0][1] = (*dPij)[1][0] = dTvl;
  (*dPij)[0][2] = (*dPij)[2][0] = dTsl;
  (*dPij)[0][3] = (*dPij)[3][0] = dTvl;

  (*dPij)[1][2] = (*dPij)[2][1] = dTvl;
  (*dPij)[1][3] = (*dPij)[3][1] = dTsl;

  (*dPij)[2][3] = (*dPij)[3][2] = dTvl;
}

/*********************************************************/

void d2PMat_K80(double l, double ***d2Pij, double rr, double k)
{
  double e1,e2,aux,aux2,aux3,aux4;
  double d2Tsl,d2Tsk;
  double d2Tvl,d2Tvk;

    /* Ts -> transition*/
    /* Tv -> transversion*/

  aux = -2.*l*rr/(k+2.);
  e1 = exp(aux *2);
  if (1.0!=k)
    e2 = exp(aux *(k+1));
  else
    e2 = e1;


  aux2 = rr*rr/pow(k+2,2);
  aux3 =    l /pow(k+2,3);
  aux4 = l *l /pow(k+2,4);
  d2Tvl = -4.*aux2 * e1;
  d2Tsl = -d2Tvl -2*aux2 *pow((k+1),2) * e2;
  d2Tvk = -2*aux3 * e1 + 4*aux4 * e1;
  d2Tsk =  d2Tvk -2*aux3 * e2 - 2*aux4 * e2;

  /*Scnd derivatives*/

  /* branch lengths */
  (*d2Pij)[0][0] = (*d2Pij)[1][1] = 
  (*d2Pij)[2][2] = (*d2Pij)[3][3] = -d2Tsl-2*d2Tvl;

  (*d2Pij)[0][1] = (*d2Pij)[1][0] = d2Tvl;
  (*d2Pij)[0][2] = (*d2Pij)[2][0] = d2Tsl;
  (*d2Pij)[0][3] = (*d2Pij)[3][0] = d2Tvl;

  (*d2Pij)[1][2] = (*d2Pij)[2][1] = d2Tvl;
  (*d2Pij)[1][3] = (*d2Pij)[3][1] = d2Tsl;

  (*d2Pij)[2][3] = (*d2Pij)[3][2] = d2Tvl;

}

/*********************************************************/

void PMat_TN93(double l, model *mod, double ***Pij)
{
  int i,j;
  double e1,e2,e3;
  double a1t,a2t,bt;
  double A,C,G,T,R,Y;
  double kappa1,kappa2;
  int kappa_has_changed;


  A = mod->pi[0]; C = mod->pi[1]; G = mod->pi[2]; T = mod->pi[3];
  R = A+G;  Y = T+C;

  kappa_has_changed = 0;
  if(mod->kappa < .0) mod->kappa = 1.0e-5;

  if(mod->whichmodel < 5) { mod->lambda = 1.; }
  else if(mod->whichmodel == 5)
    {
      do
	{
	  mod->lambda = (Y+(R-Y)/(2.*mod->kappa))/(R-(R-Y)/(2.*mod->kappa));

	  if(mod->lambda < .0)
	    {
	      mod->kappa += mod->kappa/10.;
	      kappa_has_changed = 1;
	    }
	}while(mod->lambda < .0);
    }


  if((!mod->s_opt->opt_kappa) && (kappa_has_changed))
    {
      printf("\n. WARNING: This transition/transversion ratio\n");
      printf("  is impossible with these base frequencies!\n");
      printf("  The ratio is now set to %.3f\n",mod->kappa);
    }

  kappa2 = mod->kappa*2./(1.+mod->lambda);
  kappa1 = kappa2 * mod->lambda;

  
  bt = l/(2.*(A*G*kappa1+C*T*kappa2+R*Y));

  a1t = kappa1;
  a2t = kappa2;
  a1t*=bt; a2t*=bt;

  e1 = exp(-a1t*R-bt*Y);
  e2 = exp(-a2t*Y-bt*R);
  e3 = exp(-bt);


  /*A->A*/(*Pij)[0][0] = A+Y*A/R*e3+G/R*e1; 
  /*A->C*/(*Pij)[0][1] = C*(1-e3);
  /*A->G*/(*Pij)[0][2] = G+Y*G/R*e3-G/R*e1;
  /*A->T*/(*Pij)[0][3] = T*(1-e3);

  /*C->A*/(*Pij)[1][0] = A*(1-e3);
  /*C->C*/(*Pij)[1][1] = C+R*C/Y*e3+T/Y*e2;
  /*C->G*/(*Pij)[1][2] = G*(1-e3);
  /*C->T*/(*Pij)[1][3] = T+R*T/Y*e3-T/Y*e2;

  /*G->A*/(*Pij)[2][0] = A+Y*A/R*e3-A/R*e1;
  /*G->C*/(*Pij)[2][1] = C*(1-e3);
  /*G->G*/(*Pij)[2][2] = G+Y*G/R*e3+A/R*e1;
  /*G->T*/(*Pij)[2][3] = T*(1-e3);

  /*T->A*/(*Pij)[3][0] = A*(1-e3);
  /*T->C*/(*Pij)[3][1] = C+R*C/Y*e3-C/Y*e2;
  /*T->G*/(*Pij)[3][2] = G*(1-e3);
  /*T->T*/(*Pij)[3][3] = T+R*T/Y*e3+C/Y*e2;
  
  For(i,4) For(j,4)
    if((*Pij)[i][j] < MDBL_MIN) (*Pij)[i][j] = MDBL_MIN;

}

/*********************************************************/

void dPMat_TN93(double l, double ***dPij, model *mod, double rr)
{
  double kappa1,kappa2;
  double de1dl,de2dl,de3dl;
  double A,C,G,T,R,Y;
  double Z;


  A = mod->pi[0]; C = mod->pi[1]; G = mod->pi[2]; T = mod->pi[3];
  R = A+G; Y = C+T;

  if(mod->whichmodel < 5) { mod->lambda = 1.; }
  else if(mod->whichmodel == 5)
    {
      mod->lambda = (Y+(R-Y)/(2.*mod->kappa))/(R-(R-Y)/(2.*mod->kappa));
    }

  kappa2 = mod->kappa*2./(1.+mod->lambda);
  kappa1 = kappa2 * mod->lambda;


  Z = 2.*A*G*kappa1+2.*C*T*kappa2+2.*R*Y;
  
  de1dl = -rr*(kappa1*R/Z + Y/Z)*exp(-kappa1*R/Z*l*rr-Y/Z*l*rr);
  de2dl = -rr*(kappa2*Y/Z + R/Z)*exp(-kappa2*Y/Z*l*rr-R/Z*l*rr);
  de3dl = -rr/Z*exp(-l*rr/Z);

  /*A->A*/(*dPij)[0][0] = Y*A/R*de3dl+G/R*de1dl;
  /*A->C*/(*dPij)[0][1] = -C*de3dl;
  /*A->G*/(*dPij)[0][2] = Y*G/R*de3dl-G/R*de1dl;
  /*A->T*/(*dPij)[0][3] = -T*de3dl;

  /*C->A*/(*dPij)[1][0] = -A*de3dl;
  /*C->C*/(*dPij)[1][1] = R*C/Y*de3dl+T/Y*de2dl;
  /*C->G*/(*dPij)[1][2] = -G*de3dl;
  /*C->T*/(*dPij)[1][3] = R*T/Y*de3dl-T/Y*de2dl;
 
  /*G->A*/(*dPij)[2][0] = Y*A/R*de3dl-A/R*de1dl;
  /*G->C*/(*dPij)[2][1] = -C*de3dl;
  /*G->G*/(*dPij)[2][2] = Y*G/R*de3dl+A/R*de1dl;
  /*G->T*/(*dPij)[2][3] = -T*de3dl;

  /*T->A*/(*dPij)[3][0] = -A*de3dl;
  /*T->C*/(*dPij)[3][1] = R*C/Y*de3dl-C/Y*de2dl;
  /*T->G*/(*dPij)[3][2] = -G*de3dl;
  /*T->T*/(*dPij)[3][3] = R*T/Y*de3dl+C/Y*de2dl;
}

/*********************************************************/

void d2PMat_TN93(double l, double ***d2Pij, model *mod, double rr)
{
  double kappa1,kappa2;
  double d2e1dl2,d2e2dl2,d2e3dl2;
  double A,C,G,T,R,Y;
  double Z;


  A = mod->pi[0]; C = mod->pi[1]; G = mod->pi[2]; T = mod->pi[3];
  R = A+G; Y = C+T;


  if(mod->whichmodel < 5) { mod->lambda = 1.; }
  else if(mod->whichmodel == 5)
    {
      mod->lambda = (Y+(R-Y)/(2.*mod->kappa))/(R-(R-Y)/(2.*mod->kappa));
    }

  kappa2 = mod->kappa*2./(1.+mod->lambda);
  kappa1 = kappa2 * mod->lambda;


  Z = 2.*A*G*kappa1+2.*C*T*kappa2+2.*R*Y;
  
  d2e1dl2 = (-rr*(kappa1*R/Z + Y/Z))*
            (-rr*(kappa1*R/Z + Y/Z))*
             exp(-kappa1*R/Z*l*rr-Y/Z*l*rr);
  d2e2dl2 = (-rr*(kappa2*Y/Z + R/Z))*
            (-rr*(kappa2*Y/Z + R/Z))*
             exp(-kappa2*Y/Z*l*rr-R/Z*l*rr);
  d2e3dl2 = (-rr/Z)*
            (-rr/Z)*
             exp(-l*rr/Z);

  /*A->A*/(*d2Pij)[0][0] = Y*A/R*d2e3dl2+G/R*d2e1dl2;
  /*A->C*/(*d2Pij)[0][1] = -C*d2e3dl2;
  /*A->G*/(*d2Pij)[0][2] = Y*G/R*d2e3dl2-G/R*d2e1dl2;
  /*A->T*/(*d2Pij)[0][3] = -T*d2e3dl2;

  /*C->A*/(*d2Pij)[1][0] = -A*d2e3dl2;
  /*C->C*/(*d2Pij)[1][1] = R*C/Y*d2e3dl2+T/Y*d2e2dl2;
  /*C->G*/(*d2Pij)[1][2] = -G*d2e3dl2;
  /*C->T*/(*d2Pij)[1][3] = R*T/Y*d2e3dl2-T/Y*d2e2dl2;

  /*G->A*/(*d2Pij)[2][0] = Y*A/R*d2e3dl2-A/R*d2e1dl2;
  /*G->C*/(*d2Pij)[2][1] = -C*d2e3dl2;
  /*G->G*/(*d2Pij)[2][2] = Y*G/R*d2e3dl2+A/R*d2e1dl2;
  /*G->T*/(*d2Pij)[2][3] = -T*d2e3dl2;

  /*T->A*/(*d2Pij)[3][0] = -A*d2e3dl2;
  /*T->C*/(*d2Pij)[3][1] = R*C/Y*d2e3dl2-C/Y*d2e2dl2;
  /*T->G*/(*d2Pij)[3][2] = -G*d2e3dl2;
  /*T->T*/(*d2Pij)[3][3] = R*T/Y*d2e3dl2+C/Y*d2e2dl2;

}

/*********************************************************/

int Matinv (double *x, int n, int m, double *space)
{
/* x[n*m]  ... m>=n
*/
   int i,j,k;
   int *irow;
   double ee, t,t1,xmax;
   double det;
   
   ee = 1.0E-20;
   det = 1.0;

   irow = (int *)mCalloc(n,sizeof(int));


   For (i,n)  
     {
       xmax = 0.;
       for (j=i; j<n; j++)
         if (xmax < fabs(x[j*m+i])) 
	   { 
	     xmax = fabs(x[j*m+i]); 
	     irow[i]=j; 
	   }

      det *= xmax;
      if (xmax < ee)   
	{
	  printf("\nDet becomes zero at %3d!\t\n", i+1);
	  return(-1);
	}
      if (irow[i] != i) 
	{
	  For (j,m) 
	    {
	      t = x[i*m+j];
	      x[i*m+j] = x[irow[i]*m+j];
	      x[irow[i]*m+j] = t;
	    }
	}
      t = 1./x[i*m+i];
      For (j,n) 
	{
	  if (j == i) continue;
	  t1 = t*x[j*m+i];
	  For(k,m)  x[j*m+k] -= t1*x[i*m+k];
	  x[j*m+i] = -t1;
	}
      For(j,m)   x[i*m+j] *= t;
      x[i*m+i] = t;
   }                            /* i  */
   for (i=n-1; i>=0; i--) 
     {
       if (irow[i] == i) continue;
       For(j,n)  
	 {
	   t = x[j*m+i];
	   x[j*m+i] = x[j*m + irow[i]];
	   x[j*m + irow[i]] = t;
	 }
     }

   free(irow);
   return (0);
}

/********************************************************************/
/* void PMat_Empirical(double l, model *mod, double ***Pij)         */
/*                                                                  */
/* Computes the substitution probability matrix                     */
/* from the initial substitution rate matrix and frequency vector   */
/* and one specific branch length                                   */
/*                                                                  */
/* input : l , branch length                                        */
/* input : mod , choosen model parameters, mat_Q and pi             */
/* ouput : Pij , substitution probability matrix                    */
/*                                                                  */
/* matrix P(l) is computed as follows :                             */
/* P(l) = exp(Q*t) , where :                                        */
/*                                                                  */
/*   Q = substitution rate matrix = Vr*D*inverse(Vr) , where :      */
/*                                                                  */
/*     Vr = right eigenvector matrix for Q                          */
/*     D  = diagonal matrix of eigenvalues for Q                    */
/*                                                                  */
/*   t = time interval = l / mr , where :                           */
/*                                                                  */
/*     mr = mean rate = branch length/time interval                 */
/*        = sum(i)(pi[i]*p(i->j)) , where :                         */
/*                                                                  */
/*       pi = state frequency vector                                */
/*       p(i->j) = subst. probability from i to a different state   */
/*               = -Q[ii] , as sum(j)(Q[ij]) +Q[ii] =0              */
/*                                                                  */
/* the Taylor development of exp(Q*t) gives :                       */
/* P(l) = Vr*exp(D*t)        *inverse(Vr)                           */
/*      = Vr*pow(exp(D/mr),l)*inverse(Vr)                           */
/*                                                                  */
/* for performance we compute only once the following matrixes :    */
/* Vr, inverse(Vr), exp(D/mr)                                       */
/* thus each time we compute P(l) we only have to :                 */
/* make 20 times the operation pow()                                */
/* make 2 20x20 matrix multiplications , that is :                  */
/*   16000 = 2x20x20x20 times the operation *                       */
/*   16000 = 2x20x20x20 times the operation +                       */
/*   which can be reduced to (the central matrix being diagonal) :  */
/*   8400 = 20x20 + 20x20x20 times the operation *                  */
/*   8000 = 20x20x20 times the operation +                          */
/********************************************************************/

void PMat_Empirical(double l, model *mod, double ***Pij)
{
  int n = mod->ns;
  int i, j, k;
  double *U,*V,*R;
  double *expt  = (double*)calloc(n,sizeof(double));
  double *uexpt = (double*)calloc(n*n,sizeof(double));

  U = mod->mat_Vr;
  V = mod->mat_Vi;
  R = mod->vct_eDmr;

  For (i,n) For (k,n)
    (*Pij)[i][k] = .0;

  /* compute pow(exp(D/mr),l) into mat_eDmrl */
  For (k,n)  expt[k] = pow(R[k], l);
  
  /* multiply Vr*pow(exp(D/mr),l)*Vi into Pij */
  For (i,n) For (k,n)
    uexpt[i*n+k] = U[i*n+k] * expt[k];
  For (i,n) 
    {
      For (j,n) 
	{
	  For(k,n)
	    {
	      (*Pij)[i][j] += uexpt[i*n+k] * V[k*n+j];
	    }
	  if((*Pij)[i][j] < MDBL_MIN)
	    (*Pij)[i][j] = MDBL_MIN;
	}
    }

  free(expt);
  free(uexpt);
}

/*********************************************************/

void PMat(double l, model *mod, double ***Pij)
{
  if(!mod->datatype)    
    {
      if(mod->whichmodel < 3)
	PMat_K80(l,mod->kappa,Pij);
      else
	{
	  if(mod->whichmodel < 7)
	    PMat_TN93(l,mod,Pij);
	  else
	    {
	      PMat_Empirical(l,mod,Pij);
	    }
	}
    }
  else PMat_Empirical(l,mod,Pij);
}

/*********************************************************/

void dPMat(double l, double rr, model *mod, double ***dPij)
{
  if(mod->whichmodel < 3)
    dPMat_K80(l,dPij,rr,mod->kappa);
  else
    dPMat_TN93(l,dPij,mod,rr);
}

/*********************************************************/

void d2PMat(double l, double rr, model *mod, double ***d2Pij)
{
  if(mod->whichmodel < 3)
    d2PMat_K80(l,d2Pij,rr,mod->kappa);
  else
    d2PMat_TN93(l,d2Pij,mod,rr);
}

/*********************************************************/

int GetDaa (double *daa, double *pi, char *file_name)
{
/* Get the amino acid distance (or substitution rate) matrix 
   (grantham, dayhoff, jones, etc).
*/
   FILE * fdaa;
   int i,j, naa;
   double dmax,dmin;
   double sum;  

   naa = 20;
   dmax = .0;
   dmin = 1.E+40;

   fdaa = (FILE *)Openfile(file_name,0);

   for (i=0; i<naa; i++)  for (j=0; j<i; j++)  {
     fscanf(fdaa, "%lf", &daa[i*naa+j]);
      daa[j*naa+i]=daa[i*naa+j];
      if (dmax<daa[i*naa+j]) dmax=daa[i*naa+j];
      if (dmin>daa[i*naa+j]) dmin=daa[i*naa+j];
   }

   For(i,naa) {
     if(fscanf(fdaa,"%lf",&pi[i])!=1) Exit("err aaRatefile");
   }
   sum = 0.0;
   For(i, naa) sum += pi[i];
   if (fabs(1-sum)>1e-4) {
     printf("\nSum of freq. = %.6f != 1 in aaRateFile\n",sum); 
     exit(-1);
   }
   
   fclose (fdaa);

   return (0);
}

/*********************************************************/

int Init_Qmat_Dayhoff(double *daa, double *pi)
{
  /* Dayhoff's model data
   * Dayhoff, M.O., Schwartz, R.M., Orcutt, B.C. (1978)
   * "A model of evolutionary change in proteins."
   * Dayhoff, M.O.(ed.) Atlas of Protein Sequence Structur., Vol5, Suppl3.
   * National Biomedical Research Foundation, Washington DC, pp.345-352.
   */

  int i,j,naa;

  naa = 20;


  daa[ 1*20+ 0] =   27.00; daa[ 2*20+ 0] =   98.00; daa[ 2*20+ 1] =   32.00; daa[ 3*20+ 0] =  120.00;
  daa[ 3*20+ 1] =    0.00; daa[ 3*20+ 2] =  905.00; daa[ 4*20+ 0] =   36.00; daa[ 4*20+ 1] =   23.00;
  daa[ 4*20+ 2] =    0.00; daa[ 4*20+ 3] =    0.00; daa[ 5*20+ 0] =   89.00; daa[ 5*20+ 1] =  246.00;
  daa[ 5*20+ 2] =  103.00; daa[ 5*20+ 3] =  134.00; daa[ 5*20+ 4] =    0.00; daa[ 6*20+ 0] =  198.00;
  daa[ 6*20+ 1] =    1.00; daa[ 6*20+ 2] =  148.00; daa[ 6*20+ 3] = 1153.00; daa[ 6*20+ 4] =    0.00;
  daa[ 6*20+ 5] =  716.00; daa[ 7*20+ 0] =  240.00; daa[ 7*20+ 1] =    9.00; daa[ 7*20+ 2] =  139.00;
  daa[ 7*20+ 3] =  125.00; daa[ 7*20+ 4] =   11.00; daa[ 7*20+ 5] =   28.00; daa[ 7*20+ 6] =   81.00;
  daa[ 8*20+ 0] =   23.00; daa[ 8*20+ 1] =  240.00; daa[ 8*20+ 2] =  535.00; daa[ 8*20+ 3] =   86.00;
  daa[ 8*20+ 4] =   28.00; daa[ 8*20+ 5] =  606.00; daa[ 8*20+ 6] =   43.00; daa[ 8*20+ 7] =   10.00;
  daa[ 9*20+ 0] =   65.00; daa[ 9*20+ 1] =   64.00; daa[ 9*20+ 2] =   77.00; daa[ 9*20+ 3] =   24.00;
  daa[ 9*20+ 4] =   44.00; daa[ 9*20+ 5] =   18.00; daa[ 9*20+ 6] =   61.00; daa[ 9*20+ 7] =    0.00;
  daa[ 9*20+ 8] =    7.00; daa[10*20+ 0] =   41.00; daa[10*20+ 1] =   15.00; daa[10*20+ 2] =   34.00;
  daa[10*20+ 3] =    0.00; daa[10*20+ 4] =    0.00; daa[10*20+ 5] =   73.00; daa[10*20+ 6] =   11.00;
  daa[10*20+ 7] =    7.00; daa[10*20+ 8] =   44.00; daa[10*20+ 9] =  257.00; daa[11*20+ 0] =   26.00;
  daa[11*20+ 1] =  464.00; daa[11*20+ 2] =  318.00; daa[11*20+ 3] =   71.00; daa[11*20+ 4] =    0.00;
  daa[11*20+ 5] =  153.00; daa[11*20+ 6] =   83.00; daa[11*20+ 7] =   27.00; daa[11*20+ 8] =   26.00;
  daa[11*20+ 9] =   46.00; daa[11*20+10] =   18.00; daa[12*20+ 0] =   72.00; daa[12*20+ 1] =   90.00;
  daa[12*20+ 2] =    1.00; daa[12*20+ 3] =    0.00; daa[12*20+ 4] =    0.00; daa[12*20+ 5] =  114.00;
  daa[12*20+ 6] =   30.00; daa[12*20+ 7] =   17.00; daa[12*20+ 8] =    0.00; daa[12*20+ 9] =  336.00;
  daa[12*20+10] =  527.00; daa[12*20+11] =  243.00; daa[13*20+ 0] =   18.00; daa[13*20+ 1] =   14.00;
  daa[13*20+ 2] =   14.00; daa[13*20+ 3] =    0.00; daa[13*20+ 4] =    0.00; daa[13*20+ 5] =    0.00;
  daa[13*20+ 6] =    0.00; daa[13*20+ 7] =   15.00; daa[13*20+ 8] =   48.00; daa[13*20+ 9] =  196.00;
  daa[13*20+10] =  157.00; daa[13*20+11] =    0.00; daa[13*20+12] =   92.00; daa[14*20+ 0] =  250.00;
  daa[14*20+ 1] =  103.00; daa[14*20+ 2] =   42.00; daa[14*20+ 3] =   13.00; daa[14*20+ 4] =   19.00;
  daa[14*20+ 5] =  153.00; daa[14*20+ 6] =   51.00; daa[14*20+ 7] =   34.00; daa[14*20+ 8] =   94.00;
  daa[14*20+ 9] =   12.00; daa[14*20+10] =   32.00; daa[14*20+11] =   33.00; daa[14*20+12] =   17.00;
  daa[14*20+13] =   11.00; daa[15*20+ 0] =  409.00; daa[15*20+ 1] =  154.00; daa[15*20+ 2] =  495.00;
  daa[15*20+ 3] =   95.00; daa[15*20+ 4] =  161.00; daa[15*20+ 5] =   56.00; daa[15*20+ 6] =   79.00;
  daa[15*20+ 7] =  234.00; daa[15*20+ 8] =   35.00; daa[15*20+ 9] =   24.00; daa[15*20+10] =   17.00;
  daa[15*20+11] =   96.00; daa[15*20+12] =   62.00; daa[15*20+13] =   46.00; daa[15*20+14] =  245.00;
  daa[16*20+ 0] =  371.00; daa[16*20+ 1] =   26.00; daa[16*20+ 2] =  229.00; daa[16*20+ 3] =   66.00;
  daa[16*20+ 4] =   16.00; daa[16*20+ 5] =   53.00; daa[16*20+ 6] =   34.00; daa[16*20+ 7] =   30.00;
  daa[16*20+ 8] =   22.00; daa[16*20+ 9] =  192.00; daa[16*20+10] =   33.00; daa[16*20+11] =  136.00;
  daa[16*20+12] =  104.00; daa[16*20+13] =   13.00; daa[16*20+14] =   78.00; daa[16*20+15] =  550.00;
  daa[17*20+ 0] =    0.00; daa[17*20+ 1] =  201.00; daa[17*20+ 2] =   23.00; daa[17*20+ 3] =    0.00;
  daa[17*20+ 4] =    0.00; daa[17*20+ 5] =    0.00; daa[17*20+ 6] =    0.00; daa[17*20+ 7] =    0.00;
  daa[17*20+ 8] =   27.00; daa[17*20+ 9] =    0.00; daa[17*20+10] =   46.00; daa[17*20+11] =    0.00;
  daa[17*20+12] =    0.00; daa[17*20+13] =   76.00; daa[17*20+14] =    0.00; daa[17*20+15] =   75.00;
  daa[17*20+16] =    0.00; daa[18*20+ 0] =   24.00; daa[18*20+ 1] =    8.00; daa[18*20+ 2] =   95.00;
  daa[18*20+ 3] =    0.00; daa[18*20+ 4] =   96.00; daa[18*20+ 5] =    0.00; daa[18*20+ 6] =   22.00;
  daa[18*20+ 7] =    0.00; daa[18*20+ 8] =  127.00; daa[18*20+ 9] =   37.00; daa[18*20+10] =   28.00;
  daa[18*20+11] =   13.00; daa[18*20+12] =    0.00; daa[18*20+13] =  698.00; daa[18*20+14] =    0.00;
  daa[18*20+15] =   34.00; daa[18*20+16] =   42.00; daa[18*20+17] =   61.00; daa[19*20+ 0] =  208.00;
  daa[19*20+ 1] =   24.00; daa[19*20+ 2] =   15.00; daa[19*20+ 3] =   18.00; daa[19*20+ 4] =   49.00;
  daa[19*20+ 5] =   35.00; daa[19*20+ 6] =   37.00; daa[19*20+ 7] =   54.00; daa[19*20+ 8] =   44.00;
  daa[19*20+ 9] =  889.00; daa[19*20+10] =  175.00; daa[19*20+11] =   10.00; daa[19*20+12] =  258.00;
  daa[19*20+13] =   12.00; daa[19*20+14] =   48.00; daa[19*20+15] =   30.00; daa[19*20+16] =  157.00;
  daa[19*20+17] =    0.00; daa[19*20+18] =   28.00;
  
  for (i=0; i<naa; i++)  for (j=0; j<i; j++)  daa[j*naa+i] = daa[i*naa+j];
  
  pi[ 0] = 0.087127; pi[ 1] = 0.040904; pi[ 2] = 0.040432; pi[ 3] = 0.046872;
  pi[ 4] = 0.033474; pi[ 5] = 0.038255; pi[ 6] = 0.049530; pi[ 7] = 0.088612;
  pi[ 8] = 0.033618; pi[ 9] = 0.036886; pi[10] = 0.085357; pi[11] = 0.080482;
  pi[12] = 0.014753; pi[13] = 0.039772; pi[14] = 0.050680; pi[15] = 0.069577;
  pi[16] = 0.058542; pi[17] = 0.010494; pi[18] = 0.029916; pi[19] = 0.064718;
 
  
    
  return 1;
}

/*********************************************************/

int Init_Qmat_DCMut(double *daa, double *pi)
{
  /* 
     DCMut : new implementation based on Dayhoff et al.'s raw data and amino acid mutabilities
     C. Kosiol and N. Goldman
     http://www.ebi.ac.uk/goldman-srv/dayhoff/
  */

  int i,j,naa;

  naa = 20;

  daa[ 1*20+ 0] =   26.78280; daa[ 2*20+ 0] =   98.44740; daa[ 2*20+ 1] =   32.70590; daa[ 3*20+ 0] =  119.98050; 
  daa[ 3*20+ 1] =    0.00000; daa[ 3*20+ 2] =  893.15150; daa[ 4*20+ 0] =   36.00160; daa[ 4*20+ 1] =   23.23740; 
  daa[ 4*20+ 2] =    0.00000; daa[ 4*20+ 3] =    0.00000; daa[ 5*20+ 0] =   88.77530; daa[ 5*20+ 1] =  243.99390; 
  daa[ 5*20+ 2] =  102.85090; daa[ 5*20+ 3] =  134.85510; daa[ 5*20+ 4] =    0.00000; daa[ 6*20+ 0] =  196.11670; 
  daa[ 6*20+ 1] =    0.00000; daa[ 6*20+ 2] =  149.34090; daa[ 6*20+ 3] = 1138.86590; daa[ 6*20+ 4] =    0.00000; 
  daa[ 6*20+ 5] =  708.60220; daa[ 7*20+ 0] =  238.61110; daa[ 7*20+ 1] =    8.77910; daa[ 7*20+ 2] =  138.53520; 
  daa[ 7*20+ 3] =  124.09810; daa[ 7*20+ 4] =   10.72780; daa[ 7*20+ 5] =   28.15810; daa[ 7*20+ 6] =   81.19070; 
  daa[ 8*20+ 0] =   22.81160; daa[ 8*20+ 1] =  238.31480; daa[ 8*20+ 2] =  529.00240; daa[ 8*20+ 3] =   86.82410; 
  daa[ 8*20+ 4] =   28.27290; daa[ 8*20+ 5] =  601.16130; daa[ 8*20+ 6] =   43.94690; daa[ 8*20+ 7] =   10.68020; 
  daa[ 9*20+ 0] =   65.34160; daa[ 9*20+ 1] =   63.26290; daa[ 9*20+ 2] =   76.80240; daa[ 9*20+ 3] =   23.92480; 
  daa[ 9*20+ 4] =   43.80740; daa[ 9*20+ 5] =   18.03930; daa[ 9*20+ 6] =   60.95260; daa[ 9*20+ 7] =    0.00000; 
  daa[ 9*20+ 8] =    7.69810; daa[10*20+ 0] =   40.64310; daa[10*20+ 1] =   15.49240; daa[10*20+ 2] =   34.11130; 
  daa[10*20+ 3] =    0.00000; daa[10*20+ 4] =    0.00000; daa[10*20+ 5] =   73.07720; daa[10*20+ 6] =   11.28800; 
  daa[10*20+ 7] =    7.15140; daa[10*20+ 8] =   44.35040; daa[10*20+ 9] =  255.66850; daa[11*20+ 0] =   25.86350; 
  daa[11*20+ 1] =  461.01240; daa[11*20+ 2] =  314.83710; daa[11*20+ 3] =   71.69130; daa[11*20+ 4] =    0.00000; 
  daa[11*20+ 5] =  151.90780; daa[11*20+ 6] =   83.00780; daa[11*20+ 7] =   26.76830; daa[11*20+ 8] =   27.04750; 
  daa[11*20+ 9] =   46.08570; daa[11*20+10] =   18.06290; daa[12*20+ 0] =   71.78400; daa[12*20+ 1] =   89.63210; 
  daa[12*20+ 2] =    0.00000; daa[12*20+ 3] =    0.00000; daa[12*20+ 4] =    0.00000; daa[12*20+ 5] =  112.74990; 
  daa[12*20+ 6] =   30.48030; daa[12*20+ 7] =   17.03720; daa[12*20+ 8] =    0.00000; daa[12*20+ 9] =  333.27320; 
  daa[12*20+10] =  523.01150; daa[12*20+11] =  241.17390; daa[13*20+ 0] =   18.36410; daa[13*20+ 1] =   13.69060; 
  daa[13*20+ 2] =   13.85030; daa[13*20+ 3] =    0.00000; daa[13*20+ 4] =    0.00000; daa[13*20+ 5] =    0.00000; 
  daa[13*20+ 6] =    0.00000; daa[13*20+ 7] =   15.34780; daa[13*20+ 8] =   47.59270; daa[13*20+ 9] =  195.19510; 
  daa[13*20+10] =  156.51600; daa[13*20+11] =    0.00000; daa[13*20+12] =   92.18600; daa[14*20+ 0] =  248.59200; 
  daa[14*20+ 1] =  102.83130; daa[14*20+ 2] =   41.92440; daa[14*20+ 3] =   13.39400; daa[14*20+ 4] =   18.75500; 
  daa[14*20+ 5] =  152.61880; daa[14*20+ 6] =   50.70030; daa[14*20+ 7] =   34.71530; daa[14*20+ 8] =   93.37090; 
  daa[14*20+ 9] =   11.91520; daa[14*20+10] =   31.62580; daa[14*20+11] =   33.54190; daa[14*20+12] =   17.02050; 
  daa[14*20+13] =   11.05060; daa[15*20+ 0] =  405.18700; daa[15*20+ 1] =  153.15900; daa[15*20+ 2] =  488.58920; 
  daa[15*20+ 3] =   95.60970; daa[15*20+ 4] =  159.83560; daa[15*20+ 5] =   56.18280; daa[15*20+ 6] =   79.39990; 
  daa[15*20+ 7] =  232.22430; daa[15*20+ 8] =   35.36430; daa[15*20+ 9] =   24.79550; daa[15*20+10] =   17.14320; 
  daa[15*20+11] =   95.45570; daa[15*20+12] =   61.99510; daa[15*20+13] =   45.99010; daa[15*20+14] =  242.72020; 
  daa[16*20+ 0] =  368.03650; daa[16*20+ 1] =   26.57450; daa[16*20+ 2] =  227.16970; daa[16*20+ 3] =   66.09300; 
  daa[16*20+ 4] =   16.23660; daa[16*20+ 5] =   52.56510; daa[16*20+ 6] =   34.01560; daa[16*20+ 7] =   30.66620; 
  daa[16*20+ 8] =   22.63330; daa[16*20+ 9] =  190.07390; daa[16*20+10] =   33.10900; daa[16*20+11] =  135.05990; 
  daa[16*20+12] =  103.15340; daa[16*20+13] =   13.66550; daa[16*20+14] =   78.28570; daa[16*20+15] =  543.66740; 
  daa[17*20+ 0] =    0.00000; daa[17*20+ 1] =  200.13750; daa[17*20+ 2] =   22.49680; daa[17*20+ 3] =    0.00000; 
  daa[17*20+ 4] =    0.00000; daa[17*20+ 5] =    0.00000; daa[17*20+ 6] =    0.00000; daa[17*20+ 7] =    0.00000; 
  daa[17*20+ 8] =   27.05640; daa[17*20+ 9] =    0.00000; daa[17*20+10] =   46.17760; daa[17*20+11] =    0.00000; 
  daa[17*20+12] =    0.00000; daa[17*20+13] =   76.23540; daa[17*20+14] =    0.00000; daa[17*20+15] =   74.08190; 
  daa[17*20+16] =    0.00000; daa[18*20+ 0] =   24.41390; daa[18*20+ 1] =    7.80120; daa[18*20+ 2] =   94.69400; 
  daa[18*20+ 3] =    0.00000; daa[18*20+ 4] =   95.31640; daa[18*20+ 5] =    0.00000; daa[18*20+ 6] =   21.47170; 
  daa[18*20+ 7] =    0.00000; daa[18*20+ 8] =  126.54000; daa[18*20+ 9] =   37.48340; daa[18*20+10] =   28.65720; 
  daa[18*20+11] =   13.21420; daa[18*20+12] =    0.00000; daa[18*20+13] =  695.26290; daa[18*20+14] =    0.00000; 
  daa[18*20+15] =   33.62890; daa[18*20+16] =   41.78390; daa[18*20+17] =   60.80700; daa[19*20+ 0] =  205.95640; 
  daa[19*20+ 1] =   24.03680; daa[19*20+ 2] =   15.80670; daa[19*20+ 3] =   17.83160; daa[19*20+ 4] =   48.46780; 
  daa[19*20+ 5] =   34.69830; daa[19*20+ 6] =   36.72500; daa[19*20+ 7] =   53.81650; daa[19*20+ 8] =   43.87150; 
  daa[19*20+ 9] =  881.00380; daa[19*20+10] =  174.51560; daa[19*20+11] =   10.38500; daa[19*20+12] =  256.59550; 
  daa[19*20+13] =   12.36060; daa[19*20+14] =   48.50260; daa[19*20+15] =   30.38360; daa[19*20+16] =  156.19970; 
  daa[19*20+17] =    0.00000; daa[19*20+18] =   27.93790; 
  


  for (i=0; i<naa; i++)  for (j=0; j<i; j++)  daa[j*naa+i] = daa[i*naa+j];

  pi[ 0] = 0.087127; pi[ 1] = 0.040904; pi[ 2] = 0.040432; pi[ 3] = 0.046872; 
  pi[ 4] = 0.033474; pi[ 5] = 0.038255; pi[ 6] = 0.049530; pi[ 7] = 0.088612;
  pi[ 8] = 0.033619; pi[ 9] = 0.036886; pi[10] = 0.085357; pi[11] = 0.080481;
  pi[12] = 0.014753; pi[13] = 0.039772; pi[14] = 0.050680; pi[15] = 0.069577;
  pi[16] = 0.058542; pi[17] = 0.010494; pi[18] = 0.029916; pi[19] = 0.064718; 

  return 1;


}


/*********************************************************/

int Init_Qmat_JTT(double *daa, double *pi)
{
  int i,j,naa;

  /* JTT's model data
   * D.T.Jones, W.R.Taylor and J.M.Thornton
   * "The rapid generation of mutation data matrices from protein sequences"
   * CABIOS  vol.8 no.3 1992 pp275-282
   */


  naa = 20;

  daa[ 1*20+ 0] =   58.00; daa[ 2*20+ 0] =   54.00; daa[ 2*20+ 1] =   45.00; daa[ 3*20+ 0] =   81.00;
  daa[ 3*20+ 1] =   16.00; daa[ 3*20+ 2] =  528.00; daa[ 4*20+ 0] =   56.00; daa[ 4*20+ 1] =  113.00;
  daa[ 4*20+ 2] =   34.00; daa[ 4*20+ 3] =   10.00; daa[ 5*20+ 0] =   57.00; daa[ 5*20+ 1] =  310.00;
  daa[ 5*20+ 2] =   86.00; daa[ 5*20+ 3] =   49.00; daa[ 5*20+ 4] =    9.00; daa[ 6*20+ 0] =  105.00;
  daa[ 6*20+ 1] =   29.00; daa[ 6*20+ 2] =   58.00; daa[ 6*20+ 3] =  767.00; daa[ 6*20+ 4] =    5.00;
  daa[ 6*20+ 5] =  323.00; daa[ 7*20+ 0] =  179.00; daa[ 7*20+ 1] =  137.00; daa[ 7*20+ 2] =   81.00;
  daa[ 7*20+ 3] =  130.00; daa[ 7*20+ 4] =   59.00; daa[ 7*20+ 5] =   26.00; daa[ 7*20+ 6] =  119.00;
  daa[ 8*20+ 0] =   27.00; daa[ 8*20+ 1] =  328.00; daa[ 8*20+ 2] =  391.00; daa[ 8*20+ 3] =  112.00;
  daa[ 8*20+ 4] =   69.00; daa[ 8*20+ 5] =  597.00; daa[ 8*20+ 6] =   26.00; daa[ 8*20+ 7] =   23.00;
  daa[ 9*20+ 0] =   36.00; daa[ 9*20+ 1] =   22.00; daa[ 9*20+ 2] =   47.00; daa[ 9*20+ 3] =   11.00;
  daa[ 9*20+ 4] =   17.00; daa[ 9*20+ 5] =    9.00; daa[ 9*20+ 6] =   12.00; daa[ 9*20+ 7] =    6.00;
  daa[ 9*20+ 8] =   16.00; daa[10*20+ 0] =   30.00; daa[10*20+ 1] =   38.00; daa[10*20+ 2] =   12.00;
  daa[10*20+ 3] =    7.00; daa[10*20+ 4] =   23.00; daa[10*20+ 5] =   72.00; daa[10*20+ 6] =    9.00;
  daa[10*20+ 7] =    6.00; daa[10*20+ 8] =   56.00; daa[10*20+ 9] =  229.00; daa[11*20+ 0] =   35.00;
  daa[11*20+ 1] =  646.00; daa[11*20+ 2] =  263.00; daa[11*20+ 3] =   26.00; daa[11*20+ 4] =    7.00;
  daa[11*20+ 5] =  292.00; daa[11*20+ 6] =  181.00; daa[11*20+ 7] =   27.00; daa[11*20+ 8] =   45.00;
  daa[11*20+ 9] =   21.00; daa[11*20+10] =   14.00; daa[12*20+ 0] =   54.00; daa[12*20+ 1] =   44.00;
  daa[12*20+ 2] =   30.00; daa[12*20+ 3] =   15.00; daa[12*20+ 4] =   31.00; daa[12*20+ 5] =   43.00;
  daa[12*20+ 6] =   18.00; daa[12*20+ 7] =   14.00; daa[12*20+ 8] =   33.00; daa[12*20+ 9] =  479.00;
  daa[12*20+10] =  388.00; daa[12*20+11] =   65.00; daa[13*20+ 0] =   15.00; daa[13*20+ 1] =    5.00;
  daa[13*20+ 2] =   10.00; daa[13*20+ 3] =    4.00; daa[13*20+ 4] =   78.00; daa[13*20+ 5] =    4.00;
  daa[13*20+ 6] =    5.00; daa[13*20+ 7] =    5.00; daa[13*20+ 8] =   40.00; daa[13*20+ 9] =   89.00;
  daa[13*20+10] =  248.00; daa[13*20+11] =    4.00; daa[13*20+12] =   43.00; daa[14*20+ 0] =  194.00;
  daa[14*20+ 1] =   74.00; daa[14*20+ 2] =   15.00; daa[14*20+ 3] =   15.00; daa[14*20+ 4] =   14.00;
  daa[14*20+ 5] =  164.00; daa[14*20+ 6] =   18.00; daa[14*20+ 7] =   24.00; daa[14*20+ 8] =  115.00;
  daa[14*20+ 9] =   10.00; daa[14*20+10] =  102.00; daa[14*20+11] =   21.00; daa[14*20+12] =   16.00;
  daa[14*20+13] =   17.00; daa[15*20+ 0] =  378.00; daa[15*20+ 1] =  101.00; daa[15*20+ 2] =  503.00;
  daa[15*20+ 3] =   59.00; daa[15*20+ 4] =  223.00; daa[15*20+ 5] =   53.00; daa[15*20+ 6] =   30.00;
  daa[15*20+ 7] =  201.00; daa[15*20+ 8] =   73.00; daa[15*20+ 9] =   40.00; daa[15*20+10] =   59.00;
  daa[15*20+11] =   47.00; daa[15*20+12] =   29.00; daa[15*20+13] =   92.00; daa[15*20+14] =  285.00;
  daa[16*20+ 0] =  475.00; daa[16*20+ 1] =   64.00; daa[16*20+ 2] =  232.00; daa[16*20+ 3] =   38.00;
  daa[16*20+ 4] =   42.00; daa[16*20+ 5] =   51.00; daa[16*20+ 6] =   32.00; daa[16*20+ 7] =   33.00;
  daa[16*20+ 8] =   46.00; daa[16*20+ 9] =  245.00; daa[16*20+10] =   25.00; daa[16*20+11] =  103.00;
  daa[16*20+12] =  226.00; daa[16*20+13] =   12.00; daa[16*20+14] =  118.00; daa[16*20+15] =  477.00;
  daa[17*20+ 0] =    9.00; daa[17*20+ 1] =  126.00; daa[17*20+ 2] =    8.00; daa[17*20+ 3] =    4.00;
  daa[17*20+ 4] =  115.00; daa[17*20+ 5] =   18.00; daa[17*20+ 6] =   10.00; daa[17*20+ 7] =   55.00;
  daa[17*20+ 8] =    8.00; daa[17*20+ 9] =    9.00; daa[17*20+10] =   52.00; daa[17*20+11] =   10.00;
  daa[17*20+12] =   24.00; daa[17*20+13] =   53.00; daa[17*20+14] =    6.00; daa[17*20+15] =   35.00;
  daa[17*20+16] =   12.00; daa[18*20+ 0] =   11.00; daa[18*20+ 1] =   20.00; daa[18*20+ 2] =   70.00;
  daa[18*20+ 3] =   46.00; daa[18*20+ 4] =  209.00; daa[18*20+ 5] =   24.00; daa[18*20+ 6] =    7.00;
  daa[18*20+ 7] =    8.00; daa[18*20+ 8] =  573.00; daa[18*20+ 9] =   32.00; daa[18*20+10] =   24.00;
  daa[18*20+11] =    8.00; daa[18*20+12] =   18.00; daa[18*20+13] =  536.00; daa[18*20+14] =   10.00;
  daa[18*20+15] =   63.00; daa[18*20+16] =   21.00; daa[18*20+17] =   71.00; daa[19*20+ 0] =  298.00;
  daa[19*20+ 1] =   17.00; daa[19*20+ 2] =   16.00; daa[19*20+ 3] =   31.00; daa[19*20+ 4] =   62.00;
  daa[19*20+ 5] =   20.00; daa[19*20+ 6] =   45.00; daa[19*20+ 7] =   47.00; daa[19*20+ 8] =   11.00;
  daa[19*20+ 9] =  961.00; daa[19*20+10] =  180.00; daa[19*20+11] =   14.00; daa[19*20+12] =  323.00;
  daa[19*20+13] =   62.00; daa[19*20+14] =   23.00; daa[19*20+15] =   38.00; daa[19*20+16] =  112.00;
  daa[19*20+17] =   25.00; daa[19*20+18] =   16.00;
  
  for (i=0; i<naa; i++)  for (j=0; j<i; j++)  daa[j*naa+i] = daa[i*naa+j];

  pi[ 0] = 0.076748; pi[ 1] = 0.051691; pi[ 2] = 0.042645; pi[ 3] = 0.051544;
  pi[ 4] = 0.019803; pi[ 5] = 0.040752; pi[ 6] = 0.061830; pi[ 7] = 0.073152;
  pi[ 8] = 0.022944; pi[ 9] = 0.053761; pi[10] = 0.091904; pi[11] = 0.058676;
  pi[12] = 0.023826; pi[13] = 0.040126; pi[14] = 0.050901; pi[15] = 0.068765;
  pi[16] = 0.058565; pi[17] = 0.014261; pi[18] = 0.032102; pi[19] = 0.066005;
 
 return 1;
}

/*********************************************************/

int Init_Qmat_MtREV(double *daa, double *pi)
{
  int i,j,naa;

  naa = 20;


  daa[ 1*20+ 0] =   23.18; daa[ 2*20+ 0] =   26.95; daa[ 2*20+ 1] =   13.24; daa[ 3*20+ 0] =   17.67;
  daa[ 3*20+ 1] =    1.90; daa[ 3*20+ 2] =  794.38; daa[ 4*20+ 0] =   59.93; daa[ 4*20+ 1] =  103.33;
  daa[ 4*20+ 2] =   58.94; daa[ 4*20+ 3] =    1.90; daa[ 5*20+ 0] =    1.90; daa[ 5*20+ 1] =  220.99;
  daa[ 5*20+ 2] =  173.56; daa[ 5*20+ 3] =   55.28; daa[ 5*20+ 4] =   75.24; daa[ 6*20+ 0] =    9.77;
  daa[ 6*20+ 1] =    1.90; daa[ 6*20+ 2] =   63.05; daa[ 6*20+ 3] =  583.55; daa[ 6*20+ 4] =    1.90;
  daa[ 6*20+ 5] =  313.56; daa[ 7*20+ 0] =  120.71; daa[ 7*20+ 1] =   23.03; daa[ 7*20+ 2] =   53.30;
  daa[ 7*20+ 3] =   56.77; daa[ 7*20+ 4] =   30.71; daa[ 7*20+ 5] =    6.75; daa[ 7*20+ 6] =   28.28;
  daa[ 8*20+ 0] =   13.90; daa[ 8*20+ 1] =  165.23; daa[ 8*20+ 2] =  496.13; daa[ 8*20+ 3] =  113.99;
  daa[ 8*20+ 4] =  141.49; daa[ 8*20+ 5] =  582.40; daa[ 8*20+ 6] =   49.12; daa[ 8*20+ 7] =    1.90;
  daa[ 9*20+ 0] =   96.49; daa[ 9*20+ 1] =    1.90; daa[ 9*20+ 2] =   27.10; daa[ 9*20+ 3] =    4.34;
  daa[ 9*20+ 4] =   62.73; daa[ 9*20+ 5] =    8.34; daa[ 9*20+ 6] =    3.31; daa[ 9*20+ 7] =    5.98;
  daa[ 9*20+ 8] =   12.26; daa[10*20+ 0] =   25.46; daa[10*20+ 1] =   15.58; daa[10*20+ 2] =   15.16;
  daa[10*20+ 3] =    1.90; daa[10*20+ 4] =   25.65; daa[10*20+ 5] =   39.70; daa[10*20+ 6] =    1.90;
  daa[10*20+ 7] =    2.41; daa[10*20+ 8] =   11.49; daa[10*20+ 9] =  329.09; daa[11*20+ 0] =    8.36;
  daa[11*20+ 1] =  141.40; daa[11*20+ 2] =  608.70; daa[11*20+ 3] =    2.31; daa[11*20+ 4] =    1.90;
  daa[11*20+ 5] =  465.58; daa[11*20+ 6] =  313.86; daa[11*20+ 7] =   22.73; daa[11*20+ 8] =  127.67;
  daa[11*20+ 9] =   19.57; daa[11*20+10] =   14.88; daa[12*20+ 0] =  141.88; daa[12*20+ 1] =    1.90;
  daa[12*20+ 2] =   65.41; daa[12*20+ 3] =    1.90; daa[12*20+ 4] =    6.18; daa[12*20+ 5] =   47.37;
  daa[12*20+ 6] =    1.90; daa[12*20+ 7] =    1.90; daa[12*20+ 8] =   11.97; daa[12*20+ 9] =  517.98;
  daa[12*20+10] =  537.53; daa[12*20+11] =   91.37; daa[13*20+ 0] =    6.37; daa[13*20+ 1] =    4.69;
  daa[13*20+ 2] =   15.20; daa[13*20+ 3] =    4.98; daa[13*20+ 4] =   70.80; daa[13*20+ 5] =   19.11;
  daa[13*20+ 6] =    2.67; daa[13*20+ 7] =    1.90; daa[13*20+ 8] =   48.16; daa[13*20+ 9] =   84.67;
  daa[13*20+10] =  216.06; daa[13*20+11] =    6.44; daa[13*20+12] =   90.82; daa[14*20+ 0] =   54.31;
  daa[14*20+ 1] =   23.64; daa[14*20+ 2] =   73.31; daa[14*20+ 3] =   13.43; daa[14*20+ 4] =   31.26;
  daa[14*20+ 5] =  137.29; daa[14*20+ 6] =   12.83; daa[14*20+ 7] =    1.90; daa[14*20+ 8] =   60.97;
  daa[14*20+ 9] =   20.63; daa[14*20+10] =   40.10; daa[14*20+11] =   50.10; daa[14*20+12] =   18.84;
  daa[14*20+13] =   17.31; daa[15*20+ 0] =  387.86; daa[15*20+ 1] =    6.04; daa[15*20+ 2] =  494.39;
  daa[15*20+ 3] =   69.02; daa[15*20+ 4] =  277.05; daa[15*20+ 5] =   54.11; daa[15*20+ 6] =   54.71;
  daa[15*20+ 7] =  125.93; daa[15*20+ 8] =   77.46; daa[15*20+ 9] =   47.70; daa[15*20+10] =   73.61;
  daa[15*20+11] =  105.79; daa[15*20+12] =  111.16; daa[15*20+13] =   64.29; daa[15*20+14] =  169.90;
  daa[16*20+ 0] =  480.72; daa[16*20+ 1] =    2.08; daa[16*20+ 2] =  238.46; daa[16*20+ 3] =   28.01;
  daa[16*20+ 4] =  179.97; daa[16*20+ 5] =   94.93; daa[16*20+ 6] =   14.82; daa[16*20+ 7] =   11.17;
  daa[16*20+ 8] =   44.78; daa[16*20+ 9] =  368.43; daa[16*20+10] =  126.40; daa[16*20+11] =  136.33;
  daa[16*20+12] =  528.17; daa[16*20+13] =   33.85; daa[16*20+14] =  128.22; daa[16*20+15] =  597.21;
  daa[17*20+ 0] =    1.90; daa[17*20+ 1] =   21.95; daa[17*20+ 2] =   10.68; daa[17*20+ 3] =   19.86;
  daa[17*20+ 4] =   33.60; daa[17*20+ 5] =    1.90; daa[17*20+ 6] =    1.90; daa[17*20+ 7] =   10.92;
  daa[17*20+ 8] =    7.08; daa[17*20+ 9] =    1.90; daa[17*20+10] =   32.44; daa[17*20+11] =   24.00;
  daa[17*20+12] =   21.71; daa[17*20+13] =    7.84; daa[17*20+14] =    4.21; daa[17*20+15] =   38.58;
  daa[17*20+16] =    9.99; daa[18*20+ 0] =    6.48; daa[18*20+ 1] =    1.90; daa[18*20+ 2] =  191.36;
  daa[18*20+ 3] =   21.21; daa[18*20+ 4] =  254.77; daa[18*20+ 5] =   38.82; daa[18*20+ 6] =   13.12;
  daa[18*20+ 7] =    3.21; daa[18*20+ 8] =  670.14; daa[18*20+ 9] =   25.01; daa[18*20+10] =   44.15;
  daa[18*20+11] =   51.17; daa[18*20+12] =   39.96; daa[18*20+13] =  465.58; daa[18*20+14] =   16.21;
  daa[18*20+15] =   64.92; daa[18*20+16] =   38.73; daa[18*20+17] =   26.25; daa[19*20+ 0] =  195.06;
  daa[19*20+ 1] =    7.64; daa[19*20+ 2] =    1.90; daa[19*20+ 3] =    1.90; daa[19*20+ 4] =    1.90;
  daa[19*20+ 5] =   19.00; daa[19*20+ 6] =   21.14; daa[19*20+ 7] =    2.53; daa[19*20+ 8] =    1.90;
  daa[19*20+ 9] = 1222.94; daa[19*20+10] =   91.67; daa[19*20+11] =    1.90; daa[19*20+12] =  387.54;
  daa[19*20+13] =    6.35; daa[19*20+14] =    8.23; daa[19*20+15] =    1.90; daa[19*20+16] =  204.54;
  daa[19*20+17] =    5.37; daa[19*20+18] =    1.90;
  
  for (i=0; i<naa; i++)  for (j=0; j<i; j++)  daa[j*naa+i] = daa[i*naa+j];

  pi[ 0] = 0.072000; pi[ 1] = 0.019000; pi[ 2] = 0.039000; pi[ 3] = 0.019000;
  pi[ 4] = 0.006000; pi[ 5] = 0.025000; pi[ 6] = 0.024000; pi[ 7] = 0.056000;
  pi[ 8] = 0.028000; pi[ 9] = 0.088000; pi[10] = 0.169000; pi[11] = 0.023000;
  pi[12] = 0.054000; pi[13] = 0.061000; pi[14] = 0.054000; pi[15] = 0.072000;
  pi[16] = 0.086000; pi[17] = 0.029000; pi[18] = 0.033000; pi[19] = 0.043000;

  return 1;
}


/*********************************************************/

int Init_Qmat_WAG(double *daa, double *pi)
{
  int i,j,naa;

  /* WAG's model data
   * Simon Whelan and Nick Goldman
   * 'A general empirical model of protein evolution derived from multiple
   *  protein families using a maximum-likelihood approach' 
   * MBE (2001) 18:691-699
   */

  naa = 20;

  daa[ 1*20+ 0] =  55.15710; daa[ 2*20+ 0] =  50.98480; daa[ 2*20+ 1] =  63.53460; 
  daa[ 3*20+ 0] =  73.89980; daa[ 3*20+ 1] =  14.73040; daa[ 3*20+ 2] = 542.94200; 
  daa[ 4*20+ 0] = 102.70400; daa[ 4*20+ 1] =  52.81910; daa[ 4*20+ 2] =  26.52560; 
  daa[ 4*20+ 3] =   3.02949; daa[ 5*20+ 0] =  90.85980; daa[ 5*20+ 1] = 303.55000; 
  daa[ 5*20+ 2] = 154.36400; daa[ 5*20+ 3] =  61.67830; daa[ 5*20+ 4] =   9.88179; 
  daa[ 6*20+ 0] = 158.28500; daa[ 6*20+ 1] =  43.91570; daa[ 6*20+ 2] =  94.71980; 
  daa[ 6*20+ 3] = 617.41600; daa[ 6*20+ 4] =   2.13520; daa[ 6*20+ 5] = 546.94700; 
  daa[ 7*20+ 0] = 141.67200; daa[ 7*20+ 1] =  58.46650; daa[ 7*20+ 2] = 112.55600; 
  daa[ 7*20+ 3] =  86.55840; daa[ 7*20+ 4] =  30.66740; daa[ 7*20+ 5] =  33.00520; 
  daa[ 7*20+ 6] =  56.77170; daa[ 8*20+ 0] =  31.69540; daa[ 8*20+ 1] = 213.71500; 
  daa[ 8*20+ 2] = 395.62900; daa[ 8*20+ 3] =  93.06760; daa[ 8*20+ 4] =  24.89720; 
  daa[ 8*20+ 5] = 429.41100; daa[ 8*20+ 6] =  57.00250; daa[ 8*20+ 7] =  24.94100; 
  daa[ 9*20+ 0] =  19.33350; daa[ 9*20+ 1] =  18.69790; daa[ 9*20+ 2] =  55.42360; 
  daa[ 9*20+ 3] =   3.94370; daa[ 9*20+ 4] =  17.01350; daa[ 9*20+ 5] =  11.39170; 
  daa[ 9*20+ 6] =  12.73950; daa[ 9*20+ 7] =   3.04501; daa[ 9*20+ 8] =  13.81900; 
  daa[10*20+ 0] =  39.79150; daa[10*20+ 1] =  49.76710; daa[10*20+ 2] =  13.15280; 
  daa[10*20+ 3] =   8.48047; daa[10*20+ 4] =  38.42870; daa[10*20+ 5] =  86.94890; 
  daa[10*20+ 6] =  15.42630; daa[10*20+ 7] =   6.13037; daa[10*20+ 8] =  49.94620; 
  daa[10*20+ 9] = 317.09700; daa[11*20+ 0] =  90.62650; daa[11*20+ 1] = 535.14200; 
  daa[11*20+ 2] = 301.20100; daa[11*20+ 3] =  47.98550; daa[11*20+ 4] =   7.40339; 
  daa[11*20+ 5] = 389.49000; daa[11*20+ 6] = 258.44300; daa[11*20+ 7] =  37.35580; 
  daa[11*20+ 8] =  89.04320; daa[11*20+ 9] =  32.38320; daa[11*20+10] =  25.75550; 
  daa[12*20+ 0] =  89.34960; daa[12*20+ 1] =  68.31620; daa[12*20+ 2] =  19.82210; 
  daa[12*20+ 3] =  10.37540; daa[12*20+ 4] =  39.04820; daa[12*20+ 5] = 154.52600; 
  daa[12*20+ 6] =  31.51240; daa[12*20+ 7] =  17.41000; daa[12*20+ 8] =  40.41410; 
  daa[12*20+ 9] = 425.74600; daa[12*20+10] = 485.40200; daa[12*20+11] =  93.42760; 
  daa[13*20+ 0] =  21.04940; daa[13*20+ 1] =  10.27110; daa[13*20+ 2] =   9.61621; 
  daa[13*20+ 3] =   4.67304; daa[13*20+ 4] =  39.80200; daa[13*20+ 5] =   9.99208; 
  daa[13*20+ 6] =   8.11339; daa[13*20+ 7] =   4.99310; daa[13*20+ 8] =  67.93710; 
  daa[13*20+ 9] = 105.94700; daa[13*20+10] = 211.51700; daa[13*20+11] =   8.88360; 
  daa[13*20+12] = 119.06300; daa[14*20+ 0] = 143.85500; daa[14*20+ 1] =  67.94890; 
  daa[14*20+ 2] =  19.50810; daa[14*20+ 3] =  42.39840; daa[14*20+ 4] =  10.94040; 
  daa[14*20+ 5] =  93.33720; daa[14*20+ 6] =  68.23550; daa[14*20+ 7] =  24.35700; 
  daa[14*20+ 8] =  69.61980; daa[14*20+ 9] =   9.99288; daa[14*20+10] =  41.58440; 
  daa[14*20+11] =  55.68960; daa[14*20+12] =  17.13290; daa[14*20+13] =  16.14440; 
  daa[15*20+ 0] = 337.07900; daa[15*20+ 1] = 122.41900; daa[15*20+ 2] = 397.42300; 
  daa[15*20+ 3] = 107.17600; daa[15*20+ 4] = 140.76600; daa[15*20+ 5] = 102.88700; 
  daa[15*20+ 6] =  70.49390; daa[15*20+ 7] = 134.18200; daa[15*20+ 8] =  74.01690; 
  daa[15*20+ 9] =  31.94400; daa[15*20+10] =  34.47390; daa[15*20+11] =  96.71300; 
  daa[15*20+12] =  49.39050; daa[15*20+13] =  54.59310; daa[15*20+14] = 161.32800; 
  daa[16*20+ 0] = 212.11100; daa[16*20+ 1] =  55.44130; daa[16*20+ 2] = 203.00600; 
  daa[16*20+ 3] =  37.48660; daa[16*20+ 4] =  51.29840; daa[16*20+ 5] =  85.79280; 
  daa[16*20+ 6] =  82.27650; daa[16*20+ 7] =  22.58330; daa[16*20+ 8] =  47.33070; 
  daa[16*20+ 9] = 145.81600; daa[16*20+10] =  32.66220; daa[16*20+11] = 138.69800; 
  daa[16*20+12] = 151.61200; daa[16*20+13] =  17.19030; daa[16*20+14] =  79.53840; 
  daa[16*20+15] = 437.80200; daa[17*20+ 0] =  11.31330; daa[17*20+ 1] = 116.39200; 
  daa[17*20+ 2] =   7.19167; daa[17*20+ 3] =  12.97670; daa[17*20+ 4] =  71.70700; 
  daa[17*20+ 5] =  21.57370; daa[17*20+ 6] =  15.65570; daa[17*20+ 7] =  33.69830; 
  daa[17*20+ 8] =  26.25690; daa[17*20+ 9] =  21.24830; daa[17*20+10] =  66.53090; 
  daa[17*20+11] =  13.75050; daa[17*20+12] =  51.57060; daa[17*20+13] = 152.96400; 
  daa[17*20+14] =  13.94050; daa[17*20+15] =  52.37420; daa[17*20+16] =  11.08640; 
  daa[18*20+ 0] =  24.07350; daa[18*20+ 1] =  38.15330; daa[18*20+ 2] = 108.60000; 
  daa[18*20+ 3] =  32.57110; daa[18*20+ 4] =  54.38330; daa[18*20+ 5] =  22.77100; 
  daa[18*20+ 6] =  19.63030; daa[18*20+ 7] =  10.36040; daa[18*20+ 8] = 387.34400; 
  daa[18*20+ 9] =  42.01700; daa[18*20+10] =  39.86180; daa[18*20+11] =  13.32640; 
  daa[18*20+12] =  42.84370; daa[18*20+13] = 645.42800; daa[18*20+14] =  21.60460; 
  daa[18*20+15] =  78.69930; daa[18*20+16] =  29.11480; daa[18*20+17] = 248.53900; 
  daa[19*20+ 0] = 200.60100; daa[19*20+ 1] =  25.18490; daa[19*20+ 2] =  19.62460; 
  daa[19*20+ 3] =  15.23350; daa[19*20+ 4] = 100.21400; daa[19*20+ 5] =  30.12810; 
  daa[19*20+ 6] =  58.87310; daa[19*20+ 7] =  18.72470; daa[19*20+ 8] =  11.83580; 
  daa[19*20+ 9] = 782.13000; daa[19*20+10] = 180.03400; daa[19*20+11] =  30.54340; 
  daa[19*20+12] = 205.84500; daa[19*20+13] =  64.98920; daa[19*20+14] =  31.48870; 
  daa[19*20+15] =  23.27390; daa[19*20+16] = 138.82300; daa[19*20+17] =  36.53690; 
  daa[19*20+18] =  31.47300; 

  for (i=0; i<naa; i++)  for (j=0; j<i; j++)  daa[j*naa+i] = daa[i*naa+j];

  pi[0] = 0.0866279; pi[1] =  0.043972; pi[2] =  0.0390894; pi[3] =  0.0570451;
  pi[4] =  0.0193078; pi[5] =  0.0367281; pi[6] =  0.0580589; pi[7] =  0.0832518;
  pi[8] =  0.0244313; pi[9] =  0.048466; pi[10] =  0.086209; pi[11] = 0.0620286;
  pi[12] = 0.0195027; pi[13] =  0.0384319; pi[14] =  0.0457631; pi[15] = 0.0695179;
  pi[16] =  0.0610127; pi[17] =  0.0143859; pi[18] =  0.0352742; pi[19] =  0.0708956;

  return 1;
}

/*********************************************************/

int Init_Qmat_RtREV(double *daa, double *pi)
{
    /* 
       This model has been 'translated' from John Huelsenbeck and Fredrik Ronquist
       MrBayes program into PHYML format by Federico Abascal. Many thanks to them. 
    */
    
    /* 
    Dimmic M.W., J.S. Rest, D.P. Mindell, and D. Goldstein. 2002. RArtREV:
    An amino acid substitution matrix for inference of retrovirus and
    reverse transcriptase phylogeny. Journal of Molecular Evolution
    55: 65-73.
    */

    int i,j,naa;
    naa = 20;

    daa[1*20+0]= 34;         daa[2*20+0]= 51;         daa[2*20+1]= 35;         daa[3*20+0]= 10;         
    daa[3*20+1]= 30;         daa[3*20+2]= 384;        daa[4*20+0]= 439;        daa[4*20+1]= 92;         
    daa[4*20+2]= 128;        daa[4*20+3]= 1;          daa[5*20+0]= 32;         daa[5*20+1]= 221;        
    daa[5*20+2]= 236;        daa[5*20+3]= 78;         daa[5*20+4]= 70;         daa[6*20+0]= 81;         
    daa[6*20+1]= 10;         daa[6*20+2]= 79;         daa[6*20+3]= 542;        daa[6*20+4]= 1;          
    daa[6*20+5]= 372;        daa[7*20+0]= 135;        daa[7*20+1]= 41;         daa[7*20+2]= 94;         
    daa[7*20+3]= 61;         daa[7*20+4]= 48;         daa[7*20+5]= 18;         daa[7*20+6]= 70;         
    daa[8*20+0]= 30;         daa[8*20+1]= 90;         daa[8*20+2]= 320;        daa[8*20+3]= 91;         
    daa[8*20+4]= 124;        daa[8*20+5]= 387;        daa[8*20+6]= 34;         daa[8*20+7]= 68;         
    daa[9*20+0]= 1;          daa[9*20+1]= 24;         daa[9*20+2]= 35;         daa[9*20+3]= 1;          
    daa[9*20+4]= 104;        daa[9*20+5]= 33;         daa[9*20+6]= 1;          daa[9*20+7]= 1;          
    daa[9*20+8]= 34;         daa[10*20+0]= 45;        daa[10*20+1]= 18;        daa[10*20+2]= 15;        
    daa[10*20+3]= 5;         daa[10*20+4]= 110;       daa[10*20+5]= 54;        daa[10*20+6]= 21;        
    daa[10*20+7]= 3;         daa[10*20+8]= 51;        daa[10*20+9]= 385;       daa[11*20+0]= 38;        
    daa[11*20+1]= 593;       daa[11*20+2]= 123;       daa[11*20+3]= 20;        daa[11*20+4]= 16;        
    daa[11*20+5]= 309;       daa[11*20+6]= 141;       daa[11*20+7]= 30;        daa[11*20+8]= 76;        
    daa[11*20+9]= 34;        daa[11*20+10]= 23;       daa[12*20+0]= 235;       daa[12*20+1]= 57;        
    daa[12*20+2]= 1;         daa[12*20+3]= 1;         daa[12*20+4]= 156;       daa[12*20+5]= 158;       
    daa[12*20+6]= 1;         daa[12*20+7]= 37;        daa[12*20+8]= 116;       daa[12*20+9]= 375;       
    daa[12*20+10]= 581;      daa[12*20+11]= 134;      daa[13*20+0]= 1;         daa[13*20+1]= 7;         
    daa[13*20+2]= 49;        daa[13*20+3]= 1;         daa[13*20+4]= 70;        daa[13*20+5]= 1;         
    daa[13*20+6]= 1;         daa[13*20+7]= 7;         daa[13*20+8]= 141;       daa[13*20+9]= 64;        
    daa[13*20+10]= 179;      daa[13*20+11]= 14;       daa[13*20+12]= 247;      daa[14*20+0]= 97;        
    daa[14*20+1]= 24;        daa[14*20+2]= 33;        daa[14*20+3]= 55;        daa[14*20+4]= 1;         
    daa[14*20+5]= 68;        daa[14*20+6]= 52;        daa[14*20+7]= 17;        daa[14*20+8]= 44;        
    daa[14*20+9]= 10;        daa[14*20+10]= 22;       daa[14*20+11]= 43;       daa[14*20+12]= 1;        
    daa[14*20+13]= 11;       daa[15*20+0]= 460;       daa[15*20+1]= 102;       daa[15*20+2]= 294;       
    daa[15*20+3]= 136;       daa[15*20+4]= 75;        daa[15*20+5]= 225;       daa[15*20+6]= 95;        
    daa[15*20+7]= 152;       daa[15*20+8]= 183;       daa[15*20+9]= 4;         daa[15*20+10]= 24;       
    daa[15*20+11]= 77;       daa[15*20+12]= 1;        daa[15*20+13]= 20;       daa[15*20+14]= 134;      
    daa[16*20+0]= 258;       daa[16*20+1]= 64;        daa[16*20+2]= 148;       daa[16*20+3]= 55;        
    daa[16*20+4]= 117;       daa[16*20+5]= 146;       daa[16*20+6]= 82;        daa[16*20+7]= 7;         
    daa[16*20+8]= 49;        daa[16*20+9]= 72;        daa[16*20+10]= 25;       daa[16*20+11]= 110;      
    daa[16*20+12]= 131;      daa[16*20+13]= 69;       daa[16*20+14]= 62;       daa[16*20+15]= 671;      
    daa[17*20+0]= 5;         daa[17*20+1]= 13;        daa[17*20+2]= 16;        daa[17*20+3]= 1;         
    daa[17*20+4]= 55;        daa[17*20+5]= 10;        daa[17*20+6]= 17;        daa[17*20+7]= 23;        
    daa[17*20+8]= 48;        daa[17*20+9]= 39;        daa[17*20+10]= 47;       daa[17*20+11]= 6;        
    daa[17*20+12]= 111;      daa[17*20+13]= 182;      daa[17*20+14]= 9;        daa[17*20+15]= 14;       
    daa[17*20+16]= 1;        daa[18*20+0]= 55;        daa[18*20+1]= 47;        daa[18*20+2]= 28;        
    daa[18*20+3]= 1;         daa[18*20+4]= 131;       daa[18*20+5]= 45;        daa[18*20+6]= 1;         
    daa[18*20+7]= 21;        daa[18*20+8]= 307;       daa[18*20+9]= 26;        daa[18*20+10]= 64;       
    daa[18*20+11]= 1;        daa[18*20+12]= 74;       daa[18*20+13]= 1017;     daa[18*20+14]= 14;       
    daa[18*20+15]= 31;       daa[18*20+16]= 34;       daa[18*20+17]= 176;      daa[19*20+0]= 197;       
    daa[19*20+1]= 29;        daa[19*20+2]= 21;        daa[19*20+3]= 6;         daa[19*20+4]= 295;       
    daa[19*20+5]= 36;        daa[19*20+6]= 35;        daa[19*20+7]= 3;         daa[19*20+8]= 1;         
    daa[19*20+9]= 1048;      daa[19*20+10]= 112;      daa[19*20+11]= 19;       daa[19*20+12]= 236;      
    daa[19*20+13]= 92;       daa[19*20+14]= 25;       daa[19*20+15]= 39;       daa[19*20+16]= 196;      
    daa[19*20+17]= 26;       daa[19*20+18]= 59;       

    for (i=0; i<naa; i++)  for (j=0; j<i; j++)  daa[j*naa+i] = daa[i*naa+j];

    pi[0]= 0.0646;           pi[1]= 0.0453;           pi[2]= 0.0376;           pi[3]= 0.0422;           
    pi[4]= 0.0114;           pi[5]= 0.0606;           pi[6]= 0.0607;           pi[7]= 0.0639;           
    pi[8]= 0.0273;           pi[9]= 0.0679;           pi[10]= 0.1018;          pi[11]= 0.0751;          
    pi[12]= 0.015;           pi[13]= 0.0287;          pi[14]= 0.0681;          pi[15]= 0.0488;          
    pi[16]= 0.0622;          pi[17]= 0.0251;          pi[18]= 0.0318;          pi[19]= 0.0619;          
    return 1;
}

/*********************************************************/

int Init_Qmat_CpREV(double *daa, double *pi)
{
    /* 
       This model has been 'translated' from John Huelsenbeck and Fredrik Ronquist
       MrBayes program into PHYML format by Federico Abascal. Many thanks to them. 
    */

    /*
      Adachi, J., P. Waddell, W. Martin, and M. Hasegawa. 2000. Plastid          
      genome phylogeny and a model of amino acid substitution for proteins    
      encoded by chloroplast DNA. Journal of Molecular Evolution              
      50:348-358.
    */

    int i,j,naa;
    naa = 20;

    daa[1*20+0]= 105;        daa[2*20+0]= 227;        daa[2*20+1]= 357;        daa[3*20+0]= 175;        
    daa[3*20+1]= 43;         daa[3*20+2]= 4435;       daa[4*20+0]= 669;        daa[4*20+1]= 823;        
    daa[4*20+2]= 538;        daa[4*20+3]= 10;         daa[5*20+0]= 157;        daa[5*20+1]= 1745;       
    daa[5*20+2]= 768;        daa[5*20+3]= 400;        daa[5*20+4]= 10;         daa[6*20+0]= 499;        
    daa[6*20+1]= 152;        daa[6*20+2]= 1055;       daa[6*20+3]= 3691;       daa[6*20+4]= 10;         
    daa[6*20+5]= 3122;       daa[7*20+0]= 665;        daa[7*20+1]= 243;        daa[7*20+2]= 653;        
    daa[7*20+3]= 431;        daa[7*20+4]= 303;        daa[7*20+5]= 133;        daa[7*20+6]= 379;        
    daa[8*20+0]= 66;         daa[8*20+1]= 715;        daa[8*20+2]= 1405;       daa[8*20+3]= 331;        
    daa[8*20+4]= 441;        daa[8*20+5]= 1269;       daa[8*20+6]= 162;        daa[8*20+7]= 19;         
    daa[9*20+0]= 145;        daa[9*20+1]= 136;        daa[9*20+2]= 168;        daa[9*20+3]= 10;         
    daa[9*20+4]= 280;        daa[9*20+5]= 92;         daa[9*20+6]= 148;        daa[9*20+7]= 40;         
    daa[9*20+8]= 29;         daa[10*20+0]= 197;       daa[10*20+1]= 203;       daa[10*20+2]= 113;       
    daa[10*20+3]= 10;        daa[10*20+4]= 396;       daa[10*20+5]= 286;       daa[10*20+6]= 82;        
    daa[10*20+7]= 20;        daa[10*20+8]= 66;        daa[10*20+9]= 1745;      daa[11*20+0]= 236;       
    daa[11*20+1]= 4482;      daa[11*20+2]= 2430;      daa[11*20+3]= 412;       daa[11*20+4]= 48;        
    daa[11*20+5]= 3313;      daa[11*20+6]= 2629;      daa[11*20+7]= 263;       daa[11*20+8]= 305;       
    daa[11*20+9]= 345;       daa[11*20+10]= 218;      daa[12*20+0]= 185;       daa[12*20+1]= 125;       
    daa[12*20+2]= 61;        daa[12*20+3]= 47;        daa[12*20+4]= 159;       daa[12*20+5]= 202;       
    daa[12*20+6]= 113;       daa[12*20+7]= 21;        daa[12*20+8]= 10;        daa[12*20+9]= 1772;      
    daa[12*20+10]= 1351;     daa[12*20+11]= 193;      daa[13*20+0]= 68;        daa[13*20+1]= 53;        
    daa[13*20+2]= 97;        daa[13*20+3]= 22;        daa[13*20+4]= 726;       daa[13*20+5]= 10;        
    daa[13*20+6]= 145;       daa[13*20+7]= 25;        daa[13*20+8]= 127;       daa[13*20+9]= 454;       
    daa[13*20+10]= 1268;     daa[13*20+11]= 72;       daa[13*20+12]= 327;      daa[14*20+0]= 490;       
    daa[14*20+1]= 87;        daa[14*20+2]= 173;       daa[14*20+3]= 170;       daa[14*20+4]= 285;       
    daa[14*20+5]= 323;       daa[14*20+6]= 185;       daa[14*20+7]= 28;        daa[14*20+8]= 152;       
    daa[14*20+9]= 117;       daa[14*20+10]= 219;      daa[14*20+11]= 302;      daa[14*20+12]= 100;      
    daa[14*20+13]= 43;       daa[15*20+0]= 2440;      daa[15*20+1]= 385;       daa[15*20+2]= 2085;      
    daa[15*20+3]= 590;       daa[15*20+4]= 2331;      daa[15*20+5]= 396;       daa[15*20+6]= 568;       
    daa[15*20+7]= 691;       daa[15*20+8]= 303;       daa[15*20+9]= 216;       daa[15*20+10]= 516;      
    daa[15*20+11]= 868;      daa[15*20+12]= 93;       daa[15*20+13]= 487;      daa[15*20+14]= 1202;     
    daa[16*20+0]= 1340;      daa[16*20+1]= 314;       daa[16*20+2]= 1393;      daa[16*20+3]= 266;       
    daa[16*20+4]= 576;       daa[16*20+5]= 241;       daa[16*20+6]= 369;       daa[16*20+7]= 92;        
    daa[16*20+8]= 32;        daa[16*20+9]= 1040;      daa[16*20+10]= 156;      daa[16*20+11]= 918;      
    daa[16*20+12]= 645;      daa[16*20+13]= 148;      daa[16*20+14]= 260;      daa[16*20+15]= 2151;     
    daa[17*20+0]= 14;        daa[17*20+1]= 230;       daa[17*20+2]= 40;        daa[17*20+3]= 18;        
    daa[17*20+4]= 435;       daa[17*20+5]= 53;        daa[17*20+6]= 63;        daa[17*20+7]= 82;        
    daa[17*20+8]= 69;        daa[17*20+9]= 42;        daa[17*20+10]= 159;      daa[17*20+11]= 10;       
    daa[17*20+12]= 86;       daa[17*20+13]= 468;      daa[17*20+14]= 49;       daa[17*20+15]= 73;       
    daa[17*20+16]= 29;       daa[18*20+0]= 56;        daa[18*20+1]= 323;       daa[18*20+2]= 754;       
    daa[18*20+3]= 281;       daa[18*20+4]= 1466;      daa[18*20+5]= 391;       daa[18*20+6]= 142;       
    daa[18*20+7]= 10;        daa[18*20+8]= 1971;      daa[18*20+9]= 89;        daa[18*20+10]= 189;      
    daa[18*20+11]= 247;      daa[18*20+12]= 215;      daa[18*20+13]= 2370;     daa[18*20+14]= 97;       
    daa[18*20+15]= 522;      daa[18*20+16]= 71;       daa[18*20+17]= 346;      daa[19*20+0]= 968;       
    daa[19*20+1]= 92;        daa[19*20+2]= 83;        daa[19*20+3]= 75;        daa[19*20+4]= 592;       
    daa[19*20+5]= 54;        daa[19*20+6]= 200;       daa[19*20+7]= 91;        daa[19*20+8]= 25;        
    daa[19*20+9]= 4797;      daa[19*20+10]= 865;      daa[19*20+11]= 249;      daa[19*20+12]= 475;      
    daa[19*20+13]= 317;      daa[19*20+14]= 122;      daa[19*20+15]= 167;      daa[19*20+16]= 760;      
    daa[19*20+17]= 10;       daa[19*20+18]= 119;      

    for (i=0; i<naa; i++)  for (j=0; j<i; j++)  daa[j*naa+i] = daa[i*naa+j];

    pi[0]= 0.076;            pi[1]= 0.062;            pi[2]= 0.041;            pi[3]= 0.037;            
    pi[4]= 0.009;            pi[5]= 0.038;            pi[6]= 0.049;            pi[7]= 0.084;            
    pi[8]= 0.025;            pi[9]= 0.081;            pi[10]= 0.101;           pi[11]= 0.05;            
    pi[12]= 0.022;           pi[13]= 0.051;           pi[14]= 0.043;           pi[15]= 0.062;           
    pi[16]= 0.054;           pi[17]= 0.018;           pi[18]= 0.031;           pi[19]= 0.066;           
    return 1;
}

/*********************************************************/

int Init_Qmat_VT(double *daa, double *pi)
{
    /* 
       This model has been 'translated' from John Huelsenbeck and Fredrik Ronquist
       MrBayes program into PHYML format by Federico Abascal. Many thanks to them. 
    */

    /*
      Muller, T., and M. Vingron. 2000. Modeling amino acid replacement.         
      Journal of Computational Biology 7:761-776.                             
    */

    int i,j,naa;
    naa = 20;

    daa[1*20+0]= 0.233108;   daa[2*20+0]= 0.199097;   daa[2*20+1]= 0.210797;   daa[3*20+0]= 0.265145;   
    daa[3*20+1]= 0.105191;   daa[3*20+2]= 0.883422;   daa[4*20+0]= 0.227333;   daa[4*20+1]= 0.031726;   
    daa[4*20+2]= 0.027495;   daa[4*20+3]= 0.010313;   daa[5*20+0]= 0.310084;   daa[5*20+1]= 0.493763;   
    daa[5*20+2]= 0.2757;     daa[5*20+3]= 0.205842;   daa[5*20+4]= 0.004315;   daa[6*20+0]= 0.567957;   
    daa[6*20+1]= 0.25524;    daa[6*20+2]= 0.270417;   daa[6*20+3]= 1.599461;   daa[6*20+4]= 0.005321;   
    daa[6*20+5]= 0.960976;   daa[7*20+0]= 0.876213;   daa[7*20+1]= 0.156945;   daa[7*20+2]= 0.362028;   
    daa[7*20+3]= 0.311718;   daa[7*20+4]= 0.050876;   daa[7*20+5]= 0.12866;    daa[7*20+6]= 0.250447;   
    daa[8*20+0]= 0.078692;   daa[8*20+1]= 0.213164;   daa[8*20+2]= 0.290006;   daa[8*20+3]= 0.134252;   
    daa[8*20+4]= 0.016695;   daa[8*20+5]= 0.315521;   daa[8*20+6]= 0.104458;   daa[8*20+7]= 0.058131;   
    daa[9*20+0]= 0.222972;   daa[9*20+1]= 0.08151;    daa[9*20+2]= 0.087225;   daa[9*20+3]= 0.01172;    
    daa[9*20+4]= 0.046398;   daa[9*20+5]= 0.054602;   daa[9*20+6]= 0.046589;   daa[9*20+7]= 0.051089;   
    daa[9*20+8]= 0.020039;   daa[10*20+0]= 0.42463;   daa[10*20+1]= 0.192364;  daa[10*20+2]= 0.069245;  
    daa[10*20+3]= 0.060863;  daa[10*20+4]= 0.091709;  daa[10*20+5]= 0.24353;   daa[10*20+6]= 0.151924;  
    daa[10*20+7]= 0.087056;  daa[10*20+8]= 0.103552;  daa[10*20+9]= 2.08989;   daa[11*20+0]= 0.393245;  
    daa[11*20+1]= 1.755838;  daa[11*20+2]= 0.50306;   daa[11*20+3]= 0.261101;  daa[11*20+4]= 0.004067;  
    daa[11*20+5]= 0.738208;  daa[11*20+6]= 0.88863;   daa[11*20+7]= 0.193243;  daa[11*20+8]= 0.153323;  
    daa[11*20+9]= 0.093181;  daa[11*20+10]= 0.201204; daa[12*20+0]= 0.21155;   daa[12*20+1]= 0.08793;   
    daa[12*20+2]= 0.05742;   daa[12*20+3]= 0.012182;  daa[12*20+4]= 0.02369;   daa[12*20+5]= 0.120801;  
    daa[12*20+6]= 0.058643;  daa[12*20+7]= 0.04656;   daa[12*20+8]= 0.021157;  daa[12*20+9]= 0.493845;  
    daa[12*20+10]= 1.105667; daa[12*20+11]= 0.096474; daa[13*20+0]= 0.116646;  daa[13*20+1]= 0.042569;  
    daa[13*20+2]= 0.039769;  daa[13*20+3]= 0.016577;  daa[13*20+4]= 0.051127;  daa[13*20+5]= 0.026235;  
    daa[13*20+6]= 0.028168;  daa[13*20+7]= 0.050143;  daa[13*20+8]= 0.079807;  daa[13*20+9]= 0.32102;   
    daa[13*20+10]= 0.946499; daa[13*20+11]= 0.038261; daa[13*20+12]= 0.173052; daa[14*20+0]= 0.399143;  
    daa[14*20+1]= 0.12848;   daa[14*20+2]= 0.083956;  daa[14*20+3]= 0.160063;  daa[14*20+4]= 0.011137;  
    daa[14*20+5]= 0.15657;   daa[14*20+6]= 0.205134;  daa[14*20+7]= 0.124492;  daa[14*20+8]= 0.078892;  
    daa[14*20+9]= 0.054797;  daa[14*20+10]= 0.169784; daa[14*20+11]= 0.212302; daa[14*20+12]= 0.010363; 
    daa[14*20+13]= 0.042564; daa[15*20+0]= 1.817198;  daa[15*20+1]= 0.292327;  daa[15*20+2]= 0.847049;  
    daa[15*20+3]= 0.461519;  daa[15*20+4]= 0.17527;   daa[15*20+5]= 0.358017;  daa[15*20+6]= 0.406035;  
    daa[15*20+7]= 0.612843;  daa[15*20+8]= 0.167406;  daa[15*20+9]= 0.081567;  daa[15*20+10]= 0.214977; 
    daa[15*20+11]= 0.400072; daa[15*20+12]= 0.090515; daa[15*20+13]= 0.138119; daa[15*20+14]= 0.430431; 
    daa[16*20+0]= 0.877877;  daa[16*20+1]= 0.204109;  daa[16*20+2]= 0.471268;  daa[16*20+3]= 0.178197;  
    daa[16*20+4]= 0.079511;  daa[16*20+5]= 0.248992;  daa[16*20+6]= 0.321028;  daa[16*20+7]= 0.136266;  
    daa[16*20+8]= 0.101117;  daa[16*20+9]= 0.376588;  daa[16*20+10]= 0.243227; daa[16*20+11]= 0.446646; 
    daa[16*20+12]= 0.184609; daa[16*20+13]= 0.08587;  daa[16*20+14]= 0.207143; daa[16*20+15]= 1.767766; 
    daa[17*20+0]= 0.030309;  daa[17*20+1]= 0.046417;  daa[17*20+2]= 0.010459;  daa[17*20+3]= 0.011393;  
    daa[17*20+4]= 0.007732;  daa[17*20+5]= 0.021248;  daa[17*20+6]= 0.018844;  daa[17*20+7]= 0.02399;   
    daa[17*20+8]= 0.020009;  daa[17*20+9]= 0.034954;  daa[17*20+10]= 0.083439; daa[17*20+11]= 0.023321; 
    daa[17*20+12]= 0.022019; daa[17*20+13]= 0.12805;  daa[17*20+14]= 0.014584; daa[17*20+15]= 0.035933; 
    daa[17*20+16]= 0.020437; daa[18*20+0]= 0.087061;  daa[18*20+1]= 0.09701;   daa[18*20+2]= 0.093268;  
    daa[18*20+3]= 0.051664;  daa[18*20+4]= 0.042823;  daa[18*20+5]= 0.062544;  daa[18*20+6]= 0.0552;    
    daa[18*20+7]= 0.037568;  daa[18*20+8]= 0.286027;  daa[18*20+9]= 0.086237;  daa[18*20+10]= 0.189842; 
    daa[18*20+11]= 0.068689; daa[18*20+12]= 0.073223; daa[18*20+13]= 0.898663; daa[18*20+14]= 0.032043; 
    daa[18*20+15]= 0.121979; daa[18*20+16]= 0.094617; daa[18*20+17]= 0.124746; daa[19*20+0]= 1.230985;  
    daa[19*20+1]= 0.113146;  daa[19*20+2]= 0.049824;  daa[19*20+3]= 0.048769;  daa[19*20+4]= 0.163831;  
    daa[19*20+5]= 0.112027;  daa[19*20+6]= 0.205868;  daa[19*20+7]= 0.082579;  daa[19*20+8]= 0.068575;  
    daa[19*20+9]= 3.65443;   daa[19*20+10]= 1.337571; daa[19*20+11]= 0.144587; daa[19*20+12]= 0.307309; 
    daa[19*20+13]= 0.247329; daa[19*20+14]= 0.129315; daa[19*20+15]= 0.1277;   daa[19*20+16]= 0.740372; 
    daa[19*20+17]= 0.022134; daa[19*20+18]= 0.125733; 

    for (i=0; i<naa; i++)  for (j=0; j<i; j++)  daa[j*naa+i] = daa[i*naa+j];

    pi[0]= 0.078837;         pi[1]= 0.051238;         pi[2]= 0.042313;         pi[3]= 0.053066;         
    pi[4]= 0.015175;         pi[5]= 0.036713;         pi[6]= 0.061924;         pi[7]= 0.070852;         
    pi[8]= 0.023082;         pi[9]= 0.062056;         pi[10]= 0.096371;        pi[11]= 0.057324;        
    pi[12]= 0.023771;        pi[13]= 0.043296;        pi[14]= 0.043911;        pi[15]= 0.063403;        
    pi[16]= 0.055897;        pi[17]= 0.013272;        pi[18]= 0.034399;        pi[19]= 0.073101;        
    return 1;
}

/*********************************************************/

int Init_Qmat_Blosum62 (double *daa, double *pi)
{

    /* 
       This model has been 'translated' from John Huelsenbeck and Fredrik Ronquist
       MrBayes program into PHYML format by Federico Abascal. Many thanks to them. 
    */

    /*
      Henikoff, S., and J. G. Henikoff. 1992. Amino acid substitution            
      matrices from protein blocks. Proc. Natl. Acad. Sci., U.S.A.            
      89:10915-10919.                                                         
    */

    int i,j,naa;
    naa = 20;

    daa[1*20+0]= 0.735790389698;  daa[2*20+0]= 0.485391055466;  daa[2*20+1]= 1.297446705134;  daa[3*20+0]= 0.543161820899;  
    daa[3*20+1]= 0.500964408555;  daa[3*20+2]= 3.180100048216;  daa[4*20+0]= 1.45999531047;   daa[4*20+1]= 0.227826574209;  
    daa[4*20+2]= 0.397358949897;  daa[4*20+3]= 0.240836614802;  daa[5*20+0]= 1.199705704602;  daa[5*20+1]= 3.020833610064;  
    daa[5*20+2]= 1.839216146992;  daa[5*20+3]= 1.190945703396;  daa[5*20+4]= 0.32980150463;   daa[6*20+0]= 1.1709490428;    
    daa[6*20+1]= 1.36057419042;   daa[6*20+2]= 1.24048850864;   daa[6*20+3]= 3.761625208368;  daa[6*20+4]= 0.140748891814;  
    daa[6*20+5]= 5.528919177928;  daa[7*20+0]= 1.95588357496;   daa[7*20+1]= 0.418763308518;  daa[7*20+2]= 1.355872344485;  
    daa[7*20+3]= 0.798473248968;  daa[7*20+4]= 0.418203192284;  daa[7*20+5]= 0.609846305383;  daa[7*20+6]= 0.423579992176;  
    daa[8*20+0]= 0.716241444998;  daa[8*20+1]= 1.456141166336;  daa[8*20+2]= 2.414501434208;  daa[8*20+3]= 0.778142664022;  
    daa[8*20+4]= 0.354058109831;  daa[8*20+5]= 2.43534113114;   daa[8*20+6]= 1.626891056982;  daa[8*20+7]= 0.539859124954;  
    daa[9*20+0]= 0.605899003687;  daa[9*20+1]= 0.232036445142;  daa[9*20+2]= 0.283017326278;  daa[9*20+3]= 0.418555732462;  
    daa[9*20+4]= 0.774894022794;  daa[9*20+5]= 0.236202451204;  daa[9*20+6]= 0.186848046932;  daa[9*20+7]= 0.189296292376;  
    daa[9*20+8]= 0.252718447885;  daa[10*20+0]= 0.800016530518; daa[10*20+1]= 0.622711669692; daa[10*20+2]= 0.211888159615; 
    daa[10*20+3]= 0.218131577594; daa[10*20+4]= 0.831842640142; daa[10*20+5]= 0.580737093181; daa[10*20+6]= 0.372625175087; 
    daa[10*20+7]= 0.217721159236; daa[10*20+8]= 0.348072209797; daa[10*20+9]= 3.890963773304; daa[11*20+0]= 1.295201266783; 
    daa[11*20+1]= 5.411115141489; daa[11*20+2]= 1.593137043457; daa[11*20+3]= 1.032447924952; daa[11*20+4]= 0.285078800906; 
    daa[11*20+5]= 3.945277674515; daa[11*20+6]= 2.802427151679; daa[11*20+7]= 0.752042440303; daa[11*20+8]= 1.022507035889; 
    daa[11*20+9]= 0.406193586642; daa[11*20+10]= 0.445570274261;daa[12*20+0]= 1.253758266664; daa[12*20+1]= 0.983692987457; 
    daa[12*20+2]= 0.648441278787; daa[12*20+3]= 0.222621897958; daa[12*20+4]= 0.76768882348;  daa[12*20+5]= 2.494896077113; 
    daa[12*20+6]= 0.55541539747;  daa[12*20+7]= 0.459436173579; daa[12*20+8]= 0.984311525359; daa[12*20+9]= 3.364797763104; 
    daa[12*20+10]= 6.030559379572;daa[12*20+11]= 1.073061184332;daa[13*20+0]= 0.492964679748; daa[13*20+1]= 0.371644693209; 
    daa[13*20+2]= 0.354861249223; daa[13*20+3]= 0.281730694207; daa[13*20+4]= 0.441337471187; daa[13*20+5]= 0.14435695975;  
    daa[13*20+6]= 0.291409084165; daa[13*20+7]= 0.368166464453; daa[13*20+8]= 0.714533703928; daa[13*20+9]= 1.517359325954; 
    daa[13*20+10]= 2.064839703237;daa[13*20+11]= 0.266924750511;daa[13*20+12]= 1.77385516883; daa[14*20+0]= 1.173275900924; 
    daa[14*20+1]= 0.448133661718; daa[14*20+2]= 0.494887043702; daa[14*20+3]= 0.730628272998; daa[14*20+4]= 0.356008498769; 
    daa[14*20+5]= 0.858570575674; daa[14*20+6]= 0.926563934846; daa[14*20+7]= 0.504086599527; daa[14*20+8]= 0.527007339151; 
    daa[14*20+9]= 0.388355409206; daa[14*20+10]= 0.374555687471;daa[14*20+11]= 1.047383450722;daa[14*20+12]= 0.454123625103;
    daa[14*20+13]= 0.233597909629;daa[15*20+0]= 4.325092687057; daa[15*20+1]= 1.12278310421;  daa[15*20+2]= 2.904101656456; 
    daa[15*20+3]= 1.582754142065; daa[15*20+4]= 1.197188415094; daa[15*20+5]= 1.934870924596; daa[15*20+6]= 1.769893238937; 
    daa[15*20+7]= 1.509326253224; daa[15*20+8]= 1.11702976291;  daa[15*20+9]= 0.35754441246;  daa[15*20+10]= 0.352969184527;
    daa[15*20+11]= 1.752165917819;daa[15*20+12]= 0.918723415746;daa[15*20+13]= 0.540027644824;daa[15*20+14]= 1.169129577716;
    daa[16*20+0]= 1.729178019485; daa[16*20+1]= 0.914665954563; daa[16*20+2]= 1.898173634533; daa[16*20+3]= 0.934187509431; 
    daa[16*20+4]= 1.119831358516; daa[16*20+5]= 1.277480294596; daa[16*20+6]= 1.071097236007; daa[16*20+7]= 0.641436011405; 
    daa[16*20+8]= 0.585407090225; daa[16*20+9]= 1.17909119726;  daa[16*20+10]= 0.915259857694;daa[16*20+11]= 1.303875200799;
    daa[16*20+12]= 1.488548053722;daa[16*20+13]= 0.488206118793;daa[16*20+14]= 1.005451683149;daa[16*20+15]= 5.15155629227; 
    daa[17*20+0]= 0.465839367725; daa[17*20+1]= 0.426382310122; daa[17*20+2]= 0.191482046247; daa[17*20+3]= 0.145345046279; 
    daa[17*20+4]= 0.527664418872; daa[17*20+5]= 0.758653808642; daa[17*20+6]= 0.407635648938; daa[17*20+7]= 0.508358924638; 
    daa[17*20+8]= 0.30124860078;  daa[17*20+9]= 0.34198578754;  daa[17*20+10]= 0.6914746346;  daa[17*20+11]= 0.332243040634;
    daa[17*20+12]= 0.888101098152;daa[17*20+13]= 2.074324893497;daa[17*20+14]= 0.252214830027;daa[17*20+15]= 0.387925622098;
    daa[17*20+16]= 0.513128126891;daa[18*20+0]= 0.718206697586; daa[18*20+1]= 0.720517441216; daa[18*20+2]= 0.538222519037; 
    daa[18*20+3]= 0.261422208965; daa[18*20+4]= 0.470237733696; daa[18*20+5]= 0.95898974285;  daa[18*20+6]= 0.596719300346; 
    daa[18*20+7]= 0.308055737035; daa[18*20+8]= 4.218953969389; daa[18*20+9]= 0.674617093228; daa[18*20+10]= 0.811245856323;
    daa[18*20+11]= 0.7179934869;  daa[18*20+12]= 0.951682162246;daa[18*20+13]= 6.747260430801;daa[18*20+14]= 0.369405319355;
    daa[18*20+15]= 0.796751520761;daa[18*20+16]= 0.801010243199;daa[18*20+17]= 4.054419006558;daa[19*20+0]= 2.187774522005; 
    daa[19*20+1]= 0.438388343772; daa[19*20+2]= 0.312858797993; daa[19*20+3]= 0.258129289418; daa[19*20+4]= 1.116352478606; 
    daa[19*20+5]= 0.530785790125; daa[19*20+6]= 0.524253846338; daa[19*20+7]= 0.25334079019;  daa[19*20+8]= 0.20155597175;  
    daa[19*20+9]= 8.311839405458; daa[19*20+10]= 2.231405688913;daa[19*20+11]= 0.498138475304;daa[19*20+12]= 2.575850755315;
    daa[19*20+13]= 0.838119610178;daa[19*20+14]= 0.496908410676;daa[19*20+15]= 0.561925457442;daa[19*20+16]= 2.253074051176;
    daa[19*20+17]= 0.266508731426;daa[19*20+18]= 1;             

    for (i=0; i<naa; i++)  for (j=0; j<i; j++)  daa[j*naa+i] = daa[i*naa+j];

    pi[0]= 0.074;                 pi[1]= 0.052;                 pi[2]= 0.045;                 pi[3]= 0.054;                 
    pi[4]= 0.025;                 pi[5]= 0.034;                 pi[6]= 0.054;                 pi[7]= 0.074;                 
    pi[8]= 0.026;                 pi[9]= 0.068;                 pi[10]= 0.099;                pi[11]= 0.058;                
    pi[12]= 0.025;                pi[13]= 0.047;                pi[14]= 0.039;                pi[15]= 0.057;                
    pi[16]= 0.051;                pi[17]= 0.013;                pi[18]= 0.032;                pi[19]= 0.073;                

    return 1;
  }

/*********************************************************/

int Init_Qmat_MtMam(double *daa, double *pi)
{
    /* 
       This model has been 'translated' from Ziheng Yang's PAML program 
       into PHYML format by Federico Abascal. Many thanks to them. 
    */

    /*
      Cao, Y. et al. 1998 Conflict amongst individual mitochondrial 
      proteins in resolving the phylogeny of eutherian orders. Journal 
      of Molecular Evolution 15:1600-1611.
    */

    int i,j,naa;
    naa = 20;
    
    daa[1*20+0]= 32;              daa[2*20+0]= 2;    daa[2*20+1]= 4;               daa[3*20+0]= 11;
    daa[3*20+1]= 0;               daa[3*20+2]= 864;  daa[4*20+0]= 0;               daa[4*20+1]= 186;
    daa[4*20+2]= 0;               daa[4*20+3]= 0;    daa[5*20+0]= 0;               daa[5*20+1]= 246;
    daa[5*20+2]= 8;               daa[5*20+3]= 49;   daa[5*20+4]= 0;               daa[6*20+0]= 0;
    daa[6*20+1]= 0;               daa[6*20+2]= 0;    daa[6*20+3]= 569;             daa[6*20+4]= 0;
    daa[6*20+5]= 274;             daa[7*20+0]= 78;   daa[7*20+1]= 18;              daa[7*20+2]= 47;
    daa[7*20+3]= 79;              daa[7*20+4]= 0;    daa[7*20+5]= 0;               daa[7*20+6]= 22;
    daa[8*20+0]= 8;               daa[8*20+1]= 232;  daa[8*20+2]= 458;             daa[8*20+3]= 11;
    daa[8*20+4]= 305;             daa[8*20+5]= 550;  daa[8*20+6]= 22;              daa[8*20+7]= 0;
    daa[9*20+0]= 75;              daa[9*20+1]= 0;    daa[9*20+2]= 19;              daa[9*20+3]= 0;
    daa[9*20+4]= 41;              daa[9*20+5]= 0;    daa[9*20+6]= 0;               daa[9*20+7]= 0;
    daa[9*20+8]= 0;               daa[10*20+0]= 21;  daa[10*20+1]= 6;              daa[10*20+2]= 0;
    daa[10*20+3]= 0;              daa[10*20+4]= 27;  daa[10*20+5]= 20;             daa[10*20+6]= 0;
    daa[10*20+7]= 0;              daa[10*20+8]= 26;  daa[10*20+9]= 232;            daa[11*20+0]= 0;
    daa[11*20+1]= 50;             daa[11*20+2]= 408; daa[11*20+3]= 0;              daa[11*20+4]= 0;
    daa[11*20+5]= 242;            daa[11*20+6]= 215; daa[11*20+7]= 0;              daa[11*20+8]= 0;
    daa[11*20+9]= 6;              daa[11*20+10]= 4;  daa[12*20+0]= 76;             daa[12*20+1]= 0;
    daa[12*20+2]= 21;             daa[12*20+3]= 0;   daa[12*20+4]= 0;              daa[12*20+5]= 22;
    daa[12*20+6]= 0;              daa[12*20+7]= 0;   daa[12*20+8]= 0;              daa[12*20+9]= 378;
    daa[12*20+10]= 609;           daa[12*20+11]= 59; daa[13*20+0]= 0;              daa[13*20+1]= 0;
    daa[13*20+2]= 6;              daa[13*20+3]= 5;   daa[13*20+4]= 7;              daa[13*20+5]= 0;
    daa[13*20+6]= 0;              daa[13*20+7]= 0;   daa[13*20+8]= 0;              daa[13*20+9]= 57;
    daa[13*20+10]= 246;           daa[13*20+11]= 0;  daa[13*20+12]= 11;            daa[14*20+0]= 53;
    daa[14*20+1]= 9;              daa[14*20+2]= 33;  daa[14*20+3]= 2;              daa[14*20+4]= 0;
    daa[14*20+5]= 51;             daa[14*20+6]= 0;   daa[14*20+7]= 0;              daa[14*20+8]= 53;
    daa[14*20+9]= 5;              daa[14*20+10]= 43; daa[14*20+11]= 18;            daa[14*20+12]= 0;
    daa[14*20+13]= 17;            daa[15*20+0]= 342; daa[15*20+1]= 3;              daa[15*20+2]= 446;
    daa[15*20+3]= 16;             daa[15*20+4]= 347; daa[15*20+5]= 30;             daa[15*20+6]= 21;
    daa[15*20+7]= 112;            daa[15*20+8]= 20;  daa[15*20+9]= 0;              daa[15*20+10]= 74;
    daa[15*20+11]= 65;            daa[15*20+12]= 47; daa[15*20+13]= 90;            daa[15*20+14]= 202;
    daa[16*20+0]= 681;            daa[16*20+1]= 0;   daa[16*20+2]= 110;            daa[16*20+3]= 0;
    daa[16*20+4]= 114;            daa[16*20+5]= 0;   daa[16*20+6]= 4;              daa[16*20+7]= 0;
    daa[16*20+8]= 1;              daa[16*20+9]= 360; daa[16*20+10]= 34;            daa[16*20+11]= 50;
    daa[16*20+12]= 691;           daa[16*20+13]= 8;  daa[16*20+14]= 78;            daa[16*20+15]= 614;
    daa[17*20+0]= 5;              daa[17*20+1]= 16;  daa[17*20+2]= 6;              daa[17*20+3]= 0;
    daa[17*20+4]= 65;             daa[17*20+5]= 0;   daa[17*20+6]= 0;              daa[17*20+7]= 0;
    daa[17*20+8]= 0;              daa[17*20+9]= 0;   daa[17*20+10]= 12;            daa[17*20+11]= 0;
    daa[17*20+12]= 13;            daa[17*20+13]= 0;  daa[17*20+14]= 7;             daa[17*20+15]= 17;
    daa[17*20+16]= 0;             daa[18*20+0]= 0;   daa[18*20+1]= 0;              daa[18*20+2]= 156;
    daa[18*20+3]= 0;              daa[18*20+4]= 530; daa[18*20+5]= 54;             daa[18*20+6]= 0;
    daa[18*20+7]= 1;              daa[18*20+8]= 1525;daa[18*20+9]= 16;             daa[18*20+10]= 25;
    daa[18*20+11]= 67;            daa[18*20+12]= 0;  daa[18*20+13]= 682;           daa[18*20+14]= 8;
    daa[18*20+15]= 107;           daa[18*20+16]= 0;  daa[18*20+17]= 14;            daa[19*20+0]= 398;
    daa[19*20+1]= 0;              daa[19*20+2]= 0;   daa[19*20+3]= 10;             daa[19*20+4]= 0;
    daa[19*20+5]= 33;             daa[19*20+6]= 20;  daa[19*20+7]= 5;              daa[19*20+8]= 0;
    daa[19*20+9]= 2220;           daa[19*20+10]= 100;daa[19*20+11]= 0;             daa[19*20+12]= 832;
    daa[19*20+13]= 6;             daa[19*20+14]= 0;  daa[19*20+15]= 0;             daa[19*20+16]= 237;
    daa[19*20+17]= 0;             daa[19*20+18]= 0;
    
    for (i=0; i<naa; i++) for (j=0; j<i; j++) daa[j*naa+i] = daa[i*naa+j];
    
    pi[0]= 0.0692;  pi[1]=  0.0184;  pi[2]= 0.04;    pi[3]= 0.0186;
    pi[4]= 0.0065;  pi[5]=  0.0238;  pi[6]= 0.0236;  pi[7]= 0.0557;
    pi[8]= 0.0277;  pi[9]=  0.0905;  pi[10]=0.1675;  pi[11]= 0.0221;
    pi[12]=0.0561;  pi[13]= 0.0611;  pi[14]=0.0536;  pi[15]= 0.0725;
    pi[16]=0.087;   pi[17]= 0.0293;  pi[18]=0.034;   pi[19]= 0.0428;
    
    return 1;
}

                         
/*********************************************************/

void Init_Model(allseq *data, model *mod)
{
  int i,j;
  int ns;
  double sum,aux;
  int result;
  double *dr, *di, *space;


  if(data) mod->seq_len = data->init_len;

   
  For(i,mod->n_catg) 
    {
      mod->rr[i]      = 1.0;
      mod->r_proba[i] = 1.0;
    }

 
  if(!mod->invar) For(i,data->crunch_len) data->invar[i] = 0;

  ns = mod->ns;
  mod->datatype = (mod->whichmodel>=10)?((mod->whichmodel>20)?(0):(1)):(0);


  dr      = (double *)mCalloc(  ns,sizeof(double));
  di      = (double *)mCalloc(  ns,sizeof(double));
  space   = (double *)mCalloc(2*ns,sizeof(double));

  

  For(i,ns)
      mod->pi[i] = data->b_frq[i];

  if(!mod->datatype) /* Nucleotides */
    { 
      if(mod->whichmodel < 40)
	{
	  /* init for nucleotides */
	  mod->lambda = 1.;
	  
	  if((mod->whichmodel==1) || (mod->whichmodel==2))
	    {
	      mod->pi[0] = mod->pi[1] = mod->pi[2] = mod->pi[3] = .25;
	    }
	  
	  if((mod->whichmodel==1) || (mod->whichmodel==3) || (mod->whichmodel==7) || (mod->whichmodel==8))
	    {
	      mod->kappa = 1.;
	    }
	  
	  if(mod->whichmodel == 5)
	    {
	      aux = ((mod->pi[0]+mod->pi[2])-(mod->pi[1]+mod->pi[3]))/(2.*mod->kappa);
	      mod->lambda = ((mod->pi[1]+mod->pi[3]) + aux)/((mod->pi[0]+mod->pi[2]) - aux); 
	    }
	  
	  if(mod->whichmodel == 7)
	    {		  
	      mod->custom_mod_string[0] = '0';
	      mod->custom_mod_string[1] = '1';
	      mod->custom_mod_string[2] = '2';
	      mod->custom_mod_string[3] = '3';
	      mod->custom_mod_string[4] = '4';
	      mod->custom_mod_string[5] = '5';
	      Translate_Custom_Mod_String(mod);
	      Update_Qmat_GTR(mod);
	    }

	  if(mod->whichmodel == 8)
              {
                  
	      if(mod->user_b_freq[0] > -1.)
                  {
                      For(i,4) 
                          {
                              mod->pi[i] = mod->user_b_freq[i];
                          }
                  }
	      Update_Qmat_GTR(mod);
	    }
	  
	}
      else
	{
	  /* init for codon model */
	  For(i,64) mod->pi[i] = 1./61;
	}
    }
  else 
    { /* init for amino-acids */
      /* see comments of PMat_Empirical for details */
      /* read pi and Q from file */
      
      
      switch(mod->whichmodel)
	{
	case 11 : 
	  {
	    Init_Qmat_Dayhoff(mod->mat_Q,mod->pi);
	    break;
	  }
	case 12 : 
	  {
	    Init_Qmat_JTT(mod->mat_Q,mod->pi);
	    break;
	  }
	case 13 : 
	  {
	    Init_Qmat_MtREV(mod->mat_Q,mod->pi);
	    break;
	  }
	case 14 : 
	  {
	    Init_Qmat_WAG(mod->mat_Q,mod->pi);
	    break;
	  }
	case 15 : 
	  {
	    Init_Qmat_DCMut(mod->mat_Q,mod->pi);
	    break;
	  }
	case 16 : 
	  {
	    Init_Qmat_RtREV(mod->mat_Q,mod->pi);
	    break;
	  }
	case 17 : 
	  {
	    Init_Qmat_CpREV(mod->mat_Q,mod->pi);
	    break;
	  }
	case 18 : 
	  {
	    Init_Qmat_VT(mod->mat_Q,mod->pi);
	    break;
	  }
	case 19 : 
	  {
	    Init_Qmat_Blosum62(mod->mat_Q,mod->pi);
	    break;
	  }
	case 20 : 
	  {
	    Init_Qmat_MtMam(mod->mat_Q,mod->pi);
	    break;
	  }
	default : break;
	}


      /* multiply the nth col of Q by the nth term of pi/100 just as in PAML */
      For(i,ns) For(j,ns) mod->mat_Q[i*ns+j] *= mod->pi[j] / 100.0;

      
      /* compute diagonal terms of Q and mean rate mr = l/t */
      mod->mr = .0;
      For (i,ns)
	{
	  sum=.0;
	  For(j, ns) sum += mod->mat_Q[i*ns+j];
	  mod->mat_Q[i*ns+i] = -sum;
	  mod->mr += mod->pi[i] * sum;
	}

      /* scale instantaneous rate matrix so that mu=1 */
      For (i,ns*ns) mod->mat_Q[i] /= mod->mr;


      /* compute eigenvectors/values */
      result = 0;
      if (result==eigen(1, mod->mat_Q,ns,dr,di,mod->mat_Vr, mod->mat_Vi, space))
	{
	  /* compute inverse(Vr) into Vi */
	  For (i,ns*ns) mod->mat_Vi[i] = mod->mat_Vr[i];
	  Matinv(mod->mat_Vi, ns, ns, space);
	  
	  /* compute the diagonal terms of exp(D) */
	  For (i,ns)  mod->vct_eDmr[i] = exp(dr[i]);
	}
      else
	{
	  if (result==-1)
	    printf("\n. Eigenvalues/vectors computation does not converge : computation cancelled");
	  else if (result==1)
	    printf("\n. Complex eigenvalues/vectors : computation cancelled");
	}
    }

  mod->alpha_old  = mod->alpha;
  mod->kappa_old  = mod->kappa;
  mod->lambda_old = mod->lambda;
  mod->pinvar_old = mod->pinvar;


  free(dr);free(di);free(space);
}

/*********************************************************/

void Update_Qmat_GTR(model *mod)
{
  int result;
  int i,j,ns;
  double *di,*space,*mat_buff;

  ns = 4;
  
  di    = (double *)mCalloc(ns,sizeof(double));
  space = (double *)mCalloc(2*ns,sizeof(double));
  mat_buff = (double *)mCalloc(ns*ns,sizeof(double));


  mod->mat_Q[0*4+1] = *(mod->rr_param[0])*mod->pi[1];
  mod->mat_Q[0*4+2] = *(mod->rr_param[1])*mod->pi[2];
  mod->mat_Q[0*4+3] = *(mod->rr_param[2])*mod->pi[3];
  
  mod->mat_Q[1*4+0] = *(mod->rr_param[0])*mod->pi[0];
  mod->mat_Q[1*4+2] = *(mod->rr_param[3])*mod->pi[2];
  mod->mat_Q[1*4+3] = *(mod->rr_param[4])*mod->pi[3];

  mod->mat_Q[2*4+0] = *(mod->rr_param[1])*mod->pi[0];
  mod->mat_Q[2*4+1] = *(mod->rr_param[3])*mod->pi[1];
  mod->mat_Q[2*4+3] =              1.0*mod->pi[3];

  mod->mat_Q[3*4+0] = *(mod->rr_param[2])*mod->pi[0];
  mod->mat_Q[3*4+1] = *(mod->rr_param[4])*mod->pi[1];
  mod->mat_Q[3*4+2] =              1.0*mod->pi[2];

  mod->mat_Q[0*4+0] = -(*(mod->rr_param[0])*mod->pi[1]+*(mod->rr_param[1])*mod->pi[2]+*(mod->rr_param[2])*mod->pi[3]);
  mod->mat_Q[1*4+1] = -(*(mod->rr_param[0])*mod->pi[0]+*(mod->rr_param[3])*mod->pi[2]+*(mod->rr_param[4])*mod->pi[3]);
  mod->mat_Q[2*4+2] = -(*(mod->rr_param[1])*mod->pi[0]+*(mod->rr_param[3])*mod->pi[1]+1.0*mod->pi[3]);
  mod->mat_Q[3*4+3] = -(*(mod->rr_param[2])*mod->pi[0]+*(mod->rr_param[4])*mod->pi[1]+1.0*mod->pi[2]);



  /* compute diagonal terms of Q and mean rate mr = l/t */
  mod->mr = .0;
  For (i,ns) mod->mr += mod->pi[i] * (-mod->mat_Q[i*ns+i]);
  For(i,ns*ns) mod->mat_Q[i] /= mod->mr;
/*   printf("mr=%f\n",mod->mr); */
  
  /* compute eigenvectors/values */
  result = 0;
  For(i,ns) For(j,ns) mat_buff[i*ns+j] = mod->mat_Q[i*ns+j];
  
  if (result==eigen(1,mat_buff,ns,mod->vct_ev,di,mod->mat_Vr, mod->mat_Vi, space))
    {
    /* compute inverse(Vr) into Vi */
      For (i,ns*ns) mod->mat_Vi[i] = mod->mat_Vr[i];
      Matinv(mod->mat_Vi, ns, ns, space);
      
      /* compute the diagonal terms of exp(D) */
      For (i,ns)  mod->vct_eDmr[i] = exp(mod->vct_ev[i]);
    }
  else
    {
      if (result==-1)
	printf("eigenvalues/vectors computation does not converge : computation cancelled");
      else if (result==1)
	printf("complex eigenvalues/vectors : computation cancelled");
    }

  
  Free(di);
  Free(space);
  Free(mat_buff);
}

/*********************************************************/

void Translate_Custom_Mod_String(model *mod)
{
  int identity;
  int i,j;
  int *n_diff_param;
  int *mod_code;

  mod_code = (int *)mCalloc(6,sizeof(int));

  n_diff_param = &(mod->n_diff_rr_param);

  *n_diff_param=0;

  For(i,6)
    {

      identity = -1;

      For(j,i)
	{
	  if((mod->custom_mod_string[i] == 
	      mod->custom_mod_string[j]))
	    {
	      identity = j;
	      break;
	    }
	}

      if(identity == -1)
	{
	  mod->rr_param_num[*n_diff_param][0] = i;
	  mod->n_rr_param_per_cat[*n_diff_param] = 1;
	  mod_code[i] = *n_diff_param;
	  (*n_diff_param)++;
	}
      else
	{
	  mod_code[i] = mod_code[identity];
	  mod->rr_param_num[mod_code[i]]
	    [mod->n_rr_param_per_cat[mod_code[i]]] = i;
	  mod->n_rr_param_per_cat[mod_code[i]] += 1;
	}
    }

  Free(mod_code);

}

/*********************************************************/

void Set_Model_Parameters(arbre *tree)
{
  double sum;
  int i;


  DiscreteGamma (tree->mod->r_proba, tree->mod->rr, tree->mod->alpha,
		 tree->mod->alpha,tree->mod->n_catg,0);
   

  if((tree->mod->whichmodel < 10) && (tree->mod->s_opt->opt_bfreq))
    {
      sum = .0;
      For(i,4) sum += tree->mod->pi[i];
      For(i,4) 
	{
	  tree->mod->pi[i] /= sum;
/* 	  printf("pi[%d]->%f\n",i+1,tree->mod->pi[i]); */
	}
    }


  if(tree->mod->whichmodel >= 7)
    {
        For(i,6) 
            {
                tree->mod->rr_param_values[i] /= tree->mod->rr_param_values[5];
            }
    }

  if(tree->mod->update_eigen) 
    {
      if(!tree->mod->datatype)
	{
	  if(tree->mod->whichmodel < 20) Update_Qmat_GTR(tree->mod);
	}
    }

}

/*********************************************************/
