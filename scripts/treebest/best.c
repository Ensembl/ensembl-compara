#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "phyml.h"
#include "tree.h"
#include "cpp_utils.h"
#include "utils.h"
#include "best.h"

extern FILE *tr_get_fp(const char*);
extern void ma_init_nucl_data();
extern void ma_free_nucl_data();
extern Tree * tr_root_tree(Tree*, Tree*);
extern void tr_nj_bs(Tree *tree, MultiAlign *ma, Tree *spec_tree, int bs, int dist_type, int is_node);
extern int tr_is_has_spec(const MultiAlign *ma, const Tree *spec);
extern Tree *tr_build_tree_from_align(MultiAlign *ma, int n_cons, Tree **cons, int init_cons, Tree *spec,
		int dist_type, int is_sdi_root, int is_rand);

BestConfig *best_init_option()
{
	BestConfig *bo;
	bo = (BestConfig*)malloc(sizeof(BestConfig));
	bo->ma = 0;
	bo->ctree = bo->stree = 0;
	bo->is_sequenced_only = 0;
	bo->is_contract_stree = 0;
	bo->is_collapse_splice = 0;
	bo->is_phyml = 1;
	bo->is_debug = 0;
	bo->is_quiet = 0;
	bo->is_mask_lss = 1;
	bo->is_phyml_spec = 1;
	bo->is_phyml_cons = 0;
	bo->n_cat = 2;
	bo->qual_thres = 11;
	bo->prefix = 0;
	bo->output_fn = 0;
	bo->kappa = -1.0;
	bo->alpha = 1.0;
	bo->prob_dup = 0.15;
	bo->prob_loss_spec = 0.10;
	bo->prob_loss_dup = 0.20;
	bo->prob_not_exist = 0.01;
	return bo;
}
void best_free_option(BestConfig *bo)
{
	if (bo->ma) ma_free(bo->ma);
	if (bo->ctree) tr_delete_tree(bo->ctree);
	if (bo->stree) tr_delete_tree(bo->stree);
	if (bo->prefix) free(bo->prefix);
	if (bo->output_fn) free(bo->output_fn);
	free(bo);
}
static void write_tmp_tree(const char *prefix, const char *suffix, Tree *root)
{
	char *str;
	FILE *fp;
	str = (char*)malloc(sizeof(char) * (strlen(prefix)+strlen(suffix)+1));
	strcat(strcpy(str, prefix), suffix);
	fp = fopen(str, "w");
	if (fp) {
		tr_tree_output(fp, root, OUTPUT_SDI);
		fclose(fp);
	}
	free(str);
}
static PhymlConfig *init_PhymlConfig(BestConfig *bo)
{
	PhymlConfig *pc = phyml_init_config();
	if (bo->is_phyml_spec) pc->spec_tree = tr_copy_tree(bo->stree);
	if (bo->is_phyml_cons && bo->ctree) pc->ctree = tr_copy_tree(bo->ctree);
	pc->n_cat = bo->n_cat;
	pc->kappa = bo->kappa;
	pc->alpha = bo->alpha;
	pc->prob_dup = bo->prob_dup;
	pc->prob_loss_dup = bo->prob_loss_dup;
	pc->prob_loss_spec = bo->prob_loss_spec;
	pc->prob_not_exist = bo->prob_not_exist;
	return pc;
}
Tree *best_core(BestConfig *bo)
{
	clock_t c_begin;
	int n_spec = 0;
	PhymlConfig *pc = 0;
	Tree *tree, *t_phyml_aa, *t_phyml_nt, *t_nj_dn, *t_nj_ds, *t_nj_mm, *t_nj_dn_cons, *t_nj_mm_cons, *t_final;
	MultiAlign *tma;
	extern int lh3_revision_is_quiet;

	assert(bo->ma);
	assert(bo->stree);

	if (!bo->ma->is_nucl) {
		fprintf(stderr, "<best_core> input is not a nucleotide alignment.\n");
		return 0;
	}

	/* initilization */
	if (bo->ma->n <= 3) {
		fprintf(stderr, "[best_core] less than 3 sequences. PHYML is skipped.\n");
		bo->is_phyml = 0;
	}
	tree = t_phyml_aa = t_phyml_nt = t_nj_dn = t_nj_ds = t_nj_mm = t_nj_dn_cons = t_nj_mm_cons = t_final = 0;
	/* initialization */
	ma_init_nucl_data();
	if (bo->is_phyml) phyml_init();
	lh3_revision_is_quiet = bo->is_quiet;
	if (bo->is_sequenced_only) cpp_shrink_ma_by_spec(bo->ma, bo->stree);
	if (bo->is_contract_stree) {
		tree = cpp_shrink_spec(bo->stree, bo->ma->n, bo->ma->name);
		tr_delete_tree(bo->stree);
		bo->stree = tree;
	}
	/* mask alignment */
	ma_apply_mask(bo->ma); /* aply MASKSEQ and eliminate columns consisting of only gaps */
	ma_filter(bo->ma, bo->is_collapse_splice, bo->qual_thres, bo->is_mask_lss);
	tma = ma_trans_align(bo->ma, 0);
	if (tma == 0) {
		fprintf(stderr, "<best_core> fail to translate the alignment. Is it a valid coding alignment?\n");
		ma_free_nucl_data();
		return 0;
	}

	n_spec = tr_is_has_spec(bo->ma, bo->stree);
	if (n_spec <= 2)
		fprintf(stderr, "[best_core] this algorithm is less useful if only %d species are matched.", n_spec);
	
	if (bo->is_phyml) { /* build phyml_aa tree */
		char *s;
		float lk1, lk2;
		MultiAlign *pma;
		pc = init_PhymlConfig(bo);
		pc->n_cat = 1; /* one category for PHYML-WAG */
		c_begin = clock();
		pma = ma_trans_align(bo->ma, 1);
		t_phyml_aa = phyml_core(pma, pc, 0, 1, 1);
		cpp_get_keyval(t_phyml_aa, "Loglk", &s); lk1 = (float)atof(s); free(s);
		cpp_get_keyval(t_phyml_aa, "LoglkSpec", &s); lk2 = (float)atof(s); free(s);
		ma_free(pma);
		phyml_free_config(pc);
		t_phyml_aa = tr_root_tree(t_phyml_aa, (n_spec > 2)? bo->stree : 0);
		tr_normalize_bs_value(t_phyml_aa, -80);
		if (bo->is_debug) {
			fprintf(stderr, "(best_core) Time elapses in PHYML-WAG: %.2fs\n", (float)(clock() - c_begin) / CLOCKS_PER_SEC);
			fprintf(stderr, "(best_core) PHYML-WAG (Loglk,LoglkSpec) = (%f,%f)\n", lk1, lk2);
		}
	}

	if (bo->is_phyml) { /* build phyml_nt tree */
		char *s;
		float lk1, lk2;
		c_begin = clock();
		pc = init_PhymlConfig(bo); /* this will be deleted later, not in this block */
		pc->is_nucl = 1; free(pc->model); pc->model = cpystr("HKY");
		t_phyml_nt = phyml_core(bo->ma, pc, 0, 1, 1);
		cpp_get_keyval(t_phyml_nt, "Loglk", &s); lk1 = (float)atof(s); free(s);
		cpp_get_keyval(t_phyml_nt, "LoglkSpec", &s); lk2 = (float)atof(s); free(s);
		t_phyml_nt = tr_root_tree(t_phyml_nt, (n_spec > 2)? bo->stree : 0);
		tr_normalize_bs_value(t_phyml_nt, -80);
		if (bo->is_debug) {
			fprintf(stderr, "(best_core) Time elapses in PHYML-HKY: %.2fs\n", (float)(clock() - c_begin) / CLOCKS_PER_SEC);
			fprintf(stderr, "(best_core) PHYML-HKY (Loglk,LoglkSpec) = (%f,%f)\n", lk1, lk2);
		}
	}

	{ /* build nj_dn tree */
		c_begin = clock();
		t_nj_dn = tr_build_tree_from_align(tma, 0, 0, 0, bo->stree, DIST_DN, 1, 0);
		tr_delete_tree_SDIptr(t_nj_dn);
		tr_nj_bs(t_nj_dn, tma, bo->stree, 100, DIST_DN, 1);
		tr_SDI(t_nj_dn, bo->stree, 0);
		tr_lost_infer(t_nj_dn, bo->stree);
		if (bo->ctree) {
			Tree *tmptree[1];
			tmptree[0] = bo->ctree;
			t_nj_dn_cons = tr_build_tree_from_align(tma, 1, tmptree, 1, bo->stree, DIST_DN, 1, 0);
			tr_delete_tree_SDIptr(t_nj_dn_cons);
			tr_nj_bs(t_nj_dn_cons, tma, bo->stree, 100, DIST_DN, 1);
			tr_SDI(t_nj_dn_cons, bo->stree, 0);
			tr_lost_infer(t_nj_dn_cons, bo->stree);
		}
		if (bo->is_debug)
			fprintf(stderr, "(best_core) Time elapses in NJ-dN: %.2fs\n", (float)(clock() - c_begin) / CLOCKS_PER_SEC);
	}

	{ /* build nj_ds tree */
		c_begin = clock();
		t_nj_ds = tr_build_tree_from_align(tma, 0, 0, 0, bo->stree, DIST_DS, 1, 0);
		tr_delete_tree_SDIptr(t_nj_ds);
		tr_nj_bs(t_nj_ds, tma, bo->stree, 100, DIST_DS, 1);
		tr_SDI(t_nj_ds, bo->stree, 0);
		tr_lost_infer(t_nj_ds, bo->stree);
		if (bo->is_debug)
			fprintf(stderr, "(best_core) Time elapses in NJ-dS: %.2fs\n", (float)(clock() - c_begin) / CLOCKS_PER_SEC);
	}
	
	{ /* build nj_mm tree */
		c_begin = clock();
		t_nj_mm = tr_build_tree_from_align(bo->ma, 0, 0, 0, bo->stree, DIST_NT_MM, 1, 0);
		tr_delete_tree_SDIptr(t_nj_mm);
		tr_nj_bs(t_nj_mm, tma, bo->stree, 100, DIST_NT_MM, 1);
		tr_SDI(t_nj_mm, bo->stree, 0);
		tr_lost_infer(t_nj_mm, bo->stree);
		if (bo->ctree) {
			Tree *tmptree[1];
			tmptree[0] = bo->ctree;
			t_nj_mm_cons = tr_build_tree_from_align(bo->ma, 1, tmptree, 1, bo->stree, DIST_NT_MM, 1, 0);
			tr_delete_tree_SDIptr(t_nj_mm_cons);
			tr_nj_bs(t_nj_mm_cons, tma, bo->stree, 100, DIST_NT_MM, 1);
			tr_SDI(t_nj_mm_cons, bo->stree, 0);
			tr_lost_infer(t_nj_mm_cons, bo->stree);
		}
		if (bo->is_debug)
			fprintf(stderr, "(best_core) Time elapses in NJ-MM: %.2fs\n", (float)(clock() - c_begin) / CLOCKS_PER_SEC);
	}

	if (bo->is_phyml) { /* tree merge */
		Tree *forest[7];
		c_begin = clock();
		forest[0] = t_phyml_nt; forest[1] = t_nj_ds;
		forest[2] = t_phyml_aa; forest[3] = t_nj_dn;
		forest[4] = t_nj_mm;
		if (bo->ctree == 0) {
			t_final = tr_mmerge(5, forest);
		} else {
			forest[5] = t_nj_dn_cons;
			forest[6] = t_nj_mm_cons;
			t_final = tr_mmerge(7, forest);
		}
	} else {
		Tree *forest[5];
		c_begin = clock();
		forest[0] = t_nj_mm;
		forest[1] = t_nj_dn; forest[2] = t_nj_ds;
		if (bo->ctree == 0) {
			t_final = tr_mmerge(3, forest);
		} else {
			forest[3] = t_nj_dn_cons;
			forest[4] = t_nj_mm_cons;
			t_final = tr_mmerge(5, forest);
		}
	}
	if (bo->is_debug) fprintf(stderr, "tree merge: %.2fs\n", (float)(clock() - c_begin) / CLOCKS_PER_SEC);

	if (bo->is_phyml) { /* calculate branch length */
		char *s;
		float lk1, lk2;
		c_begin = clock();
		tree = phyml_core(bo->ma, pc, t_final, 0, 1); /* pc has been initialized above */
		cpp_get_keyval(tree, "Loglk", &s); lk1 = (float)atof(s); free(s);
		cpp_get_keyval(tree, "LoglkSpec", &s); lk2 = (float)atof(s); free(s);
		phyml_free_config(pc);
		tree = (n_spec > 2)? tr_root_by_sdi(tree, bo->stree) : tr_root_by_min_height(tree);
		cpp_attach_id_by_name(tree, bo->ma->n, bo->ma->name);
		if (bo->is_debug) {
			fprintf(stderr, "(best_core) Time elapses in optimizing branch lengths: %.2fs\n", (float)(clock() - c_begin) / CLOCKS_PER_SEC);
			fprintf(stderr, "(best_core) final (Loglk,LoglkSpec) = (%f,%f)\n", lk1, lk2);
		}
	} else {
		Matrix *mat = ma_init_small_matrix(bo->ma);
		ma_cal_mm_dist(mat, bo->ma, 0, 0, 0);
		tree = tr_copy_tree(t_final);
		tr_est_len(tree, mat, 0);
		free(mat->dist);
		free(mat);
	}

	if (bo->prefix) {
		if (bo->is_phyml) {
			write_tmp_tree(bo->prefix, ".phyml-aa.nhx", t_phyml_aa);
			write_tmp_tree(bo->prefix, ".phyml-nt.nhx", t_phyml_nt);
		} else {
			write_tmp_tree(bo->prefix, ".phyml-aa.nhx", t_nj_dn);
			write_tmp_tree(bo->prefix, ".phyml-nt.nhx", t_nj_mm);
		}
		write_tmp_tree(bo->prefix, ".nj-dn.nhx", t_nj_dn);
		write_tmp_tree(bo->prefix, ".nj-ds.nhx", t_nj_ds);
		write_tmp_tree(bo->prefix, ".nj-mm.nhx", t_nj_mm);
	}

	if (bo->is_phyml) { /* bootstrap */
		c_begin = clock();
		tr_nj_bs(tree, tma, bo->stree, 100, DIST_DM, 1);
	}
	if (bo->is_debug)
		fprintf(stderr, "(best_core) Time elapse in bootstrapping: %.2fs\n", (float)(clock() - c_begin) / CLOCKS_PER_SEC);
	/* tr_dN_dS(tree, ma); */
	tr_SDI(tree, bo->stree, 0);
	tr_lost_infer(tree, bo->stree);
	tr_set_spec_leaf_order(tree);
	tr_order_core(tree);

	/* free */
	if (bo->is_phyml) {
		tr_delete_tree_SDIptr(t_phyml_nt); tr_delete_tree(t_phyml_nt);
		tr_delete_tree_SDIptr(t_phyml_aa); tr_delete_tree(t_phyml_aa);
	}
	tr_delete_tree_SDIptr(t_nj_dn); tr_delete_tree(t_nj_dn);
	tr_delete_tree_SDIptr(t_nj_ds); tr_delete_tree(t_nj_ds);
	tr_delete_tree_SDIptr(t_nj_mm); tr_delete_tree(t_nj_mm);
	if (bo->ctree) {
		tr_delete_tree_SDIptr(t_nj_dn_cons); tr_delete_tree(t_nj_dn_cons);
		tr_delete_tree_SDIptr(t_nj_mm_cons); tr_delete_tree(t_nj_mm_cons);
	}
	tr_delete_tree_SDIptr(t_final); tr_delete_tree(t_final);
	ma_free(tma);
	ma_free_nucl_data();
	if (bo->ctree) tr_compare_core(bo->ctree, tree, COMPARE_WRITE_INTERNAL_NAME);
	return tree;
}
static int best_usage()
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Usage  : treebest best [options] <CDS_alignment>\n\n");
	fprintf(stderr, "General Options:\n\n");
	fprintf(stderr, "         -P          skip PHYML\n");
	fprintf(stderr, "         -S          ignore the prob. of gene evolution (NOT recommended)\n");
	fprintf(stderr, "         -A          apply constraint to PHYML\n");
	fprintf(stderr, "         -C FILE     constraining tree                               [null]\n");
	fprintf(stderr, "         -f FILE     species tree                                 [default]\n");
	fprintf(stderr, "         -r          discard species that do not appear at all\n\n");
	fprintf(stderr, "Output Options:\n\n");
	fprintf(stderr, "         -D          output some debug information\n");
	fprintf(stderr, "         -q          suppress part of PHYML warnings\n");
	fprintf(stderr, "         -p STR      prefix of intermediate trees                    [null]\n");
	fprintf(stderr, "         -o FILE     output tree                                     [null]\n\n");
	fprintf(stderr, "Alignment Preprocessing Options:\n\n");
	fprintf(stderr, "         -s          only build tree for genes from sequenced species\n");
	fprintf(stderr, "         -g          collapse alternative splicing forms\n");
	fprintf(stderr, "         -N          do not mask low-scoring segments\n");
	fprintf(stderr, "         -F INT      quality cut-off                                   [11]\n\n");
	fprintf(stderr, "PHYML Related Options:\n\n");
	fprintf(stderr, "         -c INT      number of rate categories for PHYML-HKY            [2]\n");
	fprintf(stderr, "         -k FLOAT|e  tv/ts ratio (kappa), 'e' for estimatinig           [e]\n");
	fprintf(stderr, "         -a FLOAT|e  alpha parameter for Gamma distribution           [1.0]\n");
	fprintf(stderr, "         -d FLOAT    duplication probability                         [0.15]\n");
	fprintf(stderr, "         -l FLOAT    porbability of a loss following a speciation    [0.10]\n");
	fprintf(stderr, "         -L FLOAT    porbability of a loss following a duplication   [0.20]\n");
	fprintf(stderr, "         -b FLOAT    prob. of the presence of an inconsistent branch [0.01]\n\n");
	fprintf(stderr, "Note:    If you use this module in your work, please cite:\n\n");
	fprintf(stderr, "         Guindon S. and Gascuel O. (2003) A simple, fast, and accurate\n");
	fprintf(stderr, "           algorithm to estimate large phylogenies by maximum likelihood.\n");
	fprintf(stderr, "           Syst Biol, 52(5), 696-704\n\n");
	return 1;
}

