/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#ifndef OPTIMIZ_H
#define OPTIMIZ_H

void      Optimiz_Ext_Br(arbre *tree);
void      Optimize_Alpha(arbre *tree);
void      Optimize_Kappa(arbre *tree);
void      Optimize_Lambda(arbre *tree);
void      Optimize_Param_Parall(arbre *tree);
double    Br_Len_NR(arbre *tree,allseq *alldata,edge *b_fcus, int n_passes);
double    Optimize_Branch_Quad(arbre *tree, allseq *alldata, edge *b_fcus);
void      Optimize_After_Hide(arbre *tree, allseq *alldata, node *h);
void      Round_Optimize(arbre *tree, allseq *data);
void      Print_Lk_Progress(arbre *tree, double lk_new, double lk_old, int n_iter);
int       Dist_Seq_Brak(double *ax, double *bx, double *cx, 
			double *fa, double *fb, double *fc, 
			allseq *data, int num1, int num2, model *mod);
double    Dist_Seq_Brent(double ax, double bx, double cx, double tol, 
			 double *xmin, allseq *data, 
			 int num1, int num2, model *mod);
double    Optimize_One_Dist(allseq *data, int numseq1, int numseq2, 
			    double init_dist, model *mod);
double    Kappa_Golden(double ax, double bx, double cx, double tol, 
		       double *xmin, arbre *tree, allseq *alldata);
double    Lambda_Golden(double ax, double bx, double cx, double tol, 
			double *xmin, arbre *tree, allseq *alldata);
double    Alpha_Golden_Br_Opt(double ax, double bx, double cx, double tol, 
			      double *xmin, arbre *tree, allseq *alldata, 
			      int n_opt, double *init_l);
double    Alpha_Golden(double ax, double bx, double cx, double tol,double *xmin, 
		       arbre *tree, allseq *alldata);
double    Br_Len_Golden(double ax, double bx, double cx, double tol, 
			double *xmin, edge *b_fcus, arbre *tree);
double    Br_Len_Brent(double ax, double bx, double cx, double tol, 
		       double *xmin, edge *b_fcus, arbre *tree, int n_iter_max);
int       Br_Len_Brak(double *ax, double *bx, double *cx, 
		      double *fa, double *fb, double *fc, 
		      edge *b_fcus, arbre *tree);
double    Optimize_Path_Length(model *mod, allseq *alldata, edge *a, 
			       int lra, edge *b, int lrb, double i_len);
void      Optimize_Param_Serie(node *a, node *d, edge *b_fcus, arbre *tree, 
			       allseq *alldata, int n_passes);
double    Optimize_Dist(model *mod, double init, allseq *twoseqs);
double    Pinvar_Golden(double ax, double bx, double cx, double tol, 
			double *xmin, arbre *tree, allseq *alldata, int n_iter_max);
void      Optimize_Pinvar(arbre *tree);
int       Lambda_Brak(double *ax, double *bx, double *cx, 
		      double *fa, double *fb, double *fc, 
		      arbre *tree);
int       Kappa_Brak(double *ax, double *bx, double *cx, 
		      double *fa, double *fb, double *fc, 
		      arbre *tree);
int       Alpha_Brak(double *ax, double *bx, double *cx, 
		      double *fa, double *fb, double *fc, 
		      arbre *tree);
int       Pinvar_Brak(double *ax, double *bx, double *cx, 
		      double *fa, double *fb, double *fc, 
		      arbre *tree);
void Optimiz_All_Free_Param(arbre *tree, int verbose);
void      Optimiz_RRparam_GTR(arbre *tree, int num_param);
double    RRparam_GTR_Golden(double ax, double bx, double cx, double tol, 
		   	     double *xmin, arbre *tree, allseq *alldata, double *param, int n_iter_max);

int Powell_GTR_Param(arbre *tree, double *p, int n, double ftol);
double Linmin_GTR_Param(arbre *tree,double *p, double *xi, int n);
double F1dim(arbre *tree, double x, double *p, double *xi, double n);
int Mnbrak_1dim(double *ax, double *bx, double *cx, 
		double *fa, double *fb, double *fc,
		arbre *tree,
		double *p,  double *xi, double n);
double Brent_1dim(double ax, double bx, double cx, 
		  double tol, double *xmin,
		  arbre *tree,
		  double *p, double *xi, double n);

int Min_With_Derivatives(arbre *tree, double *p, int n, double ftol, double step_size, 
			 double (*func) (), void (*dfunc)(), double (*linmin)());
void BFGS(arbre *tree, double *p, int n, double gtol, double step_size,
	  double(*func)(), void (*dfunc)(), void (*lnsrch)(),int *failed);
void Lnsrch_RR_Param(arbre *tree, int n, double *xold, double fold, double *g, double *p, double *x,
		double *f, double stpmax, int *check);
void Optimize_Single_Param_Generic(arbre *tree, double *param, 
				   double start, 
				   double lim_inf, double lim_sup,
				   int n_max_iter);
int Generic_Brak(double *param,
		 double *ax, double *bx, double *cx, 
		 double *fa, double *fb, double *fc,
		 double lim_inf, double lim_sup,
		 arbre *tree);
double Generic_Brent(double *param, 
		     double ax, double bx, double cx, double tol, 
		     double *xmin, arbre *tree, int n_iter_max);
void Optimize_Br_Len_Serie(node *a, node *d, edge *b_fcus, 
			   arbre *tree,allseq *alldata, int n_passes);
void Lnsrch_Nucleotide_Frequencies(arbre *tree, int n, double *xold, 
				   double fold, double *g, double *p, double *x,
				   double *f, double stpmax, int *check);

void Optimize_Global_Rate(arbre *tree);



#endif

