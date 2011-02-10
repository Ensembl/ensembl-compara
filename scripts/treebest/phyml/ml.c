/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#include "utilities.h"
#include "ml.h"
#include "optimiz.h"
#include "models.h"
#include "free.h"

#ifdef LH3_REVISION
#define ALGO_TYPE double
#define ALGO_QSORT
#include "../algo.h"
#endif

int    LIM_SCALE;
double LIM_SCALE_VAL;
double MDBL_MAX;
double MDBL_MIN;

/*********************************************************/

void Init_Tips_At_One_Site_Nucleotides(char state, double **p_lk)
{
  switch(state){
  case 'A' : (*p_lk)[0]=1.; (*p_lk)[1]=(*p_lk)[2]=(*p_lk)[3]=.0;
    break;
  case 'C' : (*p_lk)[1]=1.; (*p_lk)[0]=(*p_lk)[2]=(*p_lk)[3]=.0;
    break;
  case 'G' : (*p_lk)[2]=1.; (*p_lk)[1]=(*p_lk)[0]=(*p_lk)[3]=.0;
    break;
  case 'T' : (*p_lk)[3]=1.; (*p_lk)[1]=(*p_lk)[2]=(*p_lk)[0]=.0;
    break;
  case 'U' : (*p_lk)[3]=1.; (*p_lk)[1]=(*p_lk)[2]=(*p_lk)[0]=.0;
    break;
  case 'M' : (*p_lk)[0]=(*p_lk)[1]=1.; (*p_lk)[2]=(*p_lk)[3]=.0;
    break;
  case 'R' : (*p_lk)[0]=(*p_lk)[2]=1.; (*p_lk)[1]=(*p_lk)[3]=.0;
    break;
  case 'W' : (*p_lk)[0]=(*p_lk)[3]=1.; (*p_lk)[1]=(*p_lk)[2]=.0;
    break;
  case 'S' : (*p_lk)[1]=(*p_lk)[2]=1.; (*p_lk)[0]=(*p_lk)[3]=.0;
    break;
  case 'Y' : (*p_lk)[1]=(*p_lk)[3]=1.; (*p_lk)[0]=(*p_lk)[2]=.0;
    break;
  case 'K' : (*p_lk)[2]=(*p_lk)[3]=1.; (*p_lk)[0]=(*p_lk)[1]=.0;
    break;
  case 'B' : (*p_lk)[1]=(*p_lk)[2]=(*p_lk)[3]=1.; (*p_lk)[0]=.0;
    break;
  case 'D' : (*p_lk)[0]=(*p_lk)[2]=(*p_lk)[3]=1.; (*p_lk)[1]=.0;
    break;
  case 'H' : (*p_lk)[0]=(*p_lk)[1]=(*p_lk)[3]=1.; (*p_lk)[2]=.0;
    break;
  case 'V' : (*p_lk)[0]=(*p_lk)[1]=(*p_lk)[2]=1.; (*p_lk)[3]=.0;
    break;
  case 'N' : case 'X' : case '?' : case 'O' : case '-' : 
    (*p_lk)[0]=(*p_lk)[1]=(*p_lk)[2]=(*p_lk)[3]=1.;break;
  default : 
    {
#ifndef LH3_REVISION
      printf("\n. Unknown character state : %c\n",state);
#else
      fprintf(stderr, "\n. Unknown character state : %c\n",state);
#endif
      Exit("\n. Init failed (check the data type)\n"); 
      break;
    }
  }
}

/*********************************************************/

void Init_Tips_At_One_Site_AA(char aa, double **p_lk)
{
  int i;

  For(i,20) (*p_lk)[i] = .0;

  switch(aa){
  case 'A' : (*p_lk)[0]= 1.; break;/* Alanine */
  case 'R' : (*p_lk)[1]= 1.; break;/* Arginine */
  case 'N' : (*p_lk)[2]= 1.; break;/* Asparagine */
  case 'D' : (*p_lk)[3]= 1.; break;/* Aspartic acid */
  case 'C' : (*p_lk)[4]= 1.; break;/* Cysteine */
  case 'Q' : (*p_lk)[5]= 1.; break;/* Glutamine */
  case 'E' : (*p_lk)[6]= 1.; break;/* Glutamic acid */ 
  case 'G' : (*p_lk)[7]= 1.; break;/* Glycine */
  case 'H' : (*p_lk)[8]= 1.; break;/* Histidine */ 
  case 'I' : (*p_lk)[9]= 1.; break;/* Isoleucine */
  case 'L' : (*p_lk)[10]=1.; break;/* Leucine */
  case 'K' : (*p_lk)[11]=1.; break;/* Lysine */
  case 'M' : (*p_lk)[12]=1.; break;/* Methionine */
  case 'F' : (*p_lk)[13]=1.; break;/* Phenylalanin */
  case 'P' : (*p_lk)[14]=1.; break;/* Proline */
  case 'S' : (*p_lk)[15]=1.; break;/* Serine */
  case 'T' : (*p_lk)[16]=1.; break;/* Threonine */
  case 'W' : (*p_lk)[17]=1.; break;/* Tryptophan */
  case 'Y' : (*p_lk)[18]=1.; break;/* Tyrosine */
  case 'V' : (*p_lk)[19]=1.; break;/* Valine */
    
  case 'B' : (*p_lk)[2]= 1.; break;/* Asparagine */
  case 'Z' : (*p_lk)[5]= 1.; break;/* Glutamine */

  case 'X' : case '?' : case '-' : For(i,20) (*p_lk)[i] = 1.; break;
  default : 
    {
#ifndef LH3_REVISION
      printf("\n. Unknown character state : %c\n",aa);
#else
      fprintf(stderr, "\n. Unknown character state : %c\n",aa);
#endif
      Exit("\n. Init failed (check the data type)\n");  
      break;
    }
  }
}

/*********************************************************/

