#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <unistd.h>
#include <time.h>
#include "cpp_utils.h"
#include "tree.h"
#include "utils.h"
#include "align.h"

Task *tr_alloc_task()
{
	Task *t;
	t = (Task*)malloc(sizeof(Task));
	t->func = 0;
	t->fp_dist = t->fp_align = 0;
	t->n_con = t->n_sub = 0;
	t->node_mode = 1;
	t->bs_time = 100;
	t->dist_type = DIST_MM;
	t->constraint = 0;
	t->compared = 0;
	t->tree = t->subtree = t->spec_tree = 0;
	t->sub_name = 0;
	t->rooting = 1;
	t->is_mask_segment = 1;
	t->out_flag = OUTPUT_SDI; /* default output: indent NHX output */
	t->aln = 0;
	t->is_pseudo_ortho = 1;
	t->is_aln = 0;
	t->is_mask = 1;
	t->init_cons = 1;
	t->ortho = 0;
	t->is_verbose = 0;
	t->is_sdi_root = 1;
	t->is_reorder = 1;
	t->is_strong_con = 0;
	t->real_bs_time = 0;
	t->time_limit = 0;
	t->cut = (char*)malloc(sizeof(char) * (strlen("Bilateria") + 1));
	strcpy(t->cut, "Bilateria");
	t->filter = 15;
	t->is_collapse = 0;
	return t;
}
void tr_delete_task(Task *t)
{
	if (t->aln) ma_free(t->aln);
	if (t->spec_tree) {
		tr_delete_tree_SDIptr(t->tree);
		if (t->subtree) tr_delete_tree_SDIptr(t->subtree);
		tr_delete_tree(t->spec_tree);
	}
	if (t->tree) tr_delete_tree_SDIptr(t->tree);
	if (t->compared) tr_delete_tree(t->compared);
	if (t->subtree && tr_search(t->tree, t->subtree) == 0) /* not a node in t->tree */
		tr_delete_tree(t->subtree);
	if (t->tree) tr_delete_tree(t->tree);
	if (t->cut) free(t->cut);
	if (t->ortho) tr_delete_ortho(t->ortho);
	if (t->n_con) {
		int i;
		for (i = 0; i < t->n_con; ++i)
			tr_delete_tree(t->constraint[i]);
		free(t->constraint);
	}
	if (t->n_sub) {
		int i;
		for (i = 0; i < t->n_sub; ++i)
			free(t->sub_name[i]);
		free(t->sub_name);
	}
	free(t);
}
FILE *tr_get_fp(const char *fn)
{
	if (*fn == '-' && fn[1] == '\0')
		return stdin;
	else {
		FILE *fp = fopen(fn, "r");
		if (fp == 0) {
			fprintf(stderr, "[tr_get_fp] fail to open file %s\n", fn);
			exit(1);
		}
		return fp;
	}
	return 0;
}
char **tr_get_list_str(char *str, int *n)
{
	char *s, *t;
	char **list;
	int i, j, max;

	i = max = 0;
	s = t = str;
	list = 0;
	do {
		if (*s == ',' || *s == 0) {
			if (s == t) continue;
			if (i == max) {
				max += 16;
				list = (char**)realloc(list, sizeof(char*) * max);
			}
			list[i] = (char*)malloc(sizeof(char) * (s - t + 1));
			for (j = 0; t < s; ++t) list[i][j++] = *t;
			list[i][j] = 0;
			++t; ++i;
		}
	} while (*s++);
	*n = i;
	return list;
}
char **tr_get_list(const char *fn, int *n)
{
	int i, max;
	char name[256], **list;
	FILE *fp;

	fp = tr_get_fp(fn);
	if (fp == 0) return 0;
	i = max = 0;
	list = 0;
	while (!feof(fp) && fscanf(fp, "%s", name) == 1) {
		if (i == max) {
			max += 256;
			list = (char**)realloc(list, sizeof(char*) * max);
		}
		list[i] = (char*)malloc(sizeof(char) * (strlen(name) + 1));
		strcpy(list[i++], name);
	}
	fclose(fp);
	*n = i;
	return list;
}
int tr_fill_spec(Task *task, const char *fn)
{
	FILE *fp;
	Tree **spec;
	int i, n;

	fp = tr_get_fp(fn);
	if (fp == 0) return 1;
	spec = tr_parse(fp, &n);
	task->spec_tree = spec[0];
	for (i = 1; i < n; ++i)
		tr_delete_tree(spec[i]);
	free(spec);
	task->spec_tree = cpp_post_spec_tree(task->spec_tree, 0);
	if (fp != stdin) fclose(fp);
	return 0;
}
int tr_fill_sub(Task *task, const char *fn)
{
	task->sub_name = tr_get_list(fn, &(task->n_sub));
	return 0;
}
int tr_fill_con(Task *task, const char *fn)
{
	FILE *fp;
	fp = tr_get_fp(fn);
	if (fp == 0) return 1;
	task->constraint = tr_parse(fp, &(task->n_con));
	if (fp != stdin) fclose(fp);
	return 0;
}
int tr_fill_compared(Task *task, const char *fn)
{
	FILE *fp;
	Tree **p;
	int i, n;
	fp = tr_get_fp(fn);
	if (fp == 0) return 1;
	p = tr_parse(fp, &n);
	if (p == 0 || n == 0) {
		fprintf(stderr, "[tr_fill_compared] fail to open file %s.\n", fn);
		return 1;
	}
	if (fp != stdin) fclose(fp);
	task->compared = p[0];
	for (i = 1; i < n; ++i)
		tr_delete_tree(p[i]);
	free(p);
	task->out_flag |= OUTPUT_COMPARE;
	return 0;
}
int tr_fill_con_sub(Task *task)
{
	int i, j, k, n;
	char **list;
	Tree **node;

	n = 0;
	for (i = 0; i < task->n_con; ++i)
		n += task->constraint[i]->n_leaf;
	task->n_sub = n;
	task->sub_name = list = (char**)malloc(sizeof(char*) * n);
	node = (Tree**)malloc(sizeof(Tree*) * n);
	for (i = k = 0; i < task->n_con; ++i) {
		tr_expand_leaf(task->constraint[i], node);
		for (j = 0; j < task->constraint[i]->n_leaf; ++j, ++k) {
			list[k] = (char*)malloc(sizeof(char) * (strlen(node[j]->name) + 1));
			strcpy(list[k], node[j]->name);
		}
	}
	free(node);
	return 0;
}
int tr_fill_tree(Task *task, const char *fn)
{
	FILE *fp;
	int i, n;
	Tree **root;
	fp = tr_get_fp(fn);
	if (fp == 0) return 1;
	root = tr_parse(fp, &n);
	if (fp != stdin) fclose(fp);
	task->tree = root[0];
	for (i = 1; i < n; ++i)
		tr_delete_tree(root[i]);
	free(root);
	return 0;
}
int tr_fill_fp(Task *task, const char *fn)
{
	FILE *fp;
	int c;
	
	c = 0;
	fp = tr_get_fp(fn);
	if (fp == 0) return 1;
	while (!feof(fp)) {
		c = fgetc(fp);
		if (c == ' ' || c == '\t' || c == '\n') continue;
		ungetc(c, fp);
		break;
	}
	if (isdigit(c)) {
		task->fp_dist = fp; /* BE CAREFUL: sometimes this might be wrong!!! */
		task->bs_time = 0;
	} else task->fp_align = fp;
	return 0;
}
/*
 * sutree task
 */
