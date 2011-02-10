/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#ifndef UTILITIES_H
#define UTILITIES_H


#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <ctype.h>
#include <string.h>
#include <time.h>

#ifdef LH3_ADDON
#include "lh3_addon.h"
#endif

#ifdef LH3_REVISION
extern int lh3_revision_is_quiet;
#endif

#define VERSION "v2.4.5"

extern int    NODE_DEG_MAX;
extern int    BRENT_ITMAX;
extern double BRENT_CGOLD;
extern double BRENT_ZEPS;
extern double MNBRAK_GOLD;
extern double MNBRAK_GLIMIT;
extern double MNBRAK_TINY;
extern double ALPHA_MIN;
extern double ALPHA_MAX;
extern double BL_MIN;
extern double BL_START;
extern double BL_MAX;
extern double MIN_DIFF_LK;
extern double GOLDEN_R;
extern double GOLDEN_C;
extern int    T_MAX_FILE;
extern int    T_MAX_LINE;
extern int    T_MAX_NAME;
extern int    T_MAX_SEQ;
extern int    N_MAX_INSERT;
extern int    N_MAX_OTU;
extern double UNLIKELY;
extern double NJ_SEUIL;
extern int    MAX_TOPO_DIST;
extern double ROUND_MAX;
extern double DIST_MAX;
extern int    LIM_SCALE;
extern double LIM_SCALE_VAL;
extern double AROUND_LK;
extern double PROP_STEP;
extern int    T_MAX_ALPHABET;
extern double MDBL_MAX;
extern double MDBL_MIN;
extern int    POWELL_ITMAX;
extern double LINMIN_TOL;

#define For(i,n)                     for(i=0; i<n; i++)
#define Fors(i,n,s)                  for(i=0; i<n; i+=s)
#define PointGamma(prob,alpha,beta)  PointChi2(prob,2.0*(alpha))/(2.0*(beta))
#define SHFT2(a,b,c)                 (a)=(b);(b)=(c);
#define SHFT3(a,b,c,d)               (a)=(b);(b)=(c);(c)=(d);
#define MAX(a,b)                     ((a)>(b)?(a):(b))
#define MIN(a,b)                     ((a)<(b)?(a):(b))
#define SIGN(a,b)                    ((b) > 0.0 ? fabs(a) : -fabs(a))
#define SHFT(a,b,c,d)                (a)=(b);(b)=(c);(c)=(d);


 
/*********************************************************/

typedef struct __Node {
  struct __Node         **v; /* table of pointers to neighbor nodes. Dimension = 2 x n_otu - 3 */
  struct __Node ***bip_node; /* three lists of pointer to tip nodes. One list for each direction */
  struct __Edge         **b; /* table of pointers to neighbor branches */ 
  char          ***bip_name; /* three lists of tip node names. One list for each direction */
  int             *bip_size; /* Size of each of the three lists from bip_node */ 
  double                 *l; /* lengths of the (three or one) branches connected to one internal node */ 
  int                   num; /* node number */
  char                *name; /* taxon name (if exists) */
  int                   tax; /* tax = 1 -> external node, else -> internal node */
  int              ni,agglo;
  int          check_branch;
  double             *score;
  int             is_attach;
  int               is_free;

#ifdef LH3_ADDON
  lh3Node lh3_node;
#endif
}node;


/*********************************************************/

