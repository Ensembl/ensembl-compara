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
#include "simu.h"


int    BRENT_ITMAX;
double BRENT_CGOLD;
double BRENT_ZEPS;
double MNBRAK_GOLD;
double MNBRAK_GLIMIT;
double MNBRAK_TINY;
double ALPHA_MIN;
double ALPHA_MAX;
double BL_MIN;
double BL_START;
double BL_MAX;
double MIN_DIFF_LK;
double GOLDEN_R;
double GOLDEN_C;
int    T_MAX_FILE;
int    T_MAX_LINE;
int    T_MAX_NAME;
int    T_MAX_SEQ;
int    N_MAX_INSERT;
int    N_MAX_OTU;
double UNLIKELY;
double NJ_SEUIL;
int    MAX_TOPO_DIST;
double DIST_MAX;
int    LIM_SCALE;
double AROUND_LK;
double PROP_STEP;


/*********************************************************/

void Simu(arbre *tree, int n_step_max)
{
    double old_loglk,n_iter,lambda,diff_lk;
    int i,n_neg,n_tested,n_without_swap,step,it_lim_without_swap;
    edge **sorted_b,**tested_b;
    int each,each_invar;
    int opt_free_param;
    
    sorted_b = (edge **)mCalloc(tree->n_otu-3,sizeof(edge *));
    tested_b = (edge **)mCalloc(tree->n_otu-3,sizeof(edge *));
    
    
    
    old_loglk = tree->tot_loglk = UNLIKELY;
    n_iter              = 1.0;
    it_lim_without_swap = (tree->mod->invar)?(8):(5);
    n_tested            = 0;
    n_without_swap      = 0;
    step                = 0;
    each                = 4;
    lambda              = 0.75;
    each_invar          = 2;
    old_loglk           =  tree->tot_loglk;
    opt_free_param      = 0;

    do
        {
            ++step;
            
            if(step > n_step_max) break;
            
            each--;
            each_invar--;
            
            tree->mod->s_opt->opt_bl = 0;
            tree->both_sides    = 1;
            Lk(tree,tree->data);
            
            
            if(tree->mod->s_opt->print)
                {
                    if(old_loglk < UNLIKELY+1)
                        printf("\n. Log(lk) :               * -> %15.6f ",tree->tot_loglk);
                    else
                        printf("\n. Log(lk) : %15.6f -> %15.6f ",old_loglk,tree->tot_loglk);
                    
                    if(old_loglk > UNLIKELY+1)
                        {
                            if(n_tested > 1) printf("%3d swaps done ",n_tested);
                            else             printf("%3d swap  done", n_tested);
                        }
                }
            
            fflush(NULL);
            
            if((fabs(old_loglk-tree->tot_loglk) < 1.E-03) || (n_without_swap > it_lim_without_swap)) break;
            
            diff_lk = old_loglk-tree->tot_loglk;
            
            if(tree->tot_loglk < old_loglk)
                {
                    if(tree->mod->s_opt->print)
                        printf("\n\n. Moving backward (topology + branch lengths) \n");
                    fflush(NULL);
                    if(!Mov_Backward_Topo_Bl(tree,old_loglk,tested_b,n_tested))
                        Exit("\n. Err: mov_back failed\n");
                    if(!tree->n_swap) n_neg = 0;
                    
                    For(i,2*tree->n_otu-3) tree->t_edges[i]->l_old = tree->t_edges[i]->l;
                    
                    Optimiz_All_Free_Param(tree,tree->mod->s_opt->print);
                }
            else 
                {
                    if(!each)
                        {
                            opt_free_param = 1;
                            each = 4;
                            if(tree->mod->s_opt->print) printf("\n");
                            Optimiz_All_Free_Param(tree,tree->mod->s_opt->print);
                            tree->mod->s_opt->opt_bl = 0;
                            tree->both_sides    = 1;
                            Lk(tree,tree->data);
                        }
                    
                    old_loglk = tree->tot_loglk;
                    
                    Fix_All(tree);
                    
                    n_neg = 0;
                    For(i,2*tree->n_otu-3)
                        if((!tree->t_edges[i]->left->tax) && 
                           (!tree->t_edges[i]->rght->tax)) 
                            NNI(tree,tree->t_edges[i],0);
                    
                    Select_Edges_To_Swap(tree,sorted_b,&n_neg);
                    
                    Sort_Edges_Diff_Lk(tree,sorted_b,n_neg);
                    
                    Optimiz_Ext_Br(tree);	  
                    
                    Update_Bl(tree,lambda);
                    
                    n_tested = 0;
                    For(i,(int)ceil((double)n_neg*(lambda)))
                        tested_b[n_tested++] = sorted_b[i];
                    
                    Make_N_Swap(tree,tested_b,0,n_tested);
                    
                    if(n_tested > 0) n_without_swap = 0;
                    else             n_without_swap++;
                    
                    fflush(NULL);
                }
            n_iter+=1.0;
        }
    while(1);
    
    
    Free(sorted_b);
    Free(tested_b);
    
    
    if(((n_without_swap > it_lim_without_swap) && (tree->mod->s_opt->last_opt)) || (!opt_free_param))
        {
            if(tree->mod->s_opt->print)
                printf("\n\n. Last optimization step...\n"); fflush(NULL);
            Round_Optimize(tree,tree->data);
        }
}

