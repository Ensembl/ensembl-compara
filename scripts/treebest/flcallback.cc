#include "flnjtree_ui.h"
#include "flglobal.h"

// PHYML window
void cb_phyml(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	fl_message("If you use PHYML in your work, please cite its paper:\n\nGuindon S. and Gascuel O. (2003) A simple, fast, and accurate algorithm to\n  estimate large phylogenies by maximum likelihood. Syst Biol, 52(5), 696-704");
	int n = 0;
	for (int i = 0; i < FN_N_SPACE; ++i)
		if (g->workspace[i]->get_tree()) ++n;
	if (n) g->phyml->has_tree->activate();
	else g->phyml->has_tree->deactivate();
	g->phyml_w->show();
}
void cb_phyml_inv(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	if (g->phyml->is_inv->value()) g->phyml->i_inv->deactivate();
	else g->phyml->i_inv->activate();
}
void cb_phyml_alpha(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	if (g->phyml->is_alpha->value()) g->phyml->i_alpha->deactivate();
	else g->phyml->i_alpha->activate();
}
void cb_phyml_has_tree(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	if (g->phyml->has_tree->value()) g->phyml->i_tree->activate();
	else g->phyml->i_tree->deactivate();
}
void cb_phyml_tstv(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	if (g->phyml->is_tstv->value())
		g->phyml->i_tstv->deactivate();
	else g->phyml->i_tstv->activate();
}
void cb_phyml_n_cat(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	int n_cat = atoi(g->phyml->i_num_cat->value());
	if (n_cat == 1) {
		g->phyml->is_alpha->deactivate();
		g->phyml->i_alpha->deactivate();
	} else {
		g->phyml->is_alpha->activate();
		if (g->phyml->is_alpha->value() == 0)
			g->phyml->i_alpha->activate();
	}
}
void cb_phyml_type(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	Fl_Choice *c = (Fl_Choice*)w;
	if (c->value() == 0) { // nucleotide
		g->phyml->i_model->clear();
		g->phyml->i_model->menu(menu_phyml_nt_model);
		g->phyml->i_model->redraw();
		g->phyml->is_tstv->activate();
		if (g->phyml->is_tstv->value() == 0)
			g->phyml->i_tstv->activate();
	} else if (c->value() == 1) {
		g->phyml->i_model->clear();
		g->phyml->i_model->menu(menu_phyml_aa_model);
		g->phyml->i_model->redraw();
		g->phyml->is_tstv->deactivate();
		g->phyml->i_tstv->deactivate();
	}
}
void cb_phyml_browse(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->fc_phyml_aln->show();
	while (g->fc_phyml_aln->visible()) Fl::check();
	if (g->fc_phyml_aln->value())
		g->phyml->i_alignment->value(g->fc_phyml_aln->value());
	g->phyml->i_alignment->redraw();
}
void cb_phyml_tree(Fl_Widget *w, void *global)
{
	if (fl_choice("Building ML tree is usually very slow.\nFLtreeBeST might not respond for a long time.\nBe patient, or explicitly kill the program.", "Cancel", "No", "Yes") != 2) {
		return;
	}
	FNglobal *g = (FNglobal*)global;
	if (g->phyml->has_tree->value() && g->workspace[g->phyml->i_tree->value()]->get_tree() == 0) {
		fl_alert("No tree is found in workspace %s.", g->workspace[g->phyml->i_tree->value()]);
		return;
	}
	g->active_ws()->set_tree(g->phyml->do_phyml());
	g->active_ws()->redraw();
	g->phyml->has_tree->activate();
}