static int tr_subtree_usage()
{
	fprintf(stderr, "Usage: treebest subtree <tree> <list>\n");
	return 1;
}
int tr_subtree_task(int argc, char *argv[])
{
	char **name;
	int n, m, i;
	FILE *fp_tree;
	Tree **tree;

	if (argc < 3) return tr_subtree_usage();
	name = tr_get_list(argv[2], &m);
	fp_tree = tr_get_fp(argv[1]);
	tree = tr_parse(fp_tree, &n);
	for (i = 0; i < n; ++i) {
		Tree *sub;
		sub = cpp_subtree(tree[i], m, name);
		tr_tree_output(stdout, sub, OUTPUT_SDI);
		tr_delete_tree(sub);
		tr_delete_tree(tree[i]);
	}
	fclose(fp_tree);
	for (i = 0; i < m; ++i) free(name[i]);
	free(name);
	free(tree);
	return 0;
}
/*
 * treedist task
 */
static int tr_treedist_usage()
{
	fprintf(stderr, "Usage: treebest treedist <tree1> <tree2>\n");
	return 1;
}
int tr_treedist_task(int argc, char *argv[])
{
	Tree *tree1, *tree2;
	FILE *fp1, *fp2;
	int ret;

	if (argc < 3) return tr_treedist_usage();
	fp1 = tr_get_fp(argv[1]);
	fp2 = tr_get_fp(argv[2]);
	tree1 = tr_parse_first(fp1);
	tree2 = tr_parse_first(fp2);
	ret = tr_tree_dist(tree1, tree2);
	fclose(fp1); fclose(fp2);
	tr_delete_tree(tree1); tr_delete_tree(tree2);
	printf("%d\t%d\n", ret>>16, ret&0xffff);
	return 0;
}
/*
 * SDI task: speciation/duplication inference
 */