typedef struct __Edge {
  /*
    syntax :  (node) [edge]
(left_1) .                   .(right_1)
          \ (left)  (right) /
           \._____________./
           /    [b_fcus]   \
          /                 \
(left_2) .                   .(right_2)
  
  */

  struct __Node               *left,*rght; /* node on the left/right side of the edge */ 
  int         l_r,r_l,l_v1,l_v2,r_v1,r_v2;
  /* these are directions (i.e., 0, 1 or 2): */
  /* l_r (left to right) -> left[b_fcus->l_r] = right */
  /* r_l (right to left) -> right[b_fcus->r_l] = left */
  /* l_v1 (left node to first node != from right) -> left[b_fcus->l_v1] = left_1 */
  /* l_v2 (left node to secnd node != from right) -> left[b_fcus->l_v2] = left_2 */
  /* r_v1 (right node to first node != from left) -> right[b_fcus->r_v1] = right_1 */
  /* r_v2 (right node to secnd node != from left) -> right[b_fcus->r_v2] = right_2 */
  int                                  ok;
  double                            score;
  int                                 num;
  double                                l;
  double                           best_l;
  double                            l_old;
  int                      check_this_one;
  int                             in_both;
  int                            n_bipart;
  int                           bip_score;
  double                         nj_score;
  double                          diff_lk;

  int                       get_p_lk_left; 
  /* 1 if the likelihood of the subtree on the left has to be computed */
  int                       get_p_lk_rght;
  /* 1 if the likelihood of the subtree on the right has to be computed */
  int                        ud_p_lk_left;
  /* 1 if the likelihood of the subtree on the left is up to date */
  int                        ud_p_lk_rght;
  /* 1 if the likelihood of the subtree on the right is up to date */
  double                         site_dlk; /* derivative of the likelihood (deprecated) */
  double                        site_d2lk; /* 2nd derivative of the likelihood (deprecated) */

  double                     *site_dlk_rr; 
  /* derivative of the likelihood conditional on the current relative rate */
  double                    *site_d2lk_rr;
  /* 2nd derivative of the likelihood conditional on the current relative rate  */
  double        ***p_lk_left,***p_lk_rght;
  /* likelihoods of the subtree on the left and */
  /* right side (for each site and each relative rate category) */ 
  double **site_p_lk_rght, **site_p_lk_left; /* deprecated */
  double ***Pij_rr,***dPij_rr,***d2Pij_rr;
  /* matrix of change probabilities and its first and secnd derivates */

  double                              *ql;
  int                      up_2_date_left;
  int                      up_2_date_rght;
  int                           best_conf; 
  /* best topological configuration : */
  /* ((left_1,left_2),right_1,right_2) or */ 
  /* ((left_1,right_2),right_1,left_2) or */ 
  /* ((left_1,right_1),right_1,left_2)  */ 
  int                         num_st_left; /* number of the subtree on the left side */
  int                         num_st_rght; /* number of the subtree on the right side */
  
  /* likelihood scaling factors */
  int                          scale_left;
  int                          scale_rght;
  double            site_sum_scale_f_left;
  double            site_sum_scale_f_rght;
  double                site_scale_f_left;
  double                site_scale_f_rght;
  double                *sum_scale_f_left;
  double                *sum_scale_f_rght;
  double                          bootval;
#ifdef LH3_ADDON
  lh3Edge lh3_edge;
#endif
}edge;

/*********************************************************/

typedef struct __Elk { /* this structure is used to compute the likelihood */
  double                            *lk_q;
  double                        *site_dlk;
  double                       *site_d2lk;
  double                     *site_dlk_rr;
  double                    *site_d2lk_rr;
  double        ***p_lk_left,***p_lk_rght;
  double ***Pij_rr,***dPij_rr,***d2Pij_rr;
  double                         *lk_swap;
}elk;

/*********************************************************/

typedef struct __Arbre {
    struct __Node                         *root;
    struct __Node                       **noeud;
    struct __Edge                     **t_edges;
    struct __Arbre                    *old_tree;
    struct __Arbre                   *best_tree;
    struct __Model                         *mod;
    struct __AllSeq                       *data;
    struct __Option                      *input;
    struct __P_Lk                         *p_lk;
    struct __Matrix                        *mat;
    int                                 has_bip;
    double                              T_t,T_b;
    double                          min_diff_lk;
    
    int                              both_sides;
    int                                   n_otu;
    double                    d_alpha, d2_alpha;
    int                                 n_alpha;
    int                               curr_site;
    int                               curr_catg;
    int                                   nswap;
    double                           best_loglk;
    double                            *t_best_l;
    double                                  tbl;
    
    double                            tot_loglk;
    double                    *tot_loglk_sorted; /* used to compute tot_loglk by adding sorted terms to minimize CPU errors */
    double                          *tot_dloglk;
    double                         *tot_d2loglk;
    double                             *site_lk;
    double                      unconstraint_lk;
    
    double                            prop_stab;
    double                                p_exp;
    double                            frac_site;
    int                                  n_swap;
    int                            n_p_lk_alloc;
    int                              n_iter_opt;
    
    int                               n_pattern;
    int                      has_branch_lengths;
    int                          print_boot_val;

#ifdef LH3_ADDON
	lh3Tree lh3_tree;
#endif
}arbre;


