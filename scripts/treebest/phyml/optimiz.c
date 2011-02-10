/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#include "utilities.h"
#include "optimiz.h"
#include "ml.h"
#include "free.h"

double UNLIKELY;
double ROUND_MAX;
double MIN_DIFF_LK;

/*********************************************************/

void Optimize_Single_Param_Generic(arbre *tree, double *param, 
				   double start, 
				   double lim_inf, double lim_sup,
				   int n_max_iter)
{
  double ax,bx,cx;
/*   double fa,fb,fc; */
  double lk_init;

  lk_init = tree->tot_loglk;

  tree->mod->s_opt->opt_bl = 
  tree->both_sides         = 0;

  ax =  lim_inf;
  if((*param < lim_inf) ||
     (*param > lim_sup)) bx = (lim_sup-lim_inf)/2.;
  else bx = start;
  cx = lim_sup;
  
/*   Generic_Brak(param, */
/* 	       &ax,&bx,&cx, */
/* 	       &fa,&fb,&fc, */
/* 	       lim_inf, lim_sup, */
/* 	       tree); */
  
  Generic_Brent(param,
		ax,bx,cx,1.e-10,
		param,tree,n_max_iter);

  if(tree->tot_loglk < lk_init-MIN_DIFF_LK) 
    {
      printf("\n %.10f < %.10f --> diff=%.10f\n",
	     tree->tot_loglk,lk_init,
	     tree->tot_loglk-lk_init);
      Exit("\n. Optimisation failed !\n");
    }
}

/*********************************************************/

int Generic_Brak(double *param,
		 double *ax, double *bx, double *cx, 
		 double *fa, double *fb, double *fc,
		 double lim_inf, double lim_sup,
		 arbre *tree)
{
   double ulim,u,r,q,fu,dum;

   u = 0.0;
   *param = *ax;

   if(*param > lim_sup) *param = lim_sup;
   if(*param < lim_inf) *param = lim_inf;
   *fa=-Return_Lk(tree);
   *param = *bx;
   if(*param > lim_sup) *param = lim_sup;
   if(*param < lim_inf) *param = lim_inf;
   *fb=-Return_Lk(tree);
   if (*fb > *fa) {
      SHFT(dum,*ax,*bx,dum)
      SHFT(dum,*fb,*fa,dum)
   }
   *cx=(*bx)+MNBRAK_GOLD*(*bx-*ax);
   *param = fabs(*cx);
   if(*param > lim_sup) *param = lim_sup;
   if(*param < lim_inf) *param = lim_inf;
   *fc=-Return_Lk(tree); 
   while (*fb > *fc) 
     {
        
       if(*ax > lim_sup) *ax = lim_sup;
       if(*ax < lim_inf) *ax = lim_inf;
       if(*bx > lim_sup) *bx = lim_sup;
       if(*bx < lim_inf) *bx = lim_inf;
       if(*cx > lim_sup) *cx = lim_sup;
       if(*cx < lim_inf) *cx = lim_inf;
       if(u   > lim_sup) u   = lim_sup;
       if(u   < lim_inf) u   = lim_inf;

       r=(*bx-*ax)*(*fb-*fc);
       q=(*bx-*cx)*(*fb-*fa);
       u=(*bx)-((*bx-*cx)*q-(*bx-*ax)*r)/
               (2.0*SIGN(MAX(fabs(q-r),MNBRAK_TINY),q-r));
       ulim=(*bx)+MNBRAK_GLIMIT*(*cx-*bx);
       
       if ((*bx-u)*(u-*cx) > lim_inf) 
	 {
	   *param = fabs(u);
	   if(*param > lim_sup) {*param = u = lim_sup;}
	   if(*param < lim_inf) {*param = u = lim_inf;}
	   fu=-Return_Lk(tree);
	   if (fu < *fc) 
	     {
	       *ax=(*bx);
	       *bx=u;
	       *fa=(*fb);
	       *fb=fu;
	       (*ax)=fabs(*ax);
	       (*bx)=fabs(*bx);
	       (*cx)=fabs(*cx);
	       return(0);
	     } 
	   else if (fu > *fb) 
	     {
	       *cx=u;
	       *fc=fu;	
	       (*ax)=fabs(*ax);
	       (*bx)=fabs(*bx);
	       (*cx)=fabs(*cx);
	       return(0);
	     }
	   u=(*cx)+MNBRAK_GOLD*(*cx-*bx);
	   *param = fabs(u);
	   if(*param > lim_sup) {*param = u = lim_sup;}
	   if(*param < lim_inf) {*param = u = lim_inf;}
	   fu=-Return_Lk(tree);
	 } 
       else if ((*cx-u)*(u-ulim) > lim_inf) 
	 {
	   *param = fabs(u);
	   if(*param > lim_sup) {*param = u = lim_sup;}
	   if(*param < lim_inf) {*param = u = lim_inf;}
	   fu=-Return_Lk(tree);
	   if (fu < *fc) 
	     {
	       SHFT(*bx,*cx,u,*cx+MNBRAK_GOLD*(*cx-*bx))
	       *param = fabs(u); 
	       SHFT(*fb,*fc,fu,-Return_Lk(tree))
	     }
	 } 
       else if ((u-ulim)*(ulim-*cx) >= lim_inf) 
	 {
	   u=ulim;
	   *param = fabs(u);
	   if(*param > lim_sup) {*param = u = lim_sup;}
	   if(*param < lim_inf) {*param = u = lim_inf;}
	   fu=-Return_Lk(tree);
	 } 
       else 
	 {
	   u=(*cx)+MNBRAK_GOLD*(*cx-*bx);
	   *param = fabs(u);
	   if(*param > lim_sup) {*param = u = lim_sup;}
	   if(*param < lim_inf) {*param = u = lim_inf;}
	   fu=-Return_Lk(tree);
	 }
       SHFT(*ax,*bx,*cx,u)
       SHFT(*fa,*fb,*fc,fu)


     }
   (*ax)=fabs(*ax);
   (*bx)=fabs(*bx);
   (*cx)=fabs(*cx);
   return(0);
}

/*********************************************************/

