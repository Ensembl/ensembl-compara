/** \file cpp_utils.cc
 *  \brief Utilities writen in C++
 *
 *  This file contains utilities that are written in C++, instead of C in other files.
 *  The main reason I use C++ here is to make use of my hash class.
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <math.h>
#include "cpp_utils.h"
#include "common/hash_char.h"

/** \fn int cpp_check_align_name(MultiAlign *ma)
 *  \brief Check whether a sequence name appears many times in a multialignment.
 *  \param ma The multialignment.
 *
 *  If a name appears multiple times, only the first one will be reserved.
 *  Number of remaining sequences will be returned.
 */
int cpp_check_align_name(MultiAlign *ma)
{
	int i, k;
	hash_set_char *hash;

	assert(ma);
	hash = new hash_set_char;
	for (i = k = 0; i < ma->n; ++i) {
		if (hash->find(ma->name[i])) {
			fprintf(stderr, "[cpp_check_align_name] duplicated name: %s\n", ma->name[i]);
			free(ma->name[i]); free(ma->seq[i]);
			if (ma->gene) free(ma->gene[i]);
			if (ma->comment) free(ma->comment[i]);
			continue;
		}
		hash->insert(ma->name[i]);
		if (i != k) {
			ma->name[k] = ma->name[i];
			ma->seq[k] = ma->seq[i];
			ma->gene[k] = ma->gene[i];
			ma->comment[k] = ma->comment[i];
		}
		++k;
	}
	ma->n = k;
	delete hash; // delete will call ~hash_set_char(), not free
	return k;
}
/** \fn int cpp_check_list(int m, char **name)
 *  \brief Check whether a string appears many times in an array.
 *  \param m Number of elements.
 *  \param name The array.
 *
 *  If a string appears multiple times, only the first one will be reserved.
 *  Number of remaining strings will be returned.
 */
int cpp_check_list(int m, char **name)
{
	int i, k;
	hash_set_char *hash;

	if (m == 0) return 0;
	hash = new hash_set_char;
	for (i = k = 0; i < m; ++i) {
		if (hash->find(name[i])) {
			fprintf(stderr, "[cpp_check_list] duplicated key: %s\n", name[i]);
			free(name[i]);
			continue;
		}
		hash->insert(name[i]);
		if (i != k) name[k] = name[i];
		++k;
	}
	delete hash;
	return k;
}
inline int cpp_attach_id_by_hash(Tree *root, const hash_map_char<int> *hash)
{
	Tree *p, **q, **list;
	int j, count, val;

	if (root == 0) return 0;
	assert(hash);
	q = list = tr_stack(root, TreePtr);
	*q++ = root;
	count = 0;
	while (q != list) {
		--q;
		(*q)->id = -1;
		if ((*q)->n == 0 && (*q)->name && hash->find((*q)->name, &val)) {
			(*q)->id = val;
			++count;
		}
		for (j = 0, p = *q; j < p->n; ++j)
			*q++ = p->node[j];
	}
	free(list);
	return count;
}
/** \fn int cpp_attach_id_by_name(Tree *root, int m, char **name)
 *  \brief Assign Tree::id by looking up a name array.
 *  \param root The tree.
 *  \param m Number of elements.
 *  \param name Name array.
 *
 *  This function sets p->id=k if name[k]==p->name, where p is a pointer to
 *  an external node. `-1' will be set if a name is not found in the array.
 */
int cpp_attach_id_by_name(Tree *root, int m, char **name)
{
	int count, i;
	hash_map_char<int> *hash;

	if (root == 0 || m == 0) return 0;
	hash = new hash_map_char<int>;
	for (i = 0; i < m; ++i)
		hash->insert(name[i], i);
	count = cpp_attach_id_by_hash(root, hash);
	delete hash;
	return count;
}
inline int cpp_attach_flag_by_hash(Tree *root, const hash_map_char<int> *hash)
{
	Tree *p, **q, **list;
	int j, count, val;

	if (root == 0) return 0;
	assert(hash);
	q = list = tr_stack(root, TreePtr);
	*q++ = root;
	count = 0;
	while (q != list) {
		--q;
		(*q)->flag = -1;
		if ((*q)->n == 0 && (*q)->name && hash->find((*q)->name, &val)) {
			(*q)->flag = val;
			++count;
		}
		for (j = 0, p = *q; j < p->n; ++j)
			*q++ = p->node[j];
	}
	free(list);
	return count;
}
/** \fn int cpp_attach_flag_by_name(Tree *root, int m, char **name)
 *  \brief Assign Tree::flag by looking up a name array.
 *  \param root The tree.
 *  \param m Number of elements.
 *  \param name Name array.
 *
 *  Similar to cpp_attach_id_by_name(), but in this function Tree::flag will
 *  be modified.
 */
