#ifdef LH3_ADDON
#include "../utils.h"
#include "../cpp_utils.h"
#include "../phyml.h"
#include "lh3_addon.h"
#include "utilities.h"

typedef struct
{
	edge *b;
	node *v;
	int d;
} HelperStack;

// adapted from tr_SDI() and tr_lost_infer()
inline void lh3_spec_cal_one_branch_aux(lh3Spec *s_cur, lh3Spec *s[2])
{
	TreePtr q, r;

	// infer duplications
	if (s[0]->spec == 0 && s[1]->spec == 0) {
		s_cur->spec = 0;
		s_cur->is_dup = 0;
	} else {
		int k;
		if (s[0]->spec == 0 || s[1]->spec == 0) {
			q = s_cur->spec = (s[0]->spec)? s[0]->spec : s[1]->spec;
			for (k = 0; k != q->n; ++k) s_cur->passed[k] = 0;
			s_cur->is_dup = 0;
		} else { // core codes
			TreePtr from[2];
			from[0] = from[1] = 0;
			{ // find the LCA of q and r
				Tree *q2, *r2;
				q = s[0]->spec; r = s[1]->spec;
				
				q2 = r2 = 0;
				while (q != r) {
					if (q->ftime < r->ftime) { q2 = q; q = q->pre; }
					else { r2 = r; r = r->pre; }
				}
				from[0] = q2; from[1] = r2;
			}
			s_cur->spec = q;
			// now q == r
			if (from[0] && from[0]->pre != q) {
				r = from[0];
				while (r->pre != q) r = r->pre;
				from[0] = r;
			}
			if (from[1] && from[1]->pre != q) {
				r = from[1];
				while (r->pre != q) r = r->pre;
				from[1] = r;
			}
			for (k = 0; k != q->n; ++k) s_cur->passed[k] = 0;
			if (from[0]) s_cur->passed[from[0]->flag] = 1;
			if (from[1]) s_cur->passed[from[1]->flag] = 1;
			if (q->n <= 2) { // binary node or leaf, simple method
				s_cur->is_dup = (q != s[0]->spec && q != s[1]->spec)? 0 : 1;
			} else { // polytomy
				int *t1, *t2;
				t1 = t2 = 0;
				if (q != s[0]->spec && q != s[1]->spec) {
					s_cur->is_dup = 0;
				} else if (q == s[0]->spec && q == s[1]->spec) {
					t1 = s[0]->passed;
					t2 = s[1]->passed;
				} else {
					t1 = s[(q == s[0]->spec)? 0 : 1]->passed;
					t2 = s_cur->passed;
				}
				if (t1 && t2) {
					for (k = 0; k != q->n; ++k)
						if (t1[k] && t2[k]) break;
					s_cur->is_dup = (k == q->n)? 0 : 1;
				}
			}
		}
		if (s[0]->spec == q) {
			for (int l = 0; l < q->n; ++l)
				if (s[0]->passed[l]) s_cur->passed[l] = 1;
		}
		if (s[1]->spec == q) {
			for (int l = 0; l < q->n; ++l)
				if (s[1]->passed[l]) s_cur->passed[l] = 1;
		}
	}
	s_cur->tot_dup = s[0]->tot_dup + s[1]->tot_dup + s_cur->is_dup;
	// infer losses
	s_cur->tot_spec_loss = s[0]->tot_spec_loss + s[1]->tot_spec_loss;
	s_cur->tot_dup_loss = s[0]->tot_dup_loss + s[1]->tot_dup_loss;
	for (int i = 0; i != 2; ++i) {
		int n_loss = 0;
		lh3Spec *ss = s[i];
		q = s[i]->spec;
		if (q == 0) {
			ss->n_loss = 0;
			continue;
		}
		if (q == s_cur->spec && s_cur->is_dup) {
			for (int j = 0; j != ss->spec->n; ++j)
				if (s_cur->passed[j] && !ss->passed[j] && q->node[j]->bs > 0) // appear in the parent but not in the child
					++n_loss;
		} else {
			r = q;
			if (q != s_cur->spec) {
				for (int j = 0; j != q->n; ++j)
					if (ss->passed[j] == 0 && q->node[j]->bs > 0)
						++n_loss;
				r = q; q = q->pre;
				while (q != s_cur->spec) {
					for (int j = 0; j != q->n; ++j)
						if (q->node[j] != r && q->node[j]->bs > 0)
							++n_loss;
					r = q; q = q->pre;
				}
			}
			if (s_cur->is_dup) { // now, s_cur->is_dup == 1 and q == s_cur->spec
				for (int j = 0; j != q->n; ++j)
					if (s_cur->passed[j] && q->node[j] != r && q->node[j]->bs > 0)
						++n_loss;
			}
		}
		ss->n_loss = n_loss;
		if (s_cur->is_dup) s_cur->tot_dup_loss += n_loss;
		else s_cur->tot_spec_loss += n_loss;
	}
}
void lh3_spec_cal_one_branch(arbre *tree, edge *start, int direction)
{
	if (tree->lh3_tree.spec_tree == 0) return;
	HelperStack *stack, *top;
	int n_node = 2 * tree->n_otu - 2;
	int j;

	top = stack = (HelperStack*)malloc(sizeof(HelperStack) * n_node);
	top->b = start;
	top->v = (direction == 0)? start->left : start->rght;
	++top;
	while (top != stack) {
		edge *cur = (top - 1)->b;
		node *v = (top - 1)->v;
		int d_cur = (cur->left == v)? 0 : 1;
		if (v->tax) { // external node
			lh3Spec *tmp = cur->lh3_edge.spec + d_cur;
			tmp->spec = v->lh3_node.spec;
			tmp->tot_dup = tmp->tot_dup_loss = tmp->tot_spec_loss = 0;
		} else {
			int k, cal_aux[2];
			cal_aux[0] = cal_aux[1] = -1;
			for (k = j = 0; j < 3; ++j) {
				if (v->b[j] == cur) continue; // this is the branch we are visiting now
				int d2 = (v == v->b[j]->rght)? 0 : 1;
				if (v->b[j]->lh3_edge.spec[d2].is_cal) {
					cal_aux[k++] = (j << 1) | d2;
				} else { // push down
					top->b = v->b[j];
					top->v = (d2 == 0) ? v->b[j]->left : v->b[j]->rght;
					++top;
				}
			}
			if (k == 2) { // both has been calculated
				lh3Spec *s[2];
				s[0] = &(v->b[cal_aux[0]>>1]->lh3_edge.spec[cal_aux[0]&1]);
				s[1] = &(v->b[cal_aux[1]>>1]->lh3_edge.spec[cal_aux[1]&1]);
				lh3_spec_cal_one_branch_aux(&(cur->lh3_edge.spec[d_cur]), s);
			}
		}
		if (cur == (top - 1)->b) { // no new element on the top of stack, pop up
			cur->lh3_edge.spec[d_cur].is_cal = 1;
			--top;
		}
	}
	free(stack);
}
void lh3_spec_cal_all_branch(arbre *tree)
{
	if (tree->lh3_tree.spec_tree == 0) return;
	int i;
	int n_edge = 2 * tree->n_otu - 3;
	for (i = 0; i < n_edge; ++i) {
		lh3Edge *tmp = &(tree->t_edges[i]->lh3_edge);
		lh3Spec *s[2];
		if (tmp->spec[0].is_cal == 0) lh3_spec_cal_one_branch(tree, tree->t_edges[i], 0);
		if (tmp->spec[1].is_cal == 0) lh3_spec_cal_one_branch(tree, tree->t_edges[i], 1);
		s[0] = &(tmp->spec[0]);
		s[1] = &(tmp->spec[1]);
		lh3_spec_cal_one_branch_aux(&(tmp->cur_spec), s);
	}
}
void lh3_spec_clear_cal_flag(arbre *tree)
{
	if (tree->lh3_tree.spec_tree == 0) return;
	int n_edge = 2 * tree->n_otu - 3;
	for (int i = 0; i < n_edge; ++i) {
		lh3Edge *tmp = &(tree->t_edges[i]->lh3_edge);
		tmp->spec[0].is_cal = tmp->spec[1].is_cal = 0;
	}
}
/*
 * In principle, there is a way that just needs to update the counts around
 * changed topologies after each NNI. However, this is technically hard, much harder
 * than my intuition. The difficulties come from two aspects. First, when two branches
 * are swapped in NNI, tot_dup, tot_spec_loss and tot_dup_loss must be re-calculated
 * across the tree. While solving this is still easy, the second one is harder.
 * The problem is for a directed branch there are three kinds of n_loss, one
 * calculated from cur_spec, and the other two from its two neighbour branches.
 * We have to store all these counts or calculate them each time an NNI is carried
 * out. And, to keep these counts is not easy and will make this file much more complex
 * than it looks now. Finally, I give up. As a matter of fact, the current version
 * is quite fast even given a very large tree. We can live with this speed.
 */