// BUILD window and miscellaneous
void cb_build(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	int n = 0;
	for (int i = 0; i < FN_N_SPACE; ++i)
		if (g->workspace[i]->get_tree()) ++n;
	if (n) g->build->is_cons->activate();
	else g->build->is_cons->deactivate();
	g->build_w->show();
}
void cb_merge(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->merge_w->show();
}
void cb_compare(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->compare_w->show();
}
void cb_backtrans(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->backtrans_w->show();
}
void cb_close_build(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->build_w->hide();
}
void cb_close_phyml(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->phyml_w->hide();
}
void cb_close_merge(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->merge_w->hide();
}
void cb_close_backtrans(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->backtrans_w->hide();
}
void cb_close_compare(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->compare_w->hide();
}
void cb_build_tree(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	if (g->build->is_cons->value() && g->workspace[g->build->i_cons_tree->value()]->get_tree() == 0) {
		fl_alert("No tree is found in workspace %s.", g->workspace[g->build->i_cons_tree->value()]);
		return;
	}
	g->active_ws()->set_tree(g->build->build());
	g->active_ws()->redraw();
	g->build->is_cons->activate();
}
void cb_toggle_cons(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	if (g->build->is_cons->value())
		g->build->i_cons_tree->activate();
	else g->build->i_cons_tree->deactivate();
}
void cb_do_backtrans(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->backtrans->backtrans();
	g->backtrans_w->hide();
}
void cb_merge_tree(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->active_ws()->set_tree(g->merge->merge());
	g->active_ws()->redraw();
	g->merge_w->hide();
}
void cb_compare_tree(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->compare->compare();
	g->active_ws()->redraw();
	g->compare_w->hide();
}
void cb_prev(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->tabs->value(g->workspace[g->change_ws(-1)]->parent()->parent());
	Fl::flush();
}
void cb_next(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->tabs->value(g->workspace[g->change_ws(+1)]->parent()->parent());
	Fl::flush();
}
void cb_update_buttons(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	Workspace *ws = g->active_ws();
	int n = 0;

	if (g->prev_tab == g->tabs->value()) return;
	g->prev_tab = g->tabs->value();
	for (int i = 0; i < FN_N_SPACE; ++i)
		if (g->workspace[i]->get_tree()) ++n;
	if (ws->get_tree()) {
		g->b_save->activate();
		g->b_expt->activate();
		g->b_root->activate();
		g->b_order->activate();
		g->b_comp->activate();
	} else {
		g->b_save->deactivate();
		g->b_expt->deactivate();
		g->b_root->deactivate();
		g->b_order->deactivate();
		g->b_comp->deactivate();
	}
	if (n >= 2) g->b_merge->activate();
	else g->b_merge->deactivate();
	g->b_spec->value(ws->get_pp()->show_spec);
	g->b_real->value(ws->get_pp()->is_real);
	Fl::flush();
}
void cb_open(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->fc_nhx->show();
	while (g->fc_nhx->visible()) Fl::check();
	if (g->fc_nhx->value()) {
		FILE *fp = fopen(g->fc_nhx->value(), "r");
		if (fp) {
			g->active_ws()->set_tree(fp);
			fclose(fp);
			g->active_ws()->redraw();
		}
	}
}
void cb_save(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->fc_save->show();
	while (g->fc_save->visible()) Fl::check();
	if (g->fc_save->value())
		g->active_ws()->save_nhx(g->fc_save->value());
}
void cb_expt(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->fc_eps->show();
	while (g->fc_eps->visible()) Fl::check();
	if (g->fc_eps->value())
		g->active_ws()->export_eps(g->fc_eps->value());
}
void cb_root(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->active_ws()->root_tree();
	g->active_ws()->redraw();
}
void cb_browse(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->fc_aln->show();
	while (g->fc_aln->visible()) Fl::check();
	if (g->fc_aln->value())
		g->build->i_alignment->value(g->fc_aln->value());
	g->build->i_alignment->redraw();
}
void cb_browse_aa_aln(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->fc_aa_aln->show();
	while (g->fc_aa_aln->visible()) Fl::check();
	if (g->fc_aa_aln->value())
		g->backtrans->i_aa_aln->value(g->fc_aa_aln->value());
	g->backtrans->i_aa_aln->redraw();
}
void cb_browse_nt_seq(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->fc_nt_seq->show();
	while (g->fc_nt_seq->visible()) Fl::check();
	if (g->fc_nt_seq->value())
		g->backtrans->i_nt_seq->value(g->fc_nt_seq->value());
	g->backtrans->i_nt_seq->redraw();
}
void cb_browse_nt_aln(Fl_Widget *w, void *global)
{
	FNglobal *g = (FNglobal*)global;
	g->fc_nt_aln->show();
	while (g->fc_nt_aln->visible()) Fl::check();
	if (g->fc_nt_aln->value())
		g->backtrans->i_nt_aln->value(g->fc_nt_aln->value());
	g->backtrans->i_nt_aln->redraw();
}
void cb_type(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	Fl_Choice *c = (Fl_Choice*)w;
	if (c->value() == 1) { // nucleotide
		g->build->i_dist_type->clear();
		g->build->i_dist_type->menu(menu_nt_type);
		g->build->i_dist_type->redraw();
	} else if (c->value() == 0) {
		g->build->i_dist_type->clear();
		g->build->i_dist_type->menu(menu_aa_type);
		g->build->i_dist_type->redraw();
	}
}
void cb_zoom_in_x(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	Workspace *ws = g->active_ws();
	ws->size(ws->w()+100, ws->h());
	ws->redraw();
}
void cb_zoom_out_x(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	Workspace *ws = g->active_ws();
	ws->size(ws->w()-100, ws->h());
	ws->redraw();
}
void cb_zoom_in_y(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	Workspace *ws = g->active_ws();
	ws->size(ws->w(), ws->h()+100);
	ws->redraw();
}
void cb_zoom_out_y(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	Workspace *ws = g->active_ws();
	ws->size(ws->w(), ws->h()-100);
	ws->redraw();
}
void cb_small_font(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	g->active_ws()->change_font_size(-1);
	g->active_ws()->redraw();
}
void cb_large_font(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	g->active_ws()->change_font_size(+1);
	g->active_ws()->redraw();
}
void cb_spec(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	g->active_ws()->toggle_spec();
	g->active_ws()->redraw();
}
void cb_real(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	g->active_ws()->toggle_real();
	g->active_ws()->redraw();
}
void cb_order(Fl_Widget *w, void *global)
{
	FNglobal *g =(FNglobal*)global;
	g->active_ws()->order_tree();
	g->active_ws()->redraw();
}