double Generic_Brent(double *param, 
		     double ax, double bx, double cx, double tol, 
		     double *xmin, arbre *tree, int n_iter_max)
{
  int iter;
  double a,b,d,etemp,fu,fv,fw,fx,p,q,r,tol1,tol2,u,v,w,x,xm;
  double e=0.0;
  double init_loglk, max_loglk;
  double bestx;

  d=0.0;
  a=((ax < cx) ? ax : cx);
  b=((ax > cx) ? ax : cx);
  x=w=v=bx;
  *param=bx;
  Lk(tree,tree->data);
  fw=fv=fx=-tree->tot_loglk;
  init_loglk = tree->tot_loglk;
  max_loglk = UNLIKELY;
  bestx = bx;

  for(iter=1;iter<=BRENT_ITMAX;iter++) 
    {
      xm=0.5*(a+b);
      tol2=2.0*(tol1=tol*fabs(x)+BRENT_ZEPS);
      if(fabs(x-xm) <= (tol2-0.5*(b-a))) 
	{
	  if(tree->tot_loglk < init_loglk - MIN_DIFF_LK)
              {
                  printf("\n. WARNING : Brent failed\n");
                  *param = bestx;
                  Lk(tree,tree->data);
              }
	  *xmin=x;
	  return -fx;
	}
      
      if(fabs(e) > tol1) 
	{
	  r=(x-w)*(fx-fv);
	  q=(x-v)*(fx-fw);
	  p=(x-v)*q-(x-w)*r;
	  q=2.0*(q-r);
	  if(q > 0.0) p = -p;
	  q=fabs(q);
	  etemp=e;
	  e=d;
	  if(fabs(p) >= fabs(0.5*q*etemp) || p <= q*(a-x) || p >= q*(b-x))
              {
                  d=BRENT_CGOLD*(e=(x >= xm ? a-x : b-x));
/*                   printf("Golden section step\n"); */
              }
	  else
              {
                  d=p/q;
                  u=x+d;
                  if (u-a < tol2 || b-u < tol2)
                      d=SIGN(tol1,xm-x);
/*                   printf("Parabolic step\n"); */
              }
        }
      else
          {
              d=BRENT_CGOLD*(e=(x >= xm ? a-x : b-x));
/*               printf("Golden section step (default)\n"); */
          }

      u=(fabs(d) >= tol1 ? x+d : x+SIGN(tol1,d));
      *param=u;
      Lk(tree,tree->data);
      fu=-tree->tot_loglk;
      
      if(tree->tot_loglk > max_loglk)
          {
              max_loglk = tree->tot_loglk;
              bestx = u;
          }

/*       printf("param=%f loglk=%f\n",*param,tree->tot_loglk); */

      if(fu <= fx) 
	{
	  if(iter > n_iter_max) 
	    {
	      if(tree->tot_loglk < init_loglk - MIN_DIFF_LK)
		  printf("\n. WARNING : Brent failed\n");
		  
	      return tree->tot_loglk;
	    }
	  if(u >= x) a=x; else b=x;
	  SHFT(v,w,x,u)
	    SHFT(fv,fw,fx,fu)
	    } 
      else
	{
	  if (u < x) a=u; else b=u;
	  if (fu <= fw || w == x) 
	    {
	      v=w;
	      w=u;
	      fv=fw;
            fw=fu;
	    } 
	  else if (fu <= fv || v == x || v == w) {
            v=u;
            fv=fu;
	  }
	}
    }
  Exit("\n. Too many iterations in BRENT !");
  return(-1);
  /* Not Reached ??  *xmin=x;   */
  /* Not Reached ??  return fx; */
}

/*********************************************************/

double RRparam_GTR_Golden(double ax, double bx, double cx, double tol, 
			  double *xmin, arbre *tree, allseq *alldata, double *param, int n_iter_max)
{
   double f1,f2,x0,x1,x2,x3;
   int n_iter;


   x0=ax;
   x3=cx;
   if (fabs(cx-bx) > fabs(bx-ax)) 
     {
       x1=bx;
       x2=bx+GOLDEN_C*(cx-bx);
     } 
   else 
     {
       x2=bx;
       x1=bx-GOLDEN_C*(bx-ax);
     }
   (*param)=x1;

   Lk(tree,alldata);
   f1=-tree->tot_loglk;
   (*param)=x2;

   Lk(tree,alldata);
   f2=-tree->tot_loglk;

   n_iter = 0;
   while (fabs(x3-x0) > tol*(fabs(x1)+fabs(x2))) 
     {

       if (f2 < f1) 
	 {
	   SHFT3(x0,x1,x2,GOLDEN_R*x1+GOLDEN_C*x3)
	   (*param)=x2;
	   Lk(tree,alldata);
	   SHFT2(f1,f2,-tree->tot_loglk)
	 } 
       else 
	 {
	   SHFT3(x3,x2,x1,GOLDEN_R*x2+GOLDEN_C*x0)
	   (*param)=x1;
	   Lk(tree,alldata);
	   SHFT2(f2,f1,-tree->tot_loglk)
	 }
       
       if(n_iter++ > n_iter_max) break;
       
/*        printf("p=%E %f\n",(*param),tree->tot_loglk); */
     }
   if (f1 < f2) 
    {
       *xmin=x1;
       return f1;
     } 
   else 
     {
       *xmin=x2;
       return f2;
     }
}

/*********************************************************/

double Br_Len_Golden(double ax, double bx, double cx, double tol, 
		     double *xmin, edge *b_fcus, arbre *tree)
{
   double f1,f2,x0,x1,x2,x3;

   x0=ax;
   x3=cx;
   if (fabs(cx-bx) > fabs(bx-ax)) 
     {
       x1=bx;
       x2=bx+GOLDEN_C*(cx-bx);
     } 
   else 
     {
       x2=bx;
       x1=bx-GOLDEN_C*(bx-ax);
     }
   
   b_fcus->l=x1;
   f1 = -Lk_At_Given_Edge(tree,b_fcus);
   b_fcus->l=x2;
   f2 = -Lk_At_Given_Edge(tree,b_fcus);
   while (fabs(x3-x0) > tol*(fabs(x1)+fabs(x2))) 
     {
       if (f2 < f1) 
	 {
	   SHFT3(x0,x1,x2,GOLDEN_R*x1+GOLDEN_C*x3)
	   b_fcus->l=x2;
	   SHFT2(f1,f2,-Lk_At_Given_Edge(tree,b_fcus))
	 } 
       else 
	 {
	   SHFT3(x3,x2,x1,GOLDEN_R*x2+GOLDEN_C*x0)
	   b_fcus->l=x1;
	   SHFT2(f2,f1,-Lk_At_Given_Edge(tree,b_fcus))
	 }
     }
   if (f1 < f2) 
     {
       *xmin=fabs(x1);
       return -f1;
     } 
   else 
     {
       *xmin=fabs(x2);
       return -f2;
     }
}

/*********************************************************/

