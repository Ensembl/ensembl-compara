/***
 * Author: liheng
 * Created: unknown
 * Last MDF: 2005-01-22
 *
 * 2005-01-22 liheng
 *
 *     * remove useless parameter bs_thres
 */
#include <stdlib.h>
#include <string.h>
#include "tree.h"
#include "utils.h"

/* bs_thres is useless at present. */
Tree *tr_cut_tree(Tree *tree, const Tree *spec, int m, char **ingroup, const char *cut)
{
	Tree *lca, *cut_ptr, *p, *q, *r;

	assert(cut);
	if (m > 0) assert(ingroup);
	if (!tree || !spec || !ingroup || m == 0) return tree;
	lca = tr_comm_ancester(tree, m, ingroup);
	if (lca == 0 || spec(lca) == 0) return tree;
	cut_ptr = tr_search_by_name(spec, cut);
	if (cut_ptr == 0) return tree;
	/* find CUT node */
	for (p = lca; p->pre; p = p->pre) { /* this loop can be improved. */
		r = spec(p->pre); q = cut_ptr;
		while (r->ftime != q->ftime) {
			if (r->ftime < q->ftime) r = r->pre;
			else q = q->pre;
		}
		if (q != cut_ptr) break; /* cut here */
	}
	if (p->pre == 0) p = tree; /* choose the root node as CUT */
	else if (SDIptr(p->pre)->type != 'D') p = p->pre; /* if not duplication, reserve outgroup */
	return p;
}
