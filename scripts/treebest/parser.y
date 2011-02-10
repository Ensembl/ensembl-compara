%{
#define YYPARSER
#define YYSTYPE Tree*

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "common/hash_char.h"
#include "tree.h"
#include "utils.h"

extern char lastid[];
extern double lastfnum;
extern int lineno;
extern int read_bootstrap;

#ifdef __cplusplus
extern "C" {
#endif
int yylex();
void yyerror(const char *);
char *str_cpy();
int yyparse();
void alloc_str_buffer(const char *str);
void alloc_file_buffer(FILE *fp);
void free_buffer();
#ifdef __cplusplus
}
#endif

static Tree *root;
static hash_map_char<char*> *hash;
static char *curr_key;

Tree *tr_new_node()
{
	Tree *t;
	t = (Tree*)malloc(sizeof(Tree));
	t->ptr = 0;
	t->nhx = 0;
	t->n = 0;
	t->node = 0;
	t->bs = -1;
	t->d = -2e30;
	t->name = 0;
	t->id = -1;
	t->pre = 0;
	t->ftime = 0;
	t->n_leaf = 0;
	t->is_cons = 0;
	t->flag = 0;

	t->n_node = 0;
	t->node_array = 0;
	return t;
}
%}

%token TR_ID TR_DIST TR_NHX

%%

tree		: nhx_cell ';'
				{ root = $1; return 0; }
			|
				{ return 1; }
			;

nh_cell		: node
				{ $$ = $1; }
			| node TR_DIST
				{ $$ = $1; $$->d = (float)lastfnum; }
			;

nhx_cell	: nh_cell nhx
				{
					$$ = $1;
					if (hash && hash->size() > 0) {
						char *s;
						$$->nhx = (void*)hash;
						if (hash->find("B", &s))
							$$->bs = atoi(s);
					}
					hash = 0;
				}
			| nh_cell
				{ $$ = $1; }
			;

nhx			: '[' nhx_start key_val_list ']'
			| '[' nhx_start ']'
				{ delete hash; hash = 0; }
			;

nhx_start	: TR_NHX
				{ hash = new hash_map_char<char*>; }
			;

key_val_list: key_val_list key_val_pair
			| key_val_pair
			;

key_val_pair: ':' key '=' TR_ID
				{ if (hash) hash->insert(curr_key, str_cpy()); free(curr_key); }
			;

key			: TR_ID
				{ curr_key = str_cpy(); }
			;

node		: TR_ID
				{ $$ = tr_new_node(); $$->name = str_cpy(); }
			| inner
				{ $$ = $1; }
			;

list		: list ',' nhx_cell
				{
					$1->node = (Tree**)realloc($1->node, sizeof(Tree*) * ($1->n + 1));
					$1->node[$1->n] = $3;
					++($1->n);
					$$ = $1;
					$3->pre = $$;
				}
			| nhx_cell
				{
					$$ = tr_new_node();
					$$->n = 1;
					$$->node = (Tree**)malloc(sizeof(Tree*));
					$$->node[0] = $1;
					$1->pre = $$;
				}
			;

inner		: '(' list ')'
				{ $$ = $2; }
			| '(' list ')' TR_ID
				{ $$ = $2; $$->name = str_cpy(); }
			;

%%

char *str_cpy()
{
	char *s = (char*)malloc(sizeof(char) * (strlen(lastid) + 1));
	return strcpy(s, lastid);
}
void yyerror(const char *err)
{
	fprintf(stderr, "ERROR: %s in line %d, near (%s,%g)\n", err, lineno, lastid, (float)lastfnum);
}
void tr_delete_tree(Tree *root)
{
	int i, m, is_free;
	Tree **node;
	if (root == 0) return;
	if (!root->node_array) {
		node = tr_stack(root, Tree*);
		m = tr_expand_node(root, node);
		is_free = 1;
	} else {
		node = root->node_array;
		m = root->n_node;
		is_free = 0;
	}
	for (i = 0; i < m; ++i) {
		Tree *t = node[i]; // the following is exactly the same as tr_delete_node()
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
		if (t->node_array) free(t->node_array);
		free(t);
	}
	if (is_free) free(node);
}
Tree **tr_parse(FILE *fp, int *n)
{
	Tree **forest;
	alloc_file_buffer(fp);
	lineno = 0;
	forest = 0;
	*n = 0;
	while (yyparse() == 0) {
		tr_tree_init(root); /* calculate finish time */
		tr_attach_id(root); /* add default ID */
		forest = (Tree**)realloc(forest, sizeof(Tree*) * (*n + 1));
		forest[(*n)++] = root;
	}
	free_buffer();
	return forest;
}
Tree *tr_parse_first(FILE *fp)
{
	Tree *tree;
	alloc_file_buffer(fp);
	lineno = 0;
	tree = 0;
	if (yyparse() == 0) {
		tr_tree_init(root); /* calculate finish time */
		tr_attach_id(root); /* add default ID */
		tree = root;
	}
	free_buffer();
	return tree;
}
Tree **tr_parse_str(const char *str, int *n)
{
	Tree **forest;

	alloc_str_buffer(str);
	lineno = 0;
	forest = 0;
	*n = 0;
	while (yyparse() == 0) {
		tr_tree_init(root); /* calculate finish time */
		tr_attach_id(root); /* add default ID */
		forest = (Tree**)realloc(forest, sizeof(Tree*) * (*n + 1));
		forest[(*n)++] = root;
	}
	free_buffer();
	return forest;
}