/*********************************************************/

typedef struct __Seq {
  char    *name;
  int       len;
  char    *state;
}seq;

/*********************************************************/


typedef struct __AllSeq {
  seq         **c_seq;             /* crunched sequences      */
  int          *invar;             /* 1 -> states are identical, 0 states vary */
  double        *wght;             /* # of each site in c_seq */
  double       *factw;
  int           n_otu;
  int       clean_len;             /* uncrunched sequences lenghts without gaps */
  int      crunch_len;             /* crunched sequences lengths */
  double       *b_frq;
  int        init_len;
  int         *ambigu;
  int       *sitepatt;
}allseq;

/*********************************************************/

typedef struct __Matrix {
  double    **P,**Q,**dist;
  arbre              *tree;
  int              *on_off;
  int                n_otu;
  char              **name;
  int                    r;
  struct __Node **tip_node;
  int     curr_int,curr_br;
  int               method;
}matrix;

/*********************************************************/

typedef struct __Model {
  int      whichmodel;
/*
 1 => JC69
 2 => K2P
 3 => F81
 4 => HKY85
 5 => F84
 6 => TN93
 7 => GTR
11 => Dayhoff
12 => JTT
13 => MtREV
*/
  int              ns; /* number of states (4 for ADN, 20 for AA) */
  double          *pi; /* states frequencies */
  int        datatype; /* 0->DNA, 1->AA */

  /* ADN parameters */
  double        kappa; /* transition/transversion rate */
  double       lambda; /*  */
  double        alpha; /*  */
  double    alpha_opt; /*  */
  double     *r_proba; /*  */
  double          *rr; /*  */
  int          n_catg; /*  */
  double       pinvar;
  int           invar;

  double    alpha_old;
  double    kappa_old;
  double   lambda_old;
  double   pinvar_old;
  
  double       **rr_param; /* table of pointers to relative rate parameters of the GTR or custom model */
  double *rr_param_values; /* relative rate parameters of the GTR or custom model */
  int      **rr_param_num; /* each line of this 2d table gives a serie of equal relative rate parameter number */
                           /* A<->C : number 0 */ 
                           /* A<->G : number 1 */ 
                           /* A<->T : number 2 */ 
                           /* C<->G : number 3 */ 
                           /* C<->T : number 4 */ 
                           /* G<->T : number 5 */
                           /* For example, [0][2][3]
			                   [1]
					   [4][5]
                              corresponds to the model 010022, i.e., (A<->C = A<->T = C<->T) != (A<->G) != (C<->T = G<->T)
			   */
  int *n_rr_param_per_cat; /* [3][1][2] for the previous example */
  int          n_diff_rr_param;

  int    update_eigen;

  double    ***Pij_rr;
  double   ***dPij_rr;
  double  ***d2Pij_rr;

  
  int         seq_len;
  /* AA parameters */
  /* see PMat_Empirical in models.c for AA algorithm explanation */
  double    *mat_Q; /* 20x20 amino-acids substitution rates matrix */
  double   *mat_Vr; /* 20x20 right eigenvectors of mat_Q */
  double   *mat_Vi; /* 20x20 inverse matrix of mat_Vr */
  double   *vct_ev; /* eigen values */
  double        mr; /* mean rate = branch length/time interval */
                    /* mr = -sum(i)(vct_pi[i].mat_Q[ii]) */
  double *vct_eDmr; /* diagonal terms of a 20x20 diagonal matrix */
                    /* term n = exp(nth eigenvalue of mat_Q / mr) */

  struct __Code  *c_code;

  int           stepsize;


  double    omega;
  int n_otu;
  struct __Optimiz *s_opt;
  int bootstrap; /* bootstrap values are computed if bootstrap > 0. 
		    The value give the number of replicates */
  char  *custom_mod_string;
  double      *user_b_freq;

  
}model;

