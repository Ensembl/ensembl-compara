#include <stdio.h>
#include "flglobal.h"
#include "flnjtree_ui.h"

extern "C" {
FILE *tr_get_fp(const char *fn);
};
int main(int argc, char *argv[])
{
	extern int FL_NORMAL_SIZE;
	int i;

	FL_NORMAL_SIZE = 12;
	FNglobal *g = new FNglobal;
	g->main_w = make_main_window(g);
	g->build_w = make_build_window(g);
	g->phyml_w = make_phyml_window(g);
	g->merge_w = make_merge_window(g);
	g->compare_w = make_comp_window(g);
	g->backtrans_w = make_trans_window(g);
	for (i = 0; i < 3 && i+1 < argc; ++i) {
		FILE *fp = tr_get_fp(argv[i+1]);
		if (fp) {
			g->workspace[i]->set_tree(fp);
			if (fp != stdin) fclose(fp);
		}
	}
	g->main_w->show();
	return Fl::run();
}
