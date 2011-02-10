#ifdef HAVE_PHYML
#ifndef lh3_PHYLOTREE_PHYML_H_
#define lh3_PHYLOTREE_PHYML_H_

#include "tree.h"
#include "align.h"

struct __Arbre;

typedef struct __PhymlConfig
{
	int is_nucl;
	int is_stat;
	int bs;
	char *model;
	float kappa;
	float alpha;
	float invar;
	int n_cat;

	/* for phyml addon */
	double prob_not_exist;
	double prob_dup;
	double prob_loss_dup;
	double prob_loss_spec;
	Tree *ctree, *spec_tree;
} PhymlConfig;

#ifdef __cplusplus
extern "C" {
#endif

void phyml_init();
Tree *phyml_core(MultiAlign *ma, PhymlConfig *pc, Tree *inp, int is_build, int is_opt);
Tree *phyml_arbre2tree(struct __Arbre *tree);
Matrix *phyml_matrix(MultiAlign *ma, PhymlConfig *pc);
PhymlConfig *phyml_init_config();
void phyml_free_config(PhymlConfig *pc);
int phyml_task(int argc, char *argv[]);

#ifdef __cplusplus
}
#endif

#endif
#endif /* HAVE_PHYML */