static int tr_sdi_usage()
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Usage  : treebest sdi [-r|-H|-R|-m <tree0>|-l <spec_list>] <tree>\n\n");
	fprintf(stderr, "Options: -r         reroot\n");
	fprintf(stderr, "         -c         use core species tree instead of the default one\n");
	fprintf(stderr, "         -H         reroot by minimizing tree height, instead of by\n");
	fprintf(stderr, "                    minimizing the number of duplication events.\n");
	fprintf(stderr, "         -R         do not reorder the leaves.\n");
	fprintf(stderr, "         -s FILE    species tree [default taxa tree]\n");
	fprintf(stderr, "         -l FILE    cut a subtree that contains genes whose species exist in list [null]\n");
	fprintf(stderr, "         -m FILE    compare topology with FILE and re-order the leaves [null]\n\n");
	return 1;
}
int tr_sdi_task(int argc, char *argv[])
{
	extern Tree *tr_default_spec_tree();
	Tree **root, *spec_tree, **compared, *tmp_tree;
	FILE *fp, *fp_comp, *fp_spec;
	int i, k, n, m, c, is_reroot, is_sdi_root, is_reorder, is_core;
	char **name;
	int out_flag = OUTPUT_SDI;
	
	is_core = is_reroot = 0;
	is_sdi_root = is_reorder = 1;
	fp_comp = 0;
	compared = 0;
	spec_tree = 0;
	m = k = 0;
	name = 0;
	tmp_tree = 0;
	while ((c = getopt(argc, argv, "cRrHm:l:s:")) >= 0) {
		switch (c) {
			case 'r': is_reroot = 1; break;
			case 'H': is_sdi_root = 0; break;
			case 'R': is_reorder = 0; break;
			case 'c': is_core = 1; break;
			case 's': fp_spec = tr_get_fp(optarg);
					  if (fp_spec) {
						  spec_tree = tr_parse_first(fp_spec);
						  fclose(fp_spec);
						  cpp_post_spec_tree(spec_tree, 0);
					  }
					  break;
			case 'l': name = tr_get_list_str(optarg, &k); break;
			case 'm': fp_comp = tr_get_fp(optarg);
					  if (!fp_comp) fprintf(stderr, "<tr_sdi_task> fail to open file %s, continue anyway.\n", optarg);
					  break;
		}
	}
	if (argc == optind) return tr_sdi_usage();
	/* if "-l" is applied, all the other functions except "-m" will be turned off. */
	if (k) is_reroot = is_sdi_root = is_reorder = 0;
	fp = tr_get_fp(argv[optind]);
	root = tr_parse(fp, &n);
	if (fp_comp) compared = tr_parse(fp_comp, &m);
	if (!spec_tree) spec_tree = (is_core)? tr_core_spec_tree() : tr_default_spec_tree();
	if (m) out_flag |= OUTPUT_COMPARE;
	for (i = 0; i < n; ++i) {
		if (is_reroot) {
			if (is_sdi_root) root[i] = tr_root_by_sdi(root[i], spec_tree);
			else root[i] = tr_root_by_min_height(root[i]);
		}
		tr_SDI(root[i], spec_tree, 0);
		tr_lost_infer(root[i], spec_tree);
		if (k) {
			Tree *sub = cpp_subtree_spec(root[i], spec_tree, k, name);
			tmp_tree = root[i];
			root[i] = sub;
		}
		if (is_reorder) {
			tr_set_spec_leaf_order(root[i]);
			tr_order_core(root[i]);
		}
		if (i < m) {
			tr_compare_core(compared[i], root[i], 0);
			cpp_set_leaf_order(compared[i], root[i], 0);
			tr_order_core(root[i]);
		}
		tr_tree_output(stdout, root[i], out_flag);
		if (k) {
			/* if "-l" is used, it is tmp_tree that keeps all the allocated pointers,
			 * while root[i] only keeps part. When tmp_tree->ptr is freed, there is also
			 * no need to free root[i]->ptr. */
			tr_delete_tree_SDIptr(tmp_tree);
			tr_delete_tree(tmp_tree);
			tr_clear_ptr(root[i]);
		} else tr_delete_tree_SDIptr(root[i]);
		tr_delete_tree(root[i]);
	}
	if (compared)
		for (i = 0; i < m; ++i)
			tr_delete_tree(compared[i]);
	tr_delete_tree(spec_tree);
	free(root); free(compared);
	if (fp_comp && fp_comp != stdin) fclose(fp_comp);
	if (fp != stdin) fclose(fp);
	if (k)
		for (i = 0; i < k; ++i) free(name[i]);
	free(name);
	return 0;
}
/*
 * Ortholog inference
 */
