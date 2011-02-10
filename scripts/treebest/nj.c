#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tree.h"
#include "cpp_utils.h"
#include "utils.h"

/** \file nj.c
 * \brief Utilities for the calculation of bootstrap values.
 *
 * This file also contains utilities for calculating bootstrap values. The use of
 * hash idea accelerate the calculation by far. Constrained NJ has been moved to
 * file nj2.c.
 */

/** \fn void tr_pre_bootstrap(Tree *tree, int is_node)
 *  \brief Fill Tree::ptr array and prepare for bootstrapping comparison.
 *  \param tree Binary tree to be processed.
 *  \param is_node Mode. 0 for the conventional branch mode and 1 for node mode.
 *
 *  This function will fill tree::ptr as a integer array, storing the leaves
 *  a node covers. It will also calculate a magic number for each array to
 *  accelerate the array comparison in tr_update_bootstrap(). The time
 *  complexity is O(N^2).
 *
 *  Note that this function, not like tr_compare_core() or tr_mmerge(), will
 *  not backup Tree::ptr. Any information ptr points to will be lost.
 */
void tr_pre_bootstrap(Tree *tree, int is_node)
{
	Tree **node;
	int m, i, j, l, n;
	int magic, c;
	int magica[3], ca[3], key0;
	int *r, *q;
	Tree *p;

	if (tree == 0) return;
	n = tree->n_leaf;
	node = (Tree**)malloc(sizeof(Tree*) * n);
	for (i = 0, key0 = 0; i < n; ++i) key0 ^= i;
	m = tr_expand_internal_node(tree, node);

	/* O(N^2) */
	for (i = 0; i < m; ++i) {
		p = node[i];
		p->bs = 0; /* counter */
		q = (int*)malloc(sizeof(int) * (n + 1));
		p->ptr = q;
		for (j = 0; j < n; ++j) q[j] = 0;
		for (l = 0; l < 2; ++l) { /* only the first two nodes are handled */
			magic = c = 0;
			if (p->node[l]->n == 0) {
				magic ^= p->node[l]->id;
				++c;
				q[p->node[l]->id] = l + 1; /* i.e. 1 for l=0 and 2 for l=1 */
			} else {
				r = (int*)p->node[l]->ptr;
				for (j = 0; j < n; ++j) {
					if (r[j]) {
						magic ^= j; ++c;
						q[j] = l + 1;
					}
				}
			}
			magica[l] = magic;
			ca[l] = c;
		}
		magica[2] = key0 ^ magica[0] ^ magica[1];
		ca[2] = n - ca[0] - ca[1];
		if (is_node) { /* node mode. each branch connected with this node is correct */
			for (l = 0, magic = 0; l < 3; ++l)
				if (magica[l]*n+ca[l] > magic*n+c) { magic = magica[l]; c = ca[l]; }
		} else { /* branch mode. the edge (n, n->parent) is correct */
			magic = magica[0] ^ magica[1]; c = ca[0] + ca[1];
			if (magica[2]*n+ca[2] > magic*n+c) { magic = magica[2]; c = ca[2]; };
		}
		q[n] = magic * n + c;
	}
	free(node);
}
/** \fn void tr_update_bootstrap(Tree *tree, const Tree *samp, int type)
 *  \brief Compare two trees and update Tree::bs.
 *  \param tree Tree to be updated.
 *  \param samp Resampled tree.
 *  \param is_node Mode. 0 for the conventional branch mode and 1 for node mode.
 *
 * This function compares a tree to a bootstrapped tree samp. If a node
 * is supported by bootstraped tree, Tree::bs will be increased by one.
 * The worst-case time complexity is O(N^3), but with the help of hash
 * technology, the real complexity approaches O(N^2). If we use more
 * hash, the time might be reduced to O(N). Nonetheless, I think the
 * speed here is enough.
 *
 * Branch mode realizes the conventional method to calculate bootstrap
 * values.  Such values are actually calculated for a branch, instead of
 * a node.  Node mode is initiated by TreeBeST. It evaluates the
 * accuracy of the tri-furcation at a node. So node mode is only applied
 * for a binary tree, but it is more rigorous.
 */
void tr_update_bootstrap(Tree *tree, const Tree *samp, int is_node)
{
	Tree **tnode, **snode, *p;
	int i, j, k, tm, ts, n;
	int key, t1, array[3];
	int *q, *r;

	if (tree == 0 || samp == 0) return;
	if (tree->n_leaf != samp->n_leaf) {
		fprintf(stderr, "[tr_update_bootstrap] not seem to be a resampled tree\n");
		return;
	}
	n = tree->n_leaf;
	tnode = (Tree**)malloc(sizeof(Tree*) * n);
	snode = (Tree**)malloc(sizeof(Tree*) * n);

	tm = tr_expand_internal_node(tree, tnode);
	ts = tr_expand_internal_node(samp, snode);
	/* is_bin = (tree->n > 2 || samp->n > 2)? 0 : 1; */
	for (i = 0; i < tm; ++i) {
		p = tnode[i];
		q = (int*)tnode[i]->ptr;
		key = q[n];
		for (j = 0; j < ts; ++j) {
			r = (int*)snode[j]->ptr;
			if (!is_node) { /* branch mode */
				if (key != r[n]) continue;
				for (k = 0, t1 = 0; k < n; ++k)
					if ((q[k] && r[k]) || (!q[k] && !r[k])) ++t1;
				if (t1 == 0 || t1 == n) {
					++(p->bs); r[n] = 0;
					break;
				}
			} else { /* node mode */
				if (key != r[n]) continue;
				array[0] = array[1] = array[2] = -1;
				for (k = 0; k < n; ++k) {
					if (array[q[k]] < 0) array[q[k]] = r[k];
					else if (array[q[k]] != r[k]) break;
				}
				if (k == n && array[0] + array[1] + array[2] == 0 + 1 + 2) {
					++(p->bs); r[n] = 0;
					break;
				}
			}
		}
	}
	if (!is_node) tree->bs = -1; /* no bootstrap for root node in branch mode */
	free(tnode); free(snode);
}
