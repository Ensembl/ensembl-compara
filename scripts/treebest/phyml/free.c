/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#include "utilities.h"
#include "free.h"

/*********************************************************/

void Free_All_Nodes_Light(arbre *tree)
{
  int i;
  For(i,2*tree->n_otu-2) 
    Free_Node(tree->noeud[i]);
}

/*********************************************************/

void Free_All_Edges_Light(arbre *tree)
{
  int i;
  For(i,2*tree->n_otu-3) 
    if(tree->t_edges[i])
      Free_Edge(tree->t_edges[i]);
}


/*********************************************************/

void Free_Mat(matrix *mat)
{
  int i;

  For(i,mat->n_otu)
    {
      Free(mat->P[i]);
      Free(mat->Q[i]);
      Free(mat->dist[i]);
      Free(mat->name[i]);
    }

  Free(mat->P);
  Free(mat->Q);
  Free(mat->dist);
  Free(mat->name);
  Free(mat->tip_node);
      
  Free(mat->on_off);
  Free(mat);
}

/*********************************************************/

void Free_Partial_Lk(double ****p_lk, int len, int n_catg)
{
  int i,j;

  For(i,len)
    {
      For(j,n_catg) Free((*p_lk)[i][j]);
      Free((*p_lk)[i]);
    }
  Free((*p_lk));
  (*p_lk) = NULL;
}

/*********************************************************/

void Free_Tree(arbre *tree)
{
  int i,j,k;
  edge *b;
  node *n;


  if(tree->has_bip)
    {
      For(i,2*tree->n_otu-2)
	{
	  Free(tree->noeud[i]->bip_size);
	  For(j,3)
	    {
	      Free(tree->noeud[i]->bip_node[j]);
	      For(k,tree->n_otu) Free(tree->noeud[i]->bip_name[j][k]);
	      Free(tree->noeud[i]->bip_name[j]);
	    }
	  Free(tree->noeud[i]->bip_node);
	  Free(tree->noeud[i]->bip_name);
	}
    }

  For(i,2*tree->n_otu-3)
    {
      b = tree->t_edges[i];
      Free_Edge(b);
    }
  Free(tree->t_edges);


  For(i,2*tree->n_otu-2)
    {
      n = tree->noeud[i];
      Free_Node(n);
    }
  Free(tree->noeud);

  Free(tree);
}

/*********************************************************/

void Free_Edge(edge *b)
{
  Free(b);
}

/*********************************************************/

void Free_Node(node *n)
{
  Free(n->b);
  Free(n->v);
  Free(n->l);
  Free(n->score);
  Free(n->name);
/*   Free(n->n_ex_nodes); */
  Free(n);
}

/*********************************************************/

void Free_Cseq(allseq *data)
{
  int i;
  
  Free(data->invar);
  Free(data->wght);
  Free(data->factw);
  Free(data->ambigu);
  Free(data->b_frq);
  Free(data->sitepatt);
  For(i,data->n_otu)
    {
      Free(data->c_seq[i]->name);
      Free(data->c_seq[i]->state);
      Free(data->c_seq[i]);
    }
  Free(data->c_seq);
  Free(data);
}

/*********************************************************/

void Free_Seq(seq **d, int n_otu)
{
  int i;
  For(i,n_otu)
    {
      Free(d[i]->name);
      Free(d[i]->state);
      Free(d[i]);
    }
  Free(d);
}


/*********************************************************/

void Free_All(seq **d, allseq *alldata, arbre *tree)
{
  Free_Cseq(alldata);
  Free_Seq(d,tree->n_otu);
  Free_Tree(tree);
}      

/*********************************************************/
void Free_SubTree(edge *b_fcus, node *a, node *d, arbre *tree)
{
  int i;

  if(d->tax) return;
  else
    {
      For(i,3)
	{
	  if(d->v[i] != a)
	    {
	      Free_SubTree(d->b[i],d,d->v[i],tree);
	      Free_Edge(d->b[i]);
	      Free_Node(d->v[i]);
	    }
	}
    }
}

/*********************************************************/
void Free_Tree_Ins_Tar(arbre *tree)
{
  return;
}

/*********************************************************/

void Free_Tree_Lk(arbre *tree)
{
  int i;
  edge *b;
  node *n;

  b = NULL;
  n = NULL;

  Free(tree->tot_loglk_sorted);
  Free(tree->tot_dloglk);
  Free(tree->tot_d2loglk);
  Free(tree->t_best_l);
  Free(tree->site_lk);
  if(tree->p_lk) Free(tree->p_lk);

  For(i,2*tree->n_otu-3)
    {
      b = tree->t_edges[i];
      
      Free_Edge_Lk(tree,b);

    }
}


/*********************************************************/

