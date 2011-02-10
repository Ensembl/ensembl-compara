#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tree.h"
#include "cpp_utils.h"
#include "utils.h"

Tree *tr_nj(Matrix *mat, int n_cons, Tree **ori_constraint, int init_cons)
{
	Tree **node, *p;
	int is_bin = 1;
	int i, j, m;

	assert(mat);
	if (init_cons == 0) is_bin = 0;
	if (n_cons && is_bin) {
		for (i = 0; i < n_cons; ++i) {
			node = tr_stack(ori_constraint[i], Tree*);
			m = tr_expand_internal_node(ori_constraint[i], node);
			for (j = 0; j < m-1; ++j) {
				p = node[j];
				if (p->n > 2 || (p->name && strstr(p->name, "{P}"))) break;
			}
			if (j != m-1 || node[j]->n > 3) is_bin = 0;
			free(node);
			if (is_bin == 0) break;
		}
	}
	if (is_bin) p = tr_nj_binary(mat, n_cons, ori_constraint, init_cons);
	else {
		/* if (n_cons) fprintf(stderr, "<tr_nj> constrained tree contains multifurcated nodes.\n"); */
		p = tr_nj_rooted(mat, n_cons, ori_constraint, init_cons);
	}
	return p;
}

/** \file nj2.c
 * \brief Tree builder by constrained neighbour-Joining.
 *
 * The basic idea is to disallow illegal merge in each round joining, but how
 * to achieve this goal? Here is the answer that does not increase time- and
 * space-complexity.
 */

/* structure of branch_matrix:
 * first row:
 * 		[0..n-1]: leaves that appear in the constrained tree(s);
 * following rows:
 * 		[0..n-1]: bipartition, 1 and 2. 0 stands for irrelevant nodes.
 * 		[n]: number of "1"
 * 		[n+1]: number of "2"
 */
