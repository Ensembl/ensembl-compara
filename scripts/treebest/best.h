#ifndef LH3_BEST_H_
#define LH3_BEST_H_

#include "tree.h"
#include "align.h"

typedef struct
{
	MultiAlign *ma;
	Tree *ctree;
	Tree *stree;
	int is_contract_stree;
	int is_phyml;
	int is_phyml_spec;
	int is_phyml_cons;

	/* output related */
	int is_debug;
	char *prefix;
	char *output_fn;

	/* alignment preprocessing */
	int is_sequenced_only;
	int is_collapse_splice;
	int is_mask_lss;
	int is_quiet;
	int qual_thres;

	/* PHYML related, passed to PhymlConfig */
	int n_cat;
	float kappa;
	float alpha;
	double prob_dup;
	double prob_loss_dup;
	double prob_loss_spec;
	double prob_not_exist;
} BestConfig;

#ifdef __cplusplus
extern "C" {
#endif

BestConfig *best_init_option();
void best_free_option(BestConfig *bo);
int best_task(int argc, char *argv[]);
BestConfig *best_command_line_options(int argc, char *argv[]);
Tree *best_core(BestConfig *bo);

#ifdef __cplusplus
}
#endif

#endif