static int tr_ortho_usage()
{
	fprintf(stderr, "Usage: treebest ortho <tree>\n");
	return 1;
}
int tr_ortho_task(int argc, char *argv[])
{
	extern Tree *tr_default_spec_tree();
	Tree **root, *spec_tree;
	FILE *fp;
	int i, n;
	Ortholog *ortho;

	if (argc == 1) return tr_ortho_usage();
	fp = tr_get_fp(argv[1]);
	root = tr_parse(fp, &n);
	spec_tree = tr_default_spec_tree();
	for (i = 0; i < n; ++i) {
		tr_SDI(root[i], spec_tree, 0);
		ortho = tr_ortho(root[i], spec_tree, 1);
		tr_ortho_output(stdout, ortho, root[i]);
		tr_delete_ortho(ortho);
		tr_delete_tree_SDIptr(root[i]);
		tr_delete_tree(root[i]);
	}
	tr_delete_tree(spec_tree);
	free(root);
	return 0;
}
static int tr_root_usage()
{
	fprintf(stderr, "Usage: treebest root <tree>\n");
	return 1;
}
int tr_root_task(int argc, char *argv[])
{
	Tree **root;
	FILE *fp;
	int i, n;

	if (argc == 1) return tr_root_usage();
	fp = tr_get_fp(argv[1]);
	root = tr_parse(fp, &n);
	for (i = 0; i < n; ++i) {
		root[i] = tr_root_by_min_height(root[i]);
		tr_tree_output(stdout, root[i], OUTPUT_SDI | OUTPUT_ORI_NHX);
		tr_delete_tree(root[i]);
	}
	free(root);
	if (fp != stdin) fclose(fp);
	return 0;
}
/*
 * reformat
 */
