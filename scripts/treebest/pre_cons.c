/** \file pre_cons.c
 * 	\brief Pre-process the constrained trees.
 */
#include <stdlib.h>
#include <string.h>
#include "tree.h"
#include "utils.h"

const char *tr_cons_flag = "{C}";
const char *tr_free_flag = "{P}";

static void label_cons(Tree *cons, int root_flag)
{
	int i, m;
	Tree **node, *p;

	if (cons == 0 || cons->n_leaf == 1) return;
	node = tr_stack(cons, Tree*);
	m = tr_expand_internal_node(cons, node);
	node[m - 1]->is_cons = root_flag;
	/* is_cons == 1: inheritable constraint
	 * is_cons == 2: temporary constraint
	 * is_cons == 0: no constraint
	 */
	for (i = m - 2; i >= 0; --i) {
		p = node[i];
		if (p->name) {
			if (strstr(p->name, tr_cons_flag)) p->is_cons = 1;
			else if (strstr(p->name, tr_free_flag)) p->is_cons = 0;
			else if (p->name[0]) p->is_cons = (p->pre->is_cons != 1)? 2 : 1;
			else p->is_cons = (p->pre->is_cons >= 2)? 0 : p->pre->is_cons;
		} else p->is_cons = (p->pre->is_cons >= 2)? 0 : p->pre->is_cons;
	}
	free(node);
}
/** \fn Tree *tr_pre_cons(Tree *cons, int root_flag)
 *  \brief Pre-process the constrained trees.
 *  \param cons A constrained tree.
 *  \param root_flag Whether the root is labeled as {C}.
 *
 *  This function makes multifurcation at nodes labeled
 *  as {P} and returns the resultant tree. It first labels the root according to
 *  root_flag, and then scans and labels, from the root, the nodes without {P} or {C}
 *  tags. Finally, adjacent {P} nodes are merged to a multifurcated one.
 */
Tree *tr_pre_cons(Tree *cons, int root_flag)
{
	Tree **node, **subnode, *p, *q;
	int m, i, j, k;

	if (cons == 0) return 0;
	label_cons(cons, root_flag);
	node = tr_stack(cons, Tree*);
	subnode = tr_stack(cons, Tree*);
	m = tr_expand_node(cons, node);
	for (i = 0; i < m; ++i) {
		p = node[i];
		subnode[i] = q = tr_new_node();
		if (p->n == 0) {
			q->name = (char*)malloc(sizeof(char) * (strlen(p->name) + 1));
			strcpy(q->name, p->name);
			q->id = p->id;
			q->d = p->d;
			q->ptr = p->ptr;
			q->is_cons = 1;
		} else {
			int count = 0, count2 = 0;
			if (!p->is_cons) {
				for (j = 0; j < p->n; ++j)
					if (subnode[p->node[j]->ftime]->is_cons == 0) {
						count += subnode[p->node[j]->ftime]->n;
						++count2;
					}
			}
			if (count == 0) {
				q->n = p->n;
				q->bs = p->bs;
				q->ptr = p->ptr;
				q->d = p->d;
				q->is_cons = p->is_cons;
				q->node = (Tree**)malloc(sizeof(Tree*) * q->n);
				if (p->name) {
					q->name = (char*)malloc(sizeof(char) * (strlen(p->name) + 1));
					strcpy(q->name, p->name);
				}
				for (j = 0; j < q->n; ++j) {
					subnode[p->node[j]->ftime]->pre = q;
					q->node[j] = subnode[p->node[j]->ftime];
				}
			} else {
				int l;
				Tree *r;
				q->n = p->n - count2 + count;
				q->node = (Tree**)malloc(sizeof(Tree*) * q->n);
				q->is_cons = 0;
				for (k = j = 0; j < p->n; ++j) {
					r = subnode[p->node[j]->ftime];
					if (r->is_cons)
						q->node[k++] = r;
					else {
						for (l = 0; l < r->n; ++l) {
							q->node[k++] = r->node[l];
							r->node[l]->pre = q;
						}
						tr_delete_node(r);
						subnode[p->node[j]->ftime] = 0;
					}
				}
			}
		}
	}
	p = subnode[m-1];
	free(node);
	free(subnode);
	tr_tree_init(p);
	return p;
}
