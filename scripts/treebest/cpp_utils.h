#ifndef CPP_UTILS_H_
#define CPP_UTILS_H_

#include "tree.h"
#include "utils.h"
#include "align.h"

#ifdef __cplusplus
extern "C" {
#endif

int cpp_check_align_name(MultiAlign *ma);
int cpp_check_list(int m, char **name);
int cpp_attach_id_by_name(Tree *root, int m, char **name);
int cpp_attach_flag_by_name(Tree *root, int m, char **name);
Tree *cpp_subtree(Tree *root, int m, char **name);
Tree *cpp_subtree_aux(const Tree *root);
Tree **cpp_get_spec_links(const Tree *tree, const Tree *spec);
Tree *cpp_shrink_spec(Tree *spec_tree, int m, char **name);
Tree *cpp_shrink_spec_by_tree(Tree *spec_tree, Tree *gene_tree);
Tree *cpp_check_tree(Tree *tree);
void cpp_set_leaf_order(Tree *src, Tree *dst, int def_val);
Tree *cpp_subtree_spec(Tree *root, Tree *spec, int n, char **spec_name);
void cpp_insert_keyval(Tree *t, const char *key, const char *val);
void cpp_get_keyval(Tree *t, const char *key, char **val);
void cpp_copy_nhx_hash(Tree *dst, Tree *src);
void cpp_shrink_ma_by_spec(MultiAlign *ma, Tree *spec);
void tr_dN_dS(Tree *tree, MultiAlign *ma);
Tree *cpp_post_spec_tree(Tree *tree, int is_core);

#ifdef __cplusplus
}
#endif

#endif
