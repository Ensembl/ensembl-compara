#ifdef HAVE_PHYML
#include <unistd.h>
#include <string.h>
#include "phyml/utilities.h"
#include "phyml/ml.h"
#include "phyml/models.h"
#include "phyml/bionj.h"
#include "phyml/simu.h"
#include "phyml/options.h"
#include "phyml/free.h"
#include "align_lib/table.h"
#include "phyml.h"
#include "utils.h"
#include "cpp_utils.h"
#ifdef LH3_ADDON
#include "phyml/lh3_addon.h"
#endif

#define MAX_STR_LEN	255

extern FILE *tr_get_fp(const char *fn);

extern int T_MAX_FILE;
extern double MDBL_MIN;
extern double UNLIKELY;

option *phyml_config2option(PhymlConfig *pc);
option *phyml_prepare_input(MultiAlign *ma, PhymlConfig *pc);
seq **phyml_align2seq(MultiAlign *ma);
Matrix *phyml_phymlmat2Matrix(matrix *phymlmat);

void phyml_init()
{
	Init_Constant();
	srand(time(0));
}
int phyml_usage()
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Usage:   treebest phyml [options] <alignment> [<tree>]\n\n");
	fprintf(stderr, "General Options:\n\n");
	fprintf(stderr, "         -t task     build | opt | loglk | dist                          [build]\n");
	fprintf(stderr, "         -n          the input is a nucleotide alignment\n");
	fprintf(stderr, "         -s          print out some statistics\n");
	fprintf(stderr, "         -N          do not mask low-scoring segments\n");
	fprintf(stderr, "         -g          collapse alternative splicing\n");
	fprintf(stderr, "         -b INT      number of bootstraps (slow)                             [0]\n");
	fprintf(stderr, "         -o FILE     write output to file                               [stdout]\n");
	fprintf(stderr, "         -F INT      quality cut-off                                        [15]\n\n");
	fprintf(stderr, "Model Related Options:\n\n");
	fprintf(stderr, "         -m model    nt: JC69 | K2P | F81 | HKY | F84 | TN93 | GTR         [HKY]\n");
	fprintf(stderr, "                     aa: JTT | MtREV | Dayhoff | WAG                       [WAG]\n");
	fprintf(stderr, "         -c INT      number of relative substitution rate categories         [1]\n");
	fprintf(stderr, "         -k FLOAT|e  transversion/transition ratio, 'e' for estimatinig      [e]\n");
	fprintf(stderr, "         -a FLOAT|e  alpha parameter for Gamma distribution                [1.0]\n");
	fprintf(stderr, "         -i FLOAT|e  proportion of invariable sites                          [0]\n\n");
	fprintf(stderr, "Options for TreeFam Extensions:\n\n");
	fprintf(stderr, "         -S          use a species tree to guide tree building\n");
	fprintf(stderr, "         -f FILE     species tree                         [TreeFam species tree]\n");
	fprintf(stderr, "         -d FLOAT    duplication probability                              [0.15]\n");
	fprintf(stderr, "         -l FLOAT    porbability of a loss following a speciation         [0.10]\n");
	fprintf(stderr, "         -L FLOAT    probability of a loss following a duplication        [0.20]\n");
	fprintf(stderr, "         -C FILE     constraining tree                                    [NULL]\n");
	fprintf(stderr, "         -p FLOAT    prob. of the presence of an inconsistent branch      [0.01]\n\n");
	fprintf(stderr, "Note:    Do not calculate distance for multiple rate categories. This is might\n");
	fprintf(stderr, "         be wrong due to my false implementation.\n\n");
	fprintf(stderr, "         If you use this module in your work, please cite:\n\n");
	fprintf(stderr, "         Guindon S. and Gascuel O. (2003) A simple, fast, and accurate algorithm to\n");
	fprintf(stderr, "           estimate large phylogenies by maximum likelihood. Syst Biol, 52(5), 696-704\n\n");
	return 1;
}
int phyml_task(int argc, char *argv[])
{
	PhymlConfig *pc;
	MultiAlign *ma;
	int c, is_build, is_opt, is_tree, is_spec, is_mask_segment, is_collapse, cut_off = 15;
	FILE *fp, *fpout;
	Tree *tree, *tmp_tree, *spec_tree, *inp = 0;
	char *model = 0;
	extern FILE *tr_get_fp(const char*);

	is_build = is_opt = is_tree = is_mask_segment = 1;
	is_collapse = is_spec = 0;
	spec_tree = 0;
	fpout = stdout;
	phyml_init();
	pc = phyml_init_config();
	while ((c = getopt(argc, argv, "nt:m:k:a:i:c:sF:o:Ngb:p:C:Sd:l:L:f:")) >= 0) {
		switch (c) {
			case 'S': is_spec = 1; break;
			case 'f': fp = tr_get_fp(optarg); break;
					  tmp_tree = tr_parse_first(fp);
					  spec_tree = tr_post_spec_tree(tmp_tree);
					  fclose(fp);
					  break;
			case 'd': pc->prob_dup = atof(optarg); break;
			case 'l': pc->prob_loss_spec = atof(optarg); break;
			case 'L': pc->prob_loss_dup = atof(optarg); break;
			case 'C': fp = tr_get_fp(optarg);
					  pc->ctree = tr_parse_first(fp);
					  fclose(fp);
					  break;
			case 'p': pc->prob_not_exist = atof(optarg); break;
			case 'g': is_collapse = 1; break;
			case 'n': pc->is_nucl = 1; break;
			case 'b': pc->bs = atoi(optarg); break;
			case 'N': is_mask_segment = 0; break;
			case 't': if (strcmp(optarg, "build") == 0) { is_build = 1; is_opt = 1; }
					  else if (strcmp(optarg, "opt") == 0) { is_build = 0; is_opt = 1; }
					  else if (strcmp(optarg, "loglk") == 0) { is_build = 0; is_opt = 0; }
					  else if (strcmp(optarg, "dist") == 0) { is_build = 0; is_opt = 0; is_tree = 0; }
					  else fprintf(stderr, "<phyml_task> unrecognized parameter %s\n", optarg);
					  break;
			case 'o': fpout = fopen(optarg, "w");
					  if (!fpout) {
						  fprintf(stderr, "[phyml_task] fail to create %s\n", optarg);
						  return 1;
					  }
					  break;
			case 'm': model = cpystr(optarg); break;
			case 'k': if (optarg[0] == 'e' && optarg[1] == 0) pc->kappa = -1.0;
					  else pc->kappa = atof(optarg);
					  break;
			case 'a': if (optarg[0] == 'e' && optarg[1] == 0) pc->alpha = -1.0;
					  else pc->alpha = atof(optarg);
					  break;
			case 'i': if (optarg[0] == 'e' && optarg[1] == 0) pc->invar = -1.0;
					  else pc->invar = atof(optarg);
					  break;
			case 'c': pc->n_cat = atoi(optarg); break;
			case 'F': cut_off = atoi(optarg); break;
			case 's': pc->is_stat = 1; break;
		}
	}
	/* finalise PhymlConfig structure */
	if (model) {
		free(pc->model);
		pc->model = model;
	} else if (pc->is_nucl) {
		free(pc->model);
		pc->model = cpystr("HKY");
	}
	if (is_spec)
		pc->spec_tree = (spec_tree)? spec_tree : tr_default_spec_tree();
	if (optind == argc) return phyml_usage();
	if (is_tree && !is_build && optind + 1 == argc) return phyml_usage();
	/* read and process alignment */
	fp = tr_get_fp(argv[optind]);
	ma = ma_read_alignment(fp, pc->is_nucl);
	ma_remove_gap(ma);
	ma_apply_mask(ma);
	ma_filter(ma, is_collapse, cut_off, is_mask_segment);
	if (optind+1 < argc) {
		FILE *fp_tree = tr_get_fp(argv[optind+1]);
		inp = tr_parse_first(fp_tree);
		fclose(fp_tree);
	}
	if (is_tree) { /* build and output a tree */
		tree = phyml_core(ma, pc, inp, is_build, is_opt);
		tr_tree_output(fpout, tree, OUTPUT_SDI);
		tr_delete_tree(tree);
	} else { /* calculate and output distance matrix */
		Matrix *mat = phyml_matrix(ma, pc);
		tr_matrix_output(fpout, mat);
		tr_delete_matrix(mat);
	}
	phyml_free_config(pc);
	ma_free(ma);
	tr_delete_tree(inp);
	fclose(fp);
	return 0;
}
Matrix *phyml_matrix(MultiAlign *ma, PhymlConfig *pc)
{
	allseq *alldata;
	option *input;
	model *mod;
	matrix *phymlmat;
	Matrix *mat;

	input = phyml_prepare_input(ma, pc);
	mod = input->mod;
	alldata = input->alldata;
	phymlmat = ML_Dist(alldata, mod);
	if (pc->n_cat > 1 || pc->kappa < 0.0 || pc->invar < 0.0 || pc->alpha < 0.0) {
		arbre *tree;
		phymlmat->tree = Make_Tree(alldata);
		Bionj(phymlmat);
		tree = phymlmat->tree;
		Free_Mat(phymlmat);
		tree->mod = mod;
		tree->input = input;
		tree->data = alldata;
		tree->both_sides = 1;
		tree->n_pattern = tree->data->crunch_len/tree->mod->stepsize;
		Order_Tree_CSeq(tree, alldata);
		Make_Tree_4_Lk(tree, alldata, alldata->init_len);
		Round_Optimize(tree, tree->data);
		phymlmat = ML_Dist_fixed(alldata, mod, pc->n_cat); /* this might be wrong!!! */
		Free_Tree_Lk(tree);
		Free_Tree(tree);
	}
	mat = phyml_phymlmat2Matrix(phymlmat);
	if (pc->is_stat) {
		fprintf(stderr, "<phyml_stat> kappa=%f\n", mod->kappa);
		fprintf(stderr, "<phyml_stat> alpha=%f\n", mod->alpha);
		fprintf(stderr, "<phyml_stat> invar=%f\n", mod->pinvar);
	}
	Free_Mat(phymlmat);
	Free_Cseq(alldata);
	Free_Model(mod);
	Free_Input(input);
	return mat;
}
Tree *phyml_core(MultiAlign *ma, PhymlConfig *pc, Tree *inp, int is_build, int is_opt)
{
	allseq *alldata;
	option *input;
	model *mod;
	matrix *mat;
	arbre *tree;
	Tree *p;

	if (ma->n < 4) {
		fprintf(stderr, "[phyml_core] your alignment should contain at least 4 sequences if you intend to use the `phyml' module.\n");
		return 0;
	}
	input = phyml_prepare_input(ma, pc);
	mod = input->mod;
	alldata = input->alldata;

	/* build BIONJ tree */
	if (inp) {
		char *s_tree, *str, *s, *t;
		Tree *tmp_tree;
		tmp_tree = tr_copy_tree(inp);
		tmp_tree = tr_remove_root(tmp_tree);
		str = tr_tree_string(tmp_tree, 0);
		s_tree = (char*)malloc(sizeof(char) * strlen(str));
		for (t = s_tree, s = str; *s; ++s)
			if (*s != ' ' && *s != '\n') *t++ = *s;
		*t = '\0';
		tree = Read_Tree(s_tree);
#ifdef LH3_ADDON
		lh3_addon_init(tree, pc);
#endif
		free(str);
		free(s_tree);
		tr_delete_tree(tmp_tree);
	} else {
		mat = ML_Dist(alldata, mod);
		mat->tree = Make_Tree(alldata);
		Bionj(mat);
		tree = mat->tree;
#ifdef LH3_ADDON
		lh3_addon_init(tree, pc);
#endif
		Free_Mat(mat);
	}

	/* build PHYML tree */
	tree->mod = mod;
	tree->input = input;
	tree->data = alldata;
	tree->both_sides = 1;
	tree->n_pattern = tree->data->crunch_len/tree->mod->stepsize;
	Order_Tree_CSeq(tree, alldata);
	Make_Tree_4_Lk(tree, alldata, alldata->init_len);
	if (is_build) Simu(tree, 1000);
	else {
		if(is_opt) Round_Optimize(tree, tree->data);
		else Lk(tree, tree->data); /* calculate log likelihood */
	}
	if (tree->mod->bootstrap) Bootstrap(tree);
	Update_BrLen_Invar(tree);
	{
		char buffer[64];
		char *s_tree = Write_Tree(tree);
		int n;
		/* It is possible to use phyml_arbre2tree() to convert between the two formats. However, the method below
		 * is still preferred because it is able to reserve the root. */
		Tree **ret_tree = tr_parse_str(s_tree, &n);
		p = ret_tree[0];
		Free(s_tree);
		free(ret_tree);
		tr_compare_core(inp, p, COMPARE_WRITE_INTERNAL_NAME);
		if (p && p->n >= 3) {
			p = tr_reroot(p, p->node[p->n-1], -1.0);
			tr_tree_init(p);
		}
		sprintf(buffer, "%f", tree->tot_loglk);
		cpp_insert_keyval(p, "Loglk", buffer);
		sprintf(buffer, "%f", tree->lh3_tree.ratio_cons);
		cpp_insert_keyval(p, "RatioCons", buffer);
		sprintf(buffer, "%f", tree->lh3_tree.loglk_spec);
		cpp_insert_keyval(p, "LoglkSpec", buffer);
	}
	Unconstraint_Lk(tree);

	if (pc->is_stat) {
		fprintf(stderr, "<phyml_stat> loglk=%f\n", tree->tot_loglk);
		fprintf(stderr, "<phyml_stat> kappa=%f\n", mod->kappa);
		fprintf(stderr, "<phyml_stat> alpha=%f\n", mod->alpha);
		fprintf(stderr, "<phyml_stat> invar=%f\n", mod->pinvar);
	}

	/* free */
	Free_Tree_Lk(tree);
#ifdef LH3_ADDON
	lh3_addon_free(tree);
#endif
	Free_Tree(tree);
	Free_Cseq(alldata);
	Free_Model(mod);
	Free_Input(input);
	return p;
}
option *phyml_prepare_input(MultiAlign *ma, PhymlConfig *pc)
{
	option *input;
	seq **data;
	allseq *alldata;

	input = phyml_config2option(pc);
	Make_Model_Complete(input->mod);
	data = phyml_align2seq(ma);
	input->mod->n_otu = ma->n;
	input->n_trees = 1;
	alldata = Compact_Seq(data, input);
	input->alldata = alldata;
	Free_Seq(data, alldata->n_otu);
	Init_Model(alldata, input->mod);
	Check_Ambiguities(alldata, input->mod->datatype, input->mod->stepsize);
	input->mod->s_opt->print = 0; /* supress output */
	return input;
}
Tree *phyml_arbre2tree(arbre *tree)
{
	Tree *root, *p, *q;
	Tree **stack, **top;
	node *v, *u;
	int i, j;

	if (tree->n_otu < 4) {
		fprintf(stderr, "[phyml_arbre2tree] this function only works for a tree with at least 4 leaves.\n");
		return 0;
	}
	top = stack = (Tree**)malloc(sizeof(Tree*) * (2 * tree->n_otu - 2));
	/* find an internal node as the root */
	v = 0;
	for (i = 0; i < 2 * tree->n_otu - 2; ++i) {
		v = tree->noeud[i];
		if (v->tax) continue;
		for (j = 0; j < 3; ++j) {
			u = (v->b[j]->left == v)? v->b[j]->rght : v->b[j]->left;
			if (u->tax) break;
		}
		if (j == 3) break;
	}
	root = tr_new_node();
	root->ptr = v;
	*top++ = root;
	while (top != stack) {
		q = *--top;
		v = (node*)q->ptr;
		if (v->name && v->name[0])
			q->name = cpystr(v->name);
		if (v->tax) continue; /* external nodes */
		q->n = (q->pre)? 2 : 3;
		q->node = (Tree**)malloc(sizeof(Tree*) * q->n);
		for (i = j = 0; j < 3; ++j) {
			u = (v->b[j]->left == v)? v->b[j]->rght : v->b[j]->left;
			if (q->pre && u == (node*)q->pre->ptr) continue;
			p = tr_new_node();
			q->node[i++] = p; p->pre = q;
			p->ptr = u;
			p->d = v->b[j]->l;
			if (v->b[j]->bootval != 0.0)
				p->bs = (int)v->b[j]->bootval; /* put bootstrap value at the lower node of the branch */
			*top++ = p;
		}
	}
	free(stack);
	tr_tree_init(root);
	tr_attach_id(root);
	tr_clear_ptr(root);
	return root;
}
Matrix *phyml_phymlmat2Matrix(matrix *phymlmat)
{
	Matrix *mat;
	int i, j;
	mat = (Matrix*)malloc(sizeof(Matrix));
	mat->count = phymlmat->n_otu;
	mat->name = (char**)malloc(sizeof(char*) * mat->count);
	mat->dist = (float*)malloc(sizeof(float) * mat->count * mat->count);
	for (i = 0; i < mat->count; ++i) {
		mat->name[i] = cpystr(phymlmat->name[i]);
		for (j = 0; j < mat->count; ++j)
			mat->dist[i * mat->count + j] = (float)phymlmat->dist[i][j];
		mat->dist[i * mat->count + i] = 0.0;
	}
	return mat;
}
seq **phyml_align2seq(MultiAlign *ma)
{
	seq **s, *p;
	int i, j;
	char *q;

	s = (seq**)malloc(sizeof(seq*) * ma->n);
	for (i = 0; i < ma->n; ++i) {
		p = s[i] = (seq*)malloc(sizeof(seq));
		p->name = cpystr(ma->name[i]);
		p->len = ma->len;
		p->state = (char*)malloc(sizeof(char) * (ma->len+1));
		q = ma->seq[i];
		if (ma->is_nucl)
			for (j = 0; j < ma->len; ++j)
				p->state[j] = (q[j] < 4)? aln_nt4_rev_table[(int)q[j]] : 'X';
		else
			for (j = 0; j < ma->len; ++j)
				p->state[j] = (q[j] < 20)? aln_aa_rev_table[(int)q[j]] : 'X';
		p->state[j] = '\0';
	}
	return s;
}
PhymlConfig *phyml_init_config()
{
	PhymlConfig *pc;
	pc = (PhymlConfig*)malloc(sizeof(PhymlConfig));
	pc->kappa = -1.0; /* <0 for estimating (4.0) */
	pc->alpha = 1.0; /* <0 for estimating */
	pc->n_cat = 1;
	pc->bs = 0;
	pc->invar = 0; /* no invarible sites */
	pc->is_nucl = 0;
	pc->is_stat = 0;
	pc->model = cpystr("WAG");

	pc->prob_not_exist = 0.01;
	pc->prob_dup = 0.15;
	pc->prob_loss_dup = 0.20;
	pc->prob_loss_spec = 0.10;
	pc->ctree = 0;
	pc->spec_tree = 0;
	return pc;
}
void phyml_free_config(PhymlConfig *pc)
{
	if (pc == 0) return;
	tr_delete_tree(pc->ctree);
	tr_delete_tree(pc->spec_tree);
	free(pc->model);
	free(pc);
}
/* a substitution to Get_Input() in file "phyml/option.c" */
option *phyml_config2option(PhymlConfig *pc)
{
	option *input               = (option*)mCalloc(1, sizeof(option));
	char *argv[15];
	int argc, shift, i;

	shift = (pc->is_nucl)? 1 : 0;
	argc = 13 + shift;
	argv[0] = cpystr("phyml");
#ifdef _WIN32
	argv[1] = cpystr("phymltmp");
#else
	argv[1] = cpystr("/dev/null");
#endif
	argv[2] = (pc->is_nucl)? cpystr("0") : cpystr("1");
	argv[3] = cpystr("i");
	argv[4] = cpystr("1");
	argv[5] = (char*)malloc(sizeof(char) * 31);
	sprintf(argv[5], "%d", pc->bs);
	argv[6] = cpystr(pc->model);
	if (pc->is_nucl) {
		if (pc->kappa >= 0.0) {
			argv[7] = (char*)malloc(sizeof(char) *MAX_STR_LEN);
			sprintf(argv[7], "%f", pc->kappa);
		} else argv[7] = cpystr("e");
	}
	if (pc->invar >= 0.0) {
		argv[7+shift] = (char*)malloc(sizeof(char) *MAX_STR_LEN);
		sprintf(argv[7+shift], "%f", pc->invar);
	} else argv[7+shift] = cpystr("e");
	argv[8+shift] = (char*)malloc(sizeof(char) * MAX_STR_LEN);
	sprintf(argv[8+shift], "%d", pc->n_cat);
	if (pc->alpha >= 0.0) {
		argv[9+shift] = (char*)malloc(sizeof(char) *MAX_STR_LEN);
		sprintf(argv[9+shift], "%f", pc->alpha);
	} else argv[9+shift] = cpystr("e");
	argv[10+shift] = cpystr("BIONJ");
	argv[11+shift] = cpystr("y");
	argv[12+shift] = cpystr("y");

	input->fp_seq               = NULL;
	input->fp_input_tree        = NULL;
	input->mod                  = Make_Model_Basic();
	input->seqfile              = (char *)mCalloc(T_MAX_FILE,sizeof(char));
	input->modelname            = (char *)mCalloc(50,sizeof(char));
	input->nt_or_cd             = (char *)mCalloc(50,sizeof(char));
	input->inputtreefile        = (char *)mCalloc(T_MAX_FILE,sizeof(char));
	input->phyml_tree_file      = (char *)mCalloc(T_MAX_FILE,sizeof(char));
	input->phyml_stat_file      = (char *)mCalloc(T_MAX_FILE,sizeof(char));
	input->phyml_lk_file        = (char *)mCalloc(T_MAX_FILE,sizeof(char));

	Set_Defaults_Input(input);
	Set_Defaults_Model(input->mod);
	Set_Defaults_Optimiz(input->mod->s_opt);

	Translate_Custom_Mod_String(input->mod);
	Init_Optimiz(input->mod->s_opt);

	if (pc->is_nucl) Get_Input_CommandLine_DNA(input, argc, argv);
	else Get_Input_CommandLine_AA(input, argc, argv);

	for (i = 0; i < argc; ++i)
		free(argv[i]);

	return input;
}
#endif /* HAVE_PHYML */