int Br_Len_Brak(double *ax, double *bx, double *cx, 
		double *fa, double *fb, double *fc, 
		edge *b_fcus, arbre *tree)
{
   double ulim,u,r,q,fu,dum;

   b_fcus->l = *ax;
   *fa=-Lk_At_Given_Edge(tree,b_fcus);
   b_fcus->l = *bx;
   *fb=-Lk_At_Given_Edge(tree,b_fcus);
   if (*fb > *fa) {
      SHFT(dum,*ax,*bx,dum)
      SHFT(dum,*fb,*fa,dum)
   }
   *cx=(*bx)+MNBRAK_GOLD*(*bx-*ax);
   b_fcus->l = fabs(*cx);
   *fc=-Lk_At_Given_Edge(tree,b_fcus);
   while (*fb > *fc) 
     {

       r=(*bx-*ax)*(*fb-*fc);
       q=(*bx-*cx)*(*fb-*fa);
       u=(*bx)-((*bx-*cx)*q-(*bx-*ax)*r)/
               (2.0*SIGN(MAX(fabs(q-r),MNBRAK_TINY),q-r));
       ulim=(*bx)+MNBRAK_GLIMIT*(*cx-*bx);
       
       if ((*bx-u)*(u-*cx) > 0.0) 
	 {
	   b_fcus->l = fabs(u);
	   fu=-Lk_At_Given_Edge(tree,b_fcus);
	   if (fu < *fc) 
	     {
	       *ax=(*bx);
	       *bx=u;
	       *fa=(*fb);
	       *fb=fu;
	       (*ax)=fabs(*ax);
	       (*bx)=fabs(*bx);
	       (*cx)=fabs(*cx);
	       return(0);
	     } 
	   else if (fu > *fb) 
	     {
	       *cx=u;
	       *fc=fu;	
	       (*ax)=fabs(*ax);
	       (*bx)=fabs(*bx);
	       (*cx)=fabs(*cx);
	       return(0);
	     }
	   u=(*cx)+MNBRAK_GOLD*(*cx-*bx);
	   b_fcus->l = fabs(u);
	   fu=-Lk_At_Given_Edge(tree,b_fcus);
	 } 
       else if ((*cx-u)*(u-ulim) > 0.0) 
	 {
	   b_fcus->l = fabs(u);
	   fu=-Lk_At_Given_Edge(tree,b_fcus);
	   if (fu < *fc) 
	     {
	       SHFT(*bx,*cx,u,*cx+MNBRAK_GOLD*(*cx-*bx))
	       b_fcus->l = fabs(u); 
	       SHFT(*fb,*fc,fu,-Lk_At_Given_Edge(tree,b_fcus))
	     }
	 } 
       else if ((u-ulim)*(ulim-*cx) >= 0.0) 
	 {
	   u=ulim;
	   b_fcus->l = fabs(u);
	   fu=-Lk_At_Given_Edge(tree,b_fcus);
	 } 
       else 
	 {
	   u=(*cx)+MNBRAK_GOLD*(*cx-*bx);
	   b_fcus->l = fabs(u);
	   fu=-Lk_At_Given_Edge(tree,b_fcus);
	 }
       SHFT(*ax,*bx,*cx,u)
       SHFT(*fa,*fb,*fc,fu)
      }
   (*ax)=fabs(*ax);
   (*bx)=fabs(*bx);
   (*cx)=fabs(*cx);
   return(0);
}

/*********************************************************/

double Br_Len_Brent(double ax, double bx, double cx, double tol,
		    double *xmin, edge *b_fcus, arbre *tree, int n_iter_max)
{
  int iter;
  double a,b,d,etemp,fu,fv,fw,fx,p,q,r,tol1,tol2,u,v,w,x,xm;
  double e=0.0;
  
  d=0.0;
  a=((ax < cx) ? ax : cx);
  b=((ax > cx) ? ax : cx);
  x=w=v=bx;
  b_fcus->l = fabs(bx);
  fw=fv=fx=-Lk_At_Given_Edge(tree,b_fcus);
  
  for(iter=1;iter<=BRENT_ITMAX;iter++)
    {
      xm=0.5*(a+b);
      tol2=2.0*(tol1=tol*fabs(x)+BRENT_ZEPS);
      if(fabs(x-xm) <= (tol2-0.5*(b-a)))
	{
	  *xmin=x;
	  Lk_At_Given_Edge(tree,b_fcus);
	  return -fx;
	}
      
      if(fabs(e) > tol1)
	{
	  r=(x-w)*(fx-fv);
	  q=(x-v)*(fx-fw);
	  p=(x-v)*q-(x-w)*r;
	  q=2.0*(q-r);
	  if(q > 0.0) p = -p;
	  q=fabs(q);
	  etemp=e;
	  e=d;
	  if(fabs(p) >= fabs(0.5*q*etemp) || p <= q*(a-x) || p >= q*(b-x))
	    d=BRENT_CGOLD*(e=(x >= xm ? a-x : b-x));
	  else{
	    d=p/q;
	    u=x+d;
	    if (u-a < tol2 || b-u < tol2)
	      d=SIGN(tol1,xm-x);
	  }
	}
      else
	{
	  d=BRENT_CGOLD*(e=(x >= xm ? a-x : b-x));
	}
      u=(fabs(d) >= tol1 ? x+d : x+SIGN(tol1,d));
      if(u<BL_MIN) u = BL_MIN;
      b_fcus->l=fabs(u);
      fu=-Lk_At_Given_Edge(tree,b_fcus);
/*       printf("edge %d l=%f lnL=%f\n",b_fcus->num,b_fcus->l,fu); */
      if(fu <= fx)
	{
	  if(iter > n_iter_max) 
	    {
	      printf("\n. WARNING : too many iterations in Brent\n");
	      b_fcus->l = fabs(bx);
	      Lk_At_Given_Edge(tree,b_fcus);
	      return tree->tot_loglk;
	    }

	  if(u >= x) a=x; else b=x;
	  SHFT(v,w,x,u)
	    SHFT(fv,fw,fx,fu)
	    }
      else
	{
	  if (u < x) a=u; else b=u;
	  if (fu <= fw || w == x)
	    {
	      v=w;
	      w=u;
	      fv=fw;
            fw=fu;
	    }
	  else if (fu <= fv || v == x || v == w) {
            v=u;
            fv=fu;
	  }
	}
    }
#ifdef LH3_REVISION
  fprintf(stderr, "Too many iterations in BRENT");
#else
  printf("Too many iterations in BRENT");
#endif
  return(-1);
  /* Not Reached ??  *xmin=x;   */
  /* Not Reached ??  return fx; */
}

/*********************************************************/