void Get_All_Partial_Lk(arbre *tree, edge *b_fcus, node *a, node *d)
{
  int i,j;
  double p1_lk1,p2_lk2;
  double ***p_lk,***p_lk_v1,***p_lk_v2;
  int catg,site;
  double ***Pij1,***Pij2;
  
  if(d->tax) return;
  else
    {
      int dir1,dir2;
      
      dir1=dir2=-1;
      For(i,3) if(d->v[i] != a) (dir1<0)?(dir1=i):(dir2=i);

      if(b_fcus->l < BL_MIN) b_fcus->l = BL_MIN;

      p_lk = 
	(d == b_fcus->left)?
	(b_fcus->p_lk_left):
	(b_fcus->p_lk_rght);
      
      p_lk_v1 = 
	(d == d->b[dir1]->left)?
	(d->b[dir1]->p_lk_rght):
	(d->b[dir1]->p_lk_left);
      
      p_lk_v2 = 
	(d == d->b[dir2]->left)?
	(d->b[dir2]->p_lk_rght):
	(d->b[dir2]->p_lk_left);
      
      Pij1 = d->b[dir1]->Pij_rr;
      Pij2 = d->b[dir2]->Pij_rr;
      
      For(catg,tree->mod->n_catg)
	{	  
	  For(site,tree->n_pattern)
	    {
	      For(i,tree->mod->ns) /*sort sum terms ? No global effect*/
		{
		  p1_lk1 = p2_lk2 = .0;
		  For(j,tree->mod->ns)
		    {
		      p1_lk1 += (Pij1[catg][i][j] * p_lk_v1[site][catg][j]);
		      p2_lk2 += (Pij2[catg][i][j] * p_lk_v2[site][catg][j]);
		    }

		  p_lk[site][catg][i] = p1_lk1*p2_lk2;

		  
		  if(p_lk[site][catg][i] < MDBL_MIN) 
		    {
#ifndef LH3_REVISION
		      printf("\nWARNING : scaling is required at site %d\n",site);
#else
		      fprintf(stderr, "\nWARNING : scaling is required at site %d\n",site);
#endif
		      /* 	  printf("Alpha = %f\n",tree->mod->alpha); */
		      /* 	  Exit(""); */
		    }
		}
	    }
	}
   
    }
}

/*********************************************************/

void Get_All_Partial_Lk_Scale(arbre *tree, edge *b_fcus, node *a, node *d)
{
  int i,j;
  double p1_lk1,p2_lk2;
  double ***p_lk,***p_lk_v1,***p_lk_v2;
  int catg,site;
  double ***Pij1,***Pij2;
  double max_p_lk;
/*   double min_p_lk; */
  double sum_scale_d1,sum_scale_d2;
  double try;
  
  p1_lk1 = p2_lk2 = .0;
  if(d->tax) return;
  else
    {
      int dir1,dir2;
      
      dir1=dir2=-1;
      For(i,3) if(d->v[i] != a) (dir1<0)?(dir1=i):(dir2=i);

      if(b_fcus->l < BL_MIN) b_fcus->l = BL_MIN;

      p_lk = 
	(d == b_fcus->left)?
	(b_fcus->p_lk_left):
	(b_fcus->p_lk_rght);
      
      p_lk_v1 = 
	(d == d->b[dir1]->left)?
	(d->b[dir1]->p_lk_rght):
	(d->b[dir1]->p_lk_left);
      
      p_lk_v2 = 
	(d == d->b[dir2]->left)?
	(d->b[dir2]->p_lk_rght):
	(d->b[dir2]->p_lk_left);
      
      Pij1 = d->b[dir1]->Pij_rr;
      Pij2 = d->b[dir2]->Pij_rr;

      

      For(site,tree->n_pattern)
	{	  
	  sum_scale_d1 = sum_scale_d2 = .0;

	  (d == d->b[dir1]->left)?
	    (sum_scale_d1 = d->b[dir1]->sum_scale_f_rght[site]):
	    (sum_scale_d1 = d->b[dir1]->sum_scale_f_left[site]);
	  
	  (d == d->b[dir2]->left)?
	    (sum_scale_d2 = d->b[dir2]->sum_scale_f_rght[site]):
	    (sum_scale_d2 = d->b[dir2]->sum_scale_f_left[site]);

	  (d == b_fcus->left)?
	    (b_fcus->sum_scale_f_left[site] = sum_scale_d1 + sum_scale_d2):
	    (b_fcus->sum_scale_f_rght[site] = sum_scale_d1 + sum_scale_d2);
	
/* 	  min_p_lk = MDBL_MAX; */
	  max_p_lk = MDBL_MIN;
	  For(catg,tree->mod->n_catg)
	    {
#ifdef LH3_REVISION
		double *lh3_p1, *lh3_p2, *lh3_r;
		lh3_p1 = p_lk_v1[site][catg];
		lh3_p2 = p_lk_v2[site][catg];
		lh3_r = p_lk[site][catg];
		For(i,tree->mod->ns) {
		    double *lh3_q1, *lh3_q2;
		    p1_lk1 = p2_lk2 = 0.0;
		    lh3_q1 = Pij1[catg][i];
		    lh3_q2 = Pij2[catg][i];
		    For(j,tree->mod->ns) {
			p1_lk1 += lh3_p1[j] * lh3_q1[j];
			p2_lk2 += lh3_p2[j] * lh3_q2[j];
		    }
		    lh3_r[i] = try = p1_lk1 * p2_lk2;
		    if (try > max_p_lk) max_p_lk = try;
		}
#else
	      For(i,tree->mod->ns) /*sort sum terms ? No global effect*/
		{
		  p1_lk1 = p2_lk2 = .0;
		  For(j,tree->mod->ns)
		    {
		      p1_lk1 += (Pij1[catg][i][j] * p_lk_v1[site][catg][j]);
		      p2_lk2 += (Pij2[catg][i][j] * p_lk_v2[site][catg][j]);
		    }
		  
		  try = p1_lk1*p2_lk2;
		  
		  p_lk[site][catg][i]=try;

		  if((p_lk[site][catg][i] > max_p_lk)) max_p_lk = p_lk[site][catg][i];

/* 		  if((p_lk[site][catg][i] < min_p_lk)) min_p_lk = p_lk[site][catg][i]; */
		}
#endif
	    }

	  
	  if(max_p_lk < LIM_SCALE_VAL)
	    {
	      For(catg,tree->mod->n_catg)
		{
		  For(i,tree->mod->ns)
		    {
		      p_lk[site][catg][i] /= max_p_lk;

		      if(p_lk[site][catg][i] > MDBL_MAX)
			{
			  Exit("\n. Numerical underflow ! (send me an e-mail : s.guindon@auckland.ac.nz)\n");
/*  			  p_lk[site][catg][i] = p_lk[site][catg-1][i] ; */
			}
		    }
		}

	      (d == b_fcus->left)?
		(b_fcus->sum_scale_f_left[site] += log(max_p_lk)):
		(b_fcus->sum_scale_f_rght[site] += log(max_p_lk));
	    }

	  if(max_p_lk > (1./LIM_SCALE_VAL))
	    {
	      For(catg,tree->mod->n_catg)
		{
		  For(i,tree->mod->ns)
		    {
		      p_lk[site][catg][i] /= max_p_lk;

		      if(p_lk[site][catg][i] < MDBL_MIN)
			{
			  Exit("\n. Numerical overflow ! (send me an e-mail : s.guindon@auckland.ac.nz)\n");
/*  			  p_lk[site][catg][i] = p_lk[site][catg-1][i] ; */
			}
		    }
		}

	      (d == b_fcus->left)?
		(b_fcus->sum_scale_f_left[site] += log(max_p_lk)):
		(b_fcus->sum_scale_f_rght[site] += log(max_p_lk));
	    }
	}
    }
}


