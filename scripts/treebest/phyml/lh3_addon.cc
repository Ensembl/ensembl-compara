#ifdef LH3_ADDON
#include "../common/hash_char.h"
#include "../common/hash_misc.h"
#include "../utils.h"
#include "../cpp_utils.h"
#include "../phyml.h"
#include "lh3_addon.h"
#include "utilities.h"

typedef struct
{
	int n, max;
	char **array;
} SameKey;

typedef struct
{
	edge *b;
	node *v;
	int d;
} HelperStack;

typedef hash_map_misc<SameKey*> HashedSets;

inline unsigned lh3_cal_hash_key(int m, char *array)
{
	unsigned c, magic, xor_key;
	unsigned key1, key2;

	c = magic = xor_key = 0;
	for (int i = 0; i < m; ++i) {
		xor_key ^= i;
		if (array[i]) {
			++c;
			magic ^= i;
		}
	}
	key1 = magic * m + c;
	key2 = (magic ^ xor_key) * m + (m - c);
	return (key1 < key2)? key1 : key2;
}
inline int lh3_addon_is_match(HashedSets *hs, int m, char *array)
{
	int i;
	unsigned key;
	SameKey *sk;

	key = lh3_cal_hash_key(m, array);
	if (key == 0 || key % m == 1 || key % m == (unsigned)(m - 1)) return 1; // array just contains one element
	if (hs->find(key, &sk)) {
		int j;
		char *t_array, head[2];
		for (j = 0; j < sk->n; ++j) {
			t_array = sk->array[j];
			head[0] = head[1] = -1;
			for (i = 0; i < m; ++i) {
				if (head[(int)array[i]] < 0) head[(int)array[i]] = t_array[i];
				else if (head[(int)array[i]] != t_array[i]) break;
			}
			if (i == m) return 1; // match
		}
	}
	return 0;
}
void lh3_cons_cal_one_branch(arbre *tree, edge *start, int direction)
{
	if (tree->lh3_tree.ctree == 0) return;
	HelperStack *stack, *top;
	int n_ctree = tree->lh3_tree.ctree->n_leaf;
	int n_node = 2 * tree->n_otu - 2;
	int j, k;

	if (start->lh3_edge.is_cal[direction]) return;
	top = stack = (HelperStack*)malloc(sizeof(HelperStack) * n_node);
	top->b = start;
	top->v = (direction == 0)? start->left : start->rght;
	++top;
	while (top != stack) {
		edge *cur = (top - 1)->b;
		node *v = (top - 1)->v;
		int d_cur = (cur->left == v)? 0 : 1;
		if (v->tax) { // external node
			if (v->lh3_node.cleaf) cur->lh3_edge.array[d_cur][v->lh3_node.cleaf->id] = 1;
		} else {
			for (j = 0; j < 3; ++j) {
				if (v->b[j] == cur) continue; // this is the branch we are visiting now
				int d2 = (v == v->b[j]->rght)? 0 : 1;
				if (v->b[j]->lh3_edge.is_cal[d2]) {
					char *a = cur->lh3_edge.array[d_cur];
					char *aa = v->b[j]->lh3_edge.array[d2];
					for (k = 0; k < n_ctree; ++k)
						if (aa[k]) a[k] = 1;
				} else { // push down
					top->b = v->b[j];
					top->v = (d2 == 0) ? v->b[j]->left : v->b[j]->rght;
					++top;
				}
			}
		}
		if (cur == (top - 1)->b) { // no new element on the top of stack, pop up
			cur->lh3_edge.is_cal[d_cur] = 1;
			--top;
		}
	}
	free(stack);
}
void lh3_cons_cal_all_branch(arbre *tree)
{
	if (tree->lh3_tree.ctree == 0) return;
	int i;
	int n_edge = 2 * tree->n_otu - 3;
	// actually no need to put a loop here. a line like
	//     lh3_cons_cal_one_branch(tree, tree->t_edges[0], 0);
	// is enough. I will improve this in future.
	for (i = 0; i < n_edge; ++i) { // fill lh3Edge::array[2] and set lh3Edge::cal[2]
		if (tree->t_edges[i]->lh3_edge.is_cal[0] == 0) lh3_cons_cal_one_branch(tree, tree->t_edges[i], 0);
		if (tree->t_edges[i]->lh3_edge.is_cal[1] == 0) lh3_cons_cal_one_branch(tree, tree->t_edges[i], 1);
	}
	HashedSets *hs = (HashedSets*)tree->lh3_tree.hs;
	for (i = 0; i < n_edge; ++i) { // set lh3Edge::do_exist
		int do_exist[2];
		do_exist[0] = lh3_addon_is_match(hs, tree->lh3_tree.ctree->n_leaf, tree->t_edges[i]->lh3_edge.array[0]);
		do_exist[1] = lh3_addon_is_match(hs, tree->lh3_tree.ctree->n_leaf, tree->t_edges[i]->lh3_edge.array[1]);
		// This line is redundant. do_exist[0] should ALWAYS equal to do_exist[1]. It is here for a historical reason...
		tree->t_edges[i]->lh3_edge.do_exist = (do_exist[0] && do_exist[1])? 1 : 0;
	}
}
/* clear the results calculated by lh3_cons_cal_all_branch() and similar ones. */
void lh3_cons_clear_cal_flag(arbre *tree)
{
	if (tree->lh3_tree.ctree == 0) return;
	int i, k;
	int n_edge = 2 * tree->n_otu - 3;
	for (i = 0; i < n_edge; ++i) {
		lh3Edge *tmp = &(tree->t_edges[i]->lh3_edge);
		tmp->is_cal[0] = tmp->is_cal[1] = tmp->do_exist = 0;
		for (k = 0; k < tree->lh3_tree.ctree->n_leaf; ++k) // clear the array
			tmp->array[0][k] = tmp->array[1][k] = 0;
	}
}
static void insert_to_HashedSets(HashedSets *hs, int m, char *array) // generic
{
	SameKey *sk;
	unsigned key = lh3_cal_hash_key(m, array);

	if (hs->find(key, &sk)) {
		if (sk->n == sk->max) {
			sk->max += 4;
			sk->array = (char**)realloc(sk->array, sizeof(char*) * sk->max);
		}
		sk->array[sk->n++] = array;
	} else {
		sk = (SameKey*)malloc(sizeof(SameKey));
		sk->max = 4; sk->n = 0;
		sk->array = (char**)malloc(sizeof(char*) * sk->max);
		sk->array[sk->n++] = array;
		hs->insert(key, sk);
	}
}
HashedSets *lh3_addon_cal_HashedSets(Tree *tree) // generic
{
	Tree **nodes;
	int i, n_leaf, m;

	HashedSets *hs = new HashedSets;

	n_leaf = tree->n_leaf;
	nodes = tr_stack(tree, Tree*);
	m = tr_expand_internal_node(tree, nodes);
	for (i = 0; i < m; ++i) {
		Tree *p = nodes[i];
		char *array = (char*)malloc(sizeof(char) * n_leaf);
		int j, k;
		p->ptr = array;
		for (j = 0; j < n_leaf; ++j) array[j] = 0;
		for (k = 0; k < p->n; ++k) {
			Tree *q = p->node[k];
			if (q->n == 0)
				array[q->id] = 1;
			else {
				char *r = (char*)q->ptr;
				for (j = 0; j < n_leaf; ++j)
					if (r[j]) array[j] = 1;
			}
		}
		insert_to_HashedSets(hs, n_leaf, array);
	}
	for (i = 0; i < m; ++i) // let lh3_addon_free to free ptr
		nodes[i]->ptr = 0;
	free(nodes);
	return hs;
}
/* initialization */
void lh3_addon_init(arbre *tree, PhymlConfig *pc)
{
	/* initialize log ratios */
	tree->lh3_tree.ratio_not_exist = log(pc->prob_not_exist / (1.0 - pc->prob_not_exist));
	tree->lh3_tree.log_dup = log(pc->prob_dup); tree->lh3_tree.log_spec = log(1.0 - pc->prob_dup);
	tree->lh3_tree.log_loss_spec = log(pc->prob_loss_spec); tree->lh3_tree.log_present_spec = log(1.0 - pc->prob_loss_spec);
	tree->lh3_tree.log_loss_dup = log(pc->prob_loss_dup); tree->lh3_tree.log_present_dup = log(1.0 - pc->prob_loss_dup);
	tree->lh3_tree.ctree = tree->lh3_tree.spec_tree = 0;
	tree->lh3_tree.ratio_cons = 0.0;
	tree->lh3_tree.log_spec = 0.0;
	tree->lh3_tree.is_NNI = 0;
	tree->lh3_tree.min_branch = -1;

	if (pc->spec_tree) {
		int i, j, m, max;
		// initialize the species tree
		TreePtr p, stree;
		TreePtr *spec_node;

		stree = tree->lh3_tree.spec_tree = tr_copy_tree(pc->spec_tree);
		spec_node = tr_stack(stree, Tree*);
		stree = tree->lh3_tree.spec_tree;
		m = tr_expand_internal_node(stree, spec_node);
		for (i = max = 0; i != m; ++i) {
			p = spec_node[i];
			if (p->n > max) max = p->n;
			for (j = 0; j < p->n; ++j)
				p->node[j]->flag = j;
		}
		m = tr_expand_leaf(stree, spec_node);
		hash_map_char<TreePtr> *hash = new hash_map_char<TreePtr>;
		for (i = 0; i != m; ++i)
			hash->insert(spec_node[i]->name, spec_node[i]);
		free(spec_node);
		// find lh3Node::sleaf
		char *sp, *sq;
		for (i = 0; i != 2 * tree->n_otu - 2; ++i) {
			if (tree->noeud[i]->tax) {
				sq = tree->noeud[i]->name;
				for (sp = sq + strlen(sq) - 1; sp >= sq; --sp)
					if (*sp == '_') break;
				++sp;
				if (sp != sq) {
					TreePtr q;
					tree->noeud[i]->lh3_node.spec = (hash->find(sp, &q))? q : 0;
				}
			}
		}
		delete hash;
		for (i = 0; i != 2 * tree->n_otu - 3; ++i) {
			tree->t_edges[i]->lh3_edge.spec[0].passed = (int*)malloc(sizeof(int) * max);
			tree->t_edges[i]->lh3_edge.spec[1].passed = (int*)malloc(sizeof(int) * max);
			tree->t_edges[i]->lh3_edge.cur_spec.passed = (int*)malloc(sizeof(int) * max);
		}
		lh3_spec_cal_all_branch(tree);
	}
	if (pc->ctree) {
		int i, j;
		if (pc->ctree == 0) return;
		// shrink constrained tree
		char **name = (char**)malloc(sizeof(char*) * tree->n_otu);
		for (i = j = 0; i < 2 * tree->n_otu - 2; ++i) {
			if (tree->noeud[i]->tax) // external nodes
				name[j++] = tree->noeud[i]->name;
		}
		tree->lh3_tree.ctree = tr_remove_root(cpp_subtree(pc->ctree, tree->n_otu, name));
		free(name);
		// flush Tree::id for leaves, from 0 to ctree->n_leaf
		tr_attach_id(tree->lh3_tree.ctree);
		int n_ctree = tree->lh3_tree.ctree->n_leaf;
		// build temporary hash
		hash_map_char<Tree*> *hash = new hash_map_char<Tree*>;
		Tree **nodes = tr_stack(tree->lh3_tree.ctree, Tree*);
		int m = tr_expand_leaf(tree->lh3_tree.ctree, nodes);
		for (i = 0; i < m; ++i)
			hash->insert(nodes[i]->name, nodes[i]);
		free(nodes);
		// initialize lh3Node::cleaf
		node *p;
		for (i = 0; i < 2 * tree->n_otu - 2; ++i) {
			p = tree->noeud[i];
			if (p->tax) { // external node
				Tree *q;
				if (hash->find(p->name, &q))
					p->lh3_node.cleaf = q;
			} else p->lh3_node.cleaf = 0;
		}
		delete hash;
		// initialize lh3Tree::hs
		tree->lh3_tree.hs = lh3_addon_cal_HashedSets(tree->lh3_tree.ctree);
		// initialize lh3Edge
		for (i = 0; i < 2 * tree->n_otu - 3; ++i) {
			lh3Edge *tmp = &(tree->t_edges[i]->lh3_edge);
			tmp->is_cal[0] = tmp->is_cal[1] = tmp->do_exist = 0;
			tmp->array[0] = (char*)malloc(sizeof(char) * n_ctree);
			tmp->array[1] = (char*)malloc(sizeof(char) * n_ctree);
			for (j = 0; j < n_ctree; ++j)
				tmp->array[0][j] = tmp->array[1][j] = 0;
		}
		lh3_cons_cal_all_branch(tree);
	}
}
void lh3_addon_free(arbre *tree)
{
	if (tree->lh3_tree.spec_tree) {
		for (int i = 0; i < 2 * tree->n_otu - 3; ++i) {
			free(tree->t_edges[i]->lh3_edge.spec[0].passed);
			free(tree->t_edges[i]->lh3_edge.spec[1].passed);
			free(tree->t_edges[i]->lh3_edge.cur_spec.passed);
		}
		tr_delete_tree(tree->lh3_tree.spec_tree);
	}
	if (tree->lh3_tree.ctree) {
		for (int i = 0; i < 2 * tree->n_otu - 3; ++i) {
			free(tree->t_edges[i]->lh3_edge.array[0]);
			free(tree->t_edges[i]->lh3_edge.array[1]);
		}
		tr_delete_tree(tree->lh3_tree.ctree);
		HashedSets *hs = (HashedSets*)tree->lh3_tree.hs;
		HashedSets::iterator iter;
		for (iter = hs->begin(); iter < hs->end(); ++iter) {
			if (isfilled(iter)) {
				for (int j = 0; j < iter->val->n; ++j)
					free(iter->val->array[j]);
				free(iter->val->array);
				free(iter->val);
			}
		}
		delete hs;
	}
}
double lh3_cons_cal_all_ratio(arbre *tree)
{
	if (tree->lh3_tree.ctree == 0) return 0.0;
	int i;
	double log_ratio = 0.0;
	int n_edge = 2 * tree->n_otu - 3;
	for (i = 0; i < n_edge; ++i)
		if (!tree->t_edges[i]->lh3_edge.do_exist)
			log_ratio += tree->lh3_tree.ratio_not_exist;
	tree->lh3_tree.ratio_cons = log_ratio;
	return log_ratio;
}
double lh3_cons_update_one_ratio(arbre *tree, edge *b_fcus)
{
	if (tree->lh3_tree.ctree == 0) return 0.0;
	if (tree->lh3_tree.is_NNI) {
		node *V[2];
		V[0] = b_fcus->left; V[1] = b_fcus->rght;
		b_fcus->lh3_edge.is_cal[0] = b_fcus->lh3_edge.is_cal[1] = 0;
		for (int j = 0; j < 2; ++j) {
			node *v = V[j];
			if (v->tax == 0) { // internal node
				for (int i = 0; i < 3; ++i) {
					lh3Edge *tmp = &(v->b[i]->lh3_edge);
					tmp->is_cal[0] = tmp->is_cal[1] = tmp->do_exist = 0;
					for (int k = 0; k < tree->lh3_tree.ctree->n_leaf; ++k)
						tmp->array[0][k] = tmp->array[1][k] = 0;
				}
			}
		}
	} else lh3_cons_clear_cal_flag(tree);
	lh3_cons_cal_all_branch(tree);
	return lh3_cons_cal_all_ratio(tree);
}
#endif