/*********************************************************/

void Select_Edges_To_Swap(arbre *tree, edge **sorted_b, int *n_neg)
{
  int i;
  edge *b;
  int min;


  *n_neg = 0;
  tree->min_diff_lk = .0;
  min = 0;
  For(i,2*tree->n_otu-3)
    {
      b = tree->t_edges[i];

      if((!b->left->tax) 
      && (!b->rght->tax) 
      && (b->diff_lk < 0.0-MDBL_MIN)) 
	{

	  if((b->left->b[b->l_v1]->diff_lk < b->diff_lk) ||
	     (b->left->b[b->l_v2]->diff_lk < b->diff_lk) ||
	     (b->rght->b[b->r_v1]->diff_lk < b->diff_lk) ||
	     (b->rght->b[b->r_v2]->diff_lk < b->diff_lk)) continue;

	  if(b->diff_lk < tree->min_diff_lk) 
	    {
	      tree->min_diff_lk = b->diff_lk;
	      min = i;
	    }

	  sorted_b[*n_neg] = b;
	  (*n_neg)++;
	}
    }
}

/*********************************************************/

void Fix_All(arbre *tree)
{
  int i;
  edge *b;

  tree->mod->pinvar_old = tree->mod->pinvar;
  tree->mod->alpha_old = tree->mod->alpha;
  tree->mod->kappa_old = tree->mod->kappa;
  tree->mod->lambda_old = tree->mod->lambda;
  
  For(i,2*tree->n_otu-3)
    {
      b = tree->t_edges[i];
      b->l_old = b->l;
    }
}

/*********************************************************/

void Update_Bl(arbre *tree, double fact)
{
  int i;
  edge *b;

  For(i,2*tree->n_otu-3)
    {
      b = tree->t_edges[i];
      b->l = b->l_old + (b->ql[0]-b->l_old)*fact;
    }
}

/*********************************************************/

void Make_N_Swap(arbre *tree,edge **b, int beg, int end)
{
  int i;

  tree->n_swap = 0;
  for(i=beg;i<end;i++)
    {
/*       printf("make swap on %3d d->%10f\n",b[i]->num,b[i]->diff_lk); */
/*       if(drand48()>0.75) */
/* 	{ */
	(b[i]->best_conf == 2)?
	  (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v1],tree)):
	  (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v2],tree));
	
	b[i]->l = b[i]->ql[b[i]->best_conf-1];
	tree->n_swap++;
/* 	} */
    }
}

/*********************************************************/

