#include <stdlib.h>
#include <unistd.h>
#include "common/hash_misc.h"
#include "common/hash_char.h"
#include "tree.h"
#include "utils.h"
#include "cpp_utils.h"

#define DEFAULT_BS 50

struct _Bipart;

typedef struct _AllowedNode
{
	int n, max;
	int n_leaf;
	char *array;
	char *name; // leaf name
	struct _Bipart **bipart;
	// following variables are used in tree reconstruction
	char is_calculated;
	int F, i;
} AllowedNode;

typedef struct
{
	int i;
	AllowedNode *an;
} ANStack;

typedef struct _Bipart
{
	int F, f, bs;
	int tree_index;
	AllowedNode *an[2];
} Bipart;

typedef struct
{
	int n, max;
	AllowedNode **array;
} SameMagic, *SameMagicPtr;

typedef struct
{
	SDIinfo *si;
	char *array;
	unsigned magic;
	AllowedNode *an;
} MMergeAux;

typedef hash_map_misc<SameMagicPtr> AllNodeHash;

typedef struct
{
	AllNodeHash *hash;
	AllowedNode *root_an;
	int n_leaf, n_all_node, n_stack_size, n_tree;
} MMergeGlobal;

#define MMinfo(p) ((MMergeAux*)(p)->ptr)

#ifdef __cplusplus
extern "C" {
#endif
int tr_mmerge_task(int argc, char *argv[]);
FILE *tr_get_fp(const char *fn);
Tree *tr_default_spec_tree();
#ifdef __cplusplus
}
#endif

/*
 * backup SDIinfo ptr
 */
static void dump_SDIinfo(Tree *tree)
{
	int i, m;
	MMergeAux *p;
	Tree *q, **node;

	node = tr_stack(tree, Tree*);
	m = tr_expand_node(tree, node);
	for (i = 0; i < m; ++i) {
		q = node[i];
		p = (MMergeAux*)malloc(sizeof(MMergeAux));
		p->si = SDIptr(q);
		p->array = 0;
		p->magic = 0;
		p->an = 0;
		q->ptr = p;
	}
	free(node);
}
/*
 * recover SDIinfo
 */
