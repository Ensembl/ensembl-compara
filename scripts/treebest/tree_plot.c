#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "eps.h"
#include "utils.h"
#include "tree_plot.h"

void plot_modify_PlotPtr(Tree *tree, int is_init)
{
	Tree **node;
	int i, n;
	PlotPtr *pp;

	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	for (i = 0; i < n; ++i) {
		if (is_init) {
			pp = (PlotPtr*)malloc(sizeof(PlotPtr));
			pp->x = pp->y = 0.0;
			pp->ptr = node[i]->ptr;
			node[i]->ptr = pp;
		} else {
			pp = (PlotPtr*)(node[i]->ptr);
			node[i]->ptr = pp->ptr;
			free(pp);
		}
	}
	free(node);
}
int plot_cal_x_y(Tree *tree, int is_real)
{
	Tree **node, *p;
	int i, j, n;
	float scale;

	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	scale = tree->n_leaf - 1;
	/* calculate y */
	/* here I do not scale >= 1! */
	for (i = j = 0; i < n; ++i) {
		p = node[i];
		if (p->n == 0) {
			plot_ptr(p)->y = (float)j / scale;
			++j;
		} else plot_ptr(p)->y = (plot_ptr(p->node[0])->y + plot_ptr(p->node[p->n-1])->y) / 2.0;
	}
	/* calculate x */
	if (is_real) {
		scale = plot_ptr(tree)->x = (tree->d >= 0.0)? tree->d : 0.0;
		for (i = n - 2; i >= 0; --i) {
			p = node[i];
			plot_ptr(p)->x = plot_ptr(p->pre)->x + ((p->d >= 0.0)? p->d : 0.0);
			if (plot_ptr(p)->x > scale)
				scale = plot_ptr(p)->x;
		}
		if (scale == 0.0) is_real = 0;
	}
	if (!is_real) {
		scale = plot_ptr(tree)->x = 1.0;
		for (i = n - 2; i >= 0; --i) {
			p = node[i];
			plot_ptr(p)->x = plot_ptr(p->pre)->x + 1.0;
			if (plot_ptr(p)->x > scale)
				scale = plot_ptr(p)->x;
		}
		for (i = 0; i < n - 1; ++i) {
			if (node[i]->n == 0)
				plot_ptr(node[i])->x = scale;
		}
	}
	/* rescale x */
	for (i = 0; i < n; ++i)
		plot_ptr(node[i])->x /= scale;
	free(node);
	return is_real;
}