int Dist_Seq_Brak(double *ax, double *bx, double *cx, 
		  double *fa, double *fb, double *fc, 
		  allseq *data, int numseq1, int numseq2, 
		  model *mod)
{
   double ulim,u,r,q,fu,dum;
   double dist;
   double lk,dlk,d2lk;

   dist = *ax;
   *fa=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
   dist = *bx;
   *fb=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
   if (*fb > *fa) {
      SHFT(dum,*ax,*bx,dum)
      SHFT(dum,*fb,*fa,dum)
   }
   *cx=(*bx)+MNBRAK_GOLD*(*bx-*ax);
   dist = fabs(*cx);
   *fc=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
   while (*fb > *fc) 
     {
       r=(*bx-*ax)*(*fb-*fc);
       q=(*bx-*cx)*(*fb-*fa);
       u=(*bx)-((*bx-*cx)*q-(*bx-*ax)*r)/
               (2.0*SIGN(MAX(fabs(q-r),MNBRAK_TINY),q-r));
       ulim=(*bx)+MNBRAK_GLIMIT*(*cx-*bx);
       
       if ((*bx-u)*(u-*cx) > 0.0) 
	 {
	   dist = fabs(u);
	   fu=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
	   if (fu < *fc) 
	     {
	       *ax=(*bx);
	       *bx=u;
	       *fa=(*fb);
	       *fb=fu;
	       return(0);
	     } 
	   else if (fu > *fb) 
	     {
	       *cx=u;
	       *fc=fu;
	       return(0);
	     }
	   u=(*cx)+MNBRAK_GOLD*(*cx-*bx);
	   dist = fabs(u);
	   fu=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
	 } 
       else if ((*cx-u)*(u-ulim) > 0.0) 
	 {
	   dist = fabs(u);
	   fu=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
	   if (fu < *fc) 
	     {
	       SHFT(*bx,*cx,u,*cx+MNBRAK_GOLD*(*cx-*bx))
	       dist = fabs(u); 
	       SHFT(*fb,*fc,fu,-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk))
	     }
	 } 
       else if ((u-ulim)*(ulim-*cx) >= 0.0) 
	 {
	   u=ulim;
	   dist = fabs(u);
	   fu=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
	 } 
       else 
	 {
	   u=(*cx)+MNBRAK_GOLD*(*cx-*bx);
	   dist = fabs(u);
	   fu=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
	 }
       SHFT(*ax,*bx,*cx,u)
       SHFT(*fa,*fb,*fc,fu)
      }
   return(0);
}

/*********************************************************/

double Dist_Seq_Brent(double ax, double bx, double cx, double tol, 
		      double *xmin, allseq *data, 
		      int numseq1, int numseq2, model *mod)
{
  int iter;
  double a,b,d,etemp,fu,fv,fw,fx,p,q,r,tol1,tol2,u,v,w,x,xm;
  double e=0.0;
  double dist;
  double lk,dlk,d2lk;
  
  d=0.0;
  a=((ax < cx) ? ax : cx);
  b=((ax > cx) ? ax : cx);
  x=w=v=bx;
  dist = fabs(bx);
  fw=fv=fx=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
  for(iter=1;iter<=BRENT_ITMAX;iter++) 
    {
      xm=0.5*(a+b);
      tol2=2.0*(tol1=tol*fabs(x)+BRENT_ZEPS);
      if(fabs(x-xm) <= (tol2-0.5*(b-a))) 
	{
	  *xmin=x;
	  return -fx;
	}
      
      if(fabs(e) > tol1) 
	{
	  r=(x-w)*(fx-fv);
	  q=(x-v)*(fx-fw);
	  p=(x-v)*q-(x-w)*r;
	  q=2.0*(q-r);
	  if(q > 0.0) p = -p;
	  q=fabs(q);
	  etemp=e;
	  e=d;
	  if(fabs(p) >= fabs(0.5*q*etemp) || p <= q*(a-x) || p >= q*(b-x))
	    d=BRENT_CGOLD*(e=(x >= xm ? a-x : b-x));
	  else{
	    d=p/q;
	    u=x+d;
	    if (u-a < tol2 || b-u < tol2)
	      d=SIGN(tol1,xm-x);
	  }
	} else
	  {
	    d=BRENT_CGOLD*(e=(x >= xm ? a-x : b-x));
	  }
      u=(fabs(d) >= tol1 ? x+d : x+SIGN(tol1,d));
      dist=fabs(u);
      fu=-Lk_Given_Two_Seq(data,numseq1,numseq2,dist,mod,&lk,&dlk,&d2lk);
      if(fu <= fx) {
	if(u >= x) a=x; else b=x;
	SHFT(v,w,x,u)
	  SHFT(fv,fw,fx,fu)
	  } 
      else
	{
	  if (u < x) a=u; else b=u;
	  if (fu <= fw || w == x) 
	    {
	      v=w;
	      w=u;
	      fv=fw;
	      fw=fu;
	    } 
	  else if (fu <= fv || v == x || v == w) {
            v=u;
            fv=fu;
	  }
	}
    }
  printf("\n . BRENT method failed, trying Newton-Raphson");
  return(+1.0);
  /* Not Reached ??  *xmin=x;   */
  /* Not Reached ??  return fx; */
}

/*********************************************************/

double Optimize_Dist(model *mod, double init, allseq *twoseqs)
{
  double d_infa,d_max,d_infb;
  double lk_infa, lk_max, lk_infb, lk;

  d_infa = 100.*BL_MIN;
  d_max  = init;
  d_infb = 3.*init;
  if(init <= BL_MIN) {d_infa = -BL_START; d_max = .0; d_infb = BL_START;}
  lk_infa = lk_max = lk_infb = .0;

  Dist_Seq_Brak(&d_infa, &d_max, &d_infb,
		&lk_infa,&lk_max,&lk_infb,
		twoseqs,0,1,mod);

  lk = (double)Dist_Seq_Brent(d_infa,d_max,d_infb,
			      1.e-5,&d_max,twoseqs,0,1,mod);
  if(lk > .0) return -1.0;
  else        return d_max;

}

/*********************************************************/

void Round_Optimize(arbre *tree, allseq *data)
{
  int n_round,each;
  double lk_old, lk_new, tol;
  node *root;

  lk_new = tree->tot_loglk;
  lk_old = UNLIKELY;
  n_round = 0;
  each = 1;
  tol = 1.e-2;
  root = tree->noeud[0];


  tree->mod->s_opt->opt_bl = 0;
  tree->both_sides         = 1;
  Lk(tree,data);


  while(n_round < ROUND_MAX)
    {

        (!((n_round+2)%2))?(root=tree->noeud[0]):(root=tree->noeud[tree->n_otu-1]);
        Optimize_Br_Len_Serie(root,
                              root->v[0],
                              root->b[0],
                              tree,
                              data,
                              5);
        

        tree->mod->s_opt->opt_bl = 0;
        tree->both_sides         = 1;
        Lk(tree,data);
        
        if(!each)
            {
                each = 1;
                if(tree->mod->s_opt->print) printf("\n");
                Optimiz_All_Free_Param(tree,tree->mod->s_opt->print);
                tree->mod->s_opt->opt_bl = 0;
                tree->both_sides         = 1;
                Lk(tree,data);
            }
        
        lk_new = tree->tot_loglk;
        
        if(tree->mod->s_opt->print)
            {
                if(lk_old < UNLIKELY+1)
                    printf("\n. Log(lk) :               * -> %15.6f ",lk_new);
                else
                    printf("\n. Log(lk) : %15.6f -> %15.6f ",lk_old,lk_new);
                fflush(NULL);
            }
        
        if(lk_new < lk_old - MIN_DIFF_LK) Exit("\n. Optimisation failed ! (Round_Optimize)\n");
        if(fabs(lk_new - lk_old) < MIN_DIFF_LK)  break;
        else lk_old  = lk_new;
        n_round++;
        each--;
    }
  
  if(tree->mod->s_opt->print) printf("\n");
  Optimiz_All_Free_Param(tree,tree->mod->s_opt->print);
}

