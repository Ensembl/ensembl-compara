#ifdef LH3_ADDON
#ifndef LH3_ADDON_H_
#define LH3_ADDON_H_

#include "../tree.h"

struct __Arbre;
struct __Edge;
struct __PhymlConfig;

typedef struct
{
	int is_dup, tot_dup;
	int n_loss, tot_dup_loss, tot_spec_loss;
	int is_cal;
	TreePtr spec;
	int *passed;
} lh3Spec;

typedef struct
{
	double ratio_not_exist;
	double log_dup, log_spec;
	double log_loss_spec, log_present_spec;
	double log_loss_dup, log_present_dup;
	double ratio_cons, loglk_spec;
	Tree *ctree, *spec_tree;
	int is_NNI, min_branch;
	void *hs; /* HashedSets* */
} lh3Tree;

typedef struct
{
	Tree *cleaf, *spec;
} lh3Node;

typedef struct
{
	int do_exist;
	int is_cal[2]; /* whether the left part (0) and the right part (1) have been calculated. */
	char *array[2]; /* leaf array for the left part (0) and the right part (1). */
	lh3Spec spec[2];
	lh3Spec cur_spec;
} lh3Edge;

#ifdef __cplusplus
extern "C" {
#endif
void lh3_addon_init(struct __Arbre *tree, struct __PhymlConfig *pc);
void lh3_addon_free(struct __Arbre *tree);

void lh3_cons_clear_cal_flag(struct __Arbre *tree);
void lh3_cons_cal_one_branch(struct __Arbre *tree, struct __Edge *start, int direction);
void lh3_cons_cal_all_branch(struct __Arbre *tree);
double lh3_cons_update_one_ratio(struct __Arbre *tree, struct __Edge *b_fcus);
double lh3_cons_cal_all_ratio(struct __Arbre *tree);

void lh3_spec_clear_cal_flag(struct __Arbre *tree);
void lh3_spec_cal_one_branch(struct __Arbre *tree, struct __Edge *start, int direction);
void lh3_spec_cal_all_branch(struct __Arbre *tree);
double lh3_spec_update_one_ratio(struct __Arbre *tree, struct __Edge *b_fcus);
double lh3_spec_cal_all_ratio(struct __Arbre *tree);
#ifdef __cplusplus
}
#endif

#endif

#endif
