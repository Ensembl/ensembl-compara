/***
 * Author: liheng
 * Created: 2005-01-22
 * Last MDF: 2005-01-27
 *
 * 2005-01-27 liheng
 *
 *     * fix memory violation
 *
 * 2005-01-28 liheng
 *
 *     * fix another memory violation
 */
#include <stdlib.h>
#include "utils.h"
#include "tree.h"

#ifdef USE_GCC
inline int lh3_tmp_add_lost(Tree *p, Tree *s)
#else
int lh3_tmp_add_lost(Tree *p, Tree *s)
#endif
{
	int tmp;
	while (s->n > 0 && s->bs < 2) { /* find the lowest lost genus */
		int j;
		for (j = 0; j < s->n; ++j)
			if (s->node[j]->bs > 0) break;
		s = s->node[j];
	}
	tmp = ++(SDIptr(p)->n_lost);
	SDIptr(p)->lost = (Tree**)realloc(SDIptr(p)->lost, sizeof(Tree*) * tmp);
	SDIptr(p)->lost[tmp-1] = s;
	return 1;
}
int tr_lost_infer(Tree *tree, const Tree *spec)
{
	Tree **node, *t, *s, *p;
	int count, i, j, m;

	if (tree == 0 || spec == 0) return 0;
	count = 0;
	if (!tree->node_array) {
		node = tr_stack(tree, Tree*);
		m = tr_expand_node(tree, node);
	} else {
		node = tree->node_array;
		m = tree->n_node;
	}
	for (i = 0; i < m - 1; ++i) {
		p = node[i];
		t = 0; /* just for a warning. */
		s = spec(p);
		if (s == 0) continue;
		if (s == spec(p->pre) && SDIptr(p->pre)->type == 'D') {
			for (j = 0; j < s->n; ++j)
				if (SDIptr(p->pre)->spec_node[j] != 0 && SDIptr(p)->spec_node[j] == 0 && s->node[j]->bs > 0)
					count += lh3_tmp_add_lost(p, s->node[j]);
			continue;
		}
		if (s != spec(p->pre)) { /* spec(p) is a descendant of spec(p->pre) */
			for (j = 0; j < s->n; ++j)
				if (SDIptr(p)->spec_node[j] == 0 && s->node[j]->bs > 0)
					count += lh3_tmp_add_lost(p, s->node[j]);
			t = s; s = s->pre;
			while (s != spec(p->pre)) {
				for (j = 0; j < s->n; ++j)
					if (s->node[j] != t && s->node[j]->bs > 0)
						count += lh3_tmp_add_lost(p, s->node[j]);
				t = s; s = s->pre;
			}
		}
		if (SDIptr(p->pre)->type != 'D') continue;
		else { /* now, SDIptr(p->pre)->type == 'D' and s == spec(p->pre) */
			for (j = 0; j < s->n; ++j)
				if (SDIptr(p->pre)->spec_node[j] == 1 && s->node[j] != t && s->node[j]->bs > 0)
					count += lh3_tmp_add_lost(p, s->node[j]);
		}
	}
	if (!tree->node_array) free(node);
	return count;
}
