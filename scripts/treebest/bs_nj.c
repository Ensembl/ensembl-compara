#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include "tree.h"
#include "align.h"
#include "utils.h"
#include "cpp_utils.h"
#include "phyml.h"

extern void ma_init_nucl_data();
extern void ma_free_nucl_data();

int tr_is_has_spec(const MultiAlign *ma, const Tree *spec);
void cpp_set_leaf_order(Tree *src, Tree *dst, int def_val);
Tree *tr_build_tree_from_matrix(Matrix *mat, int n_cons, Tree **cons, int init_cons, Tree *spec, int is_sdi_root);
Tree *tr_build_tree_from_align(MultiAlign *ma, int n_cons, Tree **cons, int init_cons, Tree *spec,
		int dist_type, int is_sdi_root, int is_rand);

/* core function in building a tree */
Tree *tr_build_tree(Task *task)
{
	int n, k;
	Tree *tree;
	int is_nucl, n_spec;
	MultiAlign *ma_bak = 0;

	assert(task);
	is_nucl = (task->dist_type == DIST_DN || task->dist_type == DIST_DS || task->dist_type == DIST_DM
				|| task->dist_type == DIST_NT_MM)? 1 : 0;

	if (task->fp_align == 0) {
		Matrix *mat;
		assert(task->fp_dist);
		mat = tr_read_matrix(task->fp_dist);
		if (mat == 0) {
			fprintf(stderr, "[tr_build_tree] fail to read matrix.\n");
			return 0;
		}
		task->tree = tree = tr_build_tree_from_matrix(mat, task->n_con, task->constraint, task->init_cons,
				task->spec_tree, 1); /* simply use sdi-rooting */
		tr_delete_matrix(mat);
		return tree;
	}
	if (task->fp_align) task->aln = ma_read(task->fp_align, is_nucl, task->is_aln);
	if (task->aln == 0) return 0;
	/* read alignment and build distance matrix */
	if (task->is_mask) ma_apply_mask(task->aln);
	ma_filter(task->aln, task->is_collapse, task->filter, task->is_mask_segment);
	if (is_nucl) { /* backup task->aln */
		ma_init_nucl_data();
		ma_bak = task->aln;
		task->aln = ma_trans_align(ma_bak, 0); /* just convert to codon, but do not translate */
		if (task->aln == 0) {
			ma_free(ma_bak);
			return 0;
		}
	}
	n = task->aln->n;
	n_spec = tr_is_has_spec(task->aln, task->spec_tree);
	task->is_sdi_root = (n_spec > 2)? 1 : 0;
	if (n_spec == 0) fprintf(stderr, "[tr_build_tree] no species information is available\n");

	/* build tree */
	if (task->n_con == 1 && task->constraint[0] && task->is_strong_con && task->constraint[0]->n_leaf == task->aln->n) {
		/* then, do not build new tree */
		int tmp_n;
		tree = tr_copy_tree(task->constraint[0]);
		tmp_n = cpp_attach_id_by_name(tree, task->aln->n, task->aln->name);
		if (tmp_n != task->aln->n)
			fprintf(stderr, "[tr_build_tree] the constrained tree is inconsistent with the alignment\n");
		if (tree->n == 2) tr_slide_binary_root(tree);
		if (task->is_sdi_root && task->spec_tree) tree = tr_root_by_sdi(tree, task->spec_tree);
		else tree = tr_root_by_min_height(tree);
		tr_SDI(tree, task->spec_tree, 0);
		tr_lost_infer(tree, task->spec_tree);
	} else {
		if (task->is_strong_con)
			fprintf(stderr, "[tr_build_tree] fail to treat the constrained tree as the original tree\n");
		tree = tr_build_tree_from_align(task->aln, task->n_con, task->constraint, task->init_cons, task->spec_tree,
			task->dist_type, task->is_sdi_root, 0);
	}
	task->ortho = tr_ortho(tree, task->spec_tree, task->is_pseudo_ortho); /* find ortholog */
	tr_delete_tree_SDIptr(tree); /* Tree::ptr is useless now. Free it for bootstrap */
	/* In fltreebest, task->func is used to show the progress of bootstrapping */
	if (task->func) task->func(1.0 / (1.0 + task->bs_time));

	if (task->bs_time > 0) { /* bootstrap */
		clock_t start_time = clock();
		tr_pre_bootstrap(tree, task->node_mode); /* fill Tree::ptr */
		for (k = 0; k < task->bs_time; ++k) {
			Tree *bs_tree;
			Ortholog *bs_ortho;

			bs_tree = tr_build_tree_from_align(task->aln, 0, 0, 0, task->spec_tree,
					task->dist_type, task->is_sdi_root, 1);
			bs_ortho = tr_ortho(bs_tree, task->spec_tree, 0);
			tr_comp_ortho(task->ortho, bs_ortho);
			tr_delete_ortho(bs_ortho);
			tr_delete_tree_SDIptr(bs_tree); /* Tree::ptr is useless now. Free it for bootstrap */
			tr_pre_bootstrap(bs_tree, task->node_mode);
			tr_update_bootstrap(tree, bs_tree, task->node_mode);
			tr_delete_tree(bs_tree);
			if (task->time_limit > 0 && (double)(clock() - start_time) / CLOCKS_PER_SEC > task->time_limit) break;
			if (task->func) task->func((2.0 + k) / (1.0 + task->bs_time));
		}
		tr_delete_tree_ptr(tree); /* free Tree::ptr for SDI */
		task->real_bs_time = (k == task->bs_time)? k : k+1;
		/* fprintf(stderr, "Real bootstrap times: %d in %f seconds.\n", task->real_bs_time,
				(float)(clock() - start_time) / CLOCKS_PER_SEC); */
		tr_normalize_bs_value(tree, task->real_bs_time);
	}
	/* if DIST_DM is applied, calculate the branch lengths */
	if (task->dist_type == DIST_DM) {
		Matrix *mat = ma_init_small_matrix(ma_bak);
		ma_cal_mm_dist(mat, ma_bak, 0, 0, 0);
		tr_est_len(tree, mat, 0);
		free(mat->dist);
		free(mat);
	}
	/* now, redo SDI and lost inference as they have been removed when do bootstrapping. */
	tr_SDI(tree, task->spec_tree, 0);
	tr_lost_infer(tree, task->spec_tree);
	if (task->is_reorder && !task->compared) {
		tr_set_spec_leaf_order(tree);
		tr_order_core(tree);
	}
	if (task->compared) {
		tr_compare_core(task->compared, tree, 0);
		cpp_set_leaf_order(task->compared, tree, 0);
		tr_order_core(tree);
	}
	task->tree = tree;
	if (task->n_sub)
		tr_attach_seed_tag(tree, task->n_sub, task->sub_name);
	if (task->is_collapse)
		tr_attach_geneid(tree, task->aln);
	if (task->n_sub && task->cut) {
		task->subtree = tr_cut_tree(task->tree, task->spec_tree, task->n_sub, task->sub_name, task->cut);
		assert(task->subtree);
	}
	if (is_nucl) { /* if nucl alignment, convert to standard format */
		ma_free_nucl_data();
		ma_free(task->aln); /* delete temporary alignment */
		task->aln = ma_bak;
	}
	/* if (task->n_cons) tree->is_cons = 0; */
	return tree;
}
Tree *tr_root_tree(Tree *tree, Tree *spec)
{
	tree = (spec)? tr_root_by_sdi(tree, spec) : tr_root_by_min_height(tree);
	tr_SDI(tree, spec, 0);
	tr_lost_infer(tree, spec);
	return tree;
}
Tree *tr_build_tree_from_matrix(Matrix *mat, int n_cons, Tree **cons, int init_cons, Tree *spec, int is_sdi_root)
{
	Tree *tree;
	assert(mat);
	if (n_cons) assert(cons);
	tree = tr_nj(mat, n_cons, cons, init_cons);
	if (tree->n == 2) tr_slide_binary_root(tree);
	if (is_sdi_root && spec) tree = tr_root_by_sdi(tree, spec);
	else tree = tr_root_by_min_height(tree);
	if (n_cons) {
		int i;
		for (i = 0; i < n_cons; ++i)
			tr_compare_core(cons[i], tree, COMPARE_WRITE_INTERNAL_NAME);
	}
	tr_SDI(tree, spec, 0);
	tr_lost_infer(tree, spec);
	return tree;
}
Tree *tr_build_tree_from_align(MultiAlign *ma, int n_cons, Tree **cons, int init_cons, Tree *spec,
		int dist_type, int is_sdi_root, int is_rand)
{
	Tree *tree;
	Matrix *mat;
	int is_nucl;
	extern void ma_cal_nucl_aux(Matrix *mat, const MultiAlign *ma, int is_rand, int dist_type, Matrix *mat_dn);

	assert(ma);
	if (n_cons) assert(cons);
	mat = ma_init_small_matrix(ma);

	is_nucl = (dist_type == DIST_DN || dist_type == DIST_DS || dist_type == DIST_DM)? 1 : 0;
	if (dist_type != DIST_DM) {
		DistParam *dp;
		dp = ma_alloc_DistParam(dist_type);
		ma_cal_dist(mat, ma, is_rand, dp);
		tree = tr_build_tree_from_matrix(mat, n_cons, cons, init_cons, spec, is_sdi_root);
		ma_free_DistParam(dp);
	} else { /* dist_type == DIST_DM */
		Tree *forest[3];
		Matrix *mat_dn;
		int i;

		mat_dn = ma_init_small_matrix(ma);
		/* build dS and dN trees */
		ma_cal_nucl_aux(mat, ma, is_rand, DIST_DM, mat_dn);
		forest[1] = tr_build_tree_from_matrix(mat_dn, n_cons, cons, init_cons, spec, is_sdi_root);
		forest[2] = tr_build_tree_from_matrix(mat,    n_cons, cons, init_cons, spec, is_sdi_root);
		/* build mismatch tree. Note that it uses a different aligment! */
		ma_cal_mm_dist(mat, ma, is_rand, 0, 0);
		forest[0] = tr_build_tree_from_matrix(mat,    n_cons, cons, init_cons, spec, is_sdi_root);

		/* merge the three trees */
		tree = tr_mmerge(3, forest);
		cpp_attach_id_by_name(tree, ma->n, ma->name);
		tr_SDI(tree, spec, 0);
		tr_lost_infer(tree, spec);

		/* free trees */
		for (i = 0; i < 3; ++i) {
			tr_delete_tree_SDIptr(forest[i]);
			tr_delete_tree(forest[i]);
		}
		free(mat_dn->dist);
		free(mat_dn);
	}
	free(mat->dist);
	free(mat);
	return tree;
}
/* judge whether the alignment contains species infomation. */
int tr_is_has_spec(const MultiAlign *ma, const Tree *spec)
{
	Tree **node;
	int i, j, m, count;
	char *sp, *sq;

	if (spec == 0) return 0;
	assert(ma);
	node = tr_stack(spec, Tree*);
	m = tr_expand_leaf(spec, node);
	count = 0;
	for (i = 0; i < ma->n; ++i) {
		sq = ma->name[i];
		for (sp = sq + strlen(sq) - 1; sp >= sq; --sp)
			if (*sp == '_') break;
		++sp;
		if (sp != sq) {
			for (j = 0; j < m; ++j)
				if (strcmp(sp, node[j]->name) == 0) break;
			if (j < m) ++count;
		}
	}
	free(node);
	return count;
}
/* tree->ptr will be LOST!!! */
void tr_nj_bs(Tree *tree, MultiAlign *ma, Tree *spec_tree, int bs, int dist_type, int is_node)
{
	int i;
	tr_pre_bootstrap(tree, is_node);
	for (i = 0; i < bs; ++i) {
		Tree *bs_tree;
		bs_tree = tr_build_tree_from_align(ma, 0, 0, 0, spec_tree, dist_type, 1, 1);
		tr_delete_tree_SDIptr(bs_tree); /* Tree::ptr is useless now. Free it for bootstrap */
		tr_pre_bootstrap(bs_tree, is_node);
		tr_update_bootstrap(tree, bs_tree, is_node);
		tr_delete_tree(bs_tree);
	}
	tr_delete_tree_ptr(tree);
	tr_normalize_bs_value(tree, bs);
}
