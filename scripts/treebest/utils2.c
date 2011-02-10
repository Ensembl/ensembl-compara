/***
 * Author: liheng
 * Created: unknown
 * Last MDF: 2005-01-22
 *
 * 2005-01-22 liheng
 *
 *     * check for null tree
 */
#include <stdlib.h>
#include <string.h>
#include "cpp_utils.h"
#include "tree.h"

/*
 * copy the node `node' to a new one
 */
#ifdef USE_GCC
inline Tree *tr_copy_node(const Tree *node)
#else
Tree *tr_copy_node(const Tree *node)
#endif
{
	Tree *dest;
	int i;

	dest = (Tree*)malloc(sizeof(Tree));
	dest->ptr = dest->nhx = 0; /* ptr is NOT copied. */
	dest->n = node->n;
	dest->bs = node->bs;
	if (node->name) {
		dest->name = (char*)malloc(sizeof(char) * (strlen(node->name) + 1));
		strcpy(dest->name, node->name);
	} else dest->name = 0;
	dest->is_cons = node->is_cons;
	dest->id = node->id;
	dest->flag = node->flag;
	dest->ftime = node->ftime;
	dest->n_leaf = node->n_leaf;
	dest->d = node->d;
	dest->node_array = 0;
	dest->node = (node->n == 0)? 0 : (Tree**)malloc(sizeof(Tree*) * dest->n);
	for (i = 0; i < dest->n; ++i)
		dest->node[i] = 0;
	dest->pre = 0;
	return dest;
}
/*
 * copy the whole tree
 */
Tree *tr_copy_tree(const Tree *root)
{
	int i, j, m;
	Tree **node, **dest, *p;
	TreePtr *stack, *top;
	if (root == 0) return 0;
	if (!root->node_array) {
		node = tr_stack(root, Tree*);
		m = tr_expand_node(root, node);
	} else {
		node = root->node_array;
		m = root->n_node;
	}
	dest = tr_stack(root, Tree*);
	top = stack = tr_stack(root, Tree*);
	for (i = 0; i < m; ++i) {
		p = node[i];
		if (p->n == 0) {
			dest[i] = tr_copy_node(p);
			*top++ = dest[i];
		} else {
			dest[i] = tr_copy_node(p);
			for (j = p->n - 1; j >= 0; --j) {
				--top; /* pop */
				dest[i]->node[j] = *top;
				(*top)->pre = dest[i];
			}
			*top++ = dest[i]; /* push */
		}
	}
	p = *--top; /* root node */
	free(dest);
	if (!root->node_array) free(node);
	free(stack);
	return p;
}
/*
 * calculate the height of the tree
 */
float tr_tree_height(const Tree *root)
{
	int m, i, j;
	float *d, h, max;
	Tree *p, **node;
	int *stack, *top;

	if (root->ftime == 0) return 0.0;
	node = tr_stack(root, Tree*);
	m = tr_expand_node(root, node);
	top = stack = tr_stack(root, int);
	d = tr_stack(root, float);
	for (i = 0; i < m; ++i) d[i] = 0.0;
	for (i = 0; i < m; ++i) {
		p = node[i];
		if (p->n == 0) {
			d[i] = (p->d >= 0.0)? p->d : 0.0;
			*top++ = i; /* push */
		} else {
			for (j = 0, max = -1.0; j < p->n; ++j) {
				--top; /* pop */
				if (d[*top] > max) max = d[*top];
			}
			if (p->d >= 0.0) d[i] = p->d + max;
			*top++ = i; /* push */
		}
	}
	h = (root->d >= 0.0)? d[m-1] - root->d : 0.0; /* do not add root branch */
	free(node);
	free(stack);
	free(d);
	return h;
}
/*
 * slide the root node
 */
float tr_slide_binary_root(Tree *root)
{
	float t, t0, t1, h;
	if (root->n != 2) return -1.0;
	t0 = tr_tree_height(root->node[0]);
	t1 = tr_tree_height(root->node[1]);
	t = root->node[0]->d + root->node[1]->d;
	if (t0 > t1) {
		if (t0 < t1 + t) {
			h = (t0 + t1 + t) / 2.0;
			root->node[0]->d = h - t0;
			root->node[1]->d = h - t1;
		} else {
			h = t0;
			root->node[0]->d = 0.0;
			root->node[1]->d = t;
		}
	} else { /* t0 <= t1 */
		if (t1 < t0 + t) {
			h = (t0 + t1 + t) / 2.0;
			root->node[0]->d = h - t0;
			root->node[1]->d = h - t1;
		} else {
			h = t1;
			root->node[0]->d = t;
			root->node[1]->d = 0.0;
		}
	}
	return h;
}
/*
 * SDI rooting
 */
