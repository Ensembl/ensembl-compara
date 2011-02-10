#include <stdlib.h>
#include <stdio.h>
#include "tree.h"
#include "utils.h"
#include "cpp_utils.h"
#include "common/hash_char.h"

/* tr_SDI and tr_lost_infer must be applied */
int tr_qual(const Tree *tree)
{
	int i, n, score;
	int ndd_loss, ncd_loss, ns_loss, ncd, ns, ndd;
	Tree **node, *p;
	if (tree == 0) return 0;
	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	ndd_loss = ncd_loss = ns_loss = ncd = ns = ndd = 0;
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (p->n) { // internal node
			if (SDIptr(p)->type == 'S') ++ns;
			else {
				if (SDIptr(p)->is_confirmed_dup) ++ncd;
				else ++ndd;
			}
		}
		if (!p->pre) continue;
		if (SDIptr(p->pre)->type == 'S') ns_loss += SDIptr(p)->n_lost;
		else {
			if (SDIptr(p->pre)->is_confirmed_dup) ncd_loss += SDIptr(p)->n_lost;
			else ndd_loss += SDIptr(p)->n_lost;
		}
	}
	free(node);
	/* HERE IS THE FORMULAR */
	/**/ score = ns_loss * 5 + ncd_loss * 3 + ndd_loss * 1 - ns * 4 - ndd * 2; /**/
	return score;
}

/* tr_SDI and tr_lost_infer must be applied */
static Tree *tr_trim_few_leaf(Tree *tree, Tree *spec, int thres)
{
	int i, j, n;
	char *notrim;
	int score, min;
	Tree **node, *sub, *ret, *p;
	hash_set_char *notrim_set;

	if (tree == 0) return 0;
	min = tr_qual(tree) - thres;
	notrim_set = new hash_set_char;
	ret = 0;
	node = tr_stack(tree, Tree*);
	n = tr_expand_leaf(tree, node);
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (p->n == 0) {
			cpp_get_keyval(p, "NoTrim", &notrim);
			if (notrim && *notrim == 'Y') { /* do not trim */
				if (p->name) notrim_set->insert(p->name);
				free(notrim); continue;
			}
		}
		for (j = 0; j < n; ++j) node[j]->flag = 1;
		if (p->n == 0) p->flag = -1;
		else if (p->n == 2 && p->node[0]->n == 0 && p->node[1]->n == 0) { // allow to remove two leaves
			if (!notrim_set->find(p->node[0]->name) && !notrim_set->find(p->node[1]->name))
				p->node[0]->flag = p->node[1]->flag = -1;
		} else continue; // do nothing
		sub = cpp_subtree_aux(tree);
		tr_tree_init(sub); tr_attach_id(sub); tr_clear_ptr(sub);
		tr_SDI(sub, spec, 0); tr_lost_infer(sub, spec);
		score = tr_qual(sub);
		if (score < min) {
			min = score;
			if (ret) {
				tr_delete_tree_SDIptr(ret);
				tr_delete_tree(ret);
			}
			ret = sub;
		} else {
			tr_delete_tree_SDIptr(sub);
			tr_delete_tree(sub);
		}
	}
	if (ret) {
		for (i = 0; i < n; ++i)
			if (node[i]->n == 0 && notrim_set->find(node[i]->name))
				cpp_insert_keyval(node[i], "NoTrim", "Y");
	}
	delete notrim_set;
	free(node);
	return ret;
}
Tree *tr_trim_poor_leaves(const Tree *tree, Tree *spec, int thres)
{
	char *trim;
	Tree **node, *sub, *tmp;
	int i;
	node = tr_stack(tree, Tree*);
	tr_expand_leaf(tree, node);
	for (i = 0; i < tree->n_leaf; ++i) {
		cpp_get_keyval(node[i], "DoTrim", &trim);
		node[i]->flag = (trim && *trim == 'Y')? -1 : 1;
		free(trim);
	}
	sub = cpp_subtree_aux(tree);
	tr_tree_init(sub); tr_attach_id(sub); tr_clear_ptr(sub);
	tr_SDI(sub, spec, 0); tr_lost_infer(sub, spec);
	while ((tmp = tr_trim_few_leaf(sub, spec, thres))) {
		tr_delete_tree_SDIptr(sub);
		tr_delete_tree(sub);
		sub = tmp;
	}
	free(node);
	return sub;
}
extern "C"
{
FILE *tr_get_fp(const char *);
int tr_trimpoor_task(int argc, char *argv[]);
}
int tr_trimpoor_usage()
{
	fprintf(stderr, "treebest trimpoor <tree> [<threshold>=0]\n");
	return 1;
}
int tr_trimpoor_task(int argc, char *argv[])
{
	Tree *tree, *spec_ori, *rst, *spec;
	int thres = 0;
	FILE *fp;
	if (argc > 2) thres = atoi(argv[2]);
	if (argc == 1) return tr_trimpoor_usage();
	fp = tr_get_fp(argv[1]);
	tree = tr_parse_first(fp);
	fclose(fp);
	spec_ori = tr_default_spec_tree();
	spec = cpp_shrink_spec_by_tree(spec_ori, tree);
	tr_delete_tree(spec_ori);
	tr_SDI(tree, spec, 0); tr_lost_infer(tree, spec);
	rst = tr_trim_poor_leaves(tree, spec, thres);
	tr_tree_output(stdout, rst, OUTPUT_SDI);
	tr_delete_tree(spec);
	tr_delete_tree_SDIptr(tree);
	tr_delete_tree(tree);
	tr_delete_tree_SDIptr(rst);
	tr_delete_tree(rst);
	return 0;
}