/*********************************************************/

void Pre_Order_Lk(node *pere, node *fils, arbre *tree)
{
  int i,dir1,dir2,dir3;

  dir1 = dir2 = dir3 = -1;

  if(fils->tax) return;
  else
    {
      For(i,3)
	{
	  if(fils->v[i] != pere)
	    {
	      Pre_Order_Lk(fils,fils->v[i],tree);
	      if(dir1 < 0) dir1 = i;
	      else dir2 = i;
	    }
	  else dir3 = i;
	}

      (tree->n_otu > LIM_SCALE)?
	(Get_All_Partial_Lk_Scale(tree,fils->b[dir3],pere,fils)):
	(Get_All_Partial_Lk(tree,fils->b[dir3],pere,fils));
    }
}

/*********************************************************/

void Post_Order_Lk(node *pere, node *fils, arbre *tree)
{
  int i,j,dir1,dir2;

  dir1 = dir2 = -1;
  
  if(fils->tax) return;
  else
    {
      For(i,3)
	{
	  if(fils->v[i] != pere)
	    {
	      For(j,3)
		{
		  if(j != i)
		    {
		      if(dir1 < 0) dir1 = j;
		      else dir2 = j;
		    }
		}
	      
	      (tree->n_otu > LIM_SCALE)?
	      (Get_All_Partial_Lk_Scale(tree,fils->b[i],fils->v[i],fils)):
	      (Get_All_Partial_Lk(tree,fils->b[i],fils->v[i],fils));
	      dir1 = dir2 = -1;
	      Post_Order_Lk(fils,fils->v[i],tree);
	    }
	}
    }
}

/*********************************************************/

void Lk(arbre *tree,allseq *alldata)
{
  int br,site,catg;
  double len;

  Set_Model_Parameters(tree);
  
  For(br,2*tree->n_otu-3) 
    {
      For(site,tree->n_pattern)
	{
	  tree->t_edges[br]->sum_scale_f_rght[site] = .0;
	  tree->t_edges[br]->sum_scale_f_left[site] = .0;
	}

      
      if(tree->t_edges[br]->l < BL_MIN) tree->t_edges[br]->l = BL_MIN;

      if(tree->t_edges[br]->l > BL_MAX) tree->t_edges[br]->l = BL_MAX;



      For(catg,tree->mod->n_catg)
	{
	  len = tree->t_edges[br]->l*tree->mod->rr[catg];
	  if(len < BL_MIN) len = BL_MIN;

	  PMat(len,
	       tree->mod,
	       &tree->t_edges[br]->Pij_rr[catg]);
	  
	}
    }

  Pre_Order_Lk(tree->noeud[0],tree->noeud[0]->v[0],tree);
  if(tree->both_sides)
    Post_Order_Lk(tree->noeud[0],
		  tree->noeud[0]->v[0],
		  tree);

  tree->tot_loglk = .0;    
  tree->curr_catg =  0;
  tree->curr_site =  0;

  For(site,tree->n_pattern)
    {
      tree->tot_loglk_sorted[site] = .0;
      tree->site_lk[site]          = .0;
      tree->curr_site              = site;
      Site_Lk(tree,alldata);
    }

#ifdef LH3_REVISION
  algo_qsort(tree->tot_loglk_sorted, tree->n_pattern);
#else
  qksort(tree->tot_loglk_sorted, 0, tree->n_pattern-1);
#endif
/*   qsort(tree->tot_loglk_sorted,tree->n_pattern,sizeof(double),Sort_Double_Decrease); */

  tree->tot_loglk = .0;
  For(site, tree->n_pattern)
    {
      if(tree->tot_loglk_sorted[site] < .0) /* WARNING : change cautiously */
	tree->tot_loglk += tree->tot_loglk_sorted[site];
    }

#ifdef LH3_ADDON
  if (tree->lh3_tree.spec_tree) {
	  lh3_spec_clear_cal_flag(tree);
	  lh3_spec_cal_all_branch(tree);
	  tree->tot_loglk += lh3_spec_cal_all_ratio(tree);
  }
  if (tree->lh3_tree.ctree) {
	  lh3_cons_clear_cal_flag(tree);
	  lh3_cons_cal_all_branch(tree);
	  tree->tot_loglk += lh3_cons_cal_all_ratio(tree);
  }
#endif

  For(br,2*tree->n_otu-3)
    {
      if(tree->t_edges[br]->get_p_lk_left) tree->t_edges[br]->ud_p_lk_left = 1;
      if(tree->t_edges[br]->get_p_lk_rght) tree->t_edges[br]->ud_p_lk_rght = 1;
    }
}

/*********************************************************/