static void restore_SDIinfo(Tree *tree)
{
	int i, m;
	MMergeAux *p;
	Tree **node;

	node = tr_stack(tree, Tree*);
	m = tr_expand_node(tree, node);
	for (i = 0; i < m; ++i) {
		p = MMinfo(node[i]);
		free(p->array);
		node[i]->ptr = p->si;
		free(p);
	}
	free(node);
}
static inline AllowedNode *alloc_AllowedNode()
{
	AllowedNode *an = (AllowedNode*)malloc(sizeof(AllowedNode));
	an->n = an->max = 0;
	an->i = -1;
	an->F = 0;
	an->name = 0;
	an->n_leaf = 0;
	an->is_calculated = 0;
	an->array = 0;
	an->bipart = 0;
	return an;
}
static inline SameMagicPtr locate_SameMagic(unsigned magic, AllNodeHash *all_node)
{
	SameMagicPtr smp;
	if (!all_node->find(magic, &smp)) {
		smp = (SameMagic*)malloc(sizeof(SameMagic));
		smp->n = smp->max = 0;
		smp->array = 0;
		all_node->insert(magic, smp);
	}
	return smp;
}
static inline int cal_score(Tree *t)
{
	int i, n_lost;
	for (n_lost = i = 0; i < t->n; ++i)
		n_lost += MMinfo(t->node[i])->si->n_lost;
	return (((((MMinfo(t)->si->type == 'D')? 1 : 0) << 8) + n_lost + 1) << 8);
}
static inline AllowedNode *insert_to_SameMagic(SameMagicPtr smp, int n_leaf, char *q, Tree *t, AllowedNode *an1, AllowedNode *an2, int tree_index)
{
	int i, j, k;
	for (i = 0; i < smp->n; ++i) {
		char *r = smp->array[i]->array;
		for (j = 0; j < n_leaf; ++j)
			if (q[j] != r[j]) break;
		if (j == n_leaf) break; // found!
	}
	AllowedNode *an;
	if (i == smp->n) { // not found, then append
		if (smp->n == smp->max) {
			smp->max += 4;
			smp->array = (AllowedNode**)realloc(smp->array, sizeof(AllowedNode*) * smp->max);
		}
		an = smp->array[i] = alloc_AllowedNode();
		an->array = (char*)malloc(sizeof(char) * n_leaf);
		int count = 0;
		for (j = count = 0; j < n_leaf; ++j) {
			an->array[j] = q[j];
			if (q[j]) ++count;
		}
		an->n_leaf = count;
		++(smp->n);
	} else an = smp->array[i];
	for (k = 0; k < an->n; ++k) {
		Bipart *r = an->bipart[k];
		if (r->an[0] == an1 || r->an[1] == an1) break;
	}
	if (k == an->n) { // not found, then append
		if (an->n == an->max) {
			an->max += 4;
			an->bipart = (Bipart**)realloc(an->bipart, sizeof(Bipart*) * an->max);
		}
		Bipart *b = (Bipart*)malloc(sizeof(Bipart));
		b->F = 0; b->f = cal_score(t); b->an[0] = an1; b->an[1] = an2;
		b->bs = -((t->bs > 0)? t->bs : DEFAULT_BS);
		b->tree_index = tree_index;
		an->bipart[k] = b;
		++(an->n);
	} else { // NOTE: this only works with node-based bootstrapping values!!!
		int bs = -((t->bs > 0)? t->bs : DEFAULT_BS);
		if (bs < an->bipart[k]->bs) an->bipart[k]->bs = bs;
		an->bipart[k]->tree_index |= tree_index;
	}
	return an;
}
static void insert_single_leaf(AllNodeHash *hash, int n_leaf, char **name)
{
	for (int i = 0; i < n_leaf; ++i) {
		unsigned magic = i * n_leaf + 1;
		SameMagicPtr smp = locate_SameMagic(magic, hash);
		smp->n = smp->max = 1;
		smp->array = (AllowedNode**)malloc(sizeof(AllowedNode*));
		AllowedNode *an = alloc_AllowedNode();
		an->n = an->max = 0;
		an->is_calculated = 1;
		an->n_leaf = 1;
		an->name = cpystr(name[i]);
		an->array = (char*)malloc(sizeof(char) * n_leaf);
		for (int j = 0; j < n_leaf; ++j)
			an->array[j] = 0;
		an->array[i] = 1;
		smp->array[0] = an;
	}
}
static void free_AllNodeHash(AllNodeHash *hash)
{
	AllNodeHash::iterator iter;
	for (iter = hash->begin(); iter < hash->end(); ++iter) {
		if (isfilled(iter)) {
			SameMagicPtr smp = iter->val;
			for (int i = 0; i < smp->n; ++i) {
				AllowedNode *an = smp->array[i];
				if (an->bipart) {
					for (int j = 0; j < an->n; ++j)
						free(an->bipart[j]);
					free(an->bipart);
				}
				if (an->name) free(an->name);
				free(an->array);
				free(an);
			}
			free(smp->array);
			free(smp);
		}
	}
	delete hash;
}
/* SDI must be applied */
static MMergeGlobal *initialize_G_space(int n, Tree **forest)
{
	Tree *tree, **node;
	char **name;
	int i, n_leaf, tree_index;
	AllowedNode *root_an;
	MMergeGlobal *g;

	g = (MMergeGlobal*)malloc(sizeof(MMergeGlobal));
	AllNodeHash *all_node;
	all_node = g->hash = new AllNodeHash;

	tree = forest[0];
	n_leaf = tree->n_leaf;
	g->n_leaf = n_leaf;
	g->n_tree = n;
	name = (char**)malloc(sizeof(char*) * n_leaf);
	node = (Tree**)malloc(sizeof(Tree*) * n_leaf);
	tr_expand_leaf(tree, node);
	for (i = 0; i < n_leaf; ++i) name[i] = node[i]->name;
	free(node);

	insert_single_leaf(all_node, n_leaf, name);
	root_an = 0;
	tree_index = 1;
	for (int k = 0; k < n; ++k, tree_index<<=1) {
		tree = forest[k];
		// QC
		if (tree->n_leaf != n_leaf) {
			fprintf(stderr, "[initialize_G_space] tree %d has different number of leaves (%d!=%d)\n", k, tree->n_leaf, n_leaf);
			continue;
		}
		if (tree->ftime != n_leaf * 2 - 2) {
			fprintf(stderr, "[initialize_G_space] tree %d is not a binary rooted tree (%d!=0)\n", k, n_leaf * 2 - 2 - tree->ftime);
			continue;
		}
		if (cpp_attach_flag_by_name(tree, n_leaf, name) != n_leaf) {
			fprintf(stderr, "[initialize_G_space] tree %d has different leaf set\n", k);
			continue;
		}

		SameMagicPtr smp;
		dump_SDIinfo(tree);
		node = tr_stack(tree, Tree*);
		int m = tr_expand_internal_node(tree, node);
		for (i = 0; i < m; ++i) {
			Tree *p = node[i];
			char *q = MMinfo(p)->array = (char*)malloc(sizeof(char) * n_leaf);
			for (int j = 0; j < n_leaf; ++j) q[j] = 0;
			unsigned magic = 0;
			int count = 0;
			for (int l = 0; l < p->n; ++l) {
				if (p->node[l]->n == 0) { // leaf
					if (p->node[l]->flag < 0) continue; // this should never happen
					magic ^= p->node[l]->flag;
					++count;
					q[p->node[l]->flag] = 1;
					smp = locate_SameMagic(p->node[l]->flag * n_leaf + 1, all_node);
					MMinfo(p->node[l])->an = smp->array[0]; // link AllowedNode for the leaf
				} else { // internal node
					char *r = MMinfo(p->node[l])->array;
					for (int j = 0; j < n_leaf; ++j) {
						if (r[j]) {
							magic ^= j; ++count;
							q[j] = 1;
						}
					}
				}
			}
			magic = magic * n_leaf + count;
			smp = locate_SameMagic(magic, all_node);
			MMinfo(p)->an = insert_to_SameMagic(smp, n_leaf, q, p, MMinfo(p->node[0])->an, MMinfo(p->node[1])->an, tree_index);
		}
		root_an = MMinfo(tree)->an;
		free(node);
		restore_SDIinfo(tree);
	}
	free(name);
	g->root_an = root_an;
	// calculate n_all_node
	AllNodeHash::iterator iter;
	int n_all_node, n_stack_size;
	n_all_node = n_stack_size = 0;
	for (iter = all_node->begin(); iter < all_node->end(); ++iter) {
		if (isfilled(iter)) {
			n_all_node += iter->val->n;
			for (i = 0; i < iter->val->n; ++i) {
				AllowedNode *an = iter->val->array[i];
				n_stack_size += an->n;
				for (int j = 0; j <	an->n; ++j)
					an->bipart[j]->f += an->bipart[j]->bs;
			}
		}
	}
	g->n_all_node = n_all_node;
	g->n_stack_size = n_stack_size;
	return g;
}
static Tree *make_merged_tree(AllowedNode *an)
{
	Tree *p = tr_new_node();
	if (an->name) { // leaf
		p->name = cpystr(an->name);
		p->tree_index = 0;
	} else {
		p->n = 2;
		p->bs = -an->bipart[an->i]->bs;
		p->node = (Tree**)malloc(sizeof(Tree*) * p->n);
		p->node[0] = make_merged_tree(an->bipart[an->i]->an[0]);
		p->node[1] = make_merged_tree(an->bipart[an->i]->an[1]);
		p->tree_index = an->bipart[an->i]->tree_index;
	}
	return p;
}
Tree *tr_mmerge_core(MMergeGlobal *g)
{
	ANStack *stack, *top;
	AllowedNode *an;
	Bipart *b;

	stack = (ANStack*)malloc(sizeof(ANStack) * (g->n_stack_size + 1));
	stack->i = 0;
	stack->an = g->root_an;
	top = stack;
	while (top >= stack) {
		if (top->i == top->an->n) { // pop up
			int min = 0x7fffffff;
			int min_i = -1;
			an = top->an;
			for (int i = 0; i < top->i; ++i) {
				if (an->bipart[i]->F < min) {
					min = an->bipart[i]->F;
					min_i = i;
				}
			}
			an->is_calculated = 1;
			an->F = min;
			an->i = min_i;
			--top;
		} else {
			an = top->an;
			b = an->bipart[top->i];
			if (b->an[0]->is_calculated && b->an[1]->is_calculated) {
				b->F = b->an[0]->F + b->an[1]->F + b->f;
				++(top->i);
			} else {
				if (!b->an[0]->is_calculated) {
					++top;
					top->an = b->an[0];
					top->i = 0;
				}
				if (!b->an[1]->is_calculated) {
					++top;
					top->an = b->an[1];
					top->i = 0;
				}
			}
		}
	}
	free(stack);
	Tree *tree = make_merged_tree(g->root_an);
	tr_tree_init(tree);
	tr_attach_id(tree);
	tree->bs = -1;
//	tr_normalize_bs_value(tree, 100 * g->n_tree);
	return tree;
}
Tree *tr_mmerge(int n, Tree **forest)
{
	MMergeGlobal *g = initialize_G_space(n, forest);
	Tree *tree = 0;
	if (g->root_an) tree = tr_mmerge_core(g);
	else fprintf(stderr, "[tr_mmerge] no tree to merge!\n");
	free_AllNodeHash(g->hash);
	free(g);
	return tree;
}
void tr_common_forest(int n, Tree **forest)
{
	int i, j, m, max;
	hash_set_char *set;
	Tree **node;

	max = 0;
	for (i = 0; i < n; ++i)
		if (forest[i]->n_leaf > max) max = forest[i]->n_leaf;
	node = (Tree**)malloc(sizeof(Tree*) * max);
	// get common leaves
	set = new hash_set_char;
	assert(forest[0]);
	m = tr_expand_leaf(forest[0], node);
	for (j = 0; j < m; ++j)
		set->insert(node[j]->name);
	for (i = 1; i < n; ++i) {
		hash_set_char *set2 = new hash_set_char;
		m = tr_expand_leaf(forest[i], node);
		for (j = 0; j < m; ++j)
			if (set->find(node[j]->name))
				set2->insert(node[j]->name);
		hash_set_char *set_tmp;
		set_tmp = set2; set2 = set; set = set_tmp;
		delete set2;
	}
	free(node);
	// get subtree
	char **name = (char**)malloc(sizeof(char*) * set->size());
	hash_set_char::iterator iter;
	for (iter = set->begin(), j = 0; iter < set->end(); ++iter)
		if (isfilled(iter))
			name[j++] = iter->key;
	for (i = 0; i < n; ++i) {
		if (forest[i]->n_leaf == int(set->size())) continue;
		Tree *tree = cpp_subtree(forest[i], set->size(), name);
		tr_delete_tree(forest[i]);
		forest[i] = tree;
	}
        free(name);
	delete set;
}