void Free_dPij(arbre *tree)
{
  int i,j,k;

  For(i,2*tree->n_otu-3)
    {
      For(j,tree->mod->n_catg)
	{
	  For(k,tree->mod->ns)
	    {
	      Free(tree->t_edges[i]->dPij_rr[j][k]);
	      Free(tree->t_edges[i]->d2Pij_rr[j][k]);
	    }
	  Free(tree->t_edges[i]->dPij_rr[j]);
	  Free(tree->t_edges[i]->d2Pij_rr[j]);
	}
      Free(tree->t_edges[i]->dPij_rr);
      Free(tree->t_edges[i]->d2Pij_rr);
      tree->t_edges[i]->dPij_rr = NULL;
      tree->t_edges[i]->d2Pij_rr = NULL;
    }
}

/*********************************************************/

void Free_Edge_P_Lk_Struct(edge *b, arbre *tree)
{
  int i,j;

  if(b->p_lk_left) 
    {
      For(i,tree->data->crunch_len)
	{
	  For(j,tree->mod->n_catg) Free(b->p_lk_left[i][j]);
	  Free(b->p_lk_left[i]);
	}
      Free(b->p_lk_left);
      b->p_lk_left = NULL;
    }

  if(b->p_lk_rght) 
    {
      For(i,tree->data->crunch_len)
	{
	  For(j,tree->mod->n_catg) Free(b->p_lk_rght[i][j]);
	  Free(b->p_lk_rght[i]);
	}
      Free(b->p_lk_rght);
      b->p_lk_rght = NULL;
    }
}

/*********************************************************/

void Free_Node_Lk(node *n)
{
/*   Free(n->n_ex_nodes); */
}

/*********************************************************/

void Free_Edge_Lk(arbre *tree, edge *b)
{
  int i,j;

  Free(b->ql);

  if(b->p_lk_left)
    {
      For(i,tree->data->crunch_len)
	{
	  For(j,tree->mod->n_catg)
	    {
	      Free(b->p_lk_left[i][j]);
	    }
	  Free(b->p_lk_left[i]);
	}
      Free(b->p_lk_left);
      Free(b->sum_scale_f_left);
    }

  if(b->p_lk_rght)
    {
      For(i,tree->data->crunch_len)
	{
	  For(j,tree->mod->n_catg)
	    {
	      Free(b->p_lk_rght[i][j]);
	    }
	  Free(b->p_lk_rght[i]);
	}
      Free(b->p_lk_rght);
      Free(b->sum_scale_f_rght);
    }

  For(i,tree->mod->n_catg)
    {
      For(j,tree->mod->ns)
	{
	  Free(b->Pij_rr[i][j]);
	  Free(b->dPij_rr[i][j]);
	  Free(b->d2Pij_rr[i][j]);
	}

      Free(b->Pij_rr[i]);
      Free(b->dPij_rr[i]);
      Free(b->d2Pij_rr[i]);
      Free(b->site_p_lk_left[i]);
      Free(b->site_p_lk_rght[i]);     
    }
  Free(b->Pij_rr);
  Free(b->dPij_rr);
  Free(b->d2Pij_rr);
  Free(b->site_p_lk_left);
  Free(b->site_p_lk_rght);
  Free(b->site_dlk_rr);
  Free(b->site_d2lk_rr);
}

/*********************************************************/

void Free_Model(model *mod)
{
  int i,j;

  Free(mod->custom_mod_string);
  Free(mod->user_b_freq);
  For(i,6)
    Free(mod->rr_param_num[i]);
  Free(mod->rr_param_num);
  Free(mod->rr_param);
  Free(mod->rr_param_values);
  Free(mod->n_rr_param_per_cat);
  Free(mod->s_opt);
  Free(mod->pi);
  Free(mod->r_proba);
  Free(mod->rr);

  Free(mod->mat_Q);
  Free(mod->mat_Vr);
  Free(mod->mat_Vi);
  Free(mod->vct_eDmr);
  Free(mod->vct_ev);

  For(i,mod->n_catg)
    {
      For(j,mod->ns) Free(mod->Pij_rr[i][j]);
      Free(mod->Pij_rr[i]);
    }
  Free(mod->Pij_rr);
  For(i,mod->n_catg)
    {
      For(j,mod->ns) Free(mod->dPij_rr[i][j]);
      Free(mod->dPij_rr[i]);
    }
  Free(mod->dPij_rr);
  For(i,mod->n_catg)
    {
      For(j,mod->ns) Free(mod->d2Pij_rr[i][j]);
      Free(mod->d2Pij_rr[i]);
    }
  Free(mod->d2Pij_rr);

  Free(mod);
}

/*********************************************************/

void Free(void *p)
{
  free(p);
}

/*********************************************************/

void Free_Input(option *input)
{
  Free(input->seqfile);
  Free(input->modelname);
  Free(input->inputtreefile);
  Free(input->phyml_stat_file);
  Free(input->phyml_tree_file);
  Free(input->phyml_lk_file);
  Free(input->nt_or_cd);
  Free(input);
}

/*********************************************************/

