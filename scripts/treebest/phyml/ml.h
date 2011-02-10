/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#ifndef ML_H
#define ML_H


void Init_Tips_At_One_Site_Nucleotides(char state,double **p_lk);
void Init_Tips_At_One_Site_AA(char aa,double **p_lk);
void Get_All_Partial_Lk(arbre *tree,edge *b_fcus,node *a,node *d);
void Get_All_Partial_Lk_Scale(arbre *tree,edge *b_fcus,node *a,node *d);
void Pre_Order_Lk(node *pere,node *fils,arbre *tree);
void Post_Order_Lk(node *pere,node *fils,arbre *tree);
void Lk(arbre *tree,allseq *alldata);
void Site_Lk(arbre *tree,allseq *alldata);
double Lk_At_Given_Edge(arbre *tree,edge *b_fcus);
void Update_P(arbre *tree,int t_edge_num);
double Return_Lk(arbre *tree);
double Return_Abs_Lk(arbre *tree);
matrix *ML_Dist_fixed(allseq *data, model *mod, int n_cat);
matrix *ML_Dist(allseq *data,model *mod);
double Lk_Given_Two_Seq(allseq *data,int numseq1,int numseq2,double dist,model *mod,double *loglk,double *dloglk,double *d2loglk);
double ***Get_Partial_Lk_Struct(arbre *tree,int len,int n_catg);
void Unconstraint_Lk(arbre *tree);
void Update_P_Lk(arbre *tree,edge *b_fcus,node *n);
void Make_Tree_4_Lk(arbre *tree,allseq *alldata,int n_site);
void Init_P_Lk_Tips(arbre *tree);



#endif