void Site_Lk(arbre *tree, allseq *alldata)
{
  int j,k,l,m;
  double *site_dlk=NULL, *site_d2lk=NULL;
  double log_site_lk,site_lk,aux;
  int left;
  edge *eroot;
  int is_ambigu;
  int state_root, state_elsewhere, site = tree->curr_site;


  if(alldata->wght[site] < MDBL_MIN) 
    {
      tree->tot_loglk_sorted[tree->curr_site] = 1.; /* WARNING : change cautiously */ 
      return;
    }


  if(tree->mod->s_opt->opt_bl)
    {
      site_dlk = (double *)mCalloc(2*tree->n_otu-3,sizeof(double));
      site_d2lk = (double *)mCalloc(2*tree->n_otu-3,sizeof(double));
    }
  

  eroot = tree->noeud[0]->b[0];
  (eroot->rght->tax)?(left=1):(left=0);
  
/*   state = tree->data->invar[site]; */
  is_ambigu = alldata->ambigu[site];
  
  state_root = -1;
  state_root = Assign_State(alldata->c_seq[eroot->rght->num]->state + site,
			    tree->mod->datatype,
			    tree->mod->stepsize);

  state_elsewhere = -1;
  state_elsewhere = tree->data->invar[site];

  /**/
/*    is_ambigu = 1; */
  /**/
  

  if(tree->mod->s_opt->opt_bl)
    For(j,2*tree->n_otu-3) site_dlk[j] = site_d2lk[j] = 0.0;


  log_site_lk = site_lk = .0;      

  For(j,tree->mod->n_catg)
    {
      if(is_ambigu)
	{
	  For(k,tree->mod->ns) /*sort sum terms ? No global effect*/
	    {
	      For(l,tree->mod->ns)
		{
		  site_lk += 
		    tree->mod->r_proba[j] *
		    tree->mod->pi[k] *
		    eroot->p_lk_left[site][j][k] *
		    eroot->Pij_rr[j][k][l] *
		    eroot->p_lk_rght[site][j][l];
		}
	    }
	}
      else
	{
	  For(k,tree->mod->ns) /*sort sum terms ? No global effect*/
	    {
	      site_lk +=
		tree->mod->r_proba[j] *
		tree->mod->pi[k] * 
		eroot->p_lk_left[site][j][k] *
		eroot->Pij_rr[j][k][state_root];	    
	      
	    }
	}
      
      
      if(tree->mod->s_opt->opt_bl)
	{
	  For(k,2*tree->n_otu-3)
	    {  
	      tree->t_edges[k]->site_dlk_rr[j] = .0;
	      tree->t_edges[k]->site_d2lk_rr[j] = .0;

	      For(l,tree->mod->ns) /*sort sum terms ? No global effect*/
		{
		  For(m,tree->mod->ns)
		    {
		      tree->t_edges[k]->site_dlk_rr[j] += 
			tree->mod->pi[l] * 
			tree->t_edges[k]->p_lk_left[site][j][l]*
			tree->t_edges[k]->p_lk_rght[site][j][m]*
			tree->t_edges[k]->dPij_rr[j][l][m];
		      

		      tree->t_edges[k]->site_d2lk_rr[j] += 
			tree->mod->pi[l] * 
			tree->t_edges[k]->p_lk_left[site][j][l]*
			tree->t_edges[k]->p_lk_rght[site][j][m]*
			tree->t_edges[k]->d2Pij_rr[j][l][m];
		    }
		}

	      site_dlk[k]  += tree->t_edges[k]->site_dlk_rr[j]*
		              tree->mod->r_proba[j];
	      
	      site_d2lk[k] += tree->t_edges[k]->site_d2lk_rr[j]*
		              tree->mod->r_proba[j];
	    }
	}   
    }
  


  /* code 2.3 begin*/

  if (!tree->mod->invar)
    {
      log_site_lk += log(site_lk) 
	+ eroot->sum_scale_f_left[site] + eroot->sum_scale_f_rght[site];
    }
  else
    {
      if ((double)tree->data->invar[site] > -0.5)
	{
	  if (!(eroot->sum_scale_f_left[site] + eroot->sum_scale_f_rght[site]==0.0))
	    site_lk *= exp(eroot->sum_scale_f_left[site] + eroot->sum_scale_f_rght[site]);
	  
	  log_site_lk = log(site_lk*(1.0-tree->mod->pinvar) + tree->mod->pinvar*tree->mod->pi[state_elsewhere]);
	}
      else
	{
	  log_site_lk = log(site_lk*(1.0-tree->mod->pinvar))
	    + eroot->sum_scale_f_left[site] + eroot->sum_scale_f_rght[site];
	}
    }
  /* code 2.3 end*/
  
  if(log_site_lk < -MDBL_MAX)
    {
#ifndef LH3_REVISION
      printf("%d %E %f %f %f %f\n",
	     site,
	     log_site_lk,
	     tree->mod->alpha,
	     eroot->sum_scale_f_left[site],
	     eroot->sum_scale_f_rght[site],
	     tree->mod->pinvar);
#else
      fprintf(stderr, "%d %E %f %f %f %f\n", site, log_site_lk, tree->mod->alpha,
			  eroot->sum_scale_f_left[site], eroot->sum_scale_f_rght[site], tree->mod->pinvar);
#endif
      Exit("\nlog_site_lk < -MDBL_MAX\n");
    }


  tree->site_lk[site] = log_site_lk;
  
  
  if(tree->mod->s_opt->opt_bl)
    {
      For(k,2*tree->n_otu-3)
	{
	  aux = exp(tree->t_edges[k]->sum_scale_f_rght[site]+
		    tree->t_edges[k]->sum_scale_f_left[site]);
	  site_dlk[k]  *= aux;
	  site_d2lk[k] *= aux;
	  
	  tree->t_edges[k]->site_dlk = site_dlk[k];
	  tree->t_edges[k]->site_d2lk = site_d2lk[k];	  
	}
    }
  
/*   tree->tot_loglk += alldata->wght[site]*log_site_lk; */
  tree->tot_loglk_sorted[site] = alldata->wght[site]*log_site_lk;


  if((tree->mod->s_opt->opt_bl) &&
     (fabs(site_lk = exp(log_site_lk)) > sqrt(MDBL_MIN)))
    {
      For(k,2*tree->n_otu-3)
	{
	  aux = site_dlk[k] / site_lk;
	  tree->tot_dloglk[k]  += alldata->wght[site] 
	                       *  aux;
	  tree->tot_d2loglk[k] += alldata->wght[site]
	                       * (site_d2lk[k]/site_lk
			       -  aux*aux);
	}
    }

  if(tree->mod->s_opt->opt_bl)
    {
      Free(site_dlk);
      Free(site_d2lk);
    }
}

/*********************************************************/

