#ifndef TREE_PLOT_H_
#define TREE_PLOT_H_

#include "tree.h"

#define plot_ptr(p) ((PlotPtr*)(p)->ptr)

typedef struct
{
	float x, y;
	void *ptr;
} PlotPtr;

typedef struct
{
	int width, height;
	unsigned c_line, c_ext, c_int, c_bs, c_dup;
	int is_real;
	int x_margin, y_margin;
	int font_size;
	int is_SDI;
	float font_width;
	float line_width;
	float box_width;
	float x_skip;
	char *font;
	int is_color;
	int is_bs;

	int show_spec;
} PlotParam;

#ifdef __cplusplus
extern "C" {
#endif

void plot_modify_PlotPtr(Tree *tree, int is_init);
int plot_cal_x_y(Tree *tree, int is_real);
void plot_eps(FILE *eps, Tree *tree, PlotParam *pp);
PlotParam *plot_default_param();

#ifdef __cplusplus
}
#endif

#endif
