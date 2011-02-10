#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "tree.h"
#include "utils.h"
#include "align.h"
#include "align_lib/table.h"

void tr_stat_output(FILE *fp, const Tree *root)
{
	Tree **node, *p;
	SDIinfo *q;
	int m, i, j;

	if (root == 0) return;
	node = tr_stack(root, Tree*);
	m = tr_expand_internal_node(root, node);
	for (i = 0; i < m; ++i) {
		p = node[i];
		q = SDIptr(p);
		if (q->type != 'N') {
			fprintf(fp, "%c\t%d\t%s", q->type, p->bs, spec(p)->name);
			if (q->type == 'D') {
				j = (spec(p) == spec(p->node[0]))? 1 : 0;
				if (spec(p->node[j]) && spec(p->node[j])->name)
					fprintf(fp, "\t%s", spec(p->node[j])->name);
			}
			fprintf(fp, "\t$");
			for (j = 0; j < q->n_lost; ++j)
				fprintf(fp, "-%s", q->lost[j]->name);
			fputc('\n', fp);
			fflush(fp);
		}
	}
	free(node);
}
/*
 * Output ortholog information
 */
void tr_ortho_output(FILE *fp, const Ortholog *ortho, const Tree *tree)
{
	int i, j;
	short *p;
	Tree **leaf;
	TreePtr *q;
	char *r;

	if (ortho == 0 || tree == 0) return;
	leaf = (Tree**)malloc(sizeof(Tree*) * ortho->n);
	for (i = 0; i < ortho->n; ++i)
		leaf[i] = 0;
	tr_expand_leaf_by_id(tree, leaf);
	for (i = 0; i < ortho->n; ++i) {
		p = ortho->rel[i];
		q = ortho->taxon[i];
		r = ortho->is_pseudo[i];
		if (leaf[i] == 0) continue;
		for (j = 0; j < i; ++j)
			if (p[j] > 0 && leaf[j] != 0) {
				fprintf(fp, "%s\t%s\t%s\t%d\t%d\n", leaf[i]->name, leaf[j]->name, q[j]->name, (int)(p[j]-1), (int)(r[j]));
				/* fprintf(fp, "%s\t%s\t%s\t%d\n", leaf[j]->name, leaf[i]->name, q[j]->name, (int)(p[j]-1)); */
				fflush(fp);
			}
	}
	free(leaf);
}
void tr_align_output(FILE *fp, const MultiAlign *ma)
{
	int i, j, k;
	char *seq;

	assert(ma);
	for (i = 0; i < ma->n; ++i) {
		fprintf(fp, ">%s", ma->name[i]);
		if (ma->comment && ma->comment[i]) fprintf(fp, " %s", ma->comment[i]);
		fputc('\n', fp);
		fflush(fp);
		seq = ma->seq[i];
		if (!ma->is_nucl) {
			for (j = 0; j < ma->len; j += 60) {
				for (k = j; k < ma->len && k < j + 60; ++k)
					fputc(aln_aa_rev_table[(int)seq[k]], fp);
				fputc('\n', fp);
				fflush(fp);
			}
		} else {
			for (j = 0; j < ma->len; j += 60) {
				for (k = j; k < ma->len && k < j + 60; ++k)
					fputc(aln_nt4_rev_table[(int)seq[k]], fp);
				fputc('\n', fp);
				fflush(fp);
			}
		}
	}
}
void tr_align_aln_output(FILE *fp, const MultiAlign *ma)
{
	int max_name_len = 0;
	char format[20];
	int i, j, k, len;
	char *seq;
	AlignQual *aq;

	assert(ma);
	fprintf(fp, "CLUSTAL W (1.83) multiple sequence alignment\n\n");
	aq = ma_cal_qual(ma);
	for (i = 0; i < ma->n; ++i)
		if (max_name_len < strlen(ma->name[i])) max_name_len = strlen(ma->name[i]);
	len = 80 - 1 - max_name_len;
	sprintf(format, "%%-%ds", max_name_len + 1);
	for (j = 0; j < ma->len; j += len) {
		fputc('\n', fp);
		fflush(fp);
		for (i = 0; i < ma->n; ++i) {
			seq = ma->seq[i];
			fflush(fp);
			fprintf(fp, format, ma->name[i]);
			if (!ma->is_nucl) {
				for (k = j; k < ma->len && k < j + len; ++k)
					fputc(aln_aa_rev_table[(int)seq[k]], fp);
			} else {
				for (k = j; k < ma->len && k < j + len; ++k)
					fputc(aln_nt4_rev_table[(int)seq[k]], fp);
			}
			fputc('\n', fp);
			fflush(fp);
		}
		if (!ma->is_nucl) {
			fprintf(fp, format, " ");
			for (k = j; k < ma->len && k < j + len; ++k)
				if (aq->pos_qual[k] == 100) fputc('*', fp);
				else fprintf(fp, "%1d", aq->pos_qual[k]/10);
		}
		fputc('\n', fp);
		fflush(fp);
	}
	ma_free_AlignQual(aq);
}
void tr_matrix_output(FILE *fp, const Matrix *mat)
{
	int i, j, n;
	float *p;

	assert(fp); assert(mat);
	n = mat->count;
	fprintf(fp, " %d\n", n);
	for (i = 0; i < n; ++i) {
		p = mat->dist + i * n;
		fprintf(fp, "%-30s ", mat->name[i]);
		for (j = 0; j < n; ++j)
			fprintf(fp, " %9.5f", p[j]);
		fputc('\n', fp);
	}
}
void tr_task_output(FILE *fp, const Task *task)
{
	assert(fp); assert(task);
	if (!task->is_verbose) {
		if (task->cut && task->subtree)
			tr_tree_output(fp, task->subtree, task->out_flag);
		else if (task->tree)
			tr_tree_output(fp, task->tree, task->out_flag);
		return;
	}
	if (task->tree) {
		fprintf(fp, "@begin full_tree\n");
		tr_tree_output(fp, task->tree, task->out_flag);
		fprintf(fp, "@end full_tree\n\n");
		if (task->aln) {
			fprintf(fp, "@begin alignment\n");
			tr_align_output(fp, task->aln);
			fprintf(fp, "@end alignment\n\n");
		}
		if (task->spec_tree) {
			fprintf(fp, "@begin full_ortholog\n");
			tr_ortho_output(fp, task->ortho, task->tree);
			fprintf(fp, "@end full_ortholog\n\n");
			fprintf(fp, "@begin full_stat\n");
			tr_stat_output(fp, task->tree);
			fprintf(fp, "@end full_stat\n\n");
		}
	}
	if (task->cut && task->subtree) {
		Tree *p;
		p = task->subtree;
		if (p->pre && SDIptr(p->pre)->type == 'S') p = p->pre;
		fprintf(fp, "@begin cut_tree\n");
		tr_tree_output(fp, p, task->out_flag);
		fprintf(fp, "@end cut_tree\n\n");
		if (task->spec_tree) {
			fprintf(fp, "@begin cut_ortholog\n");
			tr_ortho_output(fp, task->ortho, p);
			fprintf(fp, "@end cut_ortholog\n\n");
			fprintf(fp, "@begin cut_stat\n");
			tr_stat_output(fp, p);
			fprintf(fp, "@end cut_stat\n\n");
		}
	}
}