int cpp_attach_flag_by_name(Tree *root, int m, char **name)
{
	int count, i;
	hash_map_char<int> *hash;

	if (root == 0 || m == 0) return 0;
	hash = new hash_map_char<int>;
	for (i = 0; i < m; ++i)
		hash->insert(name[i], i);
	count = cpp_attach_flag_by_hash(root, hash);
	delete hash;
	return count;
}
// This function is a helper function for accelerating SDI.
Tree **cpp_get_spec_links(const Tree *tree, const Tree *spec)
{
	Tree **links;
	int n_tree_leaf, n_spec_leaf;
	Tree **tree_leaf, **spec_leaf;
	hash_map_char<Tree*> *hash;
	char *sp, *sq;
	int i;

	if (tree == 0) return 0;
	links = tr_stack(tree, Tree*);
	if (spec == 0)
		for (i = 0; i < tree->n_leaf; ++i) links[i] = 0;
	hash = new hash_map_char<Tree*>;
	tree_leaf = tr_stack(tree, Tree*);
	spec_leaf = tr_stack(spec, Tree*);
	n_tree_leaf = tr_expand_leaf_by_id(tree, tree_leaf);
	n_spec_leaf = tr_expand_leaf(spec, spec_leaf);
	for (i = 0; i < n_spec_leaf; ++i) // initialize hash table
		hash->insert(spec_leaf[i]->name, spec_leaf[i]);
	for (i = 0; i < n_tree_leaf; ++i)
		links[i] = 0;
	sq = 0;
	for (i = 0; i < n_tree_leaf; ++i) {
		sq = tree_leaf[i]->name;
		for (sp = sq + strlen(sq) - 1; sp >= sq; --sp)
			if (*sp == '_') break;
		++sp; /* sp is the species name if found */
		if (sp != sq) /* match species name */
			hash->find(sp, links + i);
	}
	free(tree_leaf);
	free(spec_leaf);
	delete hash;
	return links;
}
// IMPORTANT: ->ftime must be correctly set!!! 
// This is non-recursive version.
Tree *cpp_subtree_aux(const Tree *tree)
{
	Tree **subnode, **node, *p, *q;
	int n, i, *array;

	if (tree == 0) return 0;
	node = tr_stack(tree, Tree*);
	subnode = tr_stack(tree, Tree*);
	array = tr_stack(tree, int);

	n = tr_expand_node(tree, node);
	for (i = 0; i < n; ++i) { // consistency check
		if (node[i]->ftime != i) {
			fprintf(stderr, "[cpp_subtree_aux] consistency check failed: %d!=%d\n", i, node[i]->ftime);
			free(node); free(subnode); free(array);
			return 0;
		}
		subnode[i] = 0;
	}
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (p->n == 0) { // leaf
			if (p->flag < 0) continue;
			q = tr_new_node();
			q->name = (char*)malloc(sizeof(char) * (strlen(p->name) + 1));
			strcpy(q->name, p->name);
			q->id = p->flag;
			q->d = p->d;
			q->bs = p->bs;
			q->ptr = p->ptr;
			cpp_copy_nhx_hash(q, p);
			subnode[i] = q;
		} else { // internal node
			int j, k;
			for (j = k = 0; j < p->n; ++j) {
				if (subnode[p->node[j]->ftime])
					array[k++] = p->node[j]->ftime;
			}
			if (k == 1) { // just one node
				q = subnode[i] = subnode[array[0]];
				q->d += p->d;
			} else if (k >= 2) {
				q = tr_new_node();
				q->n = k;
				q->d = p->d;
				q->bs = p->bs;
				q->ptr = p->ptr;
				q->is_cons = p->is_cons;
				q->node = (Tree**)malloc(sizeof(Tree*) * k);
				if (p->name) {
					q->name = (char*)malloc(sizeof(char) * (strlen(p->name) + 1));
					strcpy(q->name, p->name);
				}
				for (j = 0; j < k; ++j) {
					subnode[array[j]]->pre = q;
					q->node[j] = subnode[array[j]];
				}
				subnode[i] = q;
			}
		}
	}
	q = subnode[n-1];
	free(array);
	free(subnode);
	free(node);
	return q;
}
/** \fn Tree *cpp_subtree(Tree *root, int m, char **name)
 *  \brief Get a subtree.
 *  \param root The tree.
 *  \param m Number of elements.
 *  \param name Name array.
 *
 *  Eliminate the leaves that are not in the name array, and
 *  adjust the tree so that every internal node has at least two children.
 *  Tree::flag of the tree root will be modified. The subtree will be returned.
 */
