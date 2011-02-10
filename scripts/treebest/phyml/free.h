/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#ifndef FREE_H
#define FREE_H

void Free_All_Nodes_Light(arbre *tree);
void Free_All_Edges_Light(arbre *tree);
void Free_Mat(matrix *mat);
void Free_Partial_Lk(double ****p_lk, int len, int n_catg);
void Free_Tree(arbre *tree);
void Free_Edge(edge *b);
void Free_Node(node *n);
void Free_Cseq(allseq *alldata);
void Free_Seq(seq **d, int n_otu);
void Free_All(seq **d, allseq *alldata, arbre *tree);
void Free_SubTree(edge *b_fcus, node *a, node *d, arbre *tree);
void Free_Tree_Ins_Tar(arbre *tree);
void Free_Tree_Lk(arbre *tree);
void Free_dPij(arbre *tree);
void Free_NNI(arbre *tree);
void Free_Edge_P_Lk_Struct(edge *b, arbre *tree);
void Free_Node_Lk(node *n);
void Free_Edge_Lk(arbre *tree, edge *b);
void Free_Model(model *mod);
void Free(void *p);
void Free_Input(option *input);
void Free_Code(code *c_code);

#endif
