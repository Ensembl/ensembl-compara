#ifndef PHYLOTREE_ALIGN_H_
#define PHYLOTREE_ALIGN_H_

#include <stdio.h>
#include <assert.h>
#include "tree.h"

#define QUAL_SCALE 4.0
#define QUAL_MIN_RES 0.3333333

#define DIST_MM 1
#define DIST_KIMURA 2
#define DIST_JTT 3
#define DIST_DN 4
#define DIST_DS 5
#define DIST_DM 6
#define DIST_NT_MM 7

#define MA_MIN_DIST 0.00001
#define MA_MAX_DIST 9.0

typedef struct __lih_MultiAlign
{
	int max, n; /* maximum number/number of sequences */
	int len; /* length of the alignment */
	int is_nucl; /* if true, treat as nucleotide alignment */
	char **name; /* names of the sequences */
	char **seq; /* character-converted sequences */
	char **gene; /* gene names, if presented in MFA file */
	char **comment; /* comment for the gene */
	struct __lih_MultiAlign *ori_nucl;
} MultiAlign;

typedef struct
{
	int n; /* number of sequences */
	int len; /* length of the alignment */
	int *pos_qual; /* quality values on each position */
	double *seq_qual; /* quality values for each sequences */
} AlignQual;

typedef struct
{
	int type; /* type of distance */
	int is_kimura; /* whether use kimura correction */
	double *mat; /* now only JTT model */
	double *eigen; /* eigen values, only used for JTT */
	double scale; /* for JTT */
} DistParam;

#ifdef __cplusplus
extern "C" {
#endif

/* alloc and free */
DistParam *ma_alloc_DistParam(int type);
void ma_free_DistParam(DistParam *dp);

/* fill `mat' from alignment `ma' with `dp' parameters. When `is_rand' is true, the
 * alignment will be resampled. It is just a wrapper. Other functions will be called. */
void ma_cal_dist(Matrix *mat, const MultiAlign *ma, int is_rand, const DistParam *dp);
/* probability distance */
void ma_cal_prob_dist(Matrix *mat, const MultiAlign *ma, int is_rand, const DistParam *dp);
/* mismatch distance */
void ma_cal_mm_dist(Matrix *mat, const MultiAlign *ma, int is_rand, int is_kimura, int *);

/* alloc and free */
MultiAlign *ma_alloc();
void ma_free(MultiAlign *ma);
/* read alignment */
MultiAlign *ma_read(FILE *fp, int is_nucl, int is_aln);
MultiAlign *ma_read_alignment(FILE *fp, int is_nucl);
MultiAlign *ma_read_aln_alignment(FILE *fp, int is_nucl);

/* alloc and free */
AlignQual *ma_alloc_AlignQual(const MultiAlign *ma);
void ma_free_AlignQual(AlignQual *aq);
/* calculate alignment quality */
AlignQual *ma_cal_qual(const MultiAlign *ma);
/* filter a multialignment */
void ma_filter(MultiAlign *ma, int is_collpase, int cut_off, int is_mask_segment);

void ma_mask_poor_segment(MultiAlign *ma, MultiAlign *ma_nt);

void ma_apply_mask(MultiAlign *ma);

void tr_align_output(FILE *fp, const MultiAlign *ma);
/* output in ALN format */
void tr_align_aln_output(FILE *fp, const MultiAlign *ma);
/* translate nucleotide alignment to protein alignment */
MultiAlign *ma_trans_align(const MultiAlign *ma, int is_trans);

MultiAlign *ma_back_trans(MultiAlign *aa, FILE *fp, float threshold);

void ma_remove_gap(MultiAlign *ma);

void tr_attach_geneid(Tree *tree, MultiAlign *ma);

Matrix *ma_init_small_matrix(MultiAlign *ma);

#ifdef __cplusplus
}
#endif
#endif