double Lk_At_Given_Edge(arbre *tree, edge *b_fcus)
{
  int site,catg,k,l,edge_num, ns = tree->mod->ns;
  double site_lk,log_site_lk,site_dlk,site_d2lk,aux;

  edge_num = b_fcus->num;
  tree->tot_loglk = log_site_lk = .0;
  tree->tot_dloglk[edge_num] = tree->tot_d2loglk[edge_num] = .0;
  tree->n_pattern = tree->data->crunch_len/tree->mod->stepsize;


  if(b_fcus->l < BL_MIN) b_fcus->l = BL_MIN;
  if(b_fcus->l > BL_MAX) b_fcus->l = BL_MAX;
  
  For(catg,tree->mod->n_catg)
    {
      aux = b_fcus->l*tree->mod->rr[catg];
      if(aux < BL_MIN) aux = BL_MIN;
      PMat(aux, tree->mod,&b_fcus->Pij_rr[catg]);
    }


  if((tree->mod->s_opt->opt_bl) && (!tree->mod->datatype))
    {
      For(catg,tree->mod->n_catg)
	{
	  dPMat(tree->t_edges[edge_num]->l,
		tree->mod->rr[catg],
		tree->mod,
		&b_fcus->dPij_rr[catg]);
	  d2PMat(tree->t_edges[edge_num]->l,
		 tree->mod->rr[catg],
		 tree->mod,
		 &b_fcus->d2Pij_rr[catg]);
	}
    }


  For(site,tree->data->crunch_len)
    {
      if(tree->data->wght[site])
	{
	  log_site_lk = site_lk = .0;
	  /* see equation (2) in phyml_tech_doc.pdf */
#ifdef LH3_REVISION
	For(catg,tree->mod->n_catg) {
	    double lh3_sum, *lh3_p, *lh3_q;
	    lh3_sum = 0.0;
	    lh3_p = b_fcus->p_lk_left[site][catg];
	    lh3_q = b_fcus->p_lk_rght[site][catg];
	    For(k, ns) {
		double *lh3_r = b_fcus->Pij_rr[catg][k];
		double lh3_sum2 = 0.0;
		For(l, ns) {
		    lh3_sum2 += lh3_q[l] * lh3_r[l];
		}
		lh3_sum += tree->mod->pi[k] * lh3_p[k] * lh3_sum2;
	    }
	    site_lk += tree->mod->r_proba[catg] * lh3_sum;
	}
#else /* LH3_REVISION */
	  For(catg,tree->mod->n_catg)
	    {
	      For(k,ns) /*sort sum terms ? No global effect*/
		{
		  For(l,ns)
		    {
		      site_lk += 
			tree->mod->r_proba[catg] *
			tree->mod->pi[k] * 
			b_fcus->p_lk_left[site][catg][k] *
			b_fcus->p_lk_rght[site][catg][l] *
			b_fcus->Pij_rr[catg][k][l];
		    }
		}
	    }
#endif /* LH3_REVISION */

	  /* code 2.3 begin*//* see equations in phyml_tech_doc.pdf */
	  /* compute log_site_lk */
	  if (!tree->mod->invar)
	    {
	      log_site_lk += log(site_lk) 
		+ b_fcus->sum_scale_f_left[site] + b_fcus->sum_scale_f_rght[site];
	    }
	  else
	    {
	      if ((double)tree->data->invar[site] > -0.5)
		{
		  if (!(b_fcus->sum_scale_f_left[site] + b_fcus->sum_scale_f_rght[site]==0.0))
		    site_lk *= exp(b_fcus->sum_scale_f_left[site] + b_fcus->sum_scale_f_rght[site]);
		  
		  log_site_lk = log(site_lk*(1.0-tree->mod->pinvar) + tree->mod->pinvar*tree->mod->pi[tree->data->invar[site]]);
		}
	      else
		{
		  log_site_lk = log(site_lk*(1.0-tree->mod->pinvar)) 
		    + b_fcus->sum_scale_f_left[site] + b_fcus->sum_scale_f_rght[site];
		}
	    }
	  /* code 2.3 end*/

	  if(log_site_lk < -MDBL_MAX) Exit("\nlog_site_lk < -MDBL_MAX\n");

	  tree->site_lk[site] = log_site_lk;

	  /*tree->tot_loglk += *//* old code */
	  tree->tot_loglk_sorted[site] = /* code 2.3 */
	    tree->data->wght[site]*log_site_lk;
	}
      else tree->tot_loglk_sorted[site] = 1.; /* WARNING : change cautiously */
    }

  /* code 2.3 begin*/
  /* sort and add numbers from smallest to biggest */
#ifdef LH3_REVISION
  algo_qsort(tree->tot_loglk_sorted, tree->n_pattern);
#else
  qksort(tree->tot_loglk_sorted, 0, tree->n_pattern-1);
#endif
/*   qsort(tree->tot_loglk_sorted,tree->n_pattern,sizeof(double),Sort_Double_Decrease); */

  tree->tot_loglk = .0;
  For(k, tree->data->crunch_len) 
    if(tree->tot_loglk_sorted[k] < .0) /* WARNING : change cautiously */
      tree->tot_loglk += tree->tot_loglk_sorted[k];
#ifdef LH3_ADDON
  if (tree->lh3_tree.spec_tree)
	  tree->tot_loglk += lh3_spec_update_one_ratio(tree, b_fcus);
  if (tree->lh3_tree.ctree)
	  tree->tot_loglk += lh3_cons_update_one_ratio(tree, b_fcus);
#endif
  /* code 2.3 end*/
  
  if((tree->mod->s_opt->opt_bl) && (!tree->mod->datatype))
    {
      For(site,tree->n_pattern)
	{
	  if(tree->data->wght[site])
	    {
	      site_dlk = site_d2lk = .0;      
	      b_fcus->site_dlk = b_fcus->site_d2lk = .0; 
	      
	      For(catg,tree->mod->n_catg)
		{
		  For(k,ns) /*sort sum terms ? No global effect*/
		    {
		      For(l,ns)
			{
			  aux = tree->mod->r_proba[catg] *
			    tree->mod->pi[k] *
			    b_fcus->p_lk_left[site][catg][k];
			  
			  site_dlk +=
			    aux *
			    b_fcus->p_lk_rght[site][catg][l] *
			    b_fcus->dPij_rr[catg][k][l];
			  
			  site_d2lk +=
			    aux *
			    b_fcus->p_lk_rght[site][catg][l] *
			    b_fcus->d2Pij_rr[catg][k][l];
			}
		    }
		}

	      if(tree->n_otu > LIM_SCALE)
		{
		  aux = exp(b_fcus->sum_scale_f_rght[site]+
			    b_fcus->sum_scale_f_left[site]);
		  site_dlk  *= aux;
		  site_d2lk *= aux;
		}

	      b_fcus->site_dlk = site_dlk;
	      b_fcus->site_d2lk = site_d2lk;

	      if(fabs(exp(log_site_lk)) > sqrt(MDBL_MIN))
		{
		  aux = site_dlk / tree->site_lk[site];
		  tree->tot_dloglk[edge_num]  += tree->data->wght[site] 
		                              * aux;
		  tree->tot_d2loglk[edge_num] += tree->data->wght[site] 
		                              * (site_d2lk/tree->site_lk[site] 
					      - aux*aux);
		}
	    }
	}
    }

  return tree->tot_loglk;
}
  