static int tr_reformat_usage()
{
	fprintf(stderr, "Usage:   treebest format [-1] <tree>\n");
	return 1;
}
int tr_reformat_task(int argc, char *argv[])
{
	int c;
	int one_line = 0;
	FILE *fp;

	while ((c = getopt(argc, argv, "1")) >= 0) {
		switch (c) {
			case '1': one_line = 1; break;
		}
	}
	if (argc == optind) return tr_reformat_usage();
	fp = tr_get_fp(argv[optind]);
	if (!one_line) {
		while (!feof(fp)) {
			c = fgetc(fp);
			if (c == EOF) break;
			if (c == '\\') c = fgetc(fp); /* escape */
			else if (c == ' ' || c == '\t' || c == '\r' || c == '\n') continue;
			else if (c == '(' || c == ',' || c == ';') { putchar(c); putchar('\n'); }
			else if (c == ')') { putchar('\n'); putchar(')'); }
			else putchar(c);
		}
	} else { /* one-line output */
		while (!feof(fp)) {
			c = fgetc(fp);
			if (c == EOF) break;
			if (c == '\\') c = fgetc(fp); /* escape */
			else if (c == ' ' || c == '\t' || c == '\r' || c == '\n') continue;
			else putchar(c);
		}
		putchar('\n');
	}
	if (fp != stdin) fclose(fp);
	return 0;
}
static int tr_filter_usage()
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Usage:   treebest filter [options] <alignment>\n\n");
	fprintf(stderr, "Options: -n         nucleotide alignment\n");
	fprintf(stderr, "         -g         collapse alternative splicing\n");
	fprintf(stderr, "         -M         do not apply alignment mask\n");
	fprintf(stderr, "         -N         do not mask low-scoring segments\n");
	fprintf(stderr, "         -F NUM     quality cut-off [15]\n\n");
	return 1;
}
int tr_filter_task(int argc, char *argv[])
{
	int c, is_collapse = 0;
	int is_nucl = 0;
	int cut_off = 15;
	FILE *fp;
	int is_mask = 1;
	int is_mask_segments = 1;
	MultiAlign *ma;

	while ((c = getopt(argc, argv, "F:ngMN")) >= 0) {
		switch (c) {
			case 'n': is_nucl = 1; break;
			case 'g': is_collapse = 1; break;
			case 'N': is_mask_segments = 0; break;
			case 'M': is_mask = 0; break;
			case 'F': cut_off = atoi(optarg); break;
		}
	}
	if (optind == argc) return tr_filter_usage();
	fp = tr_get_fp(argv[optind]);
	ma = ma_read_alignment(fp, is_nucl);
	if (is_mask) ma_apply_mask(ma);
	ma_filter(ma, is_collapse, cut_off, is_mask_segments);
	tr_align_output(stdout, ma);
	ma_free(ma);
	if (fp != stdin) fclose(fp);
	return 0;
}
/*
 * mfa2aln: convert multi-fasta to aln (clustalw) format
 */
static int tr_mfa2aln_usage()
{
	fprintf(stderr, "Usage: treebest mfa2aln [-n] <fasta_align>\n");
	return 1;
}
int tr_mfa2aln_task(int argc, char *argv[])
{
	MultiAlign *ma;
	FILE *fp;
	int c, is_nucl = 0;
	
	while ((c = getopt(argc, argv, "n")) >= 0) {
		switch (c) {
			case 'n': is_nucl = 1; break;
		}
	}
	if (optind == argc) return tr_mfa2aln_usage();
	fp = tr_get_fp(argv[optind]);
	ma = ma_read_alignment(fp, is_nucl);
	tr_align_aln_output(stdout, ma);
	ma_free(ma);
	if (fp != stdin) fclose(fp);
	return 0;
}
/*
 * leaf task: get external nodes of a tree
 */
