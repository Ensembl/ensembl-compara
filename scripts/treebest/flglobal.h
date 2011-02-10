#ifndef FLGLOBAL_H_
#define FLGLOBAL_H_

#define FN_N_SPACE	3
#define FN_ARTEMIS	0
#define FN_DIONYSIS	1
#define FN_SELENA	2

#include <FL/Fl_Double_Window.h>
#include <FL/Fl_File_Chooser.h>
#include <FL/Fl_Int_Input.h>
#include <FL/Fl_Float_Input.h>
#include <FL/Fl_Progress.h>
#include <FL/Fl_Button.h>
#include <FL/Fl_Tabs.h>
#include <FL/Fl_Check_Button.h>
#include "tree.h"
#include "phyml.h"
#include "tree_plot.h"

class FNglobal;

class Workspace : public Fl_Widget
{
	FNglobal *global;
	Tree *tree;
	PlotParam *pp;
	int is_sdi;
	void draw();
	void draw_tree();
	void init();
	void destroy_tree();
	void destroy();
public:
	Workspace(int x, int y, int width, int height);
	~Workspace() { destroy(); }
	void set_global(FNglobal *g) { global = g; }
	void size(int ww, int hh);
	void toggle_spec() { pp->show_spec = !pp->show_spec; }
	void toggle_real() { pp->is_real = !pp->is_real; }
	void change_font_size(int s) { if ((pp->font_size += s) < 5) pp->font_size = 5; }
	void set_tree(FILE *fp);
	void set_tree(Tree *);
	void root_tree();
	void order_tree();
	int export_eps(const char *fn);
	int save_nhx(const char *fn);
	PlotParam *get_pp() { return pp; }
	Tree *get_tree() { return tree; }
	void redraw();
};

class FNbuild
{
	Task *task;
	FNglobal *global;
public:
	Fl_Input *i_alignment;
	Fl_Int_Input *i_bs, *i_cutoff;
	Fl_Choice *i_type, *i_dist_type, *i_format, *i_cons_tree;
	Fl_Progress *prog_bar;
	Fl_Check_Button *is_cons;

	FNbuild(FNglobal *g);
	~FNbuild();
	Tree *build();
};

class FNphyml
{
	FNglobal *global;
	PhymlConfig *pc;
public:
	Fl_Input *i_alignment;
	Fl_Int_Input *i_bs, *i_cutoff, *i_num_cat;
	Fl_Float_Input *i_tstv, *i_inv, *i_alpha;
	Fl_Choice *i_tree, *i_type, *i_model, *i_format;
	Fl_Progress *prog_bar;
	Fl_Check_Button *has_tree, *is_tstv, *is_alpha, *is_inv, *is_bs, *is_mask_lss;

	FNphyml(FNglobal *g);
	~FNphyml();
	Tree *do_phyml();
};

class FNmerge
{
	FNglobal *global;
public:
	Fl_Choice *i_ws1, *i_ws2;
	FNmerge(FNglobal *g) { i_ws1 = i_ws2 = 0; global = g; }
	~FNmerge() { delete i_ws1; delete i_ws2; }
	Tree *merge();
};

class FNcompare
{
	FNglobal *global;
public:
	Fl_Choice *i_ws;
	FNcompare(FNglobal *g) { i_ws = 0; global = g; }
	~FNcompare() { delete i_ws; }
	void compare();
};

class FNbacktrans
{
	FNglobal *global;
public:
	Fl_Input *i_aa_aln, *i_nt_seq, *i_nt_aln;
	FNbacktrans(FNglobal *g) { i_aa_aln = i_nt_seq = i_nt_aln = 0; global = g; }
	~FNbacktrans() { delete i_aa_aln; delete i_nt_aln; delete i_nt_seq; }
	void backtrans();
};

class FNglobal
{
public:
	Fl_Double_Window *build_w, *main_w, *merge_w, *compare_w, *backtrans_w, *phyml_w;
	Fl_File_Chooser *fc_nhx, *fc_eps, *fc_save, *fc_aln, *fc_phyml_aln;
	Fl_File_Chooser *fc_aa_aln, *fc_nt_seq, *fc_nt_aln;
	Fl_Light_Button *b_spec, *b_real;
	Fl_Tabs *tabs;
	Fl_Widget *prev_tab;
	Workspace *workspace[FN_N_SPACE];

	FNbuild *build;
	FNmerge *merge;
	FNcompare *compare;
	FNbacktrans *backtrans;
	FNphyml *phyml;
	Tree *spec_tree;

	Fl_Button *b_save, *b_comp, *b_expt, *b_order, *b_merge, *b_root;

	FNglobal();
	~FNglobal();
	Workspace *active_ws();
	int change_ws(int);
};

extern Fl_Menu_Item menu_type[], menu_nt_type[], menu_aa_type[], menu_format[], menu_workspace[];
extern Fl_Menu_Item menu_phyml_type[], menu_phyml_nt_model[], menu_phyml_aa_model[];

void cb_open(Fl_Widget *w, void *global);
void cb_save(Fl_Widget *w, void *global);
void cb_expt(Fl_Widget *w, void *global);
void cb_build(Fl_Widget *w, void *global);
void cb_phyml(Fl_Widget *w, void *global);
void cb_root(Fl_Widget *w, void *global);
void cb_order(Fl_Widget *w, void *global);
void cb_merge(Fl_Widget *w, void *global);
void cb_compare(Fl_Widget *w, void *global);
void cb_backtrans(Fl_Widget *w, void *global);

void cb_compare_tree(Fl_Widget *w, void *global);
void cb_close_compare(Fl_Widget *w, void *global);

void cb_merge_tree(Fl_Widget *w, void *global);
void cb_close_merge(Fl_Widget *w, void *global);

void cb_close_backtrans(Fl_Widget *w, void *global);
void cb_do_backtrans(Fl_Widget *w, void *global);
void cb_browse_aa_aln(Fl_Widget *w, void *global);
void cb_browse_nt_seq(Fl_Widget *w, void *global);
void cb_browse_nt_aln(Fl_Widget *w, void *global);

void cb_browse(Fl_Widget *w, void *global);
void cb_type(Fl_Widget *w, void *global);
void cb_build_tree(Fl_Widget *w, void *global);
void cb_toggle_cons(Fl_Widget *w, void *global);
void cb_close_build(Fl_Widget *w, void *global);

void cb_phyml_browse(Fl_Widget *w, void *global);
void cb_phyml_type(Fl_Widget *w, void *global);
void cb_phyml_inv(Fl_Widget *w, void *global);
void cb_phyml_alpha(Fl_Widget *w, void *global);
void cb_phyml_tstv(Fl_Widget *w, void *global);
void cb_phyml_has_tree(Fl_Widget *w, void *global);
void cb_phyml_tree(Fl_Widget *w, void *global);
void cb_phyml_n_cat(Fl_Widget *w, void *global);
void cb_close_phyml(Fl_Widget *w, void *global);

void cb_zoom_in_x(Fl_Widget *w, void *global);
void cb_zoom_out_x(Fl_Widget *w, void *global);
void cb_zoom_in_y(Fl_Widget *w, void *global);
void cb_zoom_out_y(Fl_Widget *w, void *global);
void cb_small_font(Fl_Widget *w, void *global);
void cb_large_font(Fl_Widget *w, void *global);
void cb_prev(Fl_Widget *w, void *global);
void cb_next(Fl_Widget *w, void *global);

void cb_real(Fl_Widget *w, void *global);
void cb_spec(Fl_Widget *w, void *global);

void cb_update_buttons(Fl_Widget *w, void *global);

#endif
