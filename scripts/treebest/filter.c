#include <string.h>
#include <stdlib.h>
#include "align.h"
#include "align_lib/table.h"

void ma_remove_gap(MultiAlign *ma)
{
	int i, j, k;

	assert(ma);
	for (k = 0, i = 0; i < ma->len; ++i) {
		for (j = 0; j < ma->n; ++j) {
			if ((ma->is_nucl && ma->seq[j][i] != ALN_NT4_GAP)
					|| (!ma->is_nucl && ma->seq[j][i] != ALN_AA_GAP)) break;
		}
		if (j != ma->n) { /* not gapped column */
			if (i != k)
				for (j = 0; j < ma->n; ++j)
					ma->seq[j][k] = ma->seq[j][i];
			++k;
		}
	}
	ma->len = k;
}
void ma_apply_mask(MultiAlign *ma)
{
	int i, j, k;
	char *mask = 0;

	assert(ma);
	for (i = j = 0; i < ma->n; ++i) {
		if (ma->name[i] && strcmp(ma->name[i], "MASKSEQ") == 0) {
			if (mask) free(mask);
			mask = ma->seq[i];
			free(ma->name[i]);
			if (ma->gene && ma->gene[i]) free(ma->gene[i]);
			if (ma->comment && ma->comment[i]) free(ma->comment[i]);
		} else {
			if (j < i) {
				ma->name[j] = ma->name[i];
				ma->gene[j] = ma->gene[i];
				ma->comment[j] = ma->comment[i];
				ma->seq[j] = ma->seq[i];
			}
			++j;
		}
	}
	ma->n = j;
	if (mask == 0) return;
	for (i = j = 0; i < ma->len; ++i) {
		if ((ma->is_nucl && mask[i] != ALN_NT4_GAP) || (!ma->is_nucl && mask[i] != ALN_AA_GAP)) {
			if (j < i)
				for (k = 0; k < ma->n; ++k)
					ma->seq[k][j] = ma->seq[k][i];
			++j;
		}
	}
	ma->len = j;
	free(mask);
}
void ma_shrink_alignment(MultiAlign *ma, AlignQual *aq, int cut_off)
{
	int i, j, k, n, len;

	assert(ma); assert(aq);
	n = ma->n;
	len = ma->len;
	for (j = 0, k = 0; j < len; ++j) {
		if (aq->pos_qual[j] >= cut_off) {
			if (k < j) {
				/* then move column j to k */
				for (i = 0; i < n; ++i) {
					ma->seq[i][k] = ma->seq[i][j];
					aq->pos_qual[k] = aq->pos_qual[j];
				}
			}
			++k;
		}
	}
	ma->len = k;
	aq->len = k;
}
void ma_filter(MultiAlign *ma, int is_collapse, int cut_off, int is_mask_segment)
{
	extern void ma_nucl_filter(MultiAlign *tma, int is_collapse, int cut_off, int is_mask_segment);
	extern void ma_debug_qual(const MultiAlign *ma, const AlignQual *aq);
	AlignQual *aq;
	int i, j, n;
	int *flag;

	assert(ma);
	if (ma->is_nucl) { /* if ma is nucleotide alignment, use ma_nucl_filter() instead */
		ma_nucl_filter(ma, is_collapse, cut_off, is_mask_segment);
		return;
	}
	n = ma->n;
	/* first round: handle alternative splicing. */
	aq = ma_cal_qual(ma);
	if (!is_collapse) goto no_collapse_aa;
	/* choose the best aligned protein among various splicing forms */
	flag = (int*)malloc(sizeof(int) * n);
	for (i = 0; i < n; ++i)
		flag[i] = 1;
	if (ma->gene) {
		for (i = 0; i < n; ++i) {
			if (ma->gene[i] == 0) continue;
			for (j = i + 1; j < n; ++j) {
				if (ma->gene[j] && strcmp(ma->gene[i], ma->gene[j]) == 0) { /* same gene */
					if (aq->seq_qual[i] < aq->seq_qual[j]) flag[i] = 0; /* discard i */
					else flag[j] = 0; /* discard j */
				}
			}
		}
	}
	/* eliminate discarded proteins */
	for (i = j = 0; i < n; ++i) {
		if (flag[i]) {
			if (j < i) {
				ma->seq[j] = ma->seq[i];
				ma->name[j] = ma->name[i];
				ma->gene[j] = ma->gene[i];
				ma->comment[j] = ma->comment[i];
			}
			++j;
		} else {
			free(ma->seq[i]);
			free(ma->gene[i]);
			free(ma->name[i]);
			free(ma->comment[i]);
			ma->seq[i] = ma->gene[i] = ma->name[i] = ma->comment[i] = 0;
		}
	}
	free(flag);
	ma->n = j;
	if (j < n) { /* then second round */
		ma_free_AlignQual(aq);
		aq = ma_cal_qual(ma);
	}
no_collapse_aa:
	if (cut_off <= 0) ma_remove_gap(ma);
	else ma_shrink_alignment(ma, aq, cut_off);
	/* ma_debug_qual(ma, aq); */
	ma_free_AlignQual(aq);
	if (is_mask_segment) ma_mask_poor_segment(ma, 0);
}
void ma_shrink_nucl_alignment(MultiAlign *tma, MultiAlign *ma, AlignQual *aq, int cut_off)
{
	int i, j, k, n, len;

	assert(tma); assert(ma);
	n = ma->n;
	len = ma->len;
	for (j = 0, k = 0; j < len; ++j) {
		if (aq->pos_qual[j] >= cut_off) {
			if (k < j) {
				/* then move column j to k */
				for (i = 0; i < n; ++i) {
					/* move nucleotide alignment */
					tma->seq[i][3*k] = tma->seq[i][3*j];
					tma->seq[i][3*k+1] = tma->seq[i][3*j+1];
					tma->seq[i][3*k+2] = tma->seq[i][3*j+2];
					/* move amino acid alignment */
					ma->seq[i][k] = ma->seq[i][j];
					aq->pos_qual[k] = aq->pos_qual[j];
				}
			}
			++k;
		}
	}
	ma->len = k;
	tma->len = k * 3;
	aq->len = k;
}
void ma_nucl_filter(MultiAlign *tma, int is_collapse, int cut_off, int is_mask_segment)
{
	AlignQual *aq;
	int i, j, n;
	int *flag;
	MultiAlign *ma;

	assert(tma);
	ma = ma_trans_align(tma, 1);
	if (ma == 0) {
		fprintf(stderr, "[ma_nucl_filter] fail to translate a nucleotide alignment. Filtering abort.\n");
		return;
	}
	n = ma->n;
	/* first round: handle alternative splicing. */
	aq = ma_cal_qual(ma);
	if (!is_collapse) goto no_collapse_nt;
	/* choose the best aligned protein among various splicing forms */
	flag = (int*)malloc(sizeof(int) * n);
	for (i = 0; i < n; ++i)
		flag[i] = 1;
	for (i = 0; i < n; ++i) {
		if (ma->gene[i] == 0) continue;
		for (j = i + 1; j < n; ++j) {
			if (ma->gene[j] && strcmp(ma->gene[i], ma->gene[j]) == 0) { /* same gene */
				if (aq->seq_qual[i] < aq->seq_qual[j]) flag[i] = 0; /* discard i */
				else flag[j] = 0; /* discard j */
			}
		}
	}
	/* eliminate discarded proteins */
	for (i = j = 0; i < n; ++i) {
		if (flag[i]) {
			if (j < i) {
				ma->seq[j] = ma->seq[i];   tma->seq[j] = tma->seq[i];
				ma->name[j] = ma->name[i]; tma->name[j] = tma->name[i];
				ma->gene[j] = ma->gene[i]; tma->gene[j] = tma->gene[i];
				ma->comment[j] = ma->comment[i]; tma->comment[j] = tma->comment[i];
			}
			++j;
		} else {
			free(ma->seq[i]);  free(tma->seq[i]);
			free(ma->gene[i]); free(tma->gene[i]);
			free(ma->name[i]); free(tma->name[i]);
			free(ma->comment[i]); free(tma->comment[i]);
			ma->seq[i] = ma->gene[i] = ma->name[i] = ma->comment[i] = 0;
			tma->seq[i] = tma->gene[i] = tma->name[i] = ma->comment[i] = 0;
		}
	}
	free(flag);
	ma->n = tma->n = j;
	if (j < n) { /* then second round */
		ma_free_AlignQual(aq);
		aq = ma_cal_qual(ma);
	}
no_collapse_nt:
	if (cut_off <= 0) ma_remove_gap(ma);
	else ma_shrink_nucl_alignment(tma, ma, aq, cut_off);
	/* ma_debug_qual(ma, aq); */
	ma_free_AlignQual(aq);
	if (is_mask_segment) ma_mask_poor_segment(ma, tma);
	ma_free(ma);
}
