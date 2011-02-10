#include "cpp_utils.h"
#include "phyml.h"
#include "flglobal.h"
#include "align.h"

Fl_Menu_Item menu_format[] = { {"auto"}, {"fasta"}, {"aln"}, {0} };
Fl_Menu_Item menu_type[] = { {"amino acid"}, {"codon"}, {0} };
Fl_Menu_Item menu_nt_type[] = { {"merge"}, {"synonymous"}, {"nonsynonymous"}, {0} };
Fl_Menu_Item menu_aa_type[] = { {"mismatch"}, {"Kimura"}, {"JTT"}, {0} };
Fl_Menu_Item menu_workspace[] = { {"Artemis"}, {"Dionysus"}, {"Selena"}, {0} };
Fl_Menu_Item menu_phyml_type[] = { {"nucleotide"}, {"amino acid"}, {0} };
Fl_Menu_Item menu_phyml_nt_model[] = { {"HKY"}, {"JC69"}, {"K2P"}, {"F81"}, {"F84"}, {"TN93"}, {"GTR"}, {0} };
Fl_Menu_Item menu_phyml_aa_model[] = { {"WAG"}, {"JTT"}, {"MtREV"}, {"Dayhoff"}, {0} };

char *g_workspace[] = {"Artemis", "Dionysis", "Selena"};

FNglobal::FNglobal()
{
	fc_nhx = new Fl_File_Chooser(".", "New Hampshire (*.{nh,nhx})", Fl_File_Chooser::SINGLE, "Open Tree");
	fc_eps = new Fl_File_Chooser(".", "EPS (*.{eps,EPS})", Fl_File_Chooser::CREATE, "Write EPS");
	fc_aln = new Fl_File_Chooser(".", "FASTA (*.{mfa,fa*})\tCLUSTALW (*.aln)", Fl_File_Chooser::SINGLE, "Open Alignment");
	fc_save= new Fl_File_Chooser(".", "New Hampshire (*.nhx)", Fl_File_Chooser::CREATE, "Save Tree");
	fc_aa_aln = new Fl_File_Chooser(".", "FASTA (*.{mfa,fa*})\tCLUSTALW (*.aln)", Fl_File_Chooser::SINGLE, "Open Amino Acids Alignment");
	fc_nt_aln = new Fl_File_Chooser(".", "FASTA (*.{mfa,fa*})\tCLUSTALW (*.aln)", Fl_File_Chooser::CREATE, "Write Nucleotide Alignment");
	fc_nt_seq = new Fl_File_Chooser(".", "FASTA (*.{fna,fa*})", Fl_File_Chooser::SINGLE, "Open Nucleotide Seqences");
	fc_phyml_aln = new Fl_File_Chooser(".", "FASTA (*.{mfa,fa*})\tCLUSTALW (*.aln)", Fl_File_Chooser::SINGLE, "Open Alignment");
	prev_tab = 0;
	fc_nhx->textsize(12);
	fc_eps->textsize(12);
	fc_aln->textsize(12);
	fc_save->textsize(12);
	for (int i = 0; i < FN_N_SPACE; ++i)
		workspace[i] = 0;
	spec_tree = tr_default_spec_tree();
	build = new FNbuild(this);
	phyml = new FNphyml(this);
	merge = new FNmerge(this);
	compare = new FNcompare(this);
	backtrans = new FNbacktrans(this);
}
FNglobal::~FNglobal()
{
	delete build;
	delete merge;
	delete compare;
	delete backtrans;
	delete phyml;
	delete fc_nhx;
	delete fc_eps;
	delete fc_aln;
	delete fc_save;
	delete fc_aa_aln;
	delete fc_nt_aln;
	delete fc_nt_seq;
	delete fc_phyml_aln;
	for (int i = 0; i < FN_N_SPACE; ++i)
		delete workspace[i];
	tr_delete_tree(spec_tree);
}
Workspace *FNglobal::active_ws()
{
	for (int i = 0; i < FN_N_SPACE; ++i) {
		if (workspace[i]->visible_r())
			return workspace[i];
	}
	return 0;
}
int FNglobal::change_ws(int shift)
{
	int i;
	for (i = 0; i < FN_N_SPACE; ++i)
		if (workspace[i]->visible_r()) break;
	return ((i+shift)%FN_N_SPACE+FN_N_SPACE)%FN_N_SPACE;
}