static char **nj_gen_branch_matrix(Matrix *mat, int init_cons, int n_cons, Tree **ori_cons, int *m)
{
	extern Tree *tr_pre_cons(Tree *cons, int init_cons);
	int m_row, max_row, n;
	int i, j, k, l;
	char **branch_matrix;
	Tree **node, **leaf, *p;

	assert(mat);
	n = mat->count;
	node = (Tree**)malloc(sizeof(Tree*) * 2 * n);
	leaf = (Tree**)malloc(sizeof(Tree*) * n);

	/* prepare the first row which stores the leaves that are constrained. */
	max_row = 64;
	m_row = 0;
	branch_matrix = (char**)malloc(sizeof(char*) * max_row);
	branch_matrix[m_row++] = malloc(sizeof(char) * (n+2));
	for (k = 0; k < n+2; ++k) branch_matrix[0][k] = 0;

	for (i = 0; i < n_cons; ++i) {
		Tree *cons, *tmp_tree;
		int t;

		if (ori_cons[i] == 0) continue;
		/* pre-process the constrained tree */
		cons = cpp_subtree(ori_cons[i], n, mat->name);
		tr_clear_ptr(cons);
		tmp_tree = cpp_check_tree(cons); /* constraint[i] will be deleted here if duplicated leaves are removed. */
		cons = tr_pre_cons(tmp_tree, init_cons);
		tr_delete_tree(tmp_tree);
		cpp_attach_id_by_name(cons, n, mat->name);
		/* core code */
		t = tr_expand_node(cons, node);
		for (k = 0; k < n; ++k) leaf[k] = 0;
		tr_expand_leaf_by_id(cons, leaf);
		for (j = 0; j < t; ++j) {
			char *tmp_array, *array = (char*)malloc(sizeof(char) * (n+2));
			for (k = 0; k < n; ++k)
				array[k] = (leaf[k])? 1 : 0;
			p = node[j];
			p->ptr = array;
			if (p->n == 0) {
				array[p->id] = 2;
				array[n] = cons->n_leaf - 1;
				array[n+1] = 1;
				branch_matrix[0][p->id] = 1;
			} else {
				int sum = 0;
				for (l = 0; l < p->n; ++l) {
					tmp_array = (char*)p->node[l]->ptr;
					sum += tmp_array[n+1];
					for (k = 0; k < n; ++k)
						if (tmp_array[k] == 2) array[k] = 2;
				}
				array[n] = cons->n_leaf - sum;
				array[n+1] = sum;
			}
			if (max_row == m_row) {
				max_row += 64;
				branch_matrix = (char**)realloc(branch_matrix, sizeof(char*) * max_row);
			}
			branch_matrix[m_row++] = array;
		}
		for (j = 0; j < t; ++j)
			node[j]->ptr = 0;
		tr_delete_tree(cons);
	}
	free(node); free(leaf);
	*m = m_row;
	return branch_matrix;
}
/* actually, flag might not be quite necessary. Nonetheless, to use a flag is clearer. */
static void nj_gen_cons_matrix(int n, int flag, int m, char **branch_matrix, int *cons_matrix)
{
	int i, k;
	char *array;
	for (i = 1; i < m; ++i) {
		array = branch_matrix[i];
		if (array == 0) continue;
		if (array[n] == 2 || array[n+1] == 2) {
			int i1, i2, tmp;
			i1 = i2 = -1;
			tmp = (array[n] == 2)? 1 : 2;
			for (k = 0; k < n; ++k) {
				if (array[k] == tmp) {
					if (i1 < 0) i1 = k;
					else i2 = k;
				}
			}
			cons_matrix[i1*n+i2] = cons_matrix[i2*n+i1] = flag;
		}
	}
}
static int nj_modify_branch_matrix(int mi, int mj, int n, int m, char **branch_matrix)
{
	int i, ret_val;
	char *array, *first;
	first = branch_matrix[0];
	ret_val = -1;
	if (first[mi] == 0 && first[mj] == 0) return -1;
	if (first[mj]) {
		for (i = 1; i < m; ++i) {
			array = branch_matrix[i];
			if (array[mj]) { /* 1 or 2 */
				int tmp = array[mj];
				if (array[mi] == tmp && array[n+tmp-1] == 2) ret_val = i;
				if (first[mi]) --array[n+tmp-1];
				else array[mi] = tmp;
				array[mj] = 0;
			}
		}
		first[mi] = 1;
	}
	return ret_val;
}
static Tree *nj_few_leaves(Matrix *mat)
{
	int i, n;
	Tree *p, *q;

	assert(mat);
	n = mat->count;
	p = 0;
	if (n == 1) {
		p = tr_new_node();
		p->name = cpystr(mat->name[0]);
		p->id = 0;
		tr_tree_init(p);
		return p;
	} else if (n == 2) {
		p = tr_new_node();
		p->n = 2;
		p->node = (Tree**)realloc(p->node, sizeof(Tree*) * 2);
		p->node[0] = tr_new_node();
		p->node[1] = tr_new_node();
		for (i = 0; i < 2; ++i) {
			q = p->node[i];
			q->name = cpystr(mat->name[i]);
			q->d = 0.5 * mat->dist[1];
			q->pre = p;
			q->id = i;
		}
		tr_tree_init(p);
		return p;
	}
	return p;
}
/** \fn Tree *tr_nj2(Matrix *mat, int n_cons, Tree **ori_constraint, int init_cons)
 *  \brief Constrained Neighbour-joining
 *  \param mat Symmetric distance matrix.
 *  \param n_cons Number of constraints.
 *  \param ori_constraint Constrained trees.
 *  \param init_cons Whether apply constraint on the root node. It works only when n_cons > 0
 *
 *  If n_cons == 0, this function performs classical neighbour-joining.
 *  
 *  When n_cons > 0, it first pre-processes the constraints by calling
 *  tr_pre_cons() to make multifurcation at nodes labeled by {P}, and then
 *  builds a tree constrained by the given constraint(s). Each branch of the
 *  resultant tree will be supported by constraints. The time complexity of
 *  constrained neighbour-joining is O(N^3), the same as the original algorithm.
 */