PlotParam *plot_default_param()
{
	PlotParam *pp;
	pp = (PlotParam*)malloc(sizeof(PlotParam));
	pp->width = 640;
	pp->height = 480;
	pp->is_real = 1;
	pp->is_SDI = 0;
	pp->x_margin = 20;
	pp->y_margin = 20;
	pp->c_line = 5320;
	pp->c_ext = 0;
	pp->c_int = 16711680;
	pp->c_bs = 32768;
	pp->c_dup = 16711680;
	pp->font_size = 11;
	pp->font_width = pp->font_size / 2.0;
	pp->line_width = 0.5;
	pp->box_width = 4.0;
	pp->x_skip = 3.0;
	pp->is_bs = 1;
	pp->is_color = 1;
	pp->font = (char*)malloc(sizeof(char) * 256);

	pp->show_spec = 0;
	strcpy(pp->font, "Helvetica-Narrow");
	return pp;
}
void plot_eps(FILE *eps, Tree *tree, PlotParam *pp)
{
	int i, n;
	Tree **node, *p;
	int tmp, max;
	float real_x, real_y, shift_x, shift_y;
	char str[128];

	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	plot_modify_PlotPtr(tree, 1);
	plot_cal_x_y(tree, pp->is_real);
	/* get max name length */
	for (i = 0, max = 0; i < n; ++i) {
		if (node[i]->n > 0) continue;
		tmp = strlen(node[i]->name);
		if (tmp > max) max = tmp;
	}
	real_x = pp->width - 2 * pp->x_margin - max * pp->font_width;
	real_y = pp->height - 2 * pp->y_margin - pp->font_size;
	shift_x = pp->x_margin;
	shift_y = pp->y_margin + pp->font_size / 2;

	eps_header(eps, pp->width, pp->height, pp->line_width);
	eps_font(eps, pp->font, pp->font_size);
	/* name of external nodes */
	if (pp->is_color) eps_color(eps, pp->c_ext);
	else eps_gray(eps, 0);
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (p->n == 0)
			eps_Lstr4s(eps, plot_ptr(p)->x * real_x + pp->x_skip*2 + shift_x, pp->height - plot_ptr(p)->y * real_y - shift_y, p->name);
	}
	/* name of internal nodes */
	if (pp->is_color) eps_color(eps, pp->c_int);
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (p->n > 0 && p->name)
			eps_Rstr4(eps, plot_ptr(p)->x * real_x - pp->x_skip + shift_x, pp->height - plot_ptr(p)->y * real_y - shift_y, p->name);
	}
	/* bootstrap value */
	sprintf(str, "%s-Oblique", pp->font);
	eps_font(eps, str, pp->font_size-1);
	if (pp->is_color) eps_color(eps, pp->c_bs);
	else eps_gray(eps, 0.2);
	for (i = 0; i < n; ++i) {
		p = node[i];
		str[0] = '\0';
		if (pp->is_bs && p->bs > 0) {
			if (pp->is_SDI && pp->show_spec && plot_ptr(p)->ptr && ((SDIinfo*)(plot_ptr(p)->ptr))->ptr)
				sprintf(str, "%s %d", ((SDIinfo*)(plot_ptr(p)->ptr))->ptr->name, p->bs);
			else sprintf(str, "%d", p->bs);
			eps_Rstr(eps, plot_ptr(p)->x * real_x - pp->x_skip + shift_x, pp->height - plot_ptr(p)->y * real_y - pp->font_size*0.9 - shift_y, str);
		} else if (p->n > 0 && pp->is_SDI && pp->show_spec && plot_ptr(p)->ptr && ((SDIinfo*)(plot_ptr(p)->ptr))->ptr) {
			sprintf(str, "%s", ((SDIinfo*)(plot_ptr(p)->ptr))->ptr->name);
			eps_Rstr(eps, plot_ptr(p)->x * real_x - pp->x_skip + shift_x, pp->height - plot_ptr(p)->y * real_y - pp->font_size*0.9 - shift_y, str);
		}
	}
	/* now begin to draw lines */
	/* horizontal lines */
	if (pp->is_color) eps_color(eps, pp->c_line);
	else eps_gray(eps, 0);
	eps_linex(eps, shift_x, plot_ptr(tree)->x * real_x + shift_x, pp->height - plot_ptr(tree)->y * real_y - shift_y);
	for (i = 0; i < n - 1; ++i) {
		p = node[i];
		eps_linex(eps, plot_ptr(p->pre)->x * real_x + shift_x, plot_ptr(p)->x * real_x + shift_x, pp->height - plot_ptr(p)->y * real_y - shift_y);
	}
	/* vertical lines */
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (p->n == 0) continue;
		eps_liney(eps, pp->height - plot_ptr(p->node[0])->y * real_y - shift_y, pp->height - plot_ptr(p->node[p->n-1])->y * real_y - shift_y,
				plot_ptr(p)->x * real_x + shift_x);
	}
	eps_stroke(eps);
	/* nodes */
	if (pp->is_color) {
		for (i = 0; i < n; ++i) {
			float tmp_x, tmp_y, tmp_l;
			if (pp->is_SDI && plot_ptr(node[i])->ptr && ((SDIinfo*)(plot_ptr(node[i])->ptr))->type == 'D') continue;
			tmp_x = plot_ptr(node[i])->x * real_x + shift_x;
			tmp_y = pp->height - plot_ptr(node[i])->y * real_y - shift_y;
			tmp_l = pp->box_width / 2.0;
			eps_box(eps, tmp_x - tmp_l, tmp_y - tmp_l, tmp_x + tmp_l, tmp_y + tmp_l);
		}
		eps_fill(eps);
	}
	if (pp->is_color) eps_color(eps, pp->c_dup);
	else eps_gray(eps, 0);
	if (pp->is_SDI) {
		for (i = 0; i < n; ++i) {
			float tmp_x, tmp_y, tmp_l;
			if (plot_ptr(node[i])->ptr && ((SDIinfo*)(plot_ptr(node[i])->ptr))->type != 'D') continue;
			tmp_x = plot_ptr(node[i])->x * real_x + shift_x;
			tmp_y = pp->height - plot_ptr(node[i])->y * real_y - shift_y;
			tmp_l = pp->box_width / 2.0;
			eps_box(eps, tmp_x - tmp_l, tmp_y - tmp_l, tmp_x + tmp_l, tmp_y + tmp_l);
		}
		eps_fill(eps);
	}
	eps_bottom(eps);
	plot_modify_PlotPtr(tree, 0);
	free(node);
}
static int plot_eps_usage()
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Usage:   treebest export [options] <tree>\n\n");
	fprintf(stderr, "Options: -x NUM      width [640]\n");
	fprintf(stderr, "         -y NUM      height [480]\n");
	fprintf(stderr, "         -m NUM      margin [20]\n");
	fprintf(stderr, "         -f NUM      font size [11]\n");
	fprintf(stderr, "         -b FNUM     box size [4.0]\n");
	fprintf(stderr, "         -w FNUM     font width [font_size/2]\n");
	fprintf(stderr, "         -s FILE     species tree\n");
	fprintf(stderr, "         -B          suppress bootstrap value\n");
	fprintf(stderr, "         -M          black/white mode\n");
	fprintf(stderr, "         -S          show species name\n");
	fprintf(stderr, "         -d          speciation/duplication inference\n");
	fprintf(stderr, "         -p          pseudo-length\n\n");
	return 1;
}
int plot_eps_task(int argc, char *argv[])
{
	extern FILE *tr_get_fp(const char *fn);
	extern Tree *tr_default_spec_tree();
	FILE *fp_tree, *fp_spec = 0;
	Tree **tree, *spec_tree;
	int i, n, c;
	PlotParam *pp;

	pp = plot_default_param();
	fp_tree = fp_spec = 0;
	spec_tree = 0;
	while ((c = getopt(argc, argv, "x:y:m:b:f:w:s:pdSBM")) >= 0) {
		switch (c) {
			case 'b': pp->box_width = atof(optarg); break;
			case 'x': pp->width = atoi(optarg); break;
			case 'y': pp->height = atoi(optarg); break;
			case 'm': pp->x_margin = pp->y_margin = atoi(optarg); break;
			case 'f': pp->font_size = atoi(optarg); pp->font_width = pp->font_size/2.0; break;
			case 'w': pp->font_width = atof(optarg); break;
			case 'B': pp->is_bs = 0; break;
			case 'M': pp->is_color = 0; break;
			case 'd': pp->is_SDI = 1; break;
			case 'p': pp->is_real = 0; break;
			case 's': fp_spec = tr_get_fp(optarg); break;
			case 'S': pp->show_spec = 1; break;
		}
	}
	
	if (optind == argc) return plot_eps_usage();

	if (pp->is_SDI && fp_spec) {
		Tree **tmp;
		int nn;
		tmp = tr_parse(fp_spec, &nn);
		fclose(fp_spec);
		spec_tree = tmp[0];
		for (i = 1; i < nn; ++i)
			tr_delete_tree(tmp[i]);
		free(tmp);
	} else if (pp->is_SDI) spec_tree = tr_default_spec_tree();

	fp_tree = tr_get_fp(argv[optind]);
	tree = tr_parse(fp_tree, &n);
	fclose(fp_tree);
	if (pp->is_SDI) tr_SDI(tree[0], spec_tree, 0);

	plot_eps(stdout, tree[0], pp);

	for (i = 0; i < n; ++i)
		tr_delete_tree(tree[i]);
	free(tree);
	free(pp->font);
	free(pp);
	return 0;
}