/*********************************************************/

void Optimize_Br_Len_Serie(node *a, node *d, edge *b_fcus, 
			   arbre *tree,allseq *alldata, int n_passes)
{
  int i;
  double l_infa,l_max,l_infb;
  double lk_init;
  
  lk_init = tree->tot_loglk;

  l_infa = 10.*b_fcus->l;
  l_max  = b_fcus->l;
  l_infb = BL_MIN;
 

  Br_Len_Brent(l_infa,l_max,l_infb,
               1.e-5,
               &(b_fcus->l),
               b_fcus,tree,1000);

  /* Golden method is generally slower than Brent */
  /*   Br_Len_Golden(l_infa,l_max,l_infb, */
  /* 		1.e-5, */
  /* 		&(b_fcus->l), */
  /* 		b_fcus,tree); */
/*   printf("Edge %d -> %20f\n",b_fcus->num,tree->tot_loglk); */
  if(tree->tot_loglk < lk_init - MIN_DIFF_LK)
    {
#ifdef LH3_REVISION
      fprintf(stderr, "%f %f %f %f\n",l_infa,l_max,l_infb,b_fcus->l);
      fprintf(stderr, "%f -- %f \n",lk_init,tree->tot_loglk);
#else
      printf("%f %f %f %f\n",l_infa,l_max,l_infb,b_fcus->l);
      printf("%f -- %f \n",lk_init,tree->tot_loglk);
#endif
      Exit("\n. Err. in Optimize_Br_Len_Serie\n");
    }

/*   printf("Edge %3d -> %f %f\n", */
/* 	 b_fcus->num, */
/* 	 tree->tot_loglk, */
/* 	 b_fcus->l); fflush(NULL); */
    
  
  if(d->tax) return;
  else For(i,3) if(d->v[i] != a)
    {
      Update_P_Lk(tree,d->b[i],d);
      Optimize_Br_Len_Serie(d,d->v[i],d->b[i],tree,alldata,n_passes);
    }
  For(i,3) if((d->v[i] == a) && !(d->v[i]->tax)) Update_P_Lk(tree,d->b[i],d);
}

/*********************************************************/

double Br_Len_NR(arbre *tree,allseq *alldata, edge *b_fcus, int n_passes)
{
  int n_iter, n_iter_mov,edge_num;
  double step_edge,lk_new,lk_old;
  double l_branch_best;
  int l_r,r_l;
  double mult;
  int old_opt;

  old_opt =              tree->mod->s_opt->opt_bl;
  tree->mod->s_opt->opt_bl = tree->both_sides = 1;
  edge_num =                     b_fcus->num;
  l_branch_best =                  b_fcus->l;
  step_edge =                             .0;

  l_r = b_fcus->l_r;
  r_l = b_fcus->r_l;

  lk_new = lk_old = UNLIKELY;  

  n_iter = 0;
  for(;;)
    {      
      lk_new = Lk_At_Given_Edge(tree,b_fcus);

      if(fabs(lk_new - lk_old) < MIN_DIFF_LK)
	break;
      else
	{
	  if((lk_new > lk_old+MIN_DIFF_LK) || (!n_iter))
	    {
	      lk_old = lk_new;
	      l_branch_best = b_fcus->l;
	    }

	  else if((lk_new < lk_old-MIN_DIFF_LK) && (lk_old != 0.0)) 
	    {
	      tree->mod->s_opt->opt_bl = tree->both_sides = 0;
	      n_iter_mov = 0;
	      while(lk_new < lk_old-MIN_DIFF_LK)
		{
		  step_edge *= .5;
		  b_fcus->l = l_branch_best + step_edge;
		  if(b_fcus->l < BL_MIN) b_fcus->l = BL_MIN;
		  lk_new = Lk_At_Given_Edge(tree,b_fcus);
		  n_iter_mov++;
		  if(n_iter_mov > 10) 
		    {
		      b_fcus->l = l_branch_best;
		      lk_new = Lk_At_Given_Edge(tree,b_fcus);
		      tree->mod->s_opt->opt_bl = tree->both_sides = old_opt;
		      return lk_new;
		    }
		}
	      tree->mod->s_opt->opt_bl = tree->both_sides = 1;
	      lk_new = Lk_At_Given_Edge(tree,b_fcus);
	      tree->tot_dloglk[edge_num] = .0;
	    }
	}
            
      mult = 0;
      step_edge = -tree->tot_dloglk[edge_num] / tree->tot_d2loglk[edge_num];

      if(tree->tot_d2loglk[edge_num] > .0)
	{
	  b_fcus->l /= 1.2;
	  step_edge = 0;
	}
      
      while(fabs(step_edge) > b_fcus->l) step_edge /= 1.2;
      b_fcus->l += step_edge;

      if(b_fcus->l < BL_MIN) 
	{
	  b_fcus->l = BL_MIN;
	  break;
	}

      n_iter++;
      if(n_iter > n_passes) break;

    }
  tree->mod->s_opt->opt_bl = tree->both_sides = old_opt;
  return lk_new;
}

/*********************************************************/

void Moving_Backward(arbre *tree, allseq *alldata, 
		     double **step, double lk_base, double *l_branch_init)
{
  double lk_new;
  int i,n_iter_max;


  tree->mod->s_opt->opt_bl = tree->both_sides = 0;
  n_iter_max = 10;
  lk_new = lk_base-MIN_DIFF_LK-1.;
  

  For(i,2*tree->n_otu-3) 
    {
      tree->t_edges[i]->l = l_branch_init[i];
      tree->tot_dloglk[i] = .0;
      tree->tot_d2loglk[i] = -.1;
    }

  while(lk_new < lk_base-MIN_DIFF_LK)
    {
      if(!n_iter_max) 
	{
	  For(i,2*tree->n_otu-3) tree->t_edges[i]->l = l_branch_init[i];
	  tree->mod->s_opt->opt_bl = tree->both_sides = 1;
	  return;
	}

      For(i,2*tree->n_otu-3)
	{
	  (*step)[i] *= .5;
	  tree->t_edges[i]->l += (*step)[i];
	  if(tree->t_edges[i]->l < BL_MIN) tree->t_edges[i]->l = BL_MIN;
	}

      Lk(tree,alldata);
      lk_new = tree->tot_loglk;
      n_iter_max--;
    }
  tree->mod->s_opt->opt_bl = tree->both_sides = 1;
}