Tree *tr_nj_binary(Matrix *mat, int n_cons, Tree **ori_constraint, int init_cons)
{
	float *sum, *r, *x1;
	Tree **array, *p;
	int n, i, j, l, mi, mj;
	float x2, x3, x4, min, *dist;
	int m_row, *cons_matrix;
	char **branch_matrix, *first_row;

	assert(mat);
	if (n_cons) assert(ori_constraint);
	if (mat->count == 0) {
		fprintf(stderr, "[tr_nj_binary] null distance matrix!\n");
		return 0;
	}
	n = mat->count;
	if (n < 3) return nj_few_leaves(mat);
	/* allocation */
	n = mat->count; /* number of nodes */
	mi = mj = -1; /* useless. just to avoid a compiling warning */
	if (n <= 2) return 0; /* no need to construct a tree */
	r = (float*)malloc(sizeof(float) * n); /* r array */
	sum = (float*)malloc(sizeof(float) * n); /* sum array. r = sum / (|L|-2) */
	array = (Tree**)malloc(sizeof(Tree*) * n); /* where the resultant tree grows */
	for (i = 0; i < n; ++i) { /* fill array */
		p = array[i] = tr_new_node(); /* leaf nodes of the resultant tree */
		p->name = (char*)malloc(sizeof(char) * (strlen(mat->name[i]) + 1));
		strcpy(p->name, mat->name[i]);
		p->id = i;
	}
	dist = mat->dist;

	/* initialization O(N^2) */
	branch_matrix = 0; m_row = 0;
	cons_matrix = 0;
	first_row = 0;
	if (n_cons) {
		cons_matrix = (int*)malloc(sizeof(int) * n * n);
		for (i = 0; i < n * n; ++i) cons_matrix[i] = 0;
		branch_matrix = nj_gen_branch_matrix(mat, init_cons, n_cons, ori_constraint, &m_row);
		first_row = branch_matrix[0];
	}

	for (i = 0; i < n; ++i) { /* initilize the sum array */
		x1 = dist + i * n;
		for (j = 0, x2 = 0.0; j < n; ++j)
			x2 += x1[j];
		sum[i] = x2;
	}

	/* core loop */
	for (l = n; l > 2; --l) {
		/* calculate r_i, O(N) */
		for (i = 0; i < n; ++i)
			if (array[i]) r[i] = sum[i] / (l-2);

		/* find minial D_ij, O(N^2) */
		if (n_cons)
			nj_gen_cons_matrix(n, l, m_row, branch_matrix, cons_matrix);
		min = 1e30; mi = mj = -1;
		for (j = 0; j < n; ++j) {
			if (!array[j]) continue;
			x1 = dist + j * n;
			x2 = r[j];
			if (n_cons && first_row[j]) { /* constrained */
				int *tmp = cons_matrix + j*n;
				for (i = 0; i < j; ++i) { /* i<j */
					if (array[i] && x1[i] - x2 - r[i] < min) {
						if (!first_row[i] || tmp[i] == l) {
							mi = i; mj = j; min = x1[i] - x2 - r[i];
						}
					}
				}
			} else {
				for (i = 0; i < j; ++i) { /* i<j */
					if (array[i] && x1[i] - x2 - r[i] < min) { /* unlinked && minimal */
						mi = i; mj = j; min = x1[i] - x2 - r[i];
					}
				}
			}
		}
		if (mi < 0) {
			fprintf(stderr, "[tr_nj_binary] conflict constraints! stop at l=%d\n", l);
			return 0;
		}
		x2 = dist[mi * n + mj];

		/* add node to the final tree, O(1)*/
		x3 = 0.5 * (x2 + r[mi] - r[mj]); /* d_ik */
		x4 = x2 - x3;
		p = tr_new_node();
		p->n = 2;
		p->node = (Tree**)malloc(sizeof(Tree*) * 2);
		array[mi]->pre = array[mj]->pre = p; /* set parents */
		array[mi]->d = x3;
		array[mj]->d = x4;
		if (x3 < 0.0) { /* adjust for negative branch length. see QUICKTREE */
			array[mi]->d = 0.0;
			array[mj]->d = x2;
			if (x2 < 0.0) array[mj]->d = 0.0;
		} else if (x4 < 0.0) {
			array[mi]->d = x2;
			array[mj]->d = 0.0;
			if (x2 < 0.0) array[mi]->d = 0.0;
		}
		p->node[0] = array[mi]; /* join */
		p->node[1] = array[mj];
		array[mj] = 0; /* eliminate the larger node */
		array[mi] = p; /* replaced as new node */

		/* update constraint, and write is_cons tag for p (default is 0, not constrained). */
		if (n_cons) {
			if (cons_matrix[mi*n+mj] == l) p->is_cons = 1;
			nj_modify_branch_matrix(mi, mj, n, m_row, branch_matrix);
		}

		/* update dist and sum, O(N) */
		for (i = 0, x4 = 0.0; i < n; ++i) {
			if (!array[i] || i == mi) continue;
			x1 = dist + i * n;
			x3 = 0.5 * (x1[mi] + x1[mj] - x2); /* d_km */
			x4 += x3; /* calculate sum[mi] */
			sum[i] += x3 - x1[mi] - x1[mj];
			dist[mi * n + i] = x1[mi] = x3; /* set d_km */
		}
		sum[mi] = x4;
	}
	
	/* merge the last trifurcated node */
	for (i = 1; i < n; ++i)
		if (array[i]) break;
	/* Here, the method in removing negative length is different from QUICKTREE.
	 * However, I think that that is unimportant.
	 */
	if (dist[i] < 0.0) dist[i] = 0.0;
	if (mi == 0) {
		p = array[0];
		p->n = 3;
		p->node = (Tree**)realloc(p->node, sizeof(Tree*) * 3);
		p->node[2] = array[i];
		array[i]->d = dist[i];
		array[i]->pre = p;
	} else {
		p = array[i];
		p->n = 3;
		p->node = (Tree**)realloc(p->node, sizeof(Tree*) * 3);
		p->node[2] = p->node[1];
		p->node[1] = p->node[0];
		p->node[0] = array[0];
		array[0]->d = dist[i];
		array[0]->pre = p;
	}
	
	/* free */
	free(array); free(sum); free(r);
	if (n_cons) {
		for (i = 0; i < m_row; ++i)
			if (branch_matrix[i]) free(branch_matrix[i]);
		free(branch_matrix);
		free(cons_matrix);
	}

	tr_tree_init(p); /* id has already been attached */
	return p;
}
/*
 * put each leaf node of the root tree into the corresponding leaf array
 * BE SURE that each node in root tree exist exact only once in mat->name!!!
 *
 * This function is only used in tr_nj() because it will modify Tree::flag.
 */
