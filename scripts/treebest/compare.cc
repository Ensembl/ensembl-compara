/*! \file compare.cc
 *  \brief Compare two trees.
 */
#include <stdlib.h>
#include "tree.h"
#include "utils.h"
#include "common/hash_char.h"

typedef struct
{
	void *ptr;
	char *array;
	int magic;
} CompareInfo;

#define Cinfo(p) ((CompareInfo*)(p)->ptr)

static void dump_ptr(Tree *tree)
{
	int n, i;
	Tree **node, *p;
	CompareInfo *q;

	if (tree == 0) return;
	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	for (i = 0; i < n; ++i) {
		q = (CompareInfo*)malloc(sizeof(CompareInfo));
		q->array = 0;
		q->magic = 0;
		p = node[i];
		q->ptr = p->ptr;
		p->ptr = q;
	}
	free(node);
}
static void restore_ptr(Tree *tree)
{
	int n, i;
	Tree **node, *p;
	CompareInfo *q;

	if (tree == 0) return;
	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	for (i = 0; i < n; ++i) {
		p = node[i];
		q = Cinfo(p);
		p->ptr = q->ptr;
		if (q->array) free(q->array);
		free(q);
	}
	free(node);
}
/**
 * similar to function cover_set() in merge.c
 */
static void cal_magic(Tree *tree, hash_map_char<int> *map, int is_rooted = 1)
{
	int n, i, j, k, id, m, key0;
	hash_map_char<int>::iterator iter;

	if (tree == 0) return;
	assert(map);
	Tree **node, *p;
	
	/* calculate ^ over all matched nodes */
	for (iter = map->begin(), key0 = 0; iter < map->end(); ++iter)
		if (isfilled(iter)) key0 ^= iter->val;
	node = tr_stack(tree, Tree*);
	m = map->size();
	n = tr_expand_internal_node(tree, node);
	for (i = 0; i < n; ++i) {
		int magic, c;
		char *r, *q;
		p = node[i];
		q = Cinfo(p)->array = (char*)malloc(sizeof(char) * (map->size() + 1));
		for (j = 0; j <= (int)map->size(); ++j) q[j] = 0;
		magic = c = 0;
		for (k = 0; k < p->n; ++k) {
			if (p->node[k]->n == 0) { /* leaf */
				if (!map->find(p->node[k]->name, &id)) continue; /* not common leaf */
				magic ^= id;
				++c;
				q[id] = 1;
			} else {
				r = Cinfo(p->node[k])->array;
				for (j = 0; j < m; ++j) {
					if (r[j]) {
						magic ^= j; ++c;
						q[j] = 1;
					}
				}
			}
		}
		if (is_rooted) Cinfo(p)->magic = magic * m + c; /* hash key */
		else Cinfo(p)->magic = (m - c > c)? (key0 ^ magic) * m + (m - c) : magic * m + c;
	}
	free(node);
}
/*! \fn int tr_compare_core(Tree *src, Tree *dst)
 *  \brief Compare two rooted trees, src and dst.
 *  \param src The source tree.
 *  \param dst The destination tree.
 *
 *  This function compare a rooted tree dst to another one src. It will modify dst and
 *  set Tree::is_cons=1 if a clade of dst exists in src.
 */
