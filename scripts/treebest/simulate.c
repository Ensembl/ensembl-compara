#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "tree.h"
#include "utils.h"
#include "cpp_utils.h"

#define BLOCK_SIZE 16

typedef struct
{
	Tree *p, *pre;
} STACK;

void tr_default_length(Tree *tree, double height, int is_sum_length)
{
	Tree **node, *p;
	int i, n;
	double scale = tree->d = 1.0;
	node = tr_stack(tree, Tree*);
	n = tr_expand_node(tree, node);
	for (i = n - 2; i >= 0; --i) {
		p = node[i];
		p->d = p->pre->d + 1.0;
		if (p->d > scale) scale = p->d;
	}
	for (i = 0; i < n; ++i) {
		if (node[i]->n == 0) node[i]->d = scale;
		node[i]->d *= height / scale;
	}
	if (!is_sum_length) 
		for (i = 0; i < n - 1; ++i)
			node[i]->d -= node[i]->pre->d;
	free(node);
}
int tr_simulate_aux(Tree **result)
{
	if (result[0]->n == 0) {
		return 1;
	} else {
		int j, l;
		l = 1;
		for (j = 0; j < result[0]->n; ++j) {
			result[0]->node[j] = result[l];
			result[l]->pre = result[0];
			l += tr_simulate_aux(result + l);
		}
		return l;
	}
}
Tree *tr_simulate(Tree *spec, double pd, double pl, double pdl, double height, int is_name)
{
	Tree *p, *q, **result;
	int k, max_k, l, max_l, count;
	STACK *stack, *top;
	float tmp;

	max_k = BLOCK_SIZE;
	k = l = max_l = count = 0;
	stack = (STACK*)malloc(sizeof(STACK) * BLOCK_SIZE);
	stack[k].p = spec; stack[k++].pre = 0;
	result = 0;
	tr_default_length(spec, height, 1);
	
	while (k) {
		top = stack + (--k);
		p = top->p;
		q = tr_new_node();
		q->pre = top->pre;
		q->d = p->d;
#ifndef _WIN32
		if (p != spec && drand48() < pd) { /* not the root */
#else
		if (p != spec && (double)rand() / RAND_MAX < pd) { /* not the root */
#endif
			q->n = 2;
			q->flag = 1; /* duplication */
			q->node = (Tree**)malloc(sizeof(Tree*) * q->n);
			if (k+2 >= max_k) {
				max_k+= BLOCK_SIZE;
				stack = (STACK*)realloc(stack, sizeof(STACK) * max_k);
			}
			if (is_name) {
				q->name = (char*)malloc(sizeof(char) * (strlen(p->name)+1));
				strcpy(q->name, p->name);
			}
			stack[k].p = p; stack[k++].pre = q;
			stack[k].p = p; stack[k++].pre = q;
		} else {
			q->flag = 0; /* not duplication */
			if (p->n > 0) { /* internal node */
				int i, j;
				double prob = (top->pre && top->pre->flag)? pdl : pl;
				for (i = j = 0; i < p->n; ++i) {
#ifndef _WIN32
					if (drand48() >= prob) { /* not lost */
#else
					if ((double)rand() / RAND_MAX >= prob) {
#endif
						++j;
						if (k == max_k) {
							max_k += BLOCK_SIZE;
							stack = (STACK*)realloc(stack, sizeof(STACK) * max_k);
						}
						stack[k].p = p->node[i]; stack[k++].pre = q;
					}
				}
				if (is_name) {
					q->name = (char*)malloc(sizeof(char) * (strlen(p->name)+1));
					strcpy(q->name, p->name);
				}
				if (j > 0) {
					q->n = j;
					q->node = (Tree**)malloc(sizeof(Tree*) * q->n);
					q->id = 1;
				} else q->id = -1; /* will be deleted */
			} else {
				q->name = (char*)malloc(sizeof(char) * (strlen(p->name)+6));
				q->id = 0;
				sprintf(q->name, "%.4d_%s", count++, p->name);
			}
		}
		if (l == max_l) {
			max_l += BLOCK_SIZE;
			result = (Tree**)realloc(result, sizeof(Tree*) * max_l);
		}
		result[l++] = q;
	}
	
	free(stack);
	/* adjust branch length */
	for (k = 0; k < l; ++k) {
		p = result[k];
		tmp = (k == 0)? 0 : p->pre->d;
		if (p->flag) /* duplication */
			p->d = (p->d - tmp) / 2 + tmp;
	}
	for (k = l - 1; k > 0; --k)
		result[k]->d -= result[k]->pre->d;
	/* write tree */
	k = tr_simulate_aux(result);
	if (l != k) fprintf(stderr, "[tr_simulate] inconsistencies occurs (%d,%d)\n", l, k);
	p = result[0];
	tr_tree_init(p);
	k = tr_expand_node(p, result);
	/* write flag, prepare for cpp_subtree_aux() */
	k = tr_expand_leaf(p, result);
	for (l = 0; l < k; ++l)
		result[l]->flag = result[l]->id;
	free(result);
	q = cpp_subtree_aux(p);
	tr_delete_tree(p);
	tr_tree_init(q);
	tr_attach_id(q);
	return q;
}
Tree *tr_shrink_spec(Tree *spec)
{
	Tree **node, *p;
	int i, m;

	node = tr_stack(spec, Tree*);
	m = tr_expand_leaf(spec, node);
	for (i = 0; i < m; ++i) {
		p = node[i];
		p->flag = (p->bs > 0)? 1 : -1;
	}
	free(node);
	p = cpp_subtree_aux(spec);
	tr_tree_init(p);
	return p;
}
static int tr_simulate_usage()
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Usage:   treebest simulate [options]\n\n");
	fprintf(stderr, "Options: -d FNUM        duplication probability [0.05]\n");
	fprintf(stderr, "         -l FNUM        loss probability [0.01]\n");
	fprintf(stderr, "         -p FNUM        loss probability after duplication [0.25]\n");
	fprintf(stderr, "         -m FNUM        max height [0.25]\n");
	fprintf(stderr, "         -n             not show internal name\n");
	fprintf(stderr, "         -h             help\n\n");
	return 1;
}
int tr_simulate_task(int argc, char *argv[])
{
	Tree *spec, *simu, *shrink;
	int c, is_name;
	double height, pd, pl, pdl;

	pd = 0.05;
	pl = 0.01;
	pdl = 0.25;
	height = 0.25;
	is_name = 1;
#ifndef _WIN32
	srand48(time(0)^((int)getpid()));
#else
	srand(time(0));
#endif

	while ((c = getopt(argc, argv, "d:l:p:m:hn")) >= 0) {
		switch (c) {
			case 'd': pd = atof(optarg); break;
			case 'l': pl = atof(optarg); break;
			case 'p': pdl = atof(optarg); break;
			case 'm': height = atof(optarg); break;
			case 'n': is_name = 0; break;
			case 'h': return tr_simulate_usage();
		}
	}
	spec = tr_default_spec_tree();
	shrink = tr_shrink_spec(spec);
	simu = tr_simulate(shrink, pd, pl, pdl, height, is_name);
	tr_tree_output(stdout, simu, 0);
	tr_delete_tree(spec);
	tr_delete_tree(shrink);
	tr_delete_tree(simu);
	return 0;
}
