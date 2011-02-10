#include <stdlib.h>
#include "align.h"
#include "tree.h"
#include "utils.h"
#include "cpp_utils.h"

Tree *tr_est_len_nj_core(Tree *tree, Matrix *mat)
{
	Tree *forest[1], *rst;
	forest[0] = tree;
	rst = tr_nj_rooted(mat, 1, forest, 1);
	return rst;
}
void tr_est_len(Tree *tree, Matrix *mat, const char *tag)
{
	Tree **node, **node2, *tree2;
	char str[127];
	int i, n;
	
	n = mat->count;
	if (tree->n_leaf != n) {
		fprintf(stderr, "[tr_est_w_by_nj] inconsistent between the tree and the matrix!\n");
		return;
	}
	if (tree->n != 2 || tree->ftime != 2 * n - 2) {
		fprintf(stderr, "[tr_est_w_by_nj] the input tree is not a binary rooted tree!\n");
		return;
	}
	node = tr_stack(tree, Tree*);
	node2 = tr_stack(tree, Tree*);
	tr_expand_node(tree, node);
	tree2 =tr_est_len_nj_core(tree, mat);
	cpp_set_leaf_order(tree, tree2, 0);
	tr_order_core(tree2);
	n = tr_expand_node(tree2, node2);
	for (i = 0; i < n - 1; ++i) {
		if (tag) {
			sprintf(str, "%f", node2[i]->d);
			cpp_insert_keyval(node[i], tag, str);
		} else node[i]->d = node2[i]->d;
	}
	tr_delete_tree(tree2);
	free(node); free(node2);
}
static int tr_estlen_usage()
{
	fprintf(stderr, "Usage: treebest estlen <tree> <matrix> <tag>\n");
	return 1;
}
int tr_estlen_task(int argc, char *argv[])
{
	extern FILE *tr_get_fp(const char *fn);
	FILE *fp, *fpmat;
	Matrix *mat;
	Tree *tree;
	
	if (argc < 4) return tr_estlen_usage();
	fp = tr_get_fp(argv[1]);
	fpmat = tr_get_fp(argv[2]);
	tree = tr_parse_first(fp);
	mat = tr_read_matrix(fpmat);
	tr_est_len(tree, mat, argv[3]);
	tr_tree_output(stdout, tree, OUTPUT_SDI | OUTPUT_ORI_NHX);
	tr_delete_matrix(mat);
	tr_delete_tree(tree);
	return 0;
}
