/** \file utils1.c
 *  \brief Utilities, part 1
 *  
 *  This file contains basic routines related to tree manipulation.
 */
/*
 * Created:  unknown
 * Autho:    liheng
 * Last MDF: 2005-01-14
 *
 *
 * 2005-01-14 liheng:
 *
 *     * tr_attach_id_by_name(): return number of attached nodes
 *
 * 2005-01-22 liheng
 *
 *     * return number of leaves in tr_expand_leaf_by_id()
 */

#include <stdlib.h>
#include <string.h>
#include "utils.h"
#include "tree.h"

#define TR_BLOCK_SIZE 256

typedef struct
{
	TreePtr p;
	int i;
} FinishStack;

/** \fn int tr_get_leaf_num(TreePtr root)
 *  \brief Calculate number of leaves by DFS and set `pre'.
 *  \param root The tree.
 */
int tr_get_leaf_num(TreePtr root)
{
	TreePtr *stack, p;
	int max, top, counter, i;

	if (root == 0) return 0;
	max = TR_BLOCK_SIZE;
	stack = (TreePtr*)malloc(sizeof(TreePtr) * max);
	top = 0; counter = 0;
	stack[top++] = root;
	for (;;) {
		if (!top) break;
		p = stack[--top];
		p->flag = 0;
		if (p->n == 0) { /* leaf */
			++counter;
			continue;
		}
		if (top + p->n >= max) { /* enlarge the stack */
			max = ((top + p->n) / TR_BLOCK_SIZE + 1) * TR_BLOCK_SIZE;
			stack = (TreePtr*)realloc(stack, sizeof(TreePtr) * max);
		}
		for (i = 0; i < p->n; ++i) {
			stack[top++] = p->node[i];
			p->node[i]->pre = p;
		}
	}
	free(stack);
	return counter;
}
/** \fn int tr_tree_init(Tree *root)
 *  \brief Initialize a tree.
 *  \param root The tree.
 *
 *  This function will calculate number of leaves Tree::n_leaf and finish time Tree::ftime
 *  for each node. These two numbers are important to many algorithms.
 *  Be sure to apply this function to every tree.
 */
int tr_tree_init(Tree *root)
{
	int finish_time, n_leaf, n;
	FinishStack *stack, *p;
	
	if (root == 0) return 0;
	n = tr_get_leaf_num(root);
	p = stack = (FinishStack*)malloc(sizeof(FinishStack) * n * 2);
	p->i = 0;
	p->p = root;
	p->p->n_leaf = 0;
	finish_time = n_leaf = 0;
	for (;;) {
		while (p->i != p->p->n) {
			++p; /* push */
			p->i = 0;
			p->p = (p-1)->p->node[(p-1)->i];
			p->p->n_leaf = n_leaf;
		}
		if (p->i == 0) ++n_leaf;
		p->p->n_leaf = n_leaf - p->p->n_leaf;
		p->p->ftime = finish_time++;
		--p; /* pop */
		if (p >= stack) ++(p->i);
		else break;
	}
	free(stack);
	return finish_time;
}
/** \fn int tr_attach_id(Tree *root)
 *  \brief Assign an integer ID for each leaf.
 *  \param root The tree.
 *
 *  Tree::id will be moified. Internal nodes will always
 *  be assigned an ID -1.
 */
int tr_attach_id(Tree *root)
{
	int finish_time;
	FinishStack *stack, *p;
	
	if (root == 0) return 0;
	p = stack = tr_stack(root, FinishStack);
	p->p = root;
	p->i = 0;
	finish_time = 0;
	for (;;) {
		while (p->i != p->p->n) {
			++p; /* push */
			p->i = 0;
			p->p = (p-1)->p->node[(p-1)->i];
		}
		if (p->i == 0) /* p->p->n == 0 */
			p->p->id = finish_time++;
		else p->p->id = -1;
		--p; /* pop */
		if (p >= stack) ++(p->i);
		else break;
	}
	free(stack);
	return finish_time;
}
/** \fn int tr_expand_node(const Tree *root, Tree **node)
 *  \brief Expand nodes in suffix order.
 *  \param root The tree.
 *  \param node Node array to be returned.
 *
 *  Node array `node' must be allocated. Finish time, or the number
 *  of nodes, will be returned.
 *
 *  Example: given a tree ((1,2)3,(4,(5,6)7)8)9, you will get a array:
 *  (1, 2, 3, 4, 5, 6, 7, 8, 9) with each element pointing to
 *  a corresponding node.
 */
int tr_expand_node(const Tree *root, Tree **node)
{
	int finish_time;
	FinishStack *stack, *p;
	
	if (root == 0) return 0;
	assert(node);
	p = stack = tr_stack(root, FinishStack);
	p->p = (Tree*)root;
	p->i = 0;
	finish_time = 0;
	for (;;) {
		while (p->i != p->p->n) {
			++p; /* push */
			p->i = 0;
			p->p = (p-1)->p->node[(p-1)->i];
		}
		node[finish_time++] = p->p;
		--p; /* pop */
		if (p >= stack) ++(p->i);
		else break;
	}
	free(stack);
	return finish_time;
}
/** \fn int tr_expand_internal_node(const Tree *root, Tree **node)
 *  \brief Expand internal nodes in suffix order.
 *  \param root The tree.
 *  \param node Nodes array to be returned.
 *
 *  Similar to tr_expand_node(). The number of internal nodes will be returned.
 */
