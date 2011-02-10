#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "tree.h"
#include "cpp_utils.h"

/*
 * find the last common ancester of the specified nodes (id >= 0). O(N)
 * It is in fact a simplized version of tr_subtree_aux().
 */
Tree *tr_comm_ancester_aux(Tree *t)
{
	Tree *p, *q;
	int i, k;

	q = 0;
	if (t->n == 0) return (t->flag < 0)? 0 : t;
	for (i = 0, k = 0; i < t->n; ++i) {
		p = tr_comm_ancester_aux(t->node[i]);
		if (p) {
			++k;
			q = p;
		}
	}
	if (k == 0) p = 0;
	else if (k == 1) p = q;
	else p = t;
	return p;
}
/*
 * find the last common ancester. O(N)
 */
Tree *tr_comm_ancester(Tree *root, int m, char **name)
{
	cpp_attach_flag_by_name(root, m, name);
	return tr_comm_ancester_aux(root);
}