/*********************************************************/

double Optimize_One_Dist(allseq *data, int numseq1, int numseq2, double init_dist, model *mod)
{

  int n_iter, n_iter_mov;
  double lk_new,lk_old,lk_best;
  double step;
  double dlk,d2lk;
  double dist_new,dist_best;

  step = .0;
  dlk  = d2lk = .0;
  lk_old = lk_new = lk_best = .0;
  dist_new = dist_best = init_dist;
  
  n_iter = 0;
  for(;;)
    {
      
      if(dist_new < BL_MIN) dist_new = BL_MIN;

      Lk_Given_Two_Seq(data,numseq1,numseq2,dist_new,mod,&lk_new,&dlk,&d2lk);

      if(((fabs(lk_new - lk_old) < MIN_DIFF_LK) && (lk_new >= lk_old)))
	break;
      else
	{
	  if(((fabs(lk_new - lk_old) > MIN_DIFF_LK) 
	      && (lk_new > lk_old)) 
	      || (!n_iter))
	    {
	      dist_best = dist_new;
	      lk_best   = lk_new;
	      lk_old    = lk_new;
	    }
	  else
	    {
	      n_iter_mov = 20;
	      do
		{
		  dist_new = dist_best;
		  step /= 2.;
		  dist_new += step;
		  Lk_Given_Two_Seq(data,numseq1,numseq2,
				   dist_new,mod,&lk_new,&dlk,&d2lk);
		  n_iter_mov--;
		  if(!n_iter_mov) return dist_best;
		}while(lk_new < lk_best);
	      dlk = .0;
	    }
	}
      
      step = -dlk/d2lk;

      if(d2lk > 0.0) 
	{
	  step = .0;
	  dist_new /= 1.5;
	}
      
      while(fabs(step) > dist_new) step /= 1.5;
      dist_new += step;

      
      n_iter++;
      if(n_iter > 50) break;
    }
  return dist_new;
}

/*********************************************************/

void Print_Lk_Progress(arbre *tree, double lk_new, double lk_old, int n_iter)
{
  if(!n_iter)
    printf("\n. Log(lk) :               * -> %15.6f ",lk_new);
  else
    printf("\n. Log(lk) : %15.6f -> %15.6f ",lk_old,lk_new);
  fflush(stdout);
}

/*********************************************************/

int Count_Swap(arbre *tree)
{
  int i;
  
  tree->n_swap = 0;
  For(i,2*tree->n_otu-3)
    {
      if((!tree->t_edges[i]->left->tax) &&
	 (!tree->t_edges[i]->rght->tax))
	{
	  if(tree->t_edges[i]->diff_lk > -2.0)
	    {
	      tree->n_swap++;
	    }
	}
    }
  return tree->n_swap;
}

/*********************************************************/

void Optimiz_Ext_Br(arbre *tree)
{
  int i;
  edge *b;
  double l_infa,l_max,l_infb,l_init;
  double lk, lk_init;
  
  lk_init = tree->tot_loglk;
  
  For(i,2*tree->n_otu-3)
    {
      b = tree->t_edges[i];
      if((b->left->tax) || (b->rght->tax))
	{

	  l_init = b->l;
  
	  l_infa = 100.;
	  l_max  = b->l;
	  l_infb = -10.;
	  
	  lk = Br_Len_Brent(l_infa,l_max,l_infb,
			    1.e-5,
			    &(b->l),
			    b,tree,1000);
	  b->ql[0] = b->l;
	  b->best_conf = 1;
	  b->l = l_init;
	}
    }
  tree->tot_loglk = lk_init; 
}

/*********************************************************/

void Optimiz_All_Free_Param(arbre *tree, int verbose)
{
  int  init_both_sides, init_derivatives;
  

  init_both_sides     = tree->both_sides;
  init_derivatives    = tree->mod->s_opt->opt_bl;
  tree->both_sides    = 0;
  tree->mod->s_opt->opt_bl = 0;

  
  if((tree->mod->whichmodel == 7) ||
     ((tree->mod->whichmodel == 8) && 
      (tree->mod->s_opt->opt_rr_param) && 
      (tree->mod->n_diff_rr_param > 1)))
    {
        int failed;
        
        failed = 0;

        if(verbose) 
            {
                (tree->mod->whichmodel == 7)?
                    (printf("\n. Optimisation of the GTR parameters...\n")):	
                    (printf("\n. Optimisation of the custom model parameters...\n"));
            }
        
        tree->mod->update_eigen = 1;
        BFGS(tree,tree->mod->rr_param_values,tree->mod->n_diff_rr_param,1.e-5,1.e-7,
             &Return_Abs_Lk,
             &Num_Derivative_Several_Param ,
             &Lnsrch_RR_Param,&failed);
        
        if(failed)
            {
                int i;
                
                printf("\n. Optimising one-by-one...\n");
                
                For(i,tree->mod->n_diff_rr_param) 
                    if(i != 5)
                        Optimize_Single_Param_Generic(tree,&(tree->mod->rr_param_values[i]),tree->mod->rr_param_values[i],1.E-20,1.E+10,1000);
            }
        
        tree->mod->update_eigen = 0;
      
    }

  if(tree->mod->s_opt->opt_kappa)
    {
      if(verbose) printf("\n. Optimisation of the ts/tv ratio...\n");fflush(stdout);   
      Optimize_Single_Param_Generic(tree,&(tree->mod->kappa),tree->mod->kappa,0.1,100,100);
      /* 	      printf("kappa = %f\n",tree->mod->kappa); */
      
    }
  
  if(tree->mod->s_opt->opt_lambda) 
    {
      Optimize_Single_Param_Generic(tree,&(tree->mod->lambda),tree->mod->lambda,0.001,100,50);
      /* 	      printf("lambda = %f\n",tree->mod->lambda); */
    }
  
  if(tree->mod->s_opt->opt_pinvar) 
    {
      if(verbose) printf("\n. Optimisation of the proportion of invariable sites...\n");fflush(stdout);    
      tree->mod->pinvar = 0.5;
      Optimize_Single_Param_Generic(tree,&(tree->mod->pinvar),tree->mod->pinvar,0.0001,0.9999,100);            
/*       printf("p-invar = %f\n",tree->mod->pinvar); */
    }

  if(tree->mod->s_opt->opt_alpha) 
    { 
      if(verbose) printf("\n. Optimisation of the gamma shape parameter...\n");fflush(stdout);
      Optimize_Single_Param_Generic(tree,&(tree->mod->alpha),tree->mod->alpha,0.01,100,100);
/*       printf("alpha = %f %f\n",tree->mod->alpha,Return_Lk(tree));       */
    }

  if(tree->mod->s_opt->opt_bfreq)
    {
        int failed,i;
        
        failed = 0;
        tree->mod->update_eigen = 1;
        if(verbose) printf("\n. Optimisation of nucleotide frequencies...\n");
        BFGS(tree,tree->mod->pi,4,1.e-5,1.e-7,&Return_Abs_Lk,&Num_Derivative_Several_Param,&Lnsrch_Nucleotide_Frequencies,&failed);

        if(failed)
            {
                For(i,5) 
                    Optimize_Single_Param_Generic(tree,&(tree->mod->pi[i]),tree->mod->pi[i],1.E-10,0.999999,1000);                
            }
        tree->mod->update_eigen = 0;
    }


  tree->both_sides    = init_both_sides;
  tree->mod->s_opt->opt_bl = init_derivatives;

}



