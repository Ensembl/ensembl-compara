#include <stdio.h>
#include <string.h>
#include "align.h"
#include "common/hash_char.h"
#include "utils.h"
#include "tree.h"

static unsigned out_flag = 0;
static hash_set_char *set;

void tr_tree_output(FILE *fp, const Tree *root, unsigned flag)
{
	assert(fp);
	char *str = tr_tree_string(root, flag);
	fprintf(fp, "%s", str);
	free(str);
}
static int string_estimate_string_len(const Tree *tree, int out_flag)
{
	Tree **node, *p;
	int i, j, n, len = 0;
	SDIinfo *s;
	hash_map_char<char*> *hash;
	hash_map_char<char*>::iterator iter;

	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (p->name) len += strlen(p->name); // name
		if (p->n) len += 6 + 2 + p->n + (p->n-1); // "[&&NHX]" + "()" + "\n" + ","
		if (p->d > 1e-30) len += 1 + 17; // ":"dist
		if ((out_flag & OUTPUT_SDI) && SDIptr(p)) {
			s = SDIptr(p);
			len += 17; // ":D=Y:SIS=100:DD=Y"
			if (spec(p) && spec(p)->name) {
				len += 3 + strlen(spec(p)->name); // ":S="spec
				if (s->n_lost) {
					len += 4; // ":E=$"
					for (j = 0; j < s->n_lost; ++j)
						if (s->lost[j]->name)
							len += 1 + strlen(s->lost[j]->name); // "-"spec
				}
			}
			
		}
		len += 6 + 7; // ":Com=N" + ":B=100"
		hash = (hash_map_char<char*> *)p->nhx;
		if (hash) {
			for (iter = hash->begin(); iter < hash->end(); ++iter)
				if (isfilled(iter) && !set->find(iter->key))
					len += 2 + strlen(iter->key) + strlen(iter->val); // ":"key"="val
		}
	}
	len += 2; // ";\n"
	free(node);
	return len;
}
inline int string_nhx_node(char *str, const Tree *t)
{
	int i;
	char *p;
	SDIinfo *s;
	hash_map_char<char*> *hash;
	hash_map_char<char*>::iterator iter;

	if (!((out_flag & OUTPUT_SDI) && SDIptr(t)) && t->nhx == 0 && t->bs < 0)
		return 0;
	p = str;
	p += sprintf(p, "[&&NHX");
	if ((out_flag & OUTPUT_SDI) && SDIptr(t)) {
		int c;
		s = SDIptr(t);
		c = s->type;
		if (c != 'N') { /* duplication flag is defined */
			p += sprintf(p, ":D=%c", (c == 'D')? 'Y' : 'N'); /* whether duplication? */
			if (c == 'D') {
				p += sprintf(p, ":SIS=%d", s->sis);
				if (!s->is_confirmed_dup) p += sprintf(p, ":DD=Y"); /* Dubious Duplication */
			}
		}
		if (s->n_lost) {
			p += sprintf(p, ":E=$");
			for (i = 0; i < s->n_lost; ++i)
				if (s->lost[i]->name)
					p += sprintf(p, "-%s", s->lost[i]->name);
		}
		if (spec(t) && spec(t)->name && (s->type != 'N' || t->n == 0)) /* species name */
			p += sprintf(p, ":S=%s", spec(t)->name);
	}
	if (t->bs >= 0) p += sprintf(p, ":B=%d", t->bs); /* bootstrap value */
	if ((out_flag & OUTPUT_COMPARE) && t->is_cons == 0) /* identical clade */
		p += sprintf(p, ":Com=N");
	/* print miscellaneous information */
	hash = (hash_map_char<char*> *)t->nhx;
	if (hash) {
		for (iter = hash->begin(); iter < hash->end(); ++iter)
			if (isfilled(iter) && !set->find(iter->key))
				p += sprintf(p, ":%s=%s", iter->key, iter->val);
	}
	p += sprintf(p, "]");
	if (p - 6 == str) { /* strip [&&NHX] */
		p = str; *str = '\0';
	}
	return p - str;
}
static int tr_tree_string_aux(char *str, const Tree *t)
{
	int i;
	char *p = str;

	/* leaf node */
	if (t->n == 0) {
		p += sprintf(p, "%s", t->name);
		if (t->d > -1e30)
			p += sprintf(p, ":%g", t->d);
		if (out_flag & OUTPUT_SDI)
			p += string_nhx_node(p, t);
		return p - str;
	}
	p += sprintf(p, "(");
	p += tr_tree_string_aux(p, t->node[0]);
	for (i = 1; i < t->n; ++i) { /* output children recursively */
		p += sprintf(p, ",\n");
		p += tr_tree_string_aux(p, t->node[i]);
	}
	p += sprintf(p, "\n)");
	if (t->name) p += sprintf(p, "%s", t->name);
	if (t->d > -1e30) /* if reasonable length, output branch length */
		p += sprintf(p, ":%g", t->d);
	if (out_flag & OUTPUT_SDI)
		p += string_nhx_node(p, t);
	return p - str;
}
char *tr_tree_string(const Tree *root, unsigned flag)
{
	char *str, *p;
	int len;
	if (root == 0) return cpystr("_null_;\n"); // output a null tree
	out_flag = flag;
	set = new hash_set_char;
	set->insert("B");
	if (!(flag & OUTPUT_ORI_NHX)) {
		if (flag & OUTPUT_SDI) {
			set->insert("E"); set->insert("S"); set->insert("D");
		}
		if (flag & OUTPUT_COMPARE) set->insert("Com");
	}
	len = string_estimate_string_len(root, flag);
	str = (char*)malloc(sizeof(char) * len);
	p = str;
	p += tr_tree_string_aux(p, root);
	p += sprintf(p, ";\n");
	delete set;
	return str;
}
void tr_attach_geneid(Tree *tree, MultiAlign *ma)
{
	hash_map_char<char*> *hash, *nhx;
	char *s, *t;
	Tree **node, *p;
	int i, n;

	hash = new hash_map_char<char*>;
	for (i = 0; i < ma->n; ++i) {
		if (ma->name[i] && ma->gene && ma->gene[i]) {
			s = (strstr(ma->gene[i], "GENEID="))? ma->gene[i] + 7 : ma->gene[i];
			hash->insert(ma->name[i], s); // no memory allocation here
		}
	}
	node = tr_stack(tree, Tree*);
	n = tr_expand_leaf(tree, node);
	for (i = 0; i < n; ++i) {
		p = node[i];
		if (hash->find(p->name, &s)) {
			if (!p->nhx) {
				nhx = new hash_map_char<char*>;
				p->nhx = nhx;
			} else nhx = (hash_map_char<char*>*)p->nhx;
			if (nhx->find("G", &t)) free(t);
			nhx->insert("G", cpystr(s)); // memory allocation
		}
	}
	free(node);
	delete hash;
}
void tr_attach_seed_tag(Tree *tree, int n, char **list)
{
	hash_map_char<char*> *nhx;
	hash_set_char *hash;
	Tree **node, *p;
	int m, i;
	char *t;

	if (n) assert(list);
	hash = new hash_set_char;
	for (i = 0; i < n; ++i) if (list[i]) hash->insert(list[i]);
	node = tr_stack(tree, Tree*);
	m = tr_expand_leaf(tree, node);
	for (i = 0; i < m; ++i) {
		p = node[i];
		if (hash->find(p->name)) {
			if (!p->nhx) {
				nhx = new hash_map_char<char*>;
				p->nhx = nhx;
			} else nhx = (hash_map_char<char*>*)p->nhx;
			if (nhx->find("Sd", &t)) free(t);
			nhx->insert("Sd", cpystr("Y")); // memory allocation
		}
	}
	free(node);
	delete hash;
}