Tree *cpp_subtree(Tree *root, int m, char **name)
{
	Tree *tree;
	if (root == 0 || m == 0) return 0;
	cpp_attach_flag_by_name(root, m, name);
	tree = cpp_subtree_aux(root);
	tr_tree_init(tree);
	return tree;
}
/** \fn Tree *cpp_shrink_spec(Tree *spec_tree, int m, char **name)
 *  \brief Generate a sub-species tree only containing the taxa appearing in the name array.
 *  \param spec_tree The species tree.
 *  \param m Number of elements in name array.
 *  \param name Name array.
 */
Tree *cpp_shrink_spec(Tree *spec_tree, int m, char **name)
{
	Tree *new_spec;
	hash_set_char *hash;
	hash_set_char::iterator iter;
	int i;
	const char *sp, *sq;
	char **spec_name;

	if (spec_tree == 0 || m == 0) return 0;
	hash = new hash_set_char;
	for (i = 0; i < m; ++i) {
		sq = name[i];
		for (sp = sq + strlen(sq) - 1; sp >= sq; --sp)
			if (*sp == '_') break;
		++sp;
		if (sp != sq)
			hash->insert(sp);
	}
	spec_name = new char* [hash->size()];
	for (i = 0, iter = hash->begin(); iter != hash->end(); ++iter) {
		if (isfilled(iter))
			spec_name[i++] = iter->key;
	}
	new_spec = cpp_subtree(spec_tree, hash->size(), spec_name);
	tr_attach_id(new_spec);
	delete[] spec_name;
	delete hash;

	Tree **node, *p;
	node = tr_stack(new_spec, Tree*);
	int j, k, n;
	n = tr_expand_internal_node(new_spec, node);
	for (i = 0; i < n; ++i) {
		p = node[i];
		for (j = k = 0; j < p->n; ++j)
			if (p->node[j]->bs > 0) ++k;
		p->bs = k;
	}
	free(node);
	return new_spec;
}
Tree *cpp_shrink_spec_by_tree(Tree *spec_tree, Tree *gene_tree)
{
	Tree **node, *new_spec;
	int n;
	char **name;
	node = tr_stack(gene_tree, Tree*);
	name = tr_stack(gene_tree, char*);
	n = tr_expand_leaf(gene_tree, node);
	for (int i = 0; i < n; ++i)
		name[i] = node[i]->name;
	new_spec = cpp_shrink_spec(spec_tree, n, name);
	free(node); free(name);
	return new_spec;
}
/** \fn Tree *cpp_check_tree(Tree *tree)
 *  \brief Check whether there are two leaves with identical names.
 *  \param tree The tree.
 *
 *  Leaves with identical names will be removed together. No one is left.
 */
Tree *cpp_check_tree(Tree *tree)
{
	Tree **node, *new_tree;
	char **name;
	hash_set_char *hash, *hash_aux;
	hash_set_char::iterator iter;
	int i, n;

	if (tree == 0) return 0;
	new_tree = tree;
	hash = new hash_set_char;
	hash_aux = new hash_set_char;
	node = tr_stack(tree, Tree*);
	name = tr_stack(tree, char*);
	n = tr_expand_leaf(tree, node);
	for (i = 0; i < n; ++i) {
		if (hash->find(node[i]->name))
			hash_aux->insert(node[i]->name);
		else hash->insert(node[i]->name);
	}
	if (hash_aux->size()) {
		for (iter = hash_aux->begin(); iter != hash_aux->end(); ++iter) {
			if (isfilled(iter)) {
				hash->erase(iter->key);
				fprintf(stderr, "[cpp_check_tree] duplicated leaf %s\n", iter->key);
			}
		}
		for (iter = hash->begin(), i = 0; iter != hash->end(); ++iter) {
			if (isfilled(iter))
				name[i++] = iter->key;
		}
		new_tree = cpp_subtree(tree, i, name);
		tr_delete_tree(tree);
	}
	free(node);
	free(name);
	delete hash;
	delete hash_aux;
	return new_tree;
}
/** \fn void cpp_set_leaf_order(Tree *src, Tree *dst, int def_val)
 *  \brief Use the leaf order of src to label dst
 *  \param src The source tree.
 *  \param dst The destination tree.
 *  \param def_val The default value when a leaf is not present in src.
 *
 *  This function will modify Tree::flag of dst.
 */
