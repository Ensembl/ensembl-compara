#include <stdlib.h>
#include "align_lib/table.h"
#include "align.h"
#include "tree.h"
#include "utils.h"

#define MIN_POOR_LENGTH 10

Tree *tr_build_tree_from_align(MultiAlign *ma, int n_cons, Tree **cons, int init_cons, Tree *spec,
		int dist_type, int is_sdi_root, int is_rand);

static float *cal_weight(MultiAlign *ma)
{
	int i, n;
	float *fweight, f, sum;
	Tree *p, *root, **node;

	n = ma->n;
	fweight = (float*)malloc(sizeof(float) * n);
	root = tr_build_tree_from_align(ma, 0, 0, 0, 0, DIST_MM, 0, 0); /* build NJ tree */
	node = tr_stack(root, Tree*);
	tr_expand_leaf_by_id(root, node);
	/* calculate 'order'. Tree::flag should be '0' */
	for (i = 0; i < n; ++i) {
		p = node[i];
		while (p) {
			++(p->flag);
			p = p->pre;
		}
	}
	/* calculate weight */
	for (i = 0, sum = 0.0; i < n; ++i) {
		p = node[i];
		f = 0.0;
		while (p->pre) {
			f += p->d / p->flag;
			p = p->pre;
		}
		fweight[i] = f;
		sum += f;
	}
	/* re-scale */
	for (i = 0; i < n; ++i)
		fweight[i] /= sum;
	free(node);
	tr_delete_tree(root);
	return fweight;
}
static int *cal_profile_score_array(MultiAlign *ma, int k, float *weight)
{
	int i, j, n, sum;
	int *S, *new_w, *bl_array;

	n = ma->n;
	new_w = (int*)malloc(sizeof(int) * n);
	S = (int*)malloc(sizeof(int) * (ma->len + 1));
	/* calculate weight excluding sequence k */
	for (i = 0; i < n; ++i)
	   	new_w[i] = (int)(weight[i] / (1.0 - weight[k]) * 1000.0 + 0.5);
	for (j = 0; j < ma->len; ++j) {
		if (ma->seq[k][j] == ALN_AA_GAP) {
			S[j] = 0;
			continue;
		}
		bl_array = aln_sm_blosum62 + (int)ma->seq[k][j] * ALN_AA_GAP;
		sum = 0;
		for (i = 0; i < n; ++i) {
			if (i == k) continue;
			if (ma->seq[i][j] != ALN_AA_GAP)
				sum += bl_array[(int)ma->seq[i][j]] * new_w[i] + new_w[i];
		}
		S[j] = sum;
	}
	free(new_w);
	return S;
}
static void mask_one_seq(MultiAlign *ma, MultiAlign *ma_nt, int k, float *weight)
{
	int *S, *F, *B, *start;
	int n, i, j, len;
	char *seq, *seq_nt;

	n = ma->n;
	len = ma->len;
	if (ma_nt && (ma_nt->len != len * 3 || ma_nt->n != n)) {
		fprintf(stderr, "[mask_one_seq] 'ma_nt' is inconsistent with 'ma'. 'ma_nt' is skipped.\n");
		ma_nt = 0;
	}
	F = (int*)malloc(sizeof(int) * (len + 2));
	B = (int*)malloc(sizeof(int) * (len + 2));
	/* calculate F and B */
	S = cal_profile_score_array(ma, k, weight);
	--S;
	F[0] = 0;
	for (j = 1; j <= len; ++j)
		F[j] = (F[j-1] + S[j] < 0)? F[j-1] + S[j] : 0;
	B[len+1] = 0;
	for (j = len; j >= 1; --j)
		B[j] = (B[j+1] + S[j] < 0)? B[j+1] + S[j] : 0;
	++S;
	free(S);
	/* do mask */
	seq = ma->seq[k];
	seq_nt = ma_nt ? ma_nt->seq[k] : 0;
	start = (int*)malloc(sizeof(int) * (len + 2));
	start[0] = 0;
	for (j = 1; j <= len; ++j) {
		if (F[j] < 0 && B[j] < 0) {
			start[j] = (start[j-1] == 0)? j : start[j - 1];
		} else {
			start[j] = j;
			if (start[j-1] > 0 && j - start[j - 1] >= MIN_POOR_LENGTH) { /* do mask in this region */
				int n_poor = 0;
				for (i = start[j-1]; i < j; ++i)
					if (seq[i-1] != ALN_AA_GAP) ++n_poor;
				if (n_poor < MIN_POOR_LENGTH) continue;
				for (i = start[j-1]; i < j; ++i) {
					if (seq[i-1] != ALN_AA_GAP) {
						seq[i-1] = 21; /* X */
						if (seq_nt) seq_nt[i*3-3] = seq_nt[i*3-2] = seq_nt[i*3-1] = 4;
					}
				}
			}
		}
	}
	free(start); free(F); free(B);
}
void ma_mask_poor_segment(MultiAlign *ma, MultiAlign *ma_nt)
{
	int k;
	float *weight;
	assert(ma);
	if (ma->n < 3) return; /* do nothing */
	weight = cal_weight(ma);
	for (k = 0; k < ma->n; ++k)
		mask_one_seq(ma, ma_nt, k, weight);
	free(weight);
}
