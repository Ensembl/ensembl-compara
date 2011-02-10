#ifndef TREE_H_
#define TREE_H_

#include <stdio.h>
#include <assert.h>

#define OUTPUT_SDI		0x0001
#define OUTPUT_COMPARE	0x0002
#define OUTPUT_ORI_NHX	0x0004
#define COMPARE_WRITE_INTERNAL_NAME 0x0001
#define COMPARE_WRITE_BRANCH_LENGTH 0x0002
#define COMPARE_WRITE_BS_VALUE 0x0004

#define spec(p) (((SDIinfo*)(p)->ptr)->ptr)
#define SDIptr(p) ((SDIinfo*)(p)->ptr)

/**
 * structure of a node
 */
typedef struct __lih_Tree
{
	void *ptr; /**< store additional information */
	void *nhx; /**< NHX definitions */
	int n; /**< number of child nodes */
	int bs; /**< bootstrap value */
	char *name; /**< the name of this node */
	char is_cons; /**< Is this node constrained in Neighbour-Joining? This should be modified ONLY in tr_nj(). */
	int id, flag; /**< "id" should not be changed once it is assigned for the first time. */
	int ftime, n_leaf; /**< finish time and number of leaves under this node */
	float d; /**< distance */
	struct __lih_Tree **node, *pre; /**< children and parent */

	int n_node;
	struct __lih_Tree **node_array; /** used on special conditions, do not touch this!!! */
} Tree;

typedef Tree *TreePtr;

/** structure of a scoring matrix */
typedef struct
{
	int count; /**< number of sequences */
	char **name; /**< name of the sequences */
	float *dist; /**< symmetric count*count distance matrix */
} Matrix;

/** structure of SDI information */
typedef struct __lih_SDIinfo
{
	char type; /**< equals to D, S, P (pseudo-speciation, a duplication indeed) or N (not assigned) */
	Tree *ptr; /**< linked to species tree */
	int n_lost; /**< number of gene losts */
	TreePtr *lost; /**< array of lost genes */
	int n_spec_node; /**< used for tr_SDI() */
	int is_confirmed_dup;
	int sis; /* species intersection score */
	char *spec_node; /**< used for tr_SDI() */
} SDIinfo;

/** ortholog information */
typedef struct
{
	 int n; /**< number of genes */
	 short **rel; /**< a symetric n*n matrix, where an 1 cell denotes a pair of ortholog */
	 TreePtr **taxon;
	 char **is_pseudo;
} Ortholog; 

struct __lih_MultiAlign;

typedef struct
{
	FILE *fp_dist; /* file handler for distance file */
	FILE *fp_align; /* file handler for alignment file */
	int n_con; /* number of constraint tree(s) */
	Tree **constraint; /* constraint tree(s) */
	Tree *compared; /** tree to be compared */
	int bs_time; /* number of bootstraps */
	int node_mode; /* if true, use node mode to calculate BS */
	int dist_type; /* type of distance */
	int rooting; /* if true, root the tree */
	Tree *tree; /* full tree */
	int filter; /* filter threshold */
	int is_verbose; /* if true, verbose output */
	int is_sdi_root; /* if true, use SDI rooting */
	int is_reorder; /* wether reorder the leaves */
	int is_collapse; /* collapse alternative splicing */
	int is_mask; /* whether applying alignment mask */
	int is_mask_segment;
	 int is_pseudo_ortho;
	int is_strong_con; /* if true, tree will not be rebuilt. */
	struct __lih_MultiAlign *aln; /* multialignment */
	unsigned out_flag; /* output format */

	int time_limit; /* time limit: control the number of bootstrap times. Unit: seconds */
	int real_bs_time; /* the bootstrap times that are actually carried on in the specified time */
	int (*func)(float);
	int is_aln; /* input format. non-zero for ALN, otherwise MFA */
	int init_cons; /* whether constraints should be applied to the root node */

	Tree *spec_tree; /* species tree for SDI */
	Ortholog *ortho; /* results of ortholog inference */

	int n_sub; /* number of genes in `list' */
	char **sub_name; /* gene names in `list' */
	Tree *subtree; /* cut tree, a pointer to a subtree of *tree */
	char *cut; /* outgroup species */
} Task;