/*********************************************************/

typedef struct __Option {
  char                   *seqfile;
  char                 *modelname;
  struct __Model             *mod;
  int                 interleaved;
  int                     end_opt;
  int                   inputtree;
  struct __Arbre            *tree;
  char             *inputtreefile;
  FILE                    *fp_seq;
  FILE             *fp_input_tree;
  FILE              *fp_boot_tree;
  FILE             *fp_boot_stats;
  int            print_boot_trees;
  char           *phyml_stat_file;
  char           *phyml_tree_file;
  char             *phyml_lk_file;
  int   phyml_stat_file_open_mode;
  int   phyml_tree_file_open_mode;   
  int                 n_data_sets;
  int                     n_trees;
  int                     seq_len;
  int            n_data_set_asked;
  struct __Seq             **data;
  struct __AllSeq        *alldata;
  char                  *nt_or_cd;
}option;

/*********************************************************/

typedef struct __Optimiz {
  int           print;
  int first_opt_alpha;
  int first_opt_kappa;
  int       opt_alpha;
  int       opt_kappa;
  int      opt_lambda;
  int      opt_pinvar;
  int       opt_bfreq;
  int        last_opt;
  int    opt_rr_param;
  int  opt_free_param;
  int          opt_bl;
  double      init_lk;
  int        n_it_max;
  int        opt_topo;
}optimiz;

/*********************************************************/

typedef struct __Code {
  char *aa;
  int *genetc[64];
  int **n_diff_b_2_codons;
  int **tstvtable;
  int num_curr_code;
}code;

/*********************************************************/

typedef struct __Qmat{
  double **u_mat;   /* right eigen vectors             */
  double **v_mat;   /* left eigen vectors = inv(u_mat) */
  double *root_vct; /* eigen values                    */  
  double *q;        /* instantaneous rate matrix       */
}qmat;

/*********************************************************/