void cpp_set_leaf_order(Tree *src, Tree *dst, int def_val)
{
	int i, n, tmp;
	Tree **node;
	hash_map_char<int> *order;

	if (dst == 0) return;
	if (src == 0) { // no source tree. set all leaves as default.
		node = tr_stack(src, Tree*);
		n = tr_expand_leaf(src, node);
		for (i = 0; i < n; ++i)
			node[i]->flag = def_val;
		free(node);
	}
	order = new hash_map_char<int>;
	n = (src->n_leaf > dst->n_leaf)? src->n_leaf : dst->n_leaf;
	node = (Tree**)malloc(sizeof(Tree*) * n);
	n = tr_expand_leaf(src, node);
	for (i = 0; i < n; ++i)
		order->insert(node[i]->name, i);
	n = tr_expand_leaf(dst, node);
	for (i = 0; i < n; ++i) {
		if (order->find(node[i]->name, &tmp)) node[i]->flag = tmp;
		else node[i]->flag = def_val;
	}
	free(node);
	delete order;
}
/** \fn int cpp_search_by_name(const Tree *root, int n, const char **name, TreePtr *rst)
 *  \brief Locate names in a tree.
 *  \param root The tree.
 *  \param n Number of elements in name.
 *  \param name Name array.
 *  \param rst Returned pointers.
 */
