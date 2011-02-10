#include <string.h>
#include <stdlib.h>
#include "tree.h"
#include "utils.h"
#include "cpp_utils.h"

static int sdi_dup_bound = 0x7fffffff;

/* ONLY used by tr_root_by_sdi() */
void tr_sdi_set_dup_bound(int bound)
{
	sdi_dup_bound = bound;
}

void tr_normalize_bs_value(Tree *tree, int bs_time)
{
	Tree **node;
	int i, m;

	if (tree == 0) return;
	node = tr_stack(tree, Tree*);
	m = tr_expand_internal_node(tree, node);
	for (i = 0; i < m; ++i)
		node[i]->bs = (bs_time > 0)? (int)(node[i]->bs * 100.0 / bs_time + 0.5) : -bs_time;
	free(node);
}
#ifdef USE_GCC
inline SDIinfo *tr_alloc_sdi_cell()
#else
SDIinfo *tr_alloc_sdi_cell()
#endif
{
	SDIinfo *s;
	s = (SDIinfo*)malloc(sizeof(SDIinfo));
	s->type = 'N';
	s->ptr = 0;
	s->n_lost = 0;
	s->lost = 0;
	s->n_spec_node = 0;
	s->spec_node = 0;
	s->is_confirmed_dup = 0;
	s->sis = 0;
	return s;
}
SDIinfo *tr_copy_sdi(SDIinfo *s)
{
	SDIinfo *si;
	if (s == 0) return 0;
	si = tr_alloc_sdi_cell();
	si->type = s->type;
	si->ptr = s->ptr;
	si->n_lost = s->n_lost;
	if (si->n_lost) {
		int i;
		si->lost = (TreePtr*)malloc(sizeof(TreePtr) * si->n_lost);
		for (i = 0; i < si->n_lost; ++i)
			si->lost[i] = s->lost[i];
	}
	return si;
}
/*
 * delete (SDIinfo*)(Tree::ptr).
 *
 * Note that tr_delete_tree_ptr() cannot free ptr->lost.
 */
void tr_delete_tree_SDIptr(Tree *root)
{
	Tree **node, *p;
	int i, f;

	if (root == 0) return;
	if (!root->node_array) {
		node = tr_stack(root, Tree*);
		f = tr_expand_node(root, node);
	} else {
		node = root->node_array;
		f = root->n_node;
	}
	for (i = 0; i < f; ++i) {
		p = node[i];
		if (p->ptr) {
			free(SDIptr(p)->lost);
			free(SDIptr(p)->spec_node);
		}
		free(node[i]->ptr);
		node[i]->ptr = 0;
	}
	if (!root->node_array) free(node);
}
/*
 * Speciaion/Duplication Inference;
 * 
 * Input: multifurcated gene tree
 * Output: multifurcated species tre
 */