int Make_Best_Swap(arbre *tree)
{
  int i,j,return_value;
  edge *b,**sorted_b;
  

  sorted_b = (edge **)mCalloc(tree->n_otu-3,sizeof(edge *));
  
  j=0;
  For(i,2*tree->n_otu-3) if((!tree->t_edges[i]->left->tax) &&
			    (!tree->t_edges[i]->rght->tax))
                              sorted_b[j++] = tree->t_edges[i];

  Sort_Edges_Diff_Lk(tree,sorted_b,tree->n_otu-3);

  if(sorted_b[0]->diff_lk < -0.0)
    {
      b = sorted_b[0];
      return_value = 1;
      (b->best_conf == 2)?
	(Swap(b->left->v[b->l_v2],b->left,b->rght,b->rght->v[b->r_v1],tree)):
	(Swap(b->left->v[b->l_v2],b->left,b->rght,b->rght->v[b->r_v2],tree));
      
      b->l = b->ql[b->best_conf-1];
    }
  else return_value = 0;

  Free(sorted_b);

  return return_value;
}

/*********************************************************/

int Mov_Backward_Topo_Bl(arbre *tree, double lk_old, edge **tested_b, int n_tested)
{
  double *l_init;
  int i,step,n_swp,beg,end;
  edge *b,**swp;


  l_init = (double *)mCalloc(2*tree->n_otu-3,sizeof(double));
  swp = (edge **)mCalloc(tree->n_otu-3,sizeof(edge *));

  For(i,2*tree->n_otu-3) l_init[i] = tree->t_edges[i]->l;
  
  step = 2;
  tree->both_sides = 0;
  do
    {
      n_swp = 0;
      For(i,2*tree->n_otu-3) 
	{
	  b = tree->t_edges[i];
	  b->l = b->l_old + (1./step) * (l_init[i] - b->l_old);
	}

      beg = (int)floor((double)n_tested/(step-1));
      end = 0;
      Unswap_N_Branch(tree,tested_b,beg,end);
      beg = 0;
      end = (int)floor((double)n_tested/step);
      Swap_N_Branch(tree,tested_b,beg,end);
      
      if(end == n_swp) tree->n_swap = 0;
      
      tree->mod->s_opt->opt_bl = 0;
      tree->both_sides    = 0;
      Lk(tree,tree->data);
      
      step++;

    }while((tree->tot_loglk < lk_old) && (step < 100));


  if(step == 100)
    {
      For(i,2*tree->n_otu-3) 
	{
	  b = tree->t_edges[i];
	  b->l = b->l_old;
	}

      tree->mod->s_opt->opt_bl = 0;
      tree->both_sides    = 0;
      Lk(tree,tree->data);
    }

  Free(l_init);
  Free(swp);

  tree->n_swap = 0;
  For(i,2*tree->n_otu-3) 
    {
      if(tree->t_edges[i]->diff_lk < 0.0) tree->n_swap++;
      tree->t_edges[i]->diff_lk = +1.0;
    }

  if(tree->tot_loglk > lk_old)                 return  1;
  else if((tree->tot_loglk > lk_old-MIN_DIFF_LK) && 
	  (tree->tot_loglk < lk_old+MIN_DIFF_LK)) return -1;
  else                                         return  0;
}

/*********************************************************/

void Unswap_N_Branch(arbre *tree, edge **b, int beg, int end)
{
  int i;
 
  if(end>beg)
    {
      for(i=beg;i<end;i++)
	{
	  (b[i]->best_conf == 2)?
	    (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v1],tree)):
	    (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v2],tree));
	  b[i]->l = b[i]->l_old;
	}
    }
  else
    {
      for(i=beg-1;i>=end;i--)
	{
	  (b[i]->best_conf == 2)?
	    (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v1],tree)):
	    (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v2],tree));
	  b[i]->l = b[i]->l_old;
	}
    }
}

/*********************************************************/

void Swap_N_Branch(arbre *tree,edge **b, int beg, int end)
{
  int i;
  
  if(end>beg)
    {
      for(i=beg;i<end;i++)
	{
	  (b[i]->best_conf == 2)?
	    (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v1],tree)):
	    (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v2],tree));
	  b[i]->l = b[i]->ql[b[i]->best_conf-1];
	}
    }
  else
    {
      for(i=beg-1;i>=end;i--)
	{
	  (b[i]->best_conf == 2)?
	    (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v1],tree)):
	    (Swap(b[i]->left->v[b[i]->l_v2],b[i]->left,b[i]->rght,b[i]->rght->v[b[i]->r_v2],tree));
	  b[i]->l = b[i]->ql[b[i]->best_conf-1];
	}

    }
}

/*********************************************************/