/* NOT TESTED YET!!! */
void cpp_search_by_names(const Tree *root, int n, const char **name, TreePtr *rst)
{
	int m, i;
	Tree **node, *p;
	hash_map_char<TreePtr> *hash;

	if (root == 0)
		for (i = 0; i < n; ++i) rst[i] = 0;
	hash = new hash_map_char<TreePtr>;
	node = tr_stack(root, Tree*);
	m = tr_expand_node(root, node);
	for (i = 0; i < m; ++i)
		if (node[i]->name) hash->insert(node[i]->name, node[i]);
	free(node);
	for (i = 0; i < n; ++i)
		rst[i] = (hash->find(name[i], &p))? p : 0;
	delete hash;
}
/* typeof(Tree::ptr) == SDIinfo must be correct! */
Tree *cpp_subtree_spec(Tree *root, Tree *spec, int n, char **spec_name)
{
	int i, j, k, m;
	TreePtr *stack, *node, p;
	hash_set_char *set, *set2;

	if (root == 0 || spec == 0 || n == 0) return 0;

	set = new hash_set_char;
	for (i = 0; i < n; ++i)
		set->insert(spec_name[i]);

	set2 = new hash_set_char;
	node = tr_stack(spec, Tree*);
	stack = tr_stack(spec, Tree*);
	m = tr_expand_node(spec, node);
	for (i = 0; i < m; ++i) {
		p = node[i];
		if (p->name && set->find(p->name)) {
			if (p->n == 0) set2->insert(p->name);
			else {
				k = tr_expand_leaf(p, stack);
				for (j = 0; j < k; ++j)
					if (stack[j]->name) set2->insert(stack[j]->name);
			}
		}
	}
	free(stack);
	free(node);
	delete set;

	node = tr_stack(root, Tree*);
	m = tr_expand_leaf(root, node);
	for (i = 0; i < m; ++i) {
		p = node[i];
		p->flag = (SDIptr(p) && spec(p) && spec(p)->name && set2->find(spec(p)->name))? 1 : -1;
	}
	free(node);
	delete set2;
	p = cpp_subtree_aux(root);
	tr_tree_init(p);
	return p;
}
void cpp_insert_keyval(Tree *t, const char *key, const char *val)
{
	hash_map_char<char*> *hash;
	if (t->nhx == 0) {
		hash = new hash_map_char<char*>;
		t->nhx = hash;
	} else hash = (hash_map_char<char*>*)t->nhx;
	char *tmp = cpystr(val);
	hash->insert(key, tmp);
}
void cpp_get_keyval(Tree *t, const char *key, char **val)
{
	hash_map_char<char*> *hash;
	char *v;
	*val = 0;
	if (t->nhx == 0) return;
	hash = (hash_map_char<char*>*)t->nhx;
	if (hash->find(key, &v)) *val = cpystr(v);
}
void cpp_copy_nhx_hash(Tree *dst, Tree *src)
{
	if (src->nhx == 0) return;
	hash_map_char<char*>::iterator iter;
	hash_map_char<char*> *hsrc;
	hsrc = (hash_map_char<char*>*)src->nhx;
	for (iter = hsrc->begin(); iter != hsrc->end(); ++iter)
		if (isfilled(iter))
			cpp_insert_keyval(dst, iter->key, iter->val);
}
/* delete those species that have not been sequenced. */
void cpp_shrink_ma_by_spec(MultiAlign *ma, Tree *spec)
{
	Tree **node;
	int i, k, m;
	hash_set_char *set;

	assert(ma);
	if (spec == 0) return;
	node = tr_stack(spec, Tree*);
	m = tr_expand_leaf(spec, node);
	set = new hash_set_char;
	for (i = 0; i < m; ++i) {
		if (node[i]->bs) set->insert(node[i]->name);
	}
	for (i = k = 0; i < ma->n; ++i) {
		char *sp, *sq;
		sq = ma->name[i];
		for (sp = sq + strlen(sq) - 1; sp >= sq; --sp)
			if (*sp == '_') break;
		++sp;
		if (sp != sq && set->find(sp)) {
			if (i != k) {
				ma->name[k] = ma->name[i];
				ma->gene[k] = ma->gene[i];
				ma->comment[k] = ma->comment[i];
				ma->seq[k] = ma->seq[i];
			}
			++k;
		} else {
			free(ma->name[i]); free(ma->gene[i]); free(ma->comment[i]); free(ma->seq[i]);
			ma->seq[i] = ma->gene[i] = ma->name[i] = ma->comment[i] = 0;
		}
	}
	ma->n = k;
	delete set;
	free(node);
}
void tr_delete_node(Tree *t)
{
	if (t == 0) return;
	if (t->n > 0) free(t->node);
	if (t->name) free(t->name);
	if (t->ptr) free(t->ptr);
	if (t->nhx) {
		hash_map_char<char*> *p = (hash_map_char<char*> *)t->nhx;
		hash_map_char<char*>::iterator iter;
		for (iter = p->begin(); iter < p->end(); ++iter)
			if (isfilled(iter)) free(iter->val);
		delete p;
	}
	free(t);
}
extern "C" {
	void ma_init_nucl_data();
	void ma_free_nucl_data();
	void ma_cal_nucl_aux(Matrix*, MultiAlign*, int, int, Matrix*);
}
void tr_dN_dS(Tree *tree, MultiAlign *ma)
{
	int i;
	Matrix *mat_ds, *mat_dn;
	MultiAlign *tma;

	if (tree->n_leaf != ma->n) {
		fprintf(stderr, "[tr_dN_dS_ratio] inconsistent between tree and alignment!\n");
		return;
	}
	if (!ma->is_nucl) {
		fprintf(stderr, "[tr_dN_dS_ratio] the input is not a nucleotide alignment!\n");
		return;
	}
	mat_ds = ma_init_small_matrix(ma);
	mat_dn = ma_init_small_matrix(ma);
	ma_init_nucl_data();
	tma = ma_trans_align(ma, 0);
	ma_cal_nucl_aux(mat_ds, tma, 0, DIST_DM, mat_dn);
	ma_free_nucl_data();
	for (i = 0; i < ma->n * ma->n; ++i) {
		mat_ds->dist[i] = -log(1-mat_ds->dist[i]);
		mat_dn->dist[i] = -log(1-mat_dn->dist[i]);
	}
	tr_est_len(tree, mat_ds, "dS");
	tr_est_len(tree, mat_ds, "dN");
}
Tree *cpp_post_spec_tree(Tree *tree, int is_core)
{
	int i, m;
	char *q;
	Tree **node, *p;
	extern char *tr_core_species_list[];

	hash_set_char *set = 0;
	if (is_core) {
		set = new hash_set_char;
		for (i = 0; tr_core_species_list[i]; ++i)
			set->insert(tr_core_species_list[i]);
	}
	node = tr_stack(tree, Tree*);
	m = tr_expand_node(tree, node);
	for (i = 0; i < m; ++i) {
		p = node[i];
		/* remove '-' */
		for (q = p->name; *q; ++q)
			if (*q == '-') break;
		if (*q == '-') *q = '\0';
		if (p->n == 0) { /* external node */
			/* remove '*' and set fullly sequenced flag */
			for (q = p->name; *q; ++q)
				if (*q == '*') break;
			if (*q == '*') {
				*q = '\0';
				if (is_core) {
					if (set->find(p->name)) p->bs = 1;
				} else p->bs = 1; /* flag is set */
			} else p->bs = 0; /* not fully sequenced */
		} else { /* internal node */
			int j, k;
			for (k = j = 0; k < p->n; ++k)
				if (p->node[k]->bs > 0) ++j;
			p->bs = j;
		}
	}
	free(node);
	delete set;
	return tree;
}
