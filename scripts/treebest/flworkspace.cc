#include <FL/Fl_Box.h>
#include <FL/fl_draw.h>
#include <stdlib.h>
#include "flglobal.h"
#include "utils.h"
#include "tree_plot.h"
#include "common/hash_char.h"

using namespace std;

Workspace::Workspace(int x, int y, int width, int height) : Fl_Widget(x, y, width, height, 0)
{
	pp = plot_default_param();
	pp->width = width;
	pp->height = height;
	pp->font_size = 10;
	pp->is_SDI = 1;
	pp->box_width = 6.0;
	align(FL_ALIGN_TOP);
	box(FL_FLAT_BOX);
	color(FL_WHITE);
	tree = 0;
}
void Workspace::destroy_tree()
{
	if (tree) {
		tr_delete_tree_SDIptr(tree);
		tr_delete_tree(tree);
		tree = 0;
	}
}
void Workspace::destroy()
{
	destroy_tree();
	free(pp->font);
	free(pp);
}
void Workspace::size(int ww, int hh)
{
	if (ww < 10) ww = 10;
	if (hh < 10) hh = 10;
	pp->width = ww; pp->height = hh;
	Fl_Widget::size(ww, hh);
}
void Workspace::draw()
{
	draw_box();
	draw_tree();
	global->prev_tab = 0;
	cb_update_buttons(this, global);
}
void Workspace::redraw()
{
	Fl_Widget::redraw();
	this->parent()->redraw();
}
void Workspace::draw_tree()
{
	int i, n;
	Tree **node, *p;
	int tmp, max;
	float real_x, real_y, shift_x, shift_y;
	char *s;
	hash_map_char<char*> *hash;

	if (tree == 0) return;
	fl_font(FL_HELVETICA, pp->font_size);
	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	plot_modify_PlotPtr(tree, 1);
	pp->is_real = plot_cal_x_y(tree, pp->is_real);
	for (i = 0, max = 0; i < n; ++i) {
		if (node[i]->n > 0) continue;
		tmp = (int)(fl_width(node[i]->name) + 0.5);
		if (tmp > max) max = tmp;
	}
	real_x = pp->width - 2 * pp->x_margin - max;
	real_y = pp->height - 2 * pp->y_margin - pp->font_size;
	shift_x = pp->x_margin + x();
	shift_y = pp->y_margin + pp->font_size / 2 + y();

	/* name of nodes */
	{
		char str[128];

		for (i = 0; i < n; ++i) {
			p = node[i];
			if (p->n == 0) {
				hash = (hash_map_char<char*>*)p->nhx;
				if (hash && hash->find("Sd", &s) && strcmp(s, "Y") == 0)
					fl_color(255, 128, 0);
				else fl_color(FL_BLACK);
				fl_draw(p->name, (int)(plot_ptr(p)->x * real_x + pp->x_skip*2 + shift_x + 0.5),
						(int)(plot_ptr(p)->y * real_y + shift_y + pp->font_size / 2.0 - 1.0));
			}
		}
		fl_color(FL_RED);
		for (i = 0; i < n; ++i) {
			p = node[i];
			if (p->n > 0 && p->name)
				fl_draw(p->name, (int)(plot_ptr(p)->x * real_x - pp->x_skip + shift_x - fl_width(p->name) + 0.5),
						(int)(plot_ptr(p)->y * real_y + shift_y - 1.5));
		}
		fl_font(FL_HELVETICA, pp->font_size-1);
		fl_color(0, 100, 0);
		for (i = 0; i < n; ++i) {
			p = node[i];
			str[0] = '\0';
			if (p->bs > 0) {
				if (pp->show_spec && pp->is_SDI && plot_ptr(p)->ptr && ((SDIinfo*)(plot_ptr(p)->ptr))->ptr)
					sprintf(str, "%s %d", ((SDIinfo*)(plot_ptr(p)->ptr))->ptr->name, p->bs);
				else sprintf(str, "%d", p->bs);
			} else if (p->n > 0 && pp->show_spec && pp->is_SDI && plot_ptr(p)->ptr && ((SDIinfo*)(plot_ptr(p)->ptr))->ptr)
				sprintf(str, "%s", ((SDIinfo*)(plot_ptr(p)->ptr))->ptr->name);
			if (str[0])
				fl_draw(str, (int)(plot_ptr(p)->x * real_x - pp->x_skip + shift_x - fl_width(str) + 0.5),
						(int)(plot_ptr(p)->y * real_y + pp->font_size + shift_y + 0.5));
		}
	}
	/* draw lines */
	{
		fl_color(FL_BLUE);
		/* horizontal lines */
		for (i = 0; i < n - 1; ++i) {
			p = node[i];
			if (tree->is_cons && p->is_cons == 0) fl_color(FL_RED);
			fl_xyline((int)(plot_ptr(p->pre)->x * real_x + shift_x + 0.5), (int)(plot_ptr(p)->y * real_y + shift_y + 0.5),
					(int)(plot_ptr(p)->x * real_x + shift_x + 0.5));
			if (tree->is_cons && p->is_cons == 0) fl_color(FL_BLUE); // change back
		}
		/* vertical lines */
		for (i = 0; i < n; ++i) {
			p = node[i];
			if (p->n == 0) continue;
			if (tree->is_cons && p->is_cons == 0) fl_color(FL_RED);
			fl_yxline((int)(plot_ptr(p)->x * real_x + shift_x + 0.5), (int)(plot_ptr(p->node[0])->y * real_y + shift_y + 0.5),
					(int)(plot_ptr(p->node[p->n-1])->y * real_y + shift_y + 0.5));
			if (tree->is_cons && p->is_cons == 0) fl_color(FL_BLUE); // change back
		}
	}
	/* draw nodes */
	{
		fl_color(FL_BLUE);
		for (i = 0; i < n; ++i) {
			float tmp_x, tmp_y, tmp_l;
			p = node[i];
			if (pp->is_SDI && plot_ptr(p)->ptr && ((SDIinfo*)(plot_ptr(p)->ptr))->type == 'D') continue;
			tmp_x = plot_ptr(p)->x * real_x + shift_x;
			tmp_y = plot_ptr(p)->y * real_y + shift_y;
			tmp_l = pp->box_width / 2.0;
			fl_rectf((int)(tmp_x - tmp_l + 0.5), (int)(tmp_y - tmp_l + 0.5), (int)(pp->box_width + 0.5), (int)(pp->box_width + 0.5));
		}
		if (pp->is_SDI) {
			fl_color(FL_RED);
			for (i = 0; i < n; ++i) {
				float tmp_x, tmp_y, tmp_l;
				p = node[i];
				if (plot_ptr(p)->ptr && ((SDIinfo*)(plot_ptr(p)->ptr))->type != 'D') continue;
				tmp_x = plot_ptr(p)->x * real_x + shift_x;
				tmp_y = plot_ptr(p)->y * real_y + shift_y;
				tmp_l = pp->box_width / 2.0;
				fl_rectf((int)(tmp_x - tmp_l + 0.5), (int)(tmp_y - tmp_l + 0.5), (int)(pp->box_width + 0.5), (int)(pp->box_width + 0.5));
			}
		}
	}
		
	plot_modify_PlotPtr(tree, 0);
	free(node);
}
int Workspace::export_eps(const char *fn)
{
	FILE *fp;
	PlotParam *pp_eps;
	
	if (!tree) {
		fprintf(stderr, "[Workspace::export_eps] Nothing to export\n");
		return 1;
	}
	fp = fopen(fn, "w");
	if (!fp) {
		fprintf(stderr, "[Workspace::export_eps] fail to create %s\n", fn);
		return 1;
	}
	pp_eps = plot_default_param();
	pp_eps->width = pp->width;
	pp_eps->height = pp->height;
	pp_eps->x_margin = pp->x_margin;
	pp_eps->y_margin = pp->y_margin;
	pp_eps->line_width = 0.3;
	pp_eps->is_real = pp->is_real;
	pp_eps->is_SDI = pp->is_SDI;
	pp_eps->show_spec = pp->show_spec;
	pp_eps->font_size = pp->font_size;
	plot_eps(fp, tree, pp_eps);
	fclose(fp);
	free(pp_eps->font);
	free(pp_eps);
	return 0;
}
int Workspace::save_nhx(const char *fn)
{
	FILE *fp;
	if (!tree) return 1;
	fp = fopen(fn, "w");
	if (!fp) {
		fprintf(stderr, "[Workspace::save_nhx] fail to create %s\n", fn);
		return 1;
	}
	tr_tree_output(fp, tree, OUTPUT_SDI);
	fclose(fp);
	return 0;
}
void Workspace::set_tree(FILE *fp)
{
	if (fp == 0) return;
	destroy_tree();
	tree = tr_parse_first(fp);
	tr_SDI(tree, global->spec_tree, 0);
	tr_lost_infer(tree, global->spec_tree);
}
void Workspace::set_tree(Tree *t) // tr_SDI() and tr_lost_infer() must be applied by users!
{
	if (t == 0) return;
	destroy_tree();
	tree = t;
}
void Workspace::root_tree()
{
	if (tree) {
		tree = tr_root_by_sdi(tree, global->spec_tree);
		tr_SDI(tree, global->spec_tree, 0);
		tr_lost_infer(tree, global->spec_tree);
	}
}
void Workspace::order_tree()
{
	if (tree) {
		tr_set_spec_leaf_order(tree);
		tr_order_core(tree);
	}
}