/*********************************************************/

void Update_P(arbre *tree, int t_edge_num)
{
  int i;
  double len;

  len = -1.0;
  For(i,tree->mod->n_catg)
    {
      tree->curr_catg = i;
      len = tree->t_edges[t_edge_num]->l*tree->mod->rr[i];
      if(len < BL_MIN) len = BL_MIN;
      tree->mod->update_eigen = 0;
      PMat(len,tree->mod,&tree->t_edges[t_edge_num]->Pij_rr[i]);
/*        Derivatives(tree->t_edges[t_edge_num],tree);    */
    }
}

/*********************************************************/

double Return_Lk(arbre *tree)
{
  Lk(tree,tree->data);
  return tree->tot_loglk;
}

/*********************************************************/

double Return_Abs_Lk(arbre *tree)
{
  Lk(tree,tree->data);
  return fabs(tree->tot_loglk);
}

/*********************************************************/

matrix *ML_Dist_fixed(allseq *data, model *mod, int n_cat)
{
  int j,k,l;
  double init;
  int n_catg;
  double d_max;
  matrix *mat;
  allseq *twodata,*tmpdata;

  tmpdata = (allseq *)mCalloc(1,sizeof(allseq));
  tmpdata->n_otu=2;
  tmpdata->c_seq = (seq **)mCalloc(2,sizeof(seq *));
  tmpdata->factw = (double *)mCalloc(data->crunch_len,sizeof(double));
  tmpdata->b_frq = (double *)mCalloc(mod->ns,sizeof(double));
  tmpdata->ambigu = (int *)mCalloc(data->crunch_len,sizeof(int));

  tmpdata->crunch_len = tmpdata->init_len = data->crunch_len;


  mat = 
    (!mod->datatype) ?
    ((mod->whichmodel < 10)?(K2P_dist(data,2000)):(JC69_Dist(data,mod))):
    (JC69_Dist(data,mod));

  n_catg = -1;

 
  For(j,data->n_otu-1)
    {
      tmpdata->c_seq[0]=data->c_seq[j];
      tmpdata->c_seq[0]->name=data->c_seq[j]->name;
      tmpdata->wght = data->wght;

      for(k=j+1;k<data->n_otu;k++)
	{
	  tmpdata->c_seq[1]=data->c_seq[k];
	  tmpdata->c_seq[1]->name=data->c_seq[k]->name;

	  twodata = Compact_CSeq(tmpdata,mod);
	  For(l,mod->ns) twodata->b_frq[l]=data->b_frq[l];

	  Check_Ambiguities(twodata,mod->datatype,1);

	  Hide_Ambiguities(twodata);	  

	  init = mat->dist[j][k];
	  if((init == DIST_MAX) || (init < .0)) init = 0.1;


	  n_catg = mod->n_catg;
	  mod->n_catg = n_cat;


/* BRENT */
	  d_max = Optimize_Dist(mod,init,twodata);

/* 	  d_max = init; */

/* NEWTON-RAPHSON */
/* 	  if(d_max < .0) */
/* 	    { */
/* 	      d_max =  Optimize_One_Dist(twodata,0,1,init,mod); */
/* 	      d_max = init; */

/* 	    } */

	  mod->n_catg = n_catg;


	  if(d_max >= DIST_MAX) 
	    {
#ifndef LH3_REVISION
	      printf("\n. Large distance encountered between %s and %s sequences\n",
		     tmpdata->c_seq[1]->name,
		     tmpdata->c_seq[0]->name);
#else
		  if (!lh3_revision_is_quiet)
			  fprintf(stderr, "Large distance encountered between %s and %s sequences\n",
					  tmpdata->c_seq[1]->name, tmpdata->c_seq[0]->name);
#endif
	      d_max = DIST_MAX;
	    }

	  mat->dist[j][k] = d_max;
	  mat->dist[k][j] = mat->dist[j][k];
	  Free_Cseq(twodata);
	}
    }
 

  Free(tmpdata->ambigu);
  Free(tmpdata->b_frq);
  Free(tmpdata->factw);
  Free(tmpdata->c_seq);
  free(tmpdata);

  return mat;
}

matrix *ML_Dist(allseq *data, model *mod)
{
	return ML_Dist_fixed(data, mod, 1);
}

/*********************************************************/

double Lk_Given_Two_Seq(allseq *data, int numseq1, int numseq2, double dist, model *mod,
			double *loglk, double *dloglk, double *d2loglk)
{
  seq *seq1,*seq2;
  double site_lk,site_dlk,site_d2lk,log_site_lk;
  int i,j,k,l;
  double **p_lk_l,**p_lk_r;
  double len;

  DiscreteGamma (mod->r_proba, mod->rr, mod->alpha,
		 mod->alpha,mod->n_catg,0);



  seq1 = data->c_seq[numseq1];
  seq2 = data->c_seq[numseq2];

  p_lk_l = (double **)mCalloc(data->c_seq[0]->len,sizeof(double *));
  p_lk_r = (double **)mCalloc(data->c_seq[0]->len,sizeof(double *));

  For(i,data->c_seq[0]->len)
    {
      p_lk_l[i] = (double *)mCalloc(mod->ns,sizeof(double));
      p_lk_r[i] = (double *)mCalloc(mod->ns,sizeof(double));
    }


  if(dist < BL_MIN) dist = BL_START;

  For(i,mod->n_catg) 
    {
      len = dist*mod->rr[i];
      if(len < BL_MIN) len = BL_MIN;
      PMat(len,mod,&(mod->Pij_rr[i]));        
    }


  if(!mod->datatype)
    {
      For(i,mod->n_catg) 
	{
	  dPMat(dist,mod->rr[i],mod,&(mod->dPij_rr[i]));      
	  d2PMat(dist,mod->rr[i],mod,&(mod->d2Pij_rr[i]));      
	}

      For(i,data->c_seq[0]->len)
	{
	  Init_Tips_At_One_Site_Nucleotides(seq1->state[i],
					    &p_lk_l[i]);
	  Init_Tips_At_One_Site_Nucleotides(seq2->state[i],
					    &p_lk_r[i]);
	}
    }
  else
    {
      For(i,data->c_seq[0]->len)
	{
	  Init_Tips_At_One_Site_AA(seq1->state[i],
				   &p_lk_l[i]);
	  Init_Tips_At_One_Site_AA(seq2->state[i],
				   &p_lk_r[i]);
	}
    }
    

  site_lk = site_dlk = site_d2lk = .0;
  *loglk = *dloglk = *d2loglk = 0;

  For(i,data->c_seq[0]->len)
    {
      if(data->wght[i])
	{
	  site_lk = log_site_lk = .0;
	  if(!data->ambigu[i])
	    {
	      For(k,mod->ns) {if(p_lk_l[i][k] > .0001) break;}
	      For(l,mod->ns) {if(p_lk_r[i][l] > .0001) break;}
	      For(j,mod->n_catg)
		{
		  site_lk +=
		    mod->r_proba[j] *
		    mod->pi[k] *
		    p_lk_l[i][k] *
		    mod->Pij_rr[j][k][l] *
		    p_lk_r[i][l];
		}
	    }
	  else
	    {
	      For(j,mod->n_catg)
		{
		  For(k,mod->ns) /*sort sum terms ? No global effect*/
		    {
		      For(l,mod->ns)
			{
			  site_lk += 
			    mod->r_proba[j] *
			    mod->pi[k] * 
			    p_lk_l[i][k] *
			    mod->Pij_rr[j][k][l] *
			    p_lk_r[i][l]; 
			}
		    }
		}
	    }

/* 	  printf("'%c' '%c' -> %f\n",seq1->state[i],seq2->state[i],site_lk); */

	  if(site_lk <= .0) 
	    {
#ifndef LH3_REVISION
	      printf("'%c' '%c'\n",seq1->state[i],seq2->state[i]);
#else
	      fprintf(stderr, "'%c' '%c'\n",seq1->state[i],seq2->state[i]);
#endif
	      Exit("\n. Err: site lk <= 0\n");
	    }

	  log_site_lk += log(site_lk);

	  *loglk   += data->wght[i] * log_site_lk;/* sort sum terms ? No global effect*/
	}
    }

  For(i,data->c_seq[0]->len)
    {
      Free(p_lk_l[i]);
      Free(p_lk_r[i]);
    }
  Free(p_lk_l); Free(p_lk_r);
  return *loglk;
}