static void nj_expand_leaf_by_id(Tree *root, Tree **leaf)
{
	Tree *p, **q, **list;
	int j;

	if (root == 0) return;
	assert(leaf);
	list = tr_stack(root, Tree*); /* DFS stack */
	q = list;
	*q++ = root; /* push */
	while (q != list) {
		--q; /* pop */
		(*q)->flag = (*q)->n; /* flag will be modified in tr_nj() */
		if ((*q)->n == 0 && (*q)->id >= 0) /* leaf node && exist in mat->name */
			leaf[(*q)->id] = *q;
		for (j = 0, p = *q; j < p->n; ++j)
			*q++ = p->node[j];
	}
	free(list);
}
/** \fn Tree *tr_nj_rooted(Matrix *mat, int n_cons, Tree **ori_constraint, int init_cons)
 *  \brief Constrained Neighbour-joining
 *  \param mat Symmetric distance matrix.
 *  \param n_cons Number of constraints.
 *  \param ori_constraint Constrained trees.
 *  \param init_cons Whether apply constraint on the root node. It works only when n_cons > 0
 *
 *  If n_cons == 0, this function performs classical neighbour-joining.
 *  
 *  When n_cons > 0, it first pre-processes the constraints by calling
 *  tr_pre_cons() to make multifurcation at nodes labeled by {P}, and then
 *  builds a tree constrained by the given constraint(s). Each branch of the
 *  resultant tree will be supported by constraints. The time complexity of
 *  constrained neighbour-joining is O(N^3), the same as the original algorithm.
 */