BestConfig *best_command_line_options(int argc, char *argv[])
{
	int c;
	BestConfig *bo;
	FILE *fp;

	bo = best_init_option();
	while ((c = getopt(argc, argv, "qsrDNgSPAF:c:C:f:p:o:k:a:d:l:L:b:")) >= 0) {
		switch (c) {
			case 'q': bo->is_quiet = 1; break;
			case 's': bo->is_sequenced_only = 1; break;
			case 'r': bo->is_contract_stree = 1; break;
			case 'D': bo->is_debug = 1; break;
			case 'N': bo->is_mask_lss = 0; break;
			case 'g': bo->is_collapse_splice = 1; break;
			case 'S': bo->is_phyml_spec = 0; break;
			case 'A': bo->is_phyml_cons = 1; break;
			case 'P': bo->is_phyml = 0; break;
			case 'F': bo->qual_thres = atoi(optarg); break;
			case 'c': bo->n_cat = atoi(optarg); break;
			case 'C': fp = tr_get_fp(optarg);
					  bo->ctree = tr_parse_first(fp);
					  fclose(fp);
					  break;
			case 'f': fp = tr_get_fp(optarg);
					  bo->stree = tr_parse_first(fp);
					  fclose(fp);
					  bo->stree = cpp_post_spec_tree(bo->stree, 0);
					  break;
			case 'p': bo->prefix = cpystr(optarg); break;
			case 'o': bo->output_fn = cpystr(optarg); break;
			case 'a': if (optarg[0] == 'e' && optarg[1] == 0) bo->alpha = -1.0;
					  else bo->alpha = (float)atof(optarg);
					  break;
			case 'k': if (optarg[0] == 'e' && optarg[1] == 0) bo->kappa = -1.0;
					  else bo->kappa = (float)atof(optarg);
					  break;
			case 'd': bo->prob_dup = atof(optarg); break;
			case 'l': bo->prob_loss_dup = atof(optarg); break;
			case 'L': bo->prob_loss_spec = atof(optarg); break;
			case 'b': bo->prob_not_exist = atof(optarg); break;
		}
	}
	if (argc == optind) return 0;
	fp = tr_get_fp(argv[optind]);
	bo->ma = ma_read_alignment(fp, 1);
	fclose(fp);
	if (bo->stree == 0) bo->stree = tr_default_spec_tree();
	return bo;
}
int best_task(int argc, char *argv[])
{
	BestConfig *bo;
	Tree *tree;
	FILE *fp;

	bo = best_command_line_options(argc, argv);
	if (bo == 0) return best_usage();
	tree = best_core(bo);
	fp = (bo->output_fn)? fopen(bo->output_fn, "w") : stdout;
	tr_tree_output(fp, tree, OUTPUT_SDI);
	if (fp != stdout) fclose(fp);
	tr_delete_tree_SDIptr(tree);
	tr_delete_tree(tree);
	best_free_option(bo);
	return 0;
}