Tree *tr_root_by_sdi(Tree *root, Tree *spec)
{
	int m, i, min, min_i, min_dup;
	float min_h;
	Tree **node, **links, *p;
	extern void tr_sdi_set_dup_bound(int);

	if (root == 0) return 0;
	if (spec == 0) return tr_root_by_min_height(root);
	node = tr_stack(root, Tree*);
	min_dup = min = 0x7fffffff;
	min_h = 1e30;
	min_i = -1;
	links = cpp_get_spec_links(root, spec);
	root->node_array = tr_stack(root, Tree*);
	root->n_node = tr_expand_node(root, root->node_array);

	for (i = 0; i < root->ftime; ++i) {
		Tree *new_tree;
		float h;
		int n_dup, n_lost, n_total;
		new_tree = tr_copy_tree(root);
		m = tr_expand_node(new_tree, node); /* O(N) */
		/* now, calculate number of duplications and tree height if this node is the root. */
		new_tree = tr_reroot(new_tree, node[i], -1.0); /* O(N) */
		tr_tree_init(new_tree);
		new_tree->node_array = tr_stack(new_tree, Tree*);
		new_tree->n_node = tr_expand_node(new_tree, new_tree->node_array);
		/* in theory, there are exact two children of root node. */
		tr_sdi_set_dup_bound(min_dup);
		n_dup = tr_SDI(new_tree, spec, links);
		if (n_dup <= min_dup) {
			min_dup = n_dup;
			n_lost = tr_lost_infer(new_tree, spec);
			n_total = n_dup * root->ftime * spec->n_leaf + n_lost;
			if (n_total <= min) {
				h = tr_slide_binary_root(new_tree);
				if (n_total < min || h < min_h) {
					min = n_total;
					min_h = h;
					min_i = i;
				}
			}
		}
		/* fprintf(stderr, "%d\t%d\t%d\t%f\n", n_total, n_dup, n_lost, h); */
		tr_delete_tree_SDIptr(new_tree);
		tr_delete_tree(new_tree);
	}
	p = (min_i >= 0)? root->node_array[min_i] : 0;
	free(root->node_array); root->node_array = 0; root->n_node = 0;
	if (p) {
		root = tr_reroot(root, p, -1.0);
		tr_tree_init(root);
	}
	tr_slide_binary_root(root);
	free(node);
	free(links);
	tr_sdi_set_dup_bound(0x7fffffff);
	return root;
}
/* a faster version that makes use of 'Tree::ptr' */
Tree *tr_root_by_sdi_fast(Tree *root, Tree *spec)
{
	int i, min, min_i, min_dup, n, factor;
	float min_h;
	Tree **links, **node;
	Tree *cur_root;
	extern void tr_sdi_set_dup_bound(int);

	if (root == 0) return 0;
	if (spec == 0) return tr_root_by_min_height(root);
	factor = root->ftime * spec->n_leaf;
	tr_clear_ptr(root); /* Set Tree::ptr as zero. Memory pointed to by these pointers will be LOST! */

	/* these two lines avoid calling tr_expand_internal_node() for many times */
	spec->node_array = tr_stack(spec, Tree*);
	spec->n_node = tr_expand_internal_node(spec, spec->node_array);

	/* preparation */
	node = tr_stack(root, Tree*);
	cur_root = root = tr_remove_root(root);
	tr_tree_init(cur_root);
	links = cpp_get_spec_links(cur_root, spec);
	n = tr_expand_node(cur_root, node);

	/* try the 'shortest' topology first */
	cur_root = tr_root_by_min_height(cur_root);
	min_h = tr_tree_height(cur_root);
	tr_sdi_set_dup_bound(0x7fffffff);
	min_dup = tr_SDI(cur_root, spec, links);
	tr_sdi_set_dup_bound(min_dup);
	min = min_dup * factor + tr_lost_infer(cur_root, spec);
	min_i = -1;
	tr_delete_tree_SDIptr(cur_root);
	cur_root = tr_reroot(cur_root, root, -1.0);

	for (i = 0; i < n - 1; ++i) {
		float h;
		int n_dup, n_lost, n_total = 0;
		cur_root = tr_reroot(cur_root, node[i], -1.0);
		tr_tree_init(cur_root);
		cur_root->node_array = tr_stack(cur_root, Tree*);
		cur_root->n_node = tr_expand_node(cur_root, cur_root->node_array);
		tr_sdi_set_dup_bound(min_dup);
		n_dup = tr_SDI(cur_root, spec, links);
		if (n_dup <= min_dup) { /* this avoids unnecessary calls of tr_lost_infer() */
			min_dup = n_dup;
			n_lost = tr_lost_infer(cur_root, spec);
			n_total = n_dup * factor + n_lost;
			if (n_total <= min) { /* avoid unnecessary calls of tr_slide_binary_root() */
				h = tr_slide_binary_root(cur_root);
				if (n_total < min || h <= min_h) {
					min = n_total;
					min_h = h;
					min_i = i;
				}
			}
		}
		/* clean up */
		tr_delete_tree_SDIptr(cur_root);
		free(cur_root->node_array); cur_root->node_array = 0; cur_root->n_node = 0;
		/* restore the original tree */
		cur_root = tr_reroot(cur_root, root, -1.0);
	}
	if (min_i >= 0) {
		root = tr_reroot(cur_root, node[min_i], -1.0);
		tr_tree_init(root);
		tr_slide_binary_root(root);
	} else { /* the 'shortest' tree is preferred */
		tr_tree_init(cur_root);
		root = tr_root_by_min_height(cur_root);
	}
	free(node);
	free(links);
	free(spec->node_array); spec->node_array = 0; spec->n_node = 0;
	tr_sdi_set_dup_bound(0x7fffffff);
	return root;
}