int tr_compare_core(Tree *src, Tree *dst, unsigned write_flag)
{
	int n, i, j, k, n_dst, m;
	int count;
	char *used_array;
	Tree **node, **node_dst, *p;
	hash_map_char<int> *map, *aux;
	char *qsrc, *qdst;

	if (!src || !dst) return 0;
	map = new hash_map_char<int>;
	aux = new hash_map_char<int>;
	n = (src->ftime > dst->ftime)? src->ftime+1 : dst->ftime+1;
	node = (Tree**)malloc(sizeof(Tree*) * n);
	node_dst = tr_stack(dst, Tree*);
	// this array is intend to avoid repeatedly attaching internal names
	used_array = (char*)malloc(sizeof(char) * n);
	for (i = 0; i < n; ++i) used_array[i] = 0;
	
	n = tr_expand_leaf(src, node);
	for (i = 0; i < n; ++i)
		aux->insert(node[i]->name, i);
	n = tr_expand_leaf(dst, node_dst);
	for (i = j = 0; i < n; ++i) {
		if (aux->find(node_dst[i]->name, &k)) {
			if ((write_flag & COMPARE_WRITE_BRANCH_LENGTH) && node[k]->d >= 0.0)
				node_dst[i]->d = node[k]->d;
			map->insert(node_dst[i]->name, j);
			++j;
			node_dst[i]->is_cons = 1;
		} else node_dst[i]->is_cons = 0;
	}
	delete aux;

	count = 0;
	dump_ptr(src); dump_ptr(dst);
	cal_magic(src, map); cal_magic(dst, map);
	n = tr_expand_internal_node(src, node);
	n_dst = tr_expand_internal_node(dst, node_dst);
	m = map->size();
	for (i = 0; i < n_dst; ++i) {
		int magic;
		p = node_dst[i];
		qdst = Cinfo(p)->array;
		magic = Cinfo(p)->magic;
		for (j = 0; j < n; ++j) {
			if (magic == Cinfo(node[j])->magic) {
				qsrc = Cinfo(node[j])->array;
				for (k = 0; k < m; ++k)
					if (qsrc[k] != qdst[k]) break;
				if (k == m) break;
			}
		}
		if (j < n) { /* clade found */
			Tree *q = node[j];
			p->is_cons = 1;
			if ((write_flag & COMPARE_WRITE_BRANCH_LENGTH) && q->d >= 0.0 && p->n_leaf == q->n_leaf)
				p->d = q->d;
			if ((write_flag & COMPARE_WRITE_BS_VALUE) && q->bs >= 0 && p->n_leaf == q->n_leaf)
				p->bs = q->bs;
			if ((write_flag & COMPARE_WRITE_INTERNAL_NAME) && q->name && p->name == 0 && used_array[j] == 0) {
				p->name = cpystr(q->name);
				used_array[j] = 1; /* avoid writing a name many times */
			}
			++count;
		} else p->is_cons = 0;
	}
	restore_ptr(src); restore_ptr(dst);
	free(node_dst);
	
	free(node);
	free(used_array);
	delete map;
	return count;
}
int tr_tree_dist(const Tree *ori_tree1, const Tree *ori_tree2)
{
	int n1, n2, i, j, k, m;
	Tree **node1, **node2, *p;
	Tree *tree1, *tree2;
	hash_map_char<int> *map = new hash_map_char<int>;

	if (!ori_tree1 || !ori_tree2) return 0;
	// backup tree;
	tree1 = tr_copy_tree(ori_tree1);
	tree2 = tr_copy_tree(ori_tree2);
	tree1 = tr_remove_root(tree1);
	tree2 = tr_remove_root(tree2);
	node1 = tr_stack(tree1, Tree*);
	node2 = tr_stack(tree2, Tree*);
	
	// construct map hash
	hash_map_char<int> *aux = new hash_map_char<int>;
	n1 = tr_expand_leaf(tree1, node1);
	for (i = 0; i < n1; ++i)
		aux->insert(node1[i]->name, i);
	n2 = tr_expand_leaf(tree2, node2);
	for (i = j = 0; i < n2; ++i) {
		if (aux->find(node2[i]->name, &k))
			map->insert(node2[i]->name, j++);
	}
	delete aux;
	if (tree1->n_leaf != tree2->n_leaf || map->size() != unsigned(tree1->n_leaf)) {
		fprintf(stderr, "[tr_tree_dist] cannot calculate distance between two trees with different leaves!\n");
		free(node1); free(node2); delete map;
		return 0;
	}

	int magic, tmp_c;
	char *q1, *q2;
	int count = 0;
	dump_ptr(tree1); dump_ptr(tree2);
	cal_magic(tree1, map, 0); cal_magic(tree2, map, 0);
	n1 = tr_expand_internal_node(tree1, node1);
	n2 = tr_expand_internal_node(tree2, node2);
	m = map->size();
	for (i = 0; i < n1 - 1; ++i) { // skip root node
		p = node1[i];
		q1 = Cinfo(p)->array;
		magic = Cinfo(p)->magic;
		for (j = 0; j < n2 - 1; ++j) { // skip root node
			if (magic == Cinfo(node2[j])->magic) {
				q2 = Cinfo(node2[j])->array;
				for (k = 0, tmp_c = 0; k < m; ++k)
					if (q1[k] == q2[k]) ++tmp_c;
				if (tmp_c == 0 || tmp_c == m) break; /* match! */
			}
		}
		if (j != n2-1) ++count;
	}
	restore_ptr(tree1); restore_ptr(tree2);
	free(node1); free(node2);
	tr_delete_tree(tree1); tr_delete_tree(tree2);
	delete map;
	return (((n1-1)+(n2-1)-count*2)<<16)|count;
}