static int tr_leaf_usage()
{
	fprintf(stderr, "Usage: treebest leaf <nh_tree>\n");
	return 1;
}
int tr_leaf_task(int argc, char *argv[])
{
	Tree **node, **root;
	int i, m, n;
	FILE *fp;

	if (argc == 1) return tr_leaf_usage();
	fp = tr_get_fp(argv[1]);
	root = tr_parse(fp, &n);
	node = tr_stack(root[0], Tree*);
	m = tr_expand_leaf(root[0], node);
	for (i = 0; i < m; ++i) {
		if (node[i]->name)
			printf("%s\n", node[i]->name);
		else printf("NULL\n");
	}
	for (i = 0; i < n; ++i)
		tr_delete_tree(root[i]);
	free(root);
	free(node);
	if (fp != stdin) fclose(fp);
	return 0;
}
/*
 * Task: translate coding nucleotide to protein alignment
 */
static int tr_trans_usage()
{
	fprintf(stderr, "Usage: treebest trans <nucl_alignment>\n");
	return 1;
}
int tr_trans_task(int argc, char *argv[])
{
	FILE *fp;
	MultiAlign *ma, *tma;

	if (argc == 1) return tr_trans_usage();
	fp = tr_get_fp(argv[1]);
	tma = ma_read_alignment(fp, 1);
	ma = ma_trans_align(tma, 1); /* translate to amino acids */
	tr_align_output(stdout, ma);
	ma_free(ma);
	ma_free(tma);
	if (fp != stdin) fclose(fp);
	return 0;
}
/*
 * Task: calculate distance matrix
 */
