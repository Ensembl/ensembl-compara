#include <stdlib.h>
#include <assert.h>
#include "tree.h"
#include "utils.h"

Ortholog *tr_alloc_ortho(int n)
{
	 int i;
	 Ortholog *ortho;
	 ortho = (Ortholog*)malloc(sizeof(Ortholog));
	 ortho->n = n;
	 ortho->rel = (short**)malloc(sizeof(short*) * n);
	 ortho->taxon = (TreePtr**)malloc(sizeof(TreePtr*) * n);
	 ortho->is_pseudo = (char**)malloc(sizeof(char*) * n);
	 for (i = 0; i < ortho->n; ++i) {
		  ortho->rel[i] = (short*)calloc(i, sizeof(short));
		  ortho->taxon[i] = (TreePtr*)calloc(i, sizeof(TreePtr));
		  ortho->is_pseudo[i] = (char*)calloc(i, sizeof(TreePtr));
	 }
	 return ortho;
}
void tr_delete_ortho(Ortholog *ortho)
{
	 int i;
	 for (i = 0; i < ortho->n; ++i) {
		  free(ortho->rel[i]);
		  free(ortho->taxon[i]);
		  free(ortho->is_pseudo[i]);
	 }
	 free(ortho->rel);
	 free(ortho->taxon);
	 free(ortho->is_pseudo);
	 free(ortho);
}
void tr_flag_confirmed(Tree *tree, const Tree *spec)
{
	int i, j, k, m, n_leaf;
	Tree **node;
	int **tmp_array;

	if (tree == 0 || spec == 0) return;
	m = (tree->ftime > spec->ftime)? tree->ftime : spec->ftime;
	node = (Tree**)malloc(sizeof(Tree*) * (m + 1));
	/* for species tree */
	m = tr_expand_leaf(spec, node);
	for (i = 0; i < m; ++i) node[i]->flag = i;
	/* for gene tree */
	n_leaf = spec->n_leaf;
	tmp_array = tr_stack(tree, int*);
	m = tr_expand_node(tree, node);
	for (i = 0; i < m; ++i)
		tmp_array[i] = (int*)calloc(n_leaf + 1, sizeof(int));
	for (i = 0; i < m; ++i) {
		Tree *p = node[i];
		int *q = tmp_array[i];
		assert(i == p->ftime);
		if (!SDIptr(p) || !spec(p)) continue;
		if (p->n == 0) { /* external node */
			q[spec(p)->flag] = 1;
		} else {
			int c1, c2, *r;
			SDIptr(p)->is_confirmed_dup = 0;
			for (j = 0; j < p->n; ++j) {
				r = tmp_array[p->node[j]->ftime];
				for (k = 0; k < n_leaf; ++k) {
					if (r[k] && q[k]) SDIptr(p)->is_confirmed_dup = 1;
					else if (r[k]) q[k] = 1;
				}
			}
			/* only consider binary trees */
			q = tmp_array[p->node[0]->ftime];
			r = tmp_array[p->node[1]->ftime];
			c1 = c2 = 0;
			for (k = 0; k < n_leaf; ++k) {
				if (q[k] && r[k]) ++c1;
				if (q[k] || r[k]) ++c2;
			}
			SDIptr(p)->sis = (int)(100.0 * c1 / c2 + 0.5);
	 	}
	}
	for (i = 0; i < m; ++i)
		free(tmp_array[i]);
	free(tmp_array);
	free(node);
}
void tr_ortho_aux(Tree *tree, int is_pseudo)
{
	int i, m;
	Tree **node;
	SDIinfo *s;

	if (tree == 0) return;
	node = tr_stack(tree, Tree*);
	m = tr_expand_internal_node(tree, node);
	for (i = 0; i < m; ++i) {
		s = SDIptr(node[i]);
		node[i]->flag = (s->type == 'S')? 1 : 0;
		if (is_pseudo && s->type == 'D' && !s->is_confirmed_dup)
			node[i]->flag = 2;
	}
	free(node);
}
Ortholog *tr_ortho(Tree *tree, const Tree *spec, int is_pseudo)
{
	int i, j;
	int n_tree_leaf;
	Tree **tree_leaf;
	Tree *p, *q;
	Ortholog *ortho;

	if (tree == 0 || spec == 0) return 0;

	n_tree_leaf = tree->n_leaf;
	ortho = tr_alloc_ortho(n_tree_leaf);
	tree_leaf = (Tree**)calloc(n_tree_leaf, sizeof(Tree*));
	tr_expand_leaf_by_id(tree, tree_leaf);
	tr_ortho_aux(tree, is_pseudo); /* set Tree::flag */

	for (i = 0; i < n_tree_leaf; ++i) {
		if (spec(tree_leaf[i]) == 0) continue;
		for (j = 0; j < i; ++j) { /* here is O(N^2) */
			if (spec(tree_leaf[j]) == 0) continue;
			p = tree_leaf[i];
			q = tree_leaf[j];
			while (p->ftime != q->ftime) { /* find last common ancestor */
				if (p->ftime < q->ftime) p = p->pre;
				else if (p->ftime > q->ftime) q = q->pre;
			}
			/* now, p == q is the LCA */
			if (p->flag || spec(tree_leaf[i]) == spec(tree_leaf[j])) { /* ortholog OR within-species paralog */
				ortho->rel[i][j] = 1;
				ortho->taxon[i][j] = spec(p);
				ortho->is_pseudo[i][j] = (char)p->flag;
			}
		}
	}
	free(tree_leaf);
	return ortho;
}
void tr_comp_ortho(Ortholog *ori, const Ortholog *bs)
{
	 int i, j;
	 short *p, *q;
	 for (i = 0; i < ori->n; ++i) {
		  p = ori->rel[i];
		  q = bs->rel[i];
		  for (j = 0; j < i; ++j)
			   if (p[j] && q[j]) ++p[j];
	 }
}