static int tr_mmerge_usage()
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Usage  : treebest mmerge [-r] <forest>\n\n");
	fprintf(stderr, "Options: -r         reroot\n");
	fprintf(stderr, "         -s FILE    species tree [default taxa tree]\n\n");
	return 1;
}
int tr_mmerge_task(int argc, char *argv[])
{
	int i, c, is_reroot, n;
	FILE *fp, *fp_spec;
	Tree **forest, *spec_tree, *tree;

	spec_tree = 0;

	is_reroot = 0;
	while ((c = getopt(argc, argv, "s:r")) >= 0) {
		switch (c) {
			case 'r': is_reroot = 1; break;
			case 's': fp_spec = tr_get_fp(optarg);
					  if (fp_spec) {
						  spec_tree = tr_parse_first(fp_spec);
						  fclose(fp_spec);
						  cpp_post_spec_tree(spec_tree, 0);
					  }
					  break;
		}
	}
	if (argc == optind) return tr_mmerge_usage();
	fp = tr_get_fp(argv[optind]);
	forest = tr_parse(fp, &n);
	fclose(fp);
	tr_common_forest(n, forest);
	if (!spec_tree) spec_tree = tr_default_spec_tree();
	for (i = 0; i < n; ++i) {
		if (is_reroot)
			forest[i] = tr_root_by_sdi(forest[i], spec_tree);
		tr_SDI(forest[i], spec_tree, 0);
		tr_lost_infer(forest[i], spec_tree);
	}
	tree = tr_mmerge(n, forest);
	tr_SDI(tree, spec_tree, 0);
	tr_lost_infer(tree, spec_tree);
	tr_tree_output(stdout, tree, OUTPUT_SDI);
	for (i = 0; i < n; ++i) {
		tr_delete_tree_SDIptr(forest[i]);
		tr_delete_tree(forest[i]);
	}
	free(forest);
	tr_delete_tree_SDIptr(tree);
	tr_delete_tree(tree);
	tr_delete_tree(spec_tree);
	return 0;
}