static int tr_distmat_usage()
{
	fprintf(stderr, "Usage: treebest distmat <dn|ds|dm|jtt|kimura|mm|dns> <alignment>\n");
	return 1;
}
int tr_distmat_task(int argc, char *argv[])
{
	extern Matrix *ma_init_matrix(const MultiAlign *ma);
	extern void ma_init_nucl_data();
	int type = -1;
	int is_nucl = 0;
	DistParam *dp;
	MultiAlign *ma;
	Matrix *mat;
	FILE *fp;

	if (argc < 3) return tr_distmat_usage();
	if (strcmp(argv[1], "dn") == 0) { type = DIST_DN; is_nucl = 1; }
	else if (strcmp(argv[1], "ds") == 0) { type = DIST_DS; is_nucl = 1; }
	else if (strcmp(argv[1], "dm") == 0) { type = DIST_DM; is_nucl = 1; }
	else if (strcmp(argv[1], "jtt") == 0) type = DIST_JTT;
	else if (strcmp(argv[1], "kimura") == 0) type = DIST_KIMURA;
	else if (strcmp(argv[1], "mm") == 0) type = DIST_MM;
	else if (strcmp(argv[1], "dns") == 0) { type = -1; is_nucl = 1; }
	else {
		fprintf(stderr, "ERROR: unrecognized type %s\n", argv[1]);
		return 1;
	}
	
	fp = tr_get_fp(argv[2]);
	ma = ma_read_alignment(fp, is_nucl);
	if (is_nucl) { /* special consideration for nucleotide alignment */
		MultiAlign *ma_tmp;
		ma_init_nucl_data();
		ma_tmp = ma;
		ma = ma_trans_align(ma_tmp, 0);
		if (ma == 0) {
			fprintf(stderr, "ERROR: it seems that your input contains errors!\n");
			return 1;
		}
		ma_free(ma_tmp);
	}
	mat = ma_init_matrix(ma);
	if (type >= 0) {
		dp = ma_alloc_DistParam(type);
		ma_cal_dist(mat, ma, 0, dp);
		tr_matrix_output(stdout, mat);
		ma_free_DistParam(dp);
	} else {
		Matrix *mat_ds;
		int i, j;
		float *p_dn, *p_ds;

		/* calculate dn */
		dp = ma_alloc_DistParam(DIST_DN);
		ma_cal_dist(mat, ma, 0, dp);
		ma_free_DistParam(dp);

		/* calculate ds */
		mat_ds = ma_init_matrix(ma);
		dp = ma_alloc_DistParam(DIST_DS);
		ma_cal_dist(mat_ds, ma, 0, dp);
		ma_free_DistParam(dp);

		for (i = 0; i < ma->n; ++i) {
			p_dn = mat->dist + i * ma->n;
			p_ds = mat_ds->dist + i * ma->n;
			for (j = 0; j < i; ++j)
				printf("%.6f\t%.6f\t%s\t%s\n", p_dn[j], p_ds[j], ma->name[i], ma->name[j]);
		}
		tr_delete_matrix(mat_ds);
	}
	ma_free(ma);
	tr_delete_matrix(mat);
	if (fp != stdin) fclose(fp);
	return 0;
}
static int tr_sortleaf_usage()
{
	fprintf(stderr, "Usage: treebest sortleaf <tree1> [<tree2>]\n");
	return 1;
}
int tr_sortleaf_task(int argc, char *argv[])
{
	extern Tree *tr_default_spec_tree();
	Tree **forest, *tree, *spec_tree;
	int i, n;
	FILE *fp;

	if (argc < 2) return tr_sortleaf_usage();
	fp = tr_get_fp(argv[1]);
	forest = tr_parse(fp, &n);
	fclose(fp);
	tree = 0;
	if (argc > 2) {
		fp = tr_get_fp(argv[2]);
		tree = tr_parse_first(fp);
		fclose(fp);
	}
	spec_tree = tr_default_spec_tree();
	for (i = 0; i < n; ++i) {
		if (tree) cpp_set_leaf_order(tree, forest[i], forest[i]->n_leaf);
		else {
			tr_SDI(forest[i], spec_tree, 0);
			tr_set_spec_leaf_order(forest[i]);
		}
		tr_order_core(forest[i]);
		tr_tree_output(stdout, forest[i], OUTPUT_SDI | OUTPUT_ORI_NHX);
		if (tree) tr_delete_tree_SDIptr(forest[i]);
		tr_delete_tree(forest[i]);
	}
	free(forest);
	if (tree) tr_delete_tree(tree);
	return 0;
}
/*
 * Task: build tree from nt/aa alignment or from distance matrix
 */
