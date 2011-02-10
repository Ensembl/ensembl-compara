/*! \file order.c
 *  \brief Order the external nodes of a tree.
 */
#include <stdlib.h>
#include <string.h>
#include "tree.h"
#include "utils.h"

#define ORDER_MASK	0x03ff
#define ORDER_SHIFT	10
#define ORDER_TIMES	256.0

typedef struct
{
	void *ptr;
	unsigned key;
	int cnt;
	Tree *left; /** point to the left-most child */
} OrderInfo;

#define Oinfo(p) ((OrderInfo*)(p)->ptr)

#define ALGO_QSORT
#define ALGO_TYPE TreePtr
#define ALGO_CMP(a,b) ((Oinfo(a)->key<Oinfo(b)->key) || (Oinfo(a)->key==Oinfo(b)->key && strcmp(Oinfo(a)->left->name,Oinfo(b)->left->name)<0))
#include "algo.h"

static void dump_ptr(Tree *tree)
{
	int n, i;
	Tree **node, *p;
	OrderInfo *q;

	if (tree == 0) return;
	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	for (i = 0; i < n; ++i) {
		q = (OrderInfo*)malloc(sizeof(OrderInfo));
		p = node[i];
		q->left = (p->n == 0)? p : 0;
		q->key = (p->n == 0)? ((p->flag << ORDER_SHIFT) | p->flag) : 0;
		q->cnt = (p->n == 0)? (p->flag < tree->n_leaf? 1 : 0) : 0;
		q->ptr = p->ptr;
		p->ptr = q;
	}
	free(node);
}
static void restore_ptr(Tree *tree)
{
	int n, i;
	Tree **node, *p;
	OrderInfo *q;

	if (tree == 0) return;
	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	for (i = 0; i < n; ++i) {
		p = node[i];
		q = Oinfo(p);
		p->ptr = q->ptr;
		free(q);
	}
	free(node);
}
void tr_set_spec_leaf_order(Tree *tree)
{
	int i, n;
	Tree **node, *p;

	if (tree == 0) return;
	node = tr_stack(tree, Tree*);
	n = tr_expand_leaf(tree, node);
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (p->ptr && spec(p)) p->flag = spec(p)->id;
		else p->flag = n;
	}
	free(node);
}
/** \fn void tr_order_core(Tree *tree)
 *  \brief Re-order the leaves of a tree.
 *  \param tree A tree with leaves numbered.
 *
 *  This function will try to rearrange the leaves in an order that
 *  approaches increasing order. The algorithm here is very simple and intuitive.
 *  I do not know what on earth is optimized here, but it works intuitively
 *  well. Usually, you need to call cpp_set_leaf_order() first to initialize
 *  Tree::flag.
 */
void tr_order_core(Tree *tree)
{
	Tree **node, *p, *q;
	int i, j, n, y;
	float x;

	if (tree == 0) return;
	node = tr_stack(tree, Tree*);
	dump_ptr(tree);
	n = tr_expand_internal_node(tree, node);
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (p->n == 2) {
			if (!ALGO_CMP(p->node[0], p->node[1])) { /** swap! */
				q = p->node[0]; p->node[0] = p->node[1]; p->node[1] = q;
			}
		} else algo_qsort(p->node, p->n);
		for (x = 0.0, j = 0, y = 0; j < p->n; ++j) {
			y += Oinfo(p->node[j])->cnt;
			x += (Oinfo(p->node[j])->key >> ORDER_SHIFT) / ORDER_TIMES * Oinfo(p->node[j])->cnt;
		}
		Oinfo(p)->cnt = y;
		if (y) Oinfo(p)->key = ((int)(x * ORDER_TIMES / y + 0.5) << ORDER_SHIFT) | (Oinfo(p->node[0])->key & ORDER_MASK);
		else Oinfo(p)->key = 0xfffffffful << ORDER_SHIFT | (Oinfo(p->node[0])->key & ORDER_MASK);
		Oinfo(p)->left = Oinfo(p->node[0])->left;
	}
	restore_ptr(tree);
	tr_tree_init(tree);
	free(node);
}