#ifdef __cplusplus
extern "C" {
#endif

/* integrated tree builder */
Tree *tr_build_tree(Task *task);

/* the parser for the tree in NH format */
Tree **tr_parse(FILE*, int*);
Tree *tr_parse_first(FILE*);
Tree **tr_parse_str(const char*, int*);

/* constrained neighbour-joining */
Tree *tr_nj(Matrix*, int n_cons, Tree **constraint, int init_cons);
Tree *tr_nj_binary(Matrix*, int n_cons, Tree **constraint, int init_cons);
Tree *tr_nj_rooted(Matrix*, int n_cons, Tree **constraint, int init_cons);

/* write Tree:ptr array. prepare for bootstrap */
void tr_pre_bootstrap(Tree *tree, int type);

/* update bootstrap value of tree */
void tr_update_bootstrap(Tree *tree, const Tree *samp, int type);

/* normalize bootstrap value */
void tr_normalize_bs_value(Tree *tree, int bs_time);
/* find the last common ancestor of `list' in the `tree' */
Tree *tr_comm_ancester(Tree *tree, int m, char **list);
/* get the subtree of `tree' */
Tree *tr_subtree(Tree *tree, int m, char **list);
/* cut `tree' given a `m'-long array `ingroup' and cut species `cut'. */
Tree *tr_cut_tree(Tree *tree, const Tree *spec, int m, char **ingroup, const char *cut);

/* root a tree by minimizing tree height */
Tree *tr_root_by_min_height(Tree *root);
/* reroot a tree `root', using `node' as the root. `dist' is used to assign branch length */
Tree *tr_reroot(Tree *root, Tree *node, float dist);
/* not tested! */
Tree *tr_remove_root(Tree *root);
/* adjust the branch length of the two root branches */
float tr_slide_binary_root(Tree *root);
/* root a tree `root' by minimizing the number of duplication events */
Tree *tr_root_by_sdi(Tree *root, Tree *spec);
Tree *tr_root_by_sdi_fast(Tree *root, Tree *spec);

/* output */
char *tr_tree_string(const Tree *root, unsigned flag);
void tr_tree_output(FILE *fp, const Tree*, unsigned flag);
void tr_ortho_output(FILE *fp, const Ortholog *ortho, const Tree *tree);
void tr_stat_output(FILE *fp, const Tree *tree);
void tr_task_output(FILE *fp, const Task *task);
void tr_matrix_output(FILE *fp, const Matrix *mat);

/* read and delete matrix */
Matrix *tr_read_matrix(FILE*);
void tr_delete_matrix(Matrix*);

/* Speciation/Duplication Inference. The number of duplications will be returned. */
int tr_SDI(Tree *root, const Tree *spec, Tree **links);
/* lost inference */
int tr_lost_infer(Tree *tree, const Tree *spec);
/* ortholog inference */
Ortholog *tr_ortho(Tree *root, const Tree *spec, int is_pseudo);
/* compare bootstrapped ortholog relationship and the original ortholog */
void tr_comp_ortho(Ortholog *ori, const Ortholog *bs);

Tree *tr_trim_poor_leaves(const Tree *tree, Tree *spec, int thres);

Tree *tr_mmerge(int n, Tree **forest);

/* memory handler */
Tree *tr_new_node();
Ortholog *tr_alloc_ortho(int);

/** delete a node */
void tr_delete_node(Tree*);
/* recursively delete a tree */
void tr_delete_tree(Tree*);
/* delete ortholog structure */
void tr_delete_ortho(Ortholog*);
/* remove all Tree::ptr */
void tr_delete_tree_ptr(Tree*);
/* remove all (SDIinfo*)(Tree::ptr) */
void tr_delete_tree_SDIptr(Tree*);

int tr_compare_core(Tree *src, Tree *dst, unsigned write_flag);
int tr_tree_dist(const Tree *ori_tree1, const Tree *ori_tree2);

void tr_set_spec_leaf_order(Tree *tree);
void tr_order_core(Tree *tree);

Tree *tr_post_spec_tree(Tree *tree);
Tree *tr_default_spec_tree();
Tree *tr_core_spec_tree();
void tr_est_len(Tree *tree, Matrix *mat, const char *tag);

Task *tr_alloc_task();
void tr_delete_task(Task*);

void tr_attach_seed_tag(Tree *tree, int n, char **list);

#ifdef __cplusplus
}
#endif

#endif