#define ITMAX 200
#define EPS   3.0e-8
#define TOLX (4*EPS)
#define STPMX 100.0
static double sqrarg;
#define SQR(a) ((sqrarg=(a)) == 0.0 ? 0.0 : sqrarg*sqrarg)

void BFGS(arbre *tree, double *p, int n, double gtol, double step_size,
	  double(*func)(), void (*dfunc)(), void (*lnsrch)(),int *failed)
{

  int check,i,its,j;
  double den,fac,fad,fae,fp,stpmax,sum=0.0,sumdg,sumxi,temp,test,fret;
  double *dg,*g,*hdg,**hessin,*pnew,*xi;
  
  hessin = (double **)mCalloc(n,sizeof(double *));
  For(i,n) hessin[i] = (double *)mCalloc(n,sizeof(double));
  dg   = (double *)mCalloc(n,sizeof(double ));
  g    = (double *)mCalloc(n,sizeof(double ));
  pnew = (double *)mCalloc(n,sizeof(double ));
  hdg  = (double *)mCalloc(n,sizeof(double ));
  xi   = (double *)mCalloc(n,sizeof(double ));
  

  fp=(*func)(tree);
  (*dfunc)(tree,p,n,step_size,func,g);


  for (i=0;i<n;i++) 
    {
      for (j=0;j<n;j++) hessin[i][j]=0.0;
      hessin[i][i]=1.0;
      xi[i] = -g[i];
      sum += p[i]*p[i];
    }

  stpmax=STPMX*MAX(sqrt(sum),(double)n);

  for(its=1;its<=ITMAX;its++) 
    {
      lnsrch(tree,n,p,fp,g,xi,pnew,&fret,stpmax,&check);

/*       printf("BFGS -> %f\n",tree->tot_loglk); */

      fp = fret;
      
      for (i=0;i<n;i++) 
	{
	  xi[i]=pnew[i]-p[i];
	  p[i]=pnew[i];
	}

      test=0.0;
      for (i=0;i<n;i++) 
	{
	  temp=fabs(xi[i])/MAX(fabs(p[i]),1.0);
	  if (temp > test) test=temp;
	}
      if (test < TOLX) 
	{
	  (*func)(tree);
	  For(i,n) Free(hessin[i]);
	  free(hessin);
	  free(xi);
	  free(pnew);
	  free(hdg);
	  free(g);
	  free(dg);   

	  if(its == 1) 
              {
                  printf("\n. WARNING : BFGS failed ! \n");
                  *failed = 1;
              }
	  return;
	}

      for (i=0;i<n;i++) dg[i]=g[i];

      (*dfunc)(tree,p,n,step_size,func,g);

      test=0.0;
      den=MAX(fret,1.0);
      for (i=0;i<n;i++) 
	{
	  temp=fabs(g[i])*MAX(fabs(p[i]),1.0)/den;
	  if (temp > test) test=temp;
	}
      if (test < gtol) 
	{
	  (*func)(tree);
	  For(i,n) Free(hessin[i]);
	  free(hessin);
	  free(xi);
	  free(pnew);
	  free(hdg);
	  free(g);
	  free(dg);   
	  return;
	}

    for (i=0;i<n;i++) dg[i]=g[i]-dg[i];

    for (i=0;i<n;i++) 
      {
	hdg[i]=0.0;
	for (j=0;j<n;j++) hdg[i] += hessin[i][j]*dg[j];
      }

    fac=fae=sumdg=sumxi=0.0;
    for (i=0;i<n;i++) 
      {
	fac += dg[i]*xi[i];
	fae += dg[i]*hdg[i];
	sumdg += SQR(dg[i]);
	sumxi += SQR(xi[i]);
      }
    
    if(fac*fac > EPS*sumdg*sumxi) 
      {
	fac=1.0/fac;
	fad=1.0/fae;
	for (i=0;i<n;i++) dg[i]=fac*xi[i]-fad*hdg[i];
	for (i=0;i<n;i++) 
	  {
	    for (j=0;j<n;j++) 
	      {
		hessin[i][j] += fac*xi[i]*xi[j]
		  -fad*hdg[i]*hdg[j]+fae*dg[i]*dg[j];
	      }
	  }
      }
    for (i=0;i<n;i++) 
      {
	xi[i]=0.0;
	for (j=0;j<n;j++) xi[i] -= hessin[i][j]*g[j];
      }
    }
  Exit("\n. Too many iterations in BFGS...\n");
  For(i,n) Free(hessin[i]);
  free(hessin);
  free(xi);
  free(pnew);
  free(hdg);
  free(g);
  free(dg);   
}

#undef ITMAX
#undef EPS
#undef TOLX
#undef STPMX

/*********************************************************/


#define ALF 1.0e-4
#define TOLX 1.0e-7