/*********************************************************/

double ***Get_Partial_Lk_Struct(arbre *tree, int len, int n_catg)
{
  double ***p_lk;
  int j,k;

  p_lk = (double ***)mCalloc(len,sizeof(double **)); 
  For(j,len)
    {
      p_lk[j] = (double **)mCalloc((int)n_catg,sizeof(double *));
      For(k,n_catg) p_lk[j][k] = (double *)mCalloc(tree->mod->ns,sizeof(double ));
    }
  return p_lk;
}

/*********************************************************/

void Unconstraint_Lk(arbre *tree)
{
  int i;

  tree->unconstraint_lk = .0;

  For(i,tree->data->crunch_len)
    {
      tree->unconstraint_lk += 
	tree->data->wght[i]*log(tree->data->wght[i]);
    }
  tree->unconstraint_lk -= 
    tree->data->init_len*log(tree->data->init_len);
}

/*********************************************************/

void Update_P_Lk(arbre *tree, edge *b_fcus, node *n)
{
/*  
           |
	   |<- b_cus
	   |
	   n
          / \
       	 /   \
       	/     \
*/

  int k,l;
  int site, catg;
  double ***p_lk, ***p_lk_v1, ***p_lk_v2;
  double **Pij1, **Pij2;
  double *n_scale_f, *d1_scale_f, *d2_scale_f;
  double p1_lk1,p2_lk2;
  double max_p_lk;
  edge *b1, *b2;

  
  b1 = b2  = NULL;
  p_lk = p_lk_v1 = p_lk_v2 = NULL;
  max_p_lk = MDBL_MIN;


  if(n == b_fcus->left)
    {
/*       if(b_fcus->ud_p_lk_left) { printf("This p_lk is up to date\n"); return;} */
      p_lk = b_fcus->p_lk_left;
      
      p_lk_v1 = 
      (n == n->b[b_fcus->l_v1]->left)?
      (n->b[b_fcus->l_v1]->p_lk_rght):
      (n->b[b_fcus->l_v1]->p_lk_left);

      p_lk_v2 = 
      (n == n->b[b_fcus->l_v2]->left)?
      (n->b[b_fcus->l_v2]->p_lk_rght):
      (n->b[b_fcus->l_v2]->p_lk_left);


      n_scale_f = b_fcus->sum_scale_f_left;

      d1_scale_f = 
      (n == n->b[b_fcus->l_v1]->left)?
      (n->b[b_fcus->l_v1]->sum_scale_f_rght):
      (n->b[b_fcus->l_v1]->sum_scale_f_left);

      d2_scale_f = 
      (n == n->b[b_fcus->l_v2]->left)?
      (n->b[b_fcus->l_v2]->sum_scale_f_rght):
      (n->b[b_fcus->l_v2]->sum_scale_f_left);
    
      b_fcus->get_p_lk_left = 1;
      b_fcus->ud_p_lk_left  = 1;
    }

  else
    {
      p_lk = b_fcus->p_lk_rght;
      
      p_lk_v1 = 
      (n == n->b[b_fcus->r_v1]->left)?
      (n->b[b_fcus->r_v1]->p_lk_rght):
      (n->b[b_fcus->r_v1]->p_lk_left);

      p_lk_v2 = 
      (n == n->b[b_fcus->r_v2]->left)?
      (n->b[b_fcus->r_v2]->p_lk_rght):
      (n->b[b_fcus->r_v2]->p_lk_left);

      n_scale_f = b_fcus->sum_scale_f_rght;

      d1_scale_f = 
      (n == n->b[b_fcus->r_v1]->left)?
      (n->b[b_fcus->r_v1]->sum_scale_f_rght):
      (n->b[b_fcus->r_v1]->sum_scale_f_left);

      d2_scale_f = 
      (n == n->b[b_fcus->r_v2]->left)?
      (n->b[b_fcus->r_v2]->sum_scale_f_rght):
      (n->b[b_fcus->r_v2]->sum_scale_f_left);

      b_fcus->get_p_lk_rght = 1;
      b_fcus->ud_p_lk_rght  = 1;
    }

  if(b_fcus->l < BL_MIN) b_fcus->l = BL_MIN;
  
 

  if(n == b_fcus->left) 
    {
      b1 = n->b[b_fcus->l_v1];
      b2 = n->b[b_fcus->l_v2];
    }
  else
    {
      b1 = n->b[b_fcus->r_v1];
      b2 = n->b[b_fcus->r_v2];
    }


  if(tree->n_otu <= LIM_SCALE)
    {
      /* NO SCALE */

      For(site,tree->n_pattern)
	{
	  if(tree->data->wght[site])
	    {
	      For(catg,tree->mod->n_catg)
		{
		  
		  Pij1 = b1->Pij_rr[catg];
		  Pij2 = b2->Pij_rr[catg];
		  
		  
		  For(k,tree->mod->ns) /*sort sum terms ? No global effect*/
		    {
		      p1_lk1 = p2_lk2 = .0;
		      
		      For(l,tree->mod->ns)
			{
			  p1_lk1 += Pij1[k][l] * p_lk_v1[site][catg][l];
			  p2_lk2 += Pij2[k][l] * p_lk_v2[site][catg][l];
			}
		      p_lk[site][catg][k] = p1_lk1 * p2_lk2;
		    }
		}
	    }
	}
    }
  else
    {
      /* SCALE */

      For(site,tree->n_pattern)
	{
	  if(tree->data->wght[site])
	    {
	      For(catg,tree->mod->n_catg)
		{
		  
		  Pij1 = b1->Pij_rr[catg];
		  Pij2 = b2->Pij_rr[catg];
		  
		  if(!catg) 
		    {
		      n_scale_f[site] = d1_scale_f[site] + d2_scale_f[site];
		      max_p_lk = -MDBL_MAX;
		    }
		  
		  For(k,tree->mod->ns) /*sort sum terms ? No global effect*/
		    {
		      p_lk[site][catg][k] = .0;
		      p1_lk1 = p2_lk2     = .0;
		      		      
		      For(l,tree->mod->ns)
			{
			  p1_lk1 += Pij1[k][l] * p_lk_v1[site][catg][l];
			  p2_lk2 += Pij2[k][l] * p_lk_v2[site][catg][l];
			}

		      p_lk[site][catg][k] = p1_lk1 * p2_lk2;
		      

		      if((p_lk[site][catg][k] > max_p_lk)) max_p_lk = p_lk[site][catg][k];
		      
		    }
		}
	         
	      if(max_p_lk < LIM_SCALE_VAL)
		{
		  For(catg,tree->mod->n_catg)
		    {
		      For(k,tree->mod->ns) 
			{
			  p_lk[site][catg][k] /= max_p_lk;
			  
			  if(p_lk[site][catg][k] > MDBL_MAX)
			    {
			      Exit("\n. Numerical overflow ! (send me an e-mail : s.guindon@auckland.ac.nz)\n");
			    }			  
			}
		    }
		  n_scale_f[site] += log(max_p_lk);
		}
	      
	      if(max_p_lk > (1./LIM_SCALE_VAL))
		{
		  For(catg,tree->mod->n_catg)
		    {
		      For(k,tree->mod->ns) 
			{
			  p_lk[site][catg][k] /= max_p_lk;
			  if(p_lk[site][catg][k] < MDBL_MIN)
			    {
#ifndef LH3_REVISION
			      printf("\n. Numerical underflow ! (send me an e-mail : s.guindon@auckland.ac.nz)\n");
#else
			      fprintf(stderr, "\n. Numerical underflow ! (send me an e-mail : s.guindon@auckland.ac.nz)\n");
#endif
			    }			  
			}
		    }
		  n_scale_f[site] += log(max_p_lk);
		}
	    }
	}
    }
}