static Fl_Progress *progress_bar;
static int progress_func(float val)
{
	char str[8];
	sprintf(str, "%d%%", (int)(val*100+0.5));
	progress_bar->value(val);
	progress_bar->label(str);
	Fl::flush();
	return 0;
}
FNphyml::FNphyml(FNglobal *g)
{
	phyml_init();
	pc = phyml_init_config();
	global = g;
	i_alignment = 0;
	i_bs = i_cutoff = i_num_cat = 0;
	i_tstv = i_inv = i_alpha = 0;
	i_tree = i_type = i_model = i_format = 0;
	prog_bar = 0;
	has_tree = is_tstv = is_alpha = is_inv = is_bs = 0;
}
FNphyml::~FNphyml()
{
	delete i_alignment;
	delete i_bs; delete i_cutoff; delete i_num_cat;
	delete i_tstv; delete i_inv; delete i_alpha;
	delete i_tree; delete i_type; delete i_model; delete i_format;
	delete prog_bar;
	delete has_tree; delete is_tstv; delete is_alpha; delete is_inv; delete is_bs;
}
Tree *FNphyml::do_phyml()
{
	Tree *inp = 0;
	FILE *fp;
	if (has_tree->value() && global->workspace[i_tree->value()])
		inp = global->workspace[i_tree->value()]->get_tree();
	fp = fopen(i_alignment->value(), "r");
	if (fp == 0) {
		fl_alert("Fail to open file '%s'.", i_alignment->value());
		return 0;
	}
	int cutoff;
	MultiAlign *ma;
	pc->kappa = float(atof(i_tstv->value()));
	pc->alpha = float(atof(i_alpha->value()));
	pc->n_cat = int(atoi(i_num_cat->value()));
	pc->invar = float(atof(i_inv->value()));
	pc->bs = int(atoi(i_bs->value()));
	free(pc->model);
	pc->is_nucl = (i_type->value() == 0)? 1 : 0;
	cutoff = int(atoi(i_cutoff->value()));
	pc->model = cpystr(pc->is_nucl ? menu_phyml_nt_model[i_model->value()].text : menu_phyml_aa_model[i_model->value()].text);
	ma = ma_read_alignment(fp, pc->is_nucl);
	fclose(fp);
	ma_remove_gap(ma);
	ma_apply_mask(ma);
	ma_filter(ma, 0, cutoff, is_mask_lss->value());
	Tree *tree = phyml_core(ma, pc, inp, !has_tree->value(), 1);
	ma_free(ma);
	return tree;
}
FNbuild::FNbuild(FNglobal *g)
{
	global = g;
	i_alignment = 0;
	i_bs = i_cutoff = 0;
	i_type = i_dist_type = i_format = 0;
	prog_bar = 0;
	task= tr_alloc_task();
	task->spec_tree = g->spec_tree;
	task->func = progress_func;
}
FNbuild::~FNbuild()
{
	delete i_alignment;
	delete i_bs;
	delete i_cutoff;
	delete i_type;
	delete i_dist_type;
	delete i_format;
	delete prog_bar;
	task->spec_tree = 0; // Let ~FNglobal() do this.
	tr_delete_task(task);
}
Tree *FNbuild::build()
{
	static int dist_aa_type[] = {DIST_MM, DIST_KIMURA, DIST_JTT};
	static int dist_nt_type[] = {DIST_DM, DIST_DS, DIST_DN};
	Tree *tree, *tmp_tree;

	progress_bar = prog_bar;
	task->fp_align = fopen(i_alignment->value(), "r");
	if (task->fp_align == 0) {
		fprintf(stderr, "[FNglobal::build_tree] fail to load alignment in file %s\n", i_alignment->value());
		tr_delete_task(task);
		return 0;
	}
	if (i_format->value() == 0) {
		if (strstr(i_alignment->value(), ".aln")) task->is_aln = 1; // ALN format
		else task->is_aln = -1;
	} else task->is_aln = (i_format->value() == 2)? 1 : 0;
	if (is_cons->value() && global->workspace[i_cons_tree->value()]) {
		task->n_con = 1;
		tmp_tree = global->workspace[i_cons_tree->value()]->get_tree();
		task->constraint = &tmp_tree;
	}
	task->bs_time = atoi(i_bs->value());
	task->filter = atoi(i_cutoff->value());
	task->dist_type = (i_type->value() == 0)? dist_aa_type[i_dist_type->value()] :
			dist_nt_type[i_dist_type->value()];
	tree = tr_build_tree(task);
	task->tree = 0; // task->tree will be freed in Workspace
	task->n_con = 0;
	task->constraint = 0;
	progress_bar = 0;
	return tree;
}
Tree *FNmerge::merge()
{
	FNglobal *g = global;
	if (i_ws1->value() == i_ws2->value()) {
		fl_alert("Please select two trees.");
		return 0;
	}
	if (g->workspace[i_ws1->value()]->get_tree() == 0) {
		fl_alert("No tree is found in workspace %s.", g_workspace[i_ws1->value()]);
		return 0;
	}
	if (g->workspace[i_ws2->value()]->get_tree() == 0) {
		fl_alert("No tree is found in workspace %s.", g_workspace[i_ws2->value()]);
		return 0;
	}
	Tree *forest[2];
	forest[0] = g->workspace[i_ws1->value()]->get_tree();
	forest[1] = g->workspace[i_ws2->value()]->get_tree();
	Tree *tree = tr_mmerge(2, forest);
	tr_SDI(tree, g->spec_tree, 0);
	tr_lost_infer(tree, g->spec_tree);
	return tree;
}
void FNcompare::compare()
{
	FNglobal *g = global;
	if (g->workspace[i_ws->value()]->get_tree() == 0) {
		fl_alert("No tree is found in workspace %s.", g_workspace[i_ws->value()]);
		return;
	}
	tr_compare_core(g->workspace[i_ws->value()]->get_tree(), g->active_ws()->get_tree(), 0);
	cpp_set_leaf_order(g->workspace[i_ws->value()]->get_tree(), g->active_ws()->get_tree(), 0);
	tr_order_core(g->active_ws()->get_tree());
}
void FNbacktrans::backtrans()
{
	FILE *fp_aa_aln, *fp_nt_seq, *fp_nt_aln;
	MultiAlign *aa, *nt;
	fp_aa_aln = fopen(i_aa_aln->value(), "r");
	fp_nt_seq = fopen(i_nt_seq->value(), "r");
	fp_nt_aln = fopen(i_nt_aln->value(), "w+");
	if (!fp_aa_aln || !fp_nt_seq || !fp_nt_aln) {
		fl_alert("File error! Please check the files to ensure they are correct.");
		return;
	}
	aa = ma_read(fp_aa_aln, 0, (strstr(i_aa_aln->value(), ".aln"))? 1 : 0);
	nt = ma_back_trans(aa, fp_nt_seq, 0.90);
	if (strstr(i_nt_aln->value(), ".aln"))
		tr_align_aln_output(fp_nt_aln, nt);
	else tr_align_output(fp_nt_aln, nt);
	ma_free(aa); ma_free(nt);
}
