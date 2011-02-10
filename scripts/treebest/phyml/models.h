/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#ifndef MODELS_H
#define MODELS_H

void  PMat(double l, model *mod, double ***Pij);
void  PMat_K80(double l,double kappa, double ***Pij);
void  PMat_TN93(double l, model *mod, double ***Pij);
void  PMat_Empirical(double l, model *mod, double ***Pij);
void  dPMat(double l, double rr, model *mod, double ***dPij);
void  d2PMat(double l, double rr, model *mod, double ***d2Pij);
void  dPMat_K80(double l, double ***dPij, double rr, double k);
void  d2PMat_K80(double l, double ***d2Pij, double rr, double k);
void  dPMat_TN93(double l, double ***dPij, model *mod, double rr);
void  d2PMat_TN93(double l, double ***dPij, model *mod, double rr);
int GetDaa (double *daa, double *pi, char *file_name);
int Matinv (double *x, int n, int m, double *space);
void Init_Model(allseq *data, model *mod);
int Init_Qmat_Dayhoff(double *daa, double *pi);
int Init_Qmat_JTT(double *daa, double *pi);
void Update_Qmat_GTR(model *mod);
void Translate_Custom_Mod_String(model *mod);
int Init_Qmat_WAG(double *daa, double *pi);
void Set_Model_Parameters(arbre *tree);
int Init_Qmat_RtREV(double *daa, double *pi);
int Init_Qmat_CpREV(double *daa, double *pi);
int Init_Qmat_VT(double *daa, double *pi);
int Init_Qmat_Blosum62(double *daa, double *pi);
int Init_Qmat_MtMam(double *daa, double *pi);

#endif