void Lnsrch_RR_Param(arbre *tree, int n, double *xold, double fold, 
		     double *g, double *p, double *x,
		     double *f, double stpmax, int *check)
{
  int i;
  double a,alam,alam2,alamin,b,disc,f2,fold2,rhs1,rhs2,slope,sum,temp,test,tmplam;
  double *local_xold;

  alam = alam2 = f2 = fold2 = tmplam = .0;

  local_xold = (double *)mCalloc(n,sizeof(double));
  For(i,n) local_xold[i] = xold[i];


  *check=0;
  for(sum=0.0,i=0;i<n;i++) sum += p[i]*p[i];
  sum=sqrt(sum);
  if(sum > stpmax)
    for(i=0;i<n;i++) p[i] *= stpmax/sum;
  for(slope=0.0,i=0;i<n;i++)
    slope += g[i]*p[i];
  test=0.0;
  for(i=0;i<n;i++) 
    {
      temp=fabs(p[i])/MAX(fabs(local_xold[i]),1.0);
      if (temp > test) test=temp;
    }
  alamin=TOLX/test;
  alam=1.0;
  for (;;) 
    {
      for(i=0;i<n;i++) 
	{
	  x[i]=local_xold[i]+alam*p[i];
	}

      /**/
      for(i=0;i<n;i++)
	{
	  tree->mod->rr_param_values[i]=local_xold[i]+alam*p[i];
	  if(tree->mod->rr_param_values[i] < 0.0) break;
	}
      /**/

      if(i==n) 
	{
	  *f=Return_Abs_Lk(tree);
/* 	  printf("loglk = %f\n",*f); */
	}
      else     *f=1.+fold+ALF*alam*slope;
      if (alam < alamin)
	{
	  for (i=0;i<n;i++) 
	    {
	      x[i]=local_xold[i];
	      if(x[i] < .0) break;
	    }
	  /**/      
	  for(i=0;i<n;i++)
	    {
	      tree->mod->rr_param_values[i]=local_xold[i]+alam*p[i];
	      if(tree->mod->rr_param_values[i] < 0.0) 
		tree->mod->rr_param_values[i] = 0.0;
	    }
	  /**/

	  *check=1;
	  For(i,n) xold[i] = local_xold[i];
	  Free(local_xold);
	  return;
	} 
      else if (*f <= fold+ALF*alam*slope) 
	{
	  For(i,n) xold[i] = local_xold[i];
	  Free(local_xold); 
	  return;
	}
      else 
	{
	  if (alam == 1.0)
	    tmplam = -slope/(2.0*(*f-fold-slope));
	  else 
	    {
	      rhs1 = *f-fold-alam*slope;
	      rhs2=f2-fold2-alam2*slope;
	      a=(rhs1/(alam*alam)-rhs2/(alam2*alam2))/(alam-alam2);
	      b=(-alam2*rhs1/(alam*alam)+alam*rhs2/(alam2*alam2))/(alam-alam2);
	      if (a == 0.0) tmplam = -slope/(2.0*b);
	      else 
		{
		  disc=b*b-3.0*a*slope;
		  if (disc<0.0) tmplam = 0.5*alam;
		  else if(b <= 0.0) tmplam=(-b+sqrt(disc))/(3.0*a);
		  else tmplam = -slope/(b+sqrt(disc));
		}
	      if (tmplam>0.5*alam) tmplam=0.5*alam;
	    }
	}
      alam2=alam;
      f2 = *f;
      fold2=fold;
      alam=MAX(tmplam,0.1*alam);
    }
  Free(local_xold);
}

#undef ALF
#undef TOLX
#undef NRANSI

/*********************************************************/
#define ALF 1.0e-4
#define TOLX 1.0e-7

void Lnsrch_Nucleotide_Frequencies(arbre *tree, int n, double *xold, double fold, double *g, double *p, double *x,
				   double *f, double stpmax, int *check)
{
  int i;
  double a,alam,alam2,alamin,b,disc,f2,fold2,rhs1,rhs2,slope,sum,temp,test,tmplam;
  double *local_xold;

  alam = alam2 = f2 = fold2 = tmplam = .0;

  local_xold = (double *)mCalloc(n,sizeof(double));
  For(i,n) local_xold[i] = xold[i];


  *check=0;
  for(sum=0.0,i=0;i<n;i++) sum += p[i]*p[i];
  sum=sqrt(sum);
  if(sum > stpmax)
    for(i=0;i<n;i++) p[i] *= stpmax/sum;
  for(slope=0.0,i=0;i<n;i++)
    slope += g[i]*p[i];
  test=0.0;
  for(i=0;i<n;i++) 
    {
      temp=fabs(p[i])/MAX(fabs(local_xold[i]),1.0);
      if (temp > test) test=temp;
    }
  alamin=TOLX/test;
  alam=1.0;
  for (;;) 
    {
      for(i=0;i<n;i++) x[i]=fabs(local_xold[i]+alam*p[i]);
      /**/      
      for(i=0;i<n;i++) 
	{
	  tree->mod->pi[i]=fabs(local_xold[i]+alam*p[i]);
/* 	  if( */
/* 	     (tree->mod->pi[i] < 0.001) || */
/* 	     (tree->mod->pi[i] > 0.999) */
/* 	     ) */
/* 	    break; */
	}
      /**/
      if(i==n) 
	{
	  *f=Return_Abs_Lk(tree);
	}
      else     *f=1.+fold+ALF*alam*slope;
      if (alam < alamin)
	{
	  for (i=0;i<n;i++) x[i]=local_xold[i];
	  for (i=0;i<n;i++) tree->mod->pi[i]=local_xold[i];
	  *check=1;
	  For(i,n) xold[i] = local_xold[i];
	  Free(local_xold);
	  return;
	} 
      else if (*f <= fold+ALF*alam*slope) 
	{
	  For(i,n) xold[i] = local_xold[i];
	  Free(local_xold); 
	  return;
	}
      else 
	{
	  if (alam == 1.0)
	    tmplam = -slope/(2.0*(*f-fold-slope));
	  else 
	    {
	      rhs1 = *f-fold-alam*slope;
	      rhs2=f2-fold2-alam2*slope;
	      a=(rhs1/(alam*alam)-rhs2/(alam2*alam2))/(alam-alam2);
	      b=(-alam2*rhs1/(alam*alam)+alam*rhs2/(alam2*alam2))/(alam-alam2);
	      if (a == 0.0) tmplam = -slope/(2.0*b);
	      else 
		{
		  disc=b*b-3.0*a*slope;
		  if (disc<0.0) 
		    {
		      disc=b*b-3.0*a*slope;
		      if (disc<0.0) tmplam = 0.5*alam;
		      else if(b <= 0.0) tmplam=(-b+sqrt(disc))/(3.0*a);
		      else tmplam = -slope/(b+sqrt(disc));
		    }
		  else tmplam=(-b+sqrt(disc))/(3.0*a);
		}
	      if (tmplam>0.5*alam) tmplam=0.5*alam;
	    }
	}
      alam2=alam;
      f2 = *f;
      fold2=fold;
      alam=MAX(tmplam,0.1*alam);
    }
  Free(local_xold);
}

/*********************************************************/

/* void Optimize_Global_Rate(arbre *tree) */
/* { */
/*     printf("\n. Global rate (%f->)",tree->tot_loglk); */
/*     Optimize_Single_Param_Generic(tree,&(tree->tbl),tree->tbl,BL_MIN,1.E+4,100); */
/*     printf("%f)\n",tree->tot_loglk); */
/* } */


#undef ALF
#undef TOLX
#undef NRANSI