Tree *tr_nj_rooted(Matrix *mat, int n_cons, Tree **ori_constraint, int init_cons)
{
	float *sum, *r, *x1;
	Tree **array, **leaf, *p;
	Tree **constraint;
	int n, i, j, l, mi, mj;
	float x2, x3, x4, min, *dist;
	extern Tree *tr_pre_cons(Tree *cons, int init_cons);

	assert(mat);
	if (n_cons) assert(ori_constraint);
	if (mat->count == 0) {
		fprintf(stderr, "[tr_nj_rooted] null distance matrix!\n");
		return 0;
	}
	n = mat->count; /* number of nodes */
	if (n < 3) return nj_few_leaves(mat);

	/* allocation */
	mi = mj = -1; /* useless. just to avoid a compiling warning */
	if (n <= 2) return 0; /* no need to construct a tree */
	r = (float*)malloc(sizeof(float) * n); /* r array */
	sum = (float*)malloc(sizeof(float) * n); /* sum array. r = sum / (|L|-2) */
	leaf = (Tree**)malloc(sizeof(Tree*) * n); /* leaf array for constrained tree(s) */
	array = (Tree**)malloc(sizeof(Tree*) * n); /* where the resultant tree grows */
	for (i = 0; i < n; ++i) { /* fill array */
		leaf[i] = 0;
		p = array[i] = tr_new_node(); /* leaf nodes of the resultant tree */
		p->name = (char*)malloc(sizeof(char) * (strlen(mat->name[i]) + 1));
		strcpy(p->name, mat->name[i]);
		p->id = i;
	}
	dist = mat->dist;
	/* initialize constrained tree */
	constraint = 0;
	if (n_cons > 0)
		constraint = (Tree**)malloc(sizeof(Tree*) * n_cons);
	for (i = 0; i < n_cons; ++i) {
		/* attach id to constrained forest */
		Tree *tmp_tree;
		constraint[i] = 0;
		if (ori_constraint[i] == 0) continue;
		constraint[i] = cpp_subtree(ori_constraint[i], n, mat->name);
		tmp_tree = cpp_check_tree(constraint[i]); /* constraint[i] will be deleted here if duplicated leaves are removed. */
		constraint[i] = tr_pre_cons(tmp_tree, init_cons);
		tr_delete_tree(tmp_tree);
		cpp_attach_id_by_name(constraint[i], n, mat->name);
		nj_expand_leaf_by_id(constraint[i], leaf);
	}

	/* other initialization O(N^2) */
	for (i = 0; i < n; ++i) { /* initilize the sum array */
		x1 = dist + i * n;
		for (j = 0, x2 = 0.0; j < n; ++j)
			x2 += x1[j];
		sum[i] = x2;
	}

	/* core loop */
	for (l = n; l > 2; --l) {
		/* calculate r_i, O(N) */
		for (i = 0; i < n; ++i)
			if (array[i]) r[i] = sum[i] / (l-2);

		/* find minial D_ij, O(N^2) */
		min = 1e30; mi = mj = -1;
		for (j = 0; j < n; ++j) {
			if (!array[j]) continue;
			x1 = dist + j * n;
			x2 = r[j];
			if (!(p = leaf[j])) { /* free leaf, no constraint */
				for (i = 0; i < j; ++i) { /* i<j */
					if (array[i] && x1[i] - x2 - r[i] < min) { /* unlinked && minimal */
						mi = i; mj = j; min = x1[i] - x2 - r[i];
					}
				}
			} else if (constraint) {
				for (i = 0; i < j; ++i) { /* i<j */
					if (array[i] && x1[i] - x2 - r[i] < min) {
						/* not exist in constraint || have a direct common ancester */
						if (!leaf[i] || p->pre == leaf[i]->pre) {
							mi = i; mj = j; min = x1[i] - x2 - r[i];
						}
					}
				}
			}
		}
		if (mi < 0) {
			fprintf(stderr, "[tr_nj_rooted] conflict constraints! stop at l=%d\n", l);
			return 0;
		}
		x2 = dist[mi * n + mj];

		/* add node to the final tree, O(1)*/
		x3 = 0.5 * (x2 + r[mi] - r[mj]); /* d_ik */
		x4 = x2 - x3;
		p = tr_new_node();
		p->n = 2;
		p->node = (Tree**)malloc(sizeof(Tree*) * 2);
		array[mi]->pre = array[mj]->pre = p; /* set parents */
		array[mi]->d = x3;
		array[mj]->d = x4;
		if (x3 < 0.0) { /* adjust for negative branch length. see QUICKTREE */
			array[mi]->d = 0.0;
			array[mj]->d = x2;
			if (x2 < 0.0) array[mj]->d = 0.0;
		} else if (x4 < 0.0) {
			array[mi]->d = x2;
			array[mj]->d = 0.0;
			if (x2 < 0.0) array[mi]->d = 0.0;
		}
		p->node[0] = array[mi]; /* join */
		p->node[1] = array[mj];
		array[mj] = 0; /* eliminate the larger node */
		array[mi] = p; /* replaced as new node */

		/* update constraint, and write is_cons tag for p (default is 0, not constrained). */
		if (leaf[mi] && leaf[mj]) { /* constrained merge */
			if (leaf[mi]->pre->flag == 2) { /* only two nodes remained */
				leaf[mi] = leaf[mi]->pre; /* set the constrained node as the parent */
				p->is_cons = 1; /* the new node is constrained */
				if (leaf[mi]->name) { /* this constrained (internal) node has a name */
					p->name = (char*)malloc(sizeof(char) * (strlen(leaf[mi]->name) + 1));
					strcpy(p->name, leaf[mi]->name);
				}
			} else --(leaf[mi]->pre->flag); /* reduce one node */
		} else if (leaf[mi] == 0) leaf[mi] = leaf[mj];

		/* update dist and sum, O(N) */
		for (i = 0, x4 = 0.0; i < n; ++i) {
			if (!array[i] || i == mi) continue;
			x1 = dist + i * n;
			x3 = 0.5 * (x1[mi] + x1[mj] - x2); /* d_km */
			x4 += x3; /* calculate sum[mi] */
			sum[i] += x3 - x1[mi] - x1[mj];
			dist[mi * n + i] = x1[mi] = x3; /* set d_km */
		}
		sum[mi] = x4;
	}
	
	/* merge the last two nodes */
	for (i = 1; i < n; ++i)
		if (array[i]) break;
	/* Here, the method in removing negative length is different from QUICKTREE.
	 * However, I think that that is unimportant.
	 */
	if (dist[i] < 0.0) dist[i] = 0.0;
	if (leaf[0] && leaf[i]) { /* the last constraint, rooted tree */
		p = tr_new_node();
		p->n = 2;
		p->node = (Tree**)malloc(sizeof(Tree*) * 2);
		p->node[0] = array[0];
		p->node[1] = array[i];
		p->is_cons = 1; /* constrained */
		array[0]->d = array[i]->d = dist[i] / 2.0;
		array[0]->pre = array[i]->pre = p;
	} else { /* otherwise, unrooted */
		if (mi == 0) {
			p = array[0];
			p->n = 3;
			p->node = (Tree**)realloc(p->node, sizeof(Tree*) * 3);
			p->node[2] = array[i];
			array[i]->d = dist[i];
			array[i]->pre = p;
		} else {
			p = array[i];
			p->n = 3;
			p->node = (Tree**)realloc(p->node, sizeof(Tree*) * 3);
			p->node[2] = p->node[1];
			p->node[1] = p->node[0];
			p->node[0] = array[0];
			array[0]->d = dist[i];
			array[0]->pre = p;
		}
	}
	
	/* free */
	free(array); free(leaf); free(sum); free(r);
	if (constraint) {
		for (i = 0; i < n_cons; ++i)
			tr_delete_tree(constraint[i]);
		free(constraint);
	}
	tr_tree_init(p); /* id has already been attached */
	return p;
}
