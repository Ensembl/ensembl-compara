/***
 * Created:  unknown
 * Author:   liheng
 * Last MDF: 2005-01-22
 *
 *
 * 2005-01-14 liheng:
 *
 *     * declaration of tr_attach_name_by_id() and tr_expand_leaf_by_id()
 *
 * 2005-01-22 liheng
 *
 *     * several declarations
 */
#ifndef UTILES_H_
#define UTILES_H_

#include "tree.h"

#define tr_stack(tree,type) ((type*)malloc(sizeof(type) * ((tree)->ftime+1)))

#ifdef __cplusplus
extern "C" {
#endif

/* count the number of leaves and correct Tree::pre pointer if wrong */
int tr_get_leaf_num(TreePtr root);
/* set Tree::finish_time and Tree::n_leaf */
int tr_tree_init(Tree *root);
/* set Tree::id */
int tr_attach_id(Tree *root);
/* get all the nodes of `root', according to finish time */
int tr_expand_node(const Tree *root, Tree **node);
/* get internal nodes, finish time */
int tr_expand_internal_node(const Tree *root, Tree **node);
/* get leaf nodes */
int tr_expand_leaf(const Tree *root, Tree **node);
/* get leaf node according to Tree::id */
int tr_expand_leaf_by_id(const Tree *root, Tree **leaf);
/* search a node by name */
Tree *tr_search_by_name(const Tree *root, const char *name);
/* search a node by node */
Tree *tr_search(const Tree *root, const Tree *ptr);

/* copy a node, except for ->ptr point */
Tree *tr_copy_node(const Tree *node);
/* copy a tree, call tr_copy_node() */
Tree *tr_copy_tree(const Tree *root);

void tr_clear_ptr(Tree *tree);

char *cpystr(const char *s);

#ifdef __cplusplus
}
#endif

#endif
