#include <stdlib.h>
#include "tree.h"
#include "utils.h"

static float tr_root_max = 0.0; /* used for static Tree *tr_locate_root() */
static Tree *tr_root_max_ptr = 0;

/*
 * reroot a tree
 */
Tree *tr_reroot(Tree *root, Tree *node, float dist)
{
	int i;
	float d, tmp;
	Tree *p, *q, *r, *s, *new_root;
	if (node == root) return root;
	if (dist < 0.0 || dist > node->d) dist = node->d / 2.0;
	tmp = node->d;

	/* p: the central multi-parent node
	 * q: the new parent, previous a child of p
	 * r: old parent
	 * i: previous position of q in p
	 * d: previous distance p->d
	 */
	q = new_root = tr_new_node();
	q->n = 2;
	q->node = (Tree**)malloc(sizeof(Tree*) * 2);
	q->node[0] = node;
	q->node[0]->d = dist;
	p = node->pre;
	q->node[0]->pre = q;
	for (i = 0; i < p->n; ++i)
		if (p->node[i] == node) break;
	q->node[1] = p;
	d = p->d;
	p->d = tmp - dist;
	r = p->pre;
	p->pre = q;
	while (r) {
		s = r->pre; /* store r's parent */
		p->node[i] = r; /* change r to p's child */
		for (i = 0; i < r->n; ++i) /* update i */
			if (r->node[i] == p) break;
		r->pre = p; /* update r's parent */
		tmp = r->d; r->d = d; d = tmp; /* swap r->d and d, i.e. update r->d */
		q = p; p = r; r = s; /* update p, q and r */
	}
	/* now p is the root node */
	if (p->n == 2) { /* remove p and link the other child of p to q */
		r = p->node[1 - i]; /* get the other child */
		for (i = 0; i < q->n; ++i) /* the position of p in q */
			if (q->node[i] == p) break;
		r->d += p->d;
		r->pre = q;
		q->node[i] = r; /* link r to q */
		tr_delete_node(p);
	} else { /* remove one child in p */
		int j, k;
		for (j = k = 0; j < p->n; ++j) {
			p->node[k] = p->node[j];
			if (j != i) ++k;
		}
		--(p->n);
	}
	return new_root;
}
/*
 * find the root minimize the tree height
 * I can choose not to use recursive, but it will become more complex.
 * Note that two global static variables are used here.
 */
static Tree *tr_locate_root(Tree *tree, float *dist)
{
	float max1, max2, d;
	int i;
	Tree *p, *mp;

	if (tree->n == 0) {
		*dist = tree->d;
		return tree;
	}
	for (i = 0, max1 = max2 = -1e30, mp = 0; i < tree->n; ++i) {
		p = tr_locate_root(tree->node[i], &d); /* p is always the leaf node */
		if (d > max1) {
			max2 = max1; max1 = d; mp = p;
		} else if (d > max2) max2 = d;
	}
	if (max1 + max2 > tr_root_max) {
		tr_root_max = max1 + max2;
		tr_root_max_ptr = mp;
	}
	*dist = max1 + tree->d;
	return mp;
}
/*
 * root a tree by minimizing the height of the tree
 */
Tree *tr_root_by_min_height(Tree *root)
{
	float dist, d;
	Tree *p;

	if (root == 0) return 0;
	if (root->n_leaf < 3) return root; /* already rooted */
	tr_root_max = -1e30;
	tr_root_max_ptr = 0;
	tr_locate_root(root, &d);
	dist = tr_root_max / 2.0;
	p = tr_root_max_ptr; d = 0.0;
	for (;;) {
		if (p->d + d >= dist || p->pre == 0) break;
		d += p->d;
		p = p->pre;
	}
	p = tr_reroot(root, p, dist - d);
	tr_tree_init(p);
	return p;
}
Tree *tr_remove_root(Tree *root)
{
	Tree *p;
	float d;

	if (root == 0) return 0;
	d = -2e30;
	if (root->n > 2 || root->n == 0) return root;
	if (root->node[0]->d > -1e30 && root->node[1]->d > -1e30)
		d = root->node[0]->d + root->node[1]->d;
	if (root->node[0]->n == 0) { /* node[0] is a leaf node, merge to node[1] */
		if (root->node[1]->n == 0) return root;
		p = root->node[1];
		p->node = (Tree**)realloc(p->node, sizeof(Tree*) * (p->n + 1));
		p->node[p->n++] = root->node[0];
		root->node[0]->pre = p;
		root->node[0]->d = d;
	} else {
		/* no matter whether root->node[1] is a leaf node or not, the procedure is the same. */
		p = root->node[0];
		p->node = (Tree**)realloc(p->node, sizeof(Tree*) * (p->n + 1));
		p->node[p->n++] = root->node[1];
		root->node[1]->pre = p;
		root->node[1]->d = d;
	}
	p->pre = 0;
	p->d = 0.0;
	tr_delete_node(root);
	tr_tree_init(p);
	return p;
}