/*********************************************************/

void Make_Tree_4_Lk(arbre *tree, allseq *alldata, int n_site)
{
  int i;

  if(!tree->tot_loglk_sorted) tree->tot_loglk_sorted = (double *)mCalloc(tree->n_pattern, sizeof(double));

  if(!tree->tot_dloglk)       tree->tot_dloglk       = (double *)mCalloc(2*tree->n_otu-3,sizeof(double));
  if(!tree->tot_d2loglk)      tree->tot_d2loglk      = (double *)mCalloc(2*tree->n_otu-3,sizeof(double));
  if(!tree->t_best_l)         tree->t_best_l         = (double *)mCalloc(2*tree->n_otu-3,sizeof(double));
  if(!tree->site_lk)          tree->site_lk          = (double *)mCalloc(alldata->crunch_len,sizeof(double));
  
  tree->n_p_lk_alloc = 1;
  tree->root = tree->noeud[0];

  tree->tbl = .0;
  For(i,2*tree->n_otu-3) tree->tbl += tree->t_edges[i]->l;
  
  For(i,2*tree->n_otu-3)
    {
      tree->t_best_l[i] = tree->t_edges[i]->l;
      Make_Edge_Lk(tree->t_edges[i]->left,
		   tree->t_edges[i]->rght,
		   tree);
    }
  

  For(i,2*tree->n_otu-2)
    Make_Node_Lk(tree->noeud[i]);

  Alloc_All_P_Lk(tree);
/*   Make_P_Lk_Struct(tree);   */
 
  Init_P_Lk_Tips(tree);
 
}

/*********************************************************/

void Init_P_Lk_Tips(arbre *tree)
{
  int curr_site,i,j,k;
  

  Fors(curr_site,tree->data->crunch_len,tree->mod->stepsize)
    {
      For(i,tree->n_otu)
	{
	  if (!tree->mod->datatype)
	    {
		Init_Tips_At_One_Site_Nucleotides(tree->data->c_seq[i]->state[curr_site],
						  &tree->noeud[i]->b[0]->p_lk_rght[curr_site][0]);
                
	    }
	  else
	    Init_Tips_At_One_Site_AA(tree->data->c_seq[i]->state[curr_site],
				     &tree->noeud[i]->b[0]->p_lk_rght[curr_site][0]);
	  


	  if((tree->noeud[i]->b[0]->p_lk_rght) && (tree->noeud[i]->b[0]->get_p_lk_rght))
	    {
	      for(j=1;j<tree->mod->n_catg;j++)
		{
		  For(k,tree->mod->ns)
		    {
		      tree->noeud[i]->b[0]->p_lk_rght[curr_site][j][k]=
		      tree->noeud[i]->b[0]->p_lk_rght[curr_site][0][k];
		    }
		}
	    }
	  else
	    {
	      for(j=1;j<tree->mod->n_catg;j++)
		For(k,tree->mod->ns)
		  tree->noeud[i]->b[0]->p_lk_rght[curr_site][j][k]=
		  tree->noeud[i]->b[0]->p_lk_rght[curr_site][0][k];
	    }
	}
    }
}

/*********************************************************/