int tr_expand_internal_node(const Tree *root, Tree **node)
{
	int finish_time;
	FinishStack *stack, *p;
	
	if (root == 0) return 0;
	assert(node);
	p = stack = tr_stack(root, FinishStack);
	p->p = (Tree*)root;
	p->i = 0;
	finish_time = 0;
	for (;;) {
		while (p->i != p->p->n) {
			++p; /* push */
			p->i = 0;
			p->p = (p-1)->p->node[(p-1)->i];
		}
		if (p->i != 0) /* internal nodes */
			node[finish_time++] = p->p;
		--p; /* pop */
		if (p >= stack) ++(p->i);
		else break;
	}
	free(stack);
	return finish_time;
}
/** \fn int tr_expand_leaf(const Tree *root, Tree **node)
 *  \brief Expand external nodes in suffix order.
 *  \param root The tree.
 *  \param node Nodes array to be returned.
 *
 *  Similar to tr_expand_node(). The number of external nodes will be returned.
 */
int tr_expand_leaf(const Tree *root, Tree **node)
{
	int finish_time;
	FinishStack *stack, *p;
	
	if (root == 0) return 0;
	assert(node);
	p = stack = tr_stack(root, FinishStack);
	p->p = (Tree*)root;
	p->i = 0;
	finish_time = 0;
	for (;;) {
		while (p->i != p->p->n) {
			++p; /* push */
			p->i = 0;
			p->p = (p-1)->p->node[(p-1)->i];
		}
		if (p->i == 0) /* p->p->n == 0 */
			node[finish_time++] = p->p;
		--p; /* pop */
		if (p >= stack) ++(p->i);
		else break;
	}
	free(stack);
	return finish_time;
}
/** \fn int tr_expand_leaf_by_id(const Tree *root, Tree **leaf)
 *  \brief Expand external nodes according to Tree::id.
 *  \param root The tree.
 *  \param leaf Nodes array to be returned.
 *
 *  Different from tr_expand_leaf(), this function expand external
 *  nodes according to Tree::id. The resultant array leaf[] will
 *  satisfies that leaf[p->id]=p for all p->id>=0.
 */
int tr_expand_leaf_by_id(const Tree *root, Tree **leaf)
{
	Tree *p, **q, **list;
	int j;

	if (root == 0) return 0;
	assert(leaf);
	q = list = tr_stack(root, TreePtr);
	*q++ = (Tree*)root; /* push */
	while (q != list) {
		--q; /* pop */
		if ((*q)->n == 0 && (*q)->id >= 0) /* leaf node && have reasonable id */
			leaf[(*q)->id] = *q;
		for (j = 0, p = *q; j < p->n; ++j)
			*q++ = p->node[j];
	}
	free(list);
	return root->n_leaf;
}
/** \fn void tr_delete_tree_ptr(Tree *root)
 *  \brief Delete a tree.
 *  \param root The tree.
 *
 *  Note that Tree::ptr will be freed abruptly, regardless of the memory allocated
 *  inside the block pointed by ptr. Please manually free these memory before
 *  applying this function.
 */
void tr_delete_tree_ptr(Tree *root)
{
	Tree **node;
	int i, f;
	if (root == 0) return;
	node = tr_stack(root, Tree*);
	f = tr_expand_node(root, node);
	for (i = 0; i < f; ++i) {
		free(node[i]->ptr);
		node[i]->ptr = 0;
	}
	free(node);
}
/** \fn Tree *tr_search(const Tree *root, const Tree *ptr)
 *  \brief Search for a node pointer in a tree.
 *  \param root The tree.
 *  \param ptr The node to be searched for.
 */
Tree *tr_search(const Tree *root, const Tree *ptr)
{
	Tree *p, **q, **list;
	int j;

	if (root == 0 || ptr == 0) return 0;
	list = tr_stack(root, Tree*);
	q = list;
	*q++ = (Tree*)root;
	while (q != list) {
		--q;
		if (*q == ptr) { p = *q; free(list); return p; }
		for (j = 0, p = *q; j < p->n; ++j)
			*q++ = p->node[j];
	}
	free(list);
	return 0;
}
/** \fn Tree *tr_search_by_name(const Tree *root, const char *name)
 *  \brief Search for a string in a tree.
 *  \param root The tree.
 *  \param name The node name to be searched for.
 */
Tree *tr_search_by_name(const Tree *root, const char *name)
{
	Tree *p, **q, **list;
	int j;

	if (root == 0 || name == 0) return 0;
	list = tr_stack(root, Tree*);
	q = list;
	*q++ = (Tree*)root;
	while (q != list) {
		--q;
		if ((*q)->name && !strcmp(name, (*q)->name)) {
			p = *q;
			free(list); return p;
		}
		for (j = 0, p = *q; j < p->n; ++j)
			*q++ = p->node[j];
	}
	free(list);
	return 0;
}
void tr_clear_ptr(Tree *tree)
{
	int i, n;
	Tree **node;
	if (tree == 0) return;
	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	for (i = 0; i < n; ++i)
		node[i]->ptr = 0;
	free(node);
}
char *cpystr(const char *s)
{
	char *p;
	if (s == 0) return 0;
	p = (char*)malloc(sizeof(char) * (strlen(s)+1));
	return strcpy(p, s);
}