int tr_SDI(Tree *tree, const Tree *spec, Tree **links)
{
	extern void tr_flag_confirmed(Tree *tree, const Tree *spec);
	Tree **node, **spec_node;
	Tree **tmp_node;
	Tree *p, *q, *r;
	SDIinfo *s;
	int i, j, k, m;
	
	if (tree == 0 || spec == 0) return 0;

	/* connect tree leaf with spec leaf */
	tmp_node = (links)? links : cpp_get_spec_links(tree, spec);
	node = tr_stack(tree, Tree*);
	m = tr_expand_leaf_by_id(tree, node);
	for (i = 0; i < m; ++i) {
		s = tr_alloc_sdi_cell();
		node[i]->ptr = s;
		s->ptr = tmp_node[i];
	}
	free(node);
	if (links == 0) free(tmp_node);

	/* set 'flag' in spec tree: flag is the index of its parent node. */
	if (!spec->node_array) {
		spec_node = tr_stack(spec, Tree*);
		m = tr_expand_internal_node(spec, spec_node);
	} else {
		spec_node = spec->node_array;
		m = spec->n_node;
	}
	for (i = 0; i < m; ++i) {
		p = spec_node[i];
		for (j = 0; j < p->n; ++j)
			p->node[j]->flag = j;
	}
	if (!spec->node_array) free(spec_node);
	/* SDI core iteration */
	node = tr_stack(tree, Tree*);
	m = tr_expand_internal_node(tree, node);
	for (i = j = 0; i < m; ++i) { /* j is a counter */
		TreePtr *from, q2, r2; /* record the path of each children */
		int k0;
		if (j > sdi_dup_bound) break; /* ONLY used by tr_root_by_sdi() */
		p = node[i];
		s = tr_alloc_sdi_cell();
		p->ptr = s;
		/* init from */
		from = (TreePtr*)malloc(sizeof(TreePtr) * p->n);
		for (k = 0; k < p->n; ++k)
			from[k] = 0;
		/* find LCA */
		k = 0;
		while (k < p->n && spec(p->node[k]) == 0) ++k; /* find the first node with spec */
		if (k == p->n) {
			spec(p) = 0; free(from);
			continue;
		}
		k0 = k;
		q = spec(p->node[k++]);
		for (; k < p->n; ++k) {
			r = spec(p->node[k]);
			if (r == 0) continue;
			q2 = r2 = 0;
			while (q != r) { /* find LCA of q and r */
				if (q->ftime < r->ftime) { q2 = q; q = q->pre; }
				else { r2 = r; r = r->pre; }
			}
			from[k0] = q2; from[k] = r2;
		}
		/* now q is the LCA. adjust from[] array so that the parent of every
		 * non-NULL node points to q */
		for (k = 0; k < p->n; ++k) {
			if (from[k] && from[k]->pre != q) {
				r = from[k];
				while (r->pre != q) r = r->pre;
				from[k] = r;
			}
		}
		/* from[] stores the visited child nodes of q. if spec(p->node[k]) == q, from[k] = 0.
		 * the other possibility that from[k] == 0 is when spec(p->node[k]) == 0. */
		spec(p) = q;
		s->n_spec_node = q->n;
		s->spec_node = (char*)malloc(sizeof(char) * q->n);
		for (k = 0; k < q->n; ++k)
			s->spec_node[k] = 0;
		for (k = 0; k < p->n; ++k)
			if (from[k]) s->spec_node[from[k]->flag] = 1; /* passed path */
		free(from);
		/* now, s->spec_node[k] == 1, iff there is l so that spec(p->node[l]) != q and
		 * spec(p->node[l]) is the children of q->node[k]. */
		if (p->n > 2) { /* multifurcation in gene tree */
			s->type = 'N'; goto end_loop;
		}
		/* now, p->n == 2 stands */
		if (spec(p->node[0]) == 0 || spec(p->node[1]) == 0) {
			s->type = 'N';
		} else if (q != spec(p->node[0]) && q != spec(p->node[1]) && q->n <= 2) { /* non-multi spec node */
			s->type = 'S'; /* speciation */
		} else if ((q == spec(p->node[0]) || q == spec(p->node[1])) && q->n <= 2) { /* non-multi spec node */
			s->type = 'D'; ++j; /* duplication */
		} else { /* multifurcation and possible duplication */
			SDIinfo *si1, *si2;
			if (q == spec(p->node[0]) && q == spec(p->node[1])) {
				si1 = SDIptr(p->node[0]);
				si2 = SDIptr(p->node[1]);
			} else if (q != spec(p->node[0]) && q != spec(p->node[1])) {
				s->type = 'S';
				goto end_loop;
			} else {
				si1 = SDIptr(p->node[(q == spec(p->node[0]))? 0 : 1]);
				si2 = SDIptr(p);
			}
			for (k = 0; k < q->n; ++k)
				if (si1->spec_node[k] && si2->spec_node[k]) break;
			if (k < q->n) { s->type = 'D'; ++j; } /* duplication */
			else s->type = 'S'; /* speciation */
		}
end_loop:
		/* update s->spec_node[] so that s->spec_node[k] == 1, iff there exists l satisfying
		 * spec(p->node[l]) is the children of q->node[k] */
		for (k = 0; k < p->n; ++k) {
			if (spec(p->node[k]) == q) {
				int l;
				for (l = 0; l < q->n; ++l)
					if (SDIptr(p->node[k])->spec_node[l] != 0) s->spec_node[l] = 1;
			}
		}
	}
	free(node);
	tr_flag_confirmed(tree, spec);
	return j;
}