double bico(int n,int k);
double factln(int n);
double gammln(double xx);
double Pbinom(int N,int ni,double p);
void Plim_Binom(double pH0,int N,double *pinf,double *psup);
double LnGamma(double alpha);
double IncompleteGamma(double x,double alpha,double ln_gamma_alpha);
double PointChi2(double prob,double v);
double PointNormal(double prob);
int DiscreteGamma(double freqK[],double rK[],double alfa,double beta,int K,int median);
arbre *Read_Tree(char *s_tree);
void Make_All_Edges_Light(node *a,node *d);
void Make_All_Edges_Lk(node *a,node *d,arbre *tree);
void R_rtree(char *s_tree,node *pere,arbre *tree,int *n_int,int *n_ext);
void Clean_Multifurcation(char **subtrees,int current_deg,int end_deg);
char **Sub_Trees(char *tree,int *degree);
int Next_Par(char *s,int pos);
char *Write_Tree(arbre *tree);
void R_wtree(node *pere,node *fils,char *s_tree,arbre *tree);
void Init_Tree(arbre *tree);
void Make_Edge_Light(node *a,node *d);
void Init_Edge_Light(edge *b);
void Make_Edge_Dirs(edge *b,node *a,node *d);
void Make_Edge_Lk(node *a,node *d,arbre *tree);
void Make_Node_Light(node *n);
void Init_Node_Light(node *n);
void Make_Node_Lk(node *n);
seq **Get_Seq(option *input,int rw);
seq **Read_Seq_Sequential(FILE *in,int *n_otu);
seq **Read_Seq_Interleaved(FILE *in,int *n_otu);
int Read_One_Line_Seq(seq ***data,int num_otu,FILE *in);
void Uppercase(char *ch);
allseq *Compact_Seq(seq **data,option *input);
allseq *Compact_CSeq(allseq *data,model *mod);
void Get_Base_Freqs(allseq *data);
void Get_AA_Freqs(allseq *data);
arbre *Read_Tree_File(FILE *fp_input_tree);
void Init_Tree_Edges(node *a,node *d,arbre *tree,int *cur);
void Exit(char *message);
void *mCalloc(int nb,size_t size);
void *mRealloc(void *p,int nb,size_t size);
arbre *Make_Light_Tree_Struct(int n_otu);
int Sort_Double_Decrease(const void *a,const void *b);
void qksort(double *A,int ilo,int ihi);
void Print_Site(allseq *alldata,int num,int n_otu,char *sep,int stepsize);
void Print_Seq(seq **data,int n_otu);
void Print_CSeq(FILE *fp,allseq *alldata);
void Order_Tree_Seq(arbre *tree,seq **data);
void Order_Tree_CSeq(arbre *tree,allseq *data);
matrix *Make_Mat(int n_otu);
void Init_Mat(matrix *mat,allseq *data);
arbre *Make_Tree(allseq *data);
void Print_Dist(matrix *mat);
void Print_Node(node *a,node *d,arbre *tree);
void Share_Lk_Struct(arbre *t_full,arbre *t_empt);
void Init_Constant();
void Print_Mat(matrix *mat);
int Sort_Edges_Diff_Lk(arbre *tree,edge **sorted_edges,int n_elem);
void NNI(arbre *tree,edge *b_fcus,int do_swap);
void Swap(node *a,node *b,node *c,node *d,arbre *tree);
void Update_All_Partial_Lk(edge *b_fcus,arbre *tree);
void Update_SubTree_Partial_Lk(edge *b_fcus,node *a,node *d,arbre *tree);
double Update_Lk_At_Given_Edge(edge *b_fcus,arbre *tree);
void Update_PMat_At_Given_Edge(edge *b_fcus,arbre *tree);
allseq *Make_Seq(int n_otu,int len,char **sp_names);
allseq *Copy_CData(allseq *ori,model *mod);
optimiz *Alloc_Optimiz();
void Init_Optimiz(optimiz *s_opt);
int Filexists(char *filename);
FILE *Openfile(char *filename,int mode);
void Print_Fp_Out(FILE *fp_out,time_t t_beg,time_t t_end,arbre *tree,option *input,int n_data_set);
void Print_Fp_Out_Lines(FILE *fp_out,time_t t_beg,time_t t_end,arbre *tree,option *input,int n_data_set);
void Alloc_All_P_Lk(arbre *tree);
matrix *K2P_dist(allseq *data,double g_shape);
matrix *JC69_Dist(allseq *data,model *mod);
matrix *Hamming_Dist(allseq *data,model *mod);
int Is_Ambigu(char *state,int datatype,int stepsize);
void Check_Ambiguities(allseq *data,int datatype,int stepsize);
int Assign_State(char *c,int datatype,int stepsize);
void Bootstrap(arbre *tree);
void Update_BrLen_Invar(arbre *tree);
void Getstring_Stdin(char *file_name);
void Print_Freq(arbre *tree);
double Num_Derivatives_One_Param(double(*func)(arbre *tree),arbre *tree,double f0,double *param,double stepsize,double *err,int precise);
void Num_Derivative_Several_Param(arbre *tree,double *param,int n_param,double stepsize,double(*func)(arbre *tree),double *derivatives);
int Compare_Two_States(char *state1,char *state2,int state_size);
void Copy_One_State(char *from,char *to,int state_size);
model *Make_Model_Basic();
void Make_Model_Complete(model *mod);
model *Copy_Model(model *ori);
void Set_Defaults_Input(option *input);
void Set_Defaults_Model(model *mod);
void Set_Defaults_Optimiz(optimiz *s_opt);
void Copy_Optimiz(optimiz *ori,optimiz *cpy);
void Get_Bip(node *a,node *d,arbre *tree);
void Alloc_Bip(arbre *tree);
int Sort_Double_Increase(const void *a,const void *b);
int Sort_String(const void *a,const void *b);
void Compare_Bip(arbre *tree1,arbre *tree2);
void Test_Multiple_Data_Set_Format(option *input);
int Are_Compatible(char *statea,char *stateb,int stepsize,int datatype);
void Hide_Ambiguities(allseq *data);
void Print_Site_Lk(arbre *tree);
#endif