static int tr_build_usage()
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Usage  : treebest nj [options] <input_file>\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "Options: -c FILE    constrained tree(s) in NH format [null]\n");
	fprintf(stderr, "         -m FILE    tree to be compared [null]\n");
	fprintf(stderr, "         -s FILE    species tree in NH format [default taxa tree]\n");
	fprintf(stderr, "         -l FILE    ingroup list file [null]\n");
	fprintf(stderr, "         -t TYPE    codon NT: ntmm, dn, ds, dm; AA: mm, jtt, kimura [mm]\n");
	fprintf(stderr, "                    ntmm    p-distance (codon alignment)\n");
	fprintf(stderr, "                    dn      non-synonymous distance\n");
	fprintf(stderr, "                    ds      synonymous distance\n");
	fprintf(stderr, "                    dm      dn-ds merge (tree merge)\n");
	fprintf(stderr, "                    mm      p-distance (amino acid alignment)\n");
	fprintf(stderr, "                    jtt     JTT model (maximum likelihood)\n");
	fprintf(stderr, "                    kimura  mm + Kimura's correction\n");
	fprintf(stderr, "         -T NUM     time limit in seconds [no limit]\n");
	fprintf(stderr, "         -b NUM     bootstrapping times [100]\n");
	fprintf(stderr, "         -F NUM     quality cut-off [15]\n");
	fprintf(stderr, "         -o STR     outgroup for tree cutting [Bilateria]\n");
	fprintf(stderr, "         -S         treat the first constrained tree as the original tree\n");
	fprintf(stderr, "         -C         use the leaves of constrained trees as ingroup\n");
	fprintf(stderr, "         -M         do not apply alignment mask\n");
	fprintf(stderr, "         -N         do not mask poorly aligned segments\n");
	fprintf(stderr, "         -g         collapse alternative splicing\n");
	fprintf(stderr, "         -R         do not apply leaf-reordering\n");
	fprintf(stderr, "         -p         the root node is a putative node\n");
	fprintf(stderr, "         -a         branch mode that is used by most tree-builder\n");
	fprintf(stderr, "         -A         the input alignment is stored in ALN format\n");
	fprintf(stderr, "         -W         wipe out root (SDI information will be lost!)\n");
	fprintf(stderr, "         -v         verbose output\n");
	fprintf(stderr, "         -h         help\n\n");
	exit(1);
}
int tr_build(int argc, char *argv[])
{
	int c, is_ingroup = 0, is_no_root = 0;
	Task *task;

#ifdef _WIN32
	srand(time(0)); /* initialize the seed */
#else
	srand48(time(0)); /* initialize the seed */
#endif
	task = tr_alloc_task();
	while ((c = getopt(argc, argv, "b:s:c:t:ahl:o:F:vT:Apm:CRMgSNW")) >= 0) {
		switch (c) {
			case 'A': task->is_aln = 1; break;
			case 'S': task->is_strong_con = 1; break;
			case 'b': task->bs_time = atoi(optarg); break;
			case 's': tr_fill_spec(task, optarg); break;
			case 'c': tr_fill_con(task, optarg); break;
			case 'm': tr_fill_compared(task, optarg); break;
			case 'C': is_ingroup = 1; break;
			case 'M': task->is_mask = 0; break;
			case 'N': task->is_mask_segment = 0; break;
			case 't': if (strcmp(optarg, "jtt") == 0)
						  task->dist_type = DIST_JTT;
					  else if (strcmp(optarg, "kimura") == 0)
						  task->dist_type = DIST_KIMURA;
					  else if (strcmp(optarg, "mm") == 0)
						  task->dist_type = DIST_MM;
					  else if (strcmp(optarg, "dn") == 0)
						  task->dist_type = DIST_DN;
					  else if (strcmp(optarg, "ds") == 0)
						  task->dist_type = DIST_DS;
					  else if (strcmp(optarg, "dm") == 0)
						  task->dist_type = DIST_DM;
					  else if (strcmp(optarg, "ntmm") == 0)
						  task->dist_type = DIST_NT_MM;
					  else {
						  fprintf(stderr, "Unrecognized method: %s\n", optarg);
						  exit(2);
					  }
					  break;
			case 'T': task->time_limit = atoi(optarg); break;
			case 'o': if (task->cut) free(task->cut);
					  task->cut = (char*)malloc(sizeof(char) * (strlen(optarg) + 1));
					  strcpy(task->cut, optarg);
					  break;
			case 'l': tr_fill_sub(task, optarg); break;
			case 'a': task->node_mode = 0; break;
			case 'F': task->filter = atoi(optarg); break;
			case 'v': task->is_verbose = 1; break;
			case 'R': task->is_reorder = 0; break;
			case 'g': task->is_collapse = 1; break;
			case 'p': task->init_cons = 0; break;
			case 'W': is_no_root = 1; break;
			case 'h': tr_build_usage(); break;
			default: tr_build_usage();
		}
	}
	if (is_ingroup && task->n_sub == 0 && task->n_con)
		tr_fill_con_sub(task);
	if (optind == argc) {
		tr_delete_task(task);
		return tr_build_usage();
	}
	if (task->spec_tree == 0) task->spec_tree = tr_default_spec_tree();
	tr_fill_fp(task, argv[optind]);
	tr_build_tree(task);
	if (is_no_root) task->tree = tr_remove_root(task->tree);
	tr_task_output(stdout, task);
	tr_delete_task(task);
	return 0;
}