double lh3_spec_update_one_ratio(arbre *tree, edge *b_fcus)
{
	if (tree->lh3_tree.spec_tree == 0) return 0.0;
	lh3_spec_clear_cal_flag(tree);
	lh3_spec_cal_all_branch(tree);
	return lh3_spec_cal_all_ratio(tree);
}
double lh3_spec_cal_all_ratio(arbre *tree)
{
	if (tree->lh3_tree.spec_tree == 0) return 0.0;
	int n_edge = 2 * tree->n_otu - 3;
	int min = 0x7fffffff;
	int min_i = -1;
	lh3Edge *tmp;

	for (int i = 0; i < n_edge; ++i) {
		tmp = &(tree->t_edges[i]->lh3_edge);
		int x = (tmp->cur_spec.tot_dup << 16) + (tmp->cur_spec.tot_dup_loss + tmp->cur_spec.tot_spec_loss);
		if (x < min) { min = x; min_i = i; }
	}
	tree->lh3_tree.min_branch = min_i;
	tmp = &(tree->t_edges[min_i]->lh3_edge);
	tree->lh3_tree.loglk_spec = tmp->cur_spec.tot_dup * tree->lh3_tree.log_dup
			+ tmp->cur_spec.tot_spec_loss * tree->lh3_tree.log_loss_spec
			+ tmp->cur_spec.tot_dup_loss * tree->lh3_tree.log_loss_dup
			+ (tree->n_otu + tree->lh3_tree.spec_tree->n_leaf + tmp->cur_spec.tot_dup - 2) * tree->lh3_tree.log_spec
			+ (tree->n_otu + 2 * tree->lh3_tree.spec_tree->n_leaf - 2 - 4 * tmp->cur_spec.tot_dup + tmp->cur_spec.tot_dup_loss)
				* tree->lh3_tree.log_present_spec
			+ (4 * tmp->cur_spec.tot_dup - tmp->cur_spec.tot_dup_loss) * tree->lh3_tree.log_present_dup;
	return tree->lh3_tree.loglk_spec;
}

#endif
