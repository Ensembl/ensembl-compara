/*
 * libalign -- alignment utilities
 *
 * Copyright (c) 2003-2004, Li Heng <liheng@genomics.org.cn>
 *                                  <lihengsci@yahoo.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#ifndef ALN_LIB_ALIGN_H_
#define ALN_LIB_ALIGN_H_

#include "common/common.h"
#include "table.h"

#define FROM_M 0
#define FROM_I 1
#define FROM_D 2
#define FROM_N 3
#define FROM_O 3
#define FROM_T 4
#define FROM_G 5
#define FROM_0 7

#define ALN_LOCAL_ALIGN 0
#define ALN_GLOBAL_ALIGN 1
#define ALN_BOUND_ALIGN 2

#define FLAW_INS 0x0100
#define FLAW_DEL 0x0200
#define FLAW_FRAME_SHIFT	0x0400
#define FLAW_NO_HEAD	0x0800
#define FLAW_NO_TAIL	0x1000

#define MINOR_INF -1073741823

typedef struct
{
	int gap_open;
	int gap_ext;
	int gap_end;

	int frame_shift;

	int good_splice;
	int bad_splice;

	int matrix_mean;
	int *matrix;
	int row;
	int band_width;
} AlnParam;

typedef struct
{
	int i, j;
	unsigned char ctype;
} path_t;

typedef struct
{
	path_t *path;
	int path_len;
} AlnSubPath;

typedef struct
{
	path_t *path;
	int path_len;
	int score;

	char *out1, *out2;
	char *outm;

	int n_sub_path;
	AlnSubPath *asp;
} AlnAln;

typedef int (*AlnCoreFunc)(unsigned char *, int, unsigned char *, int, AlnParam *, path_t *, int *);

#ifdef __cplusplus
extern "C" {
#endif

AlnAln *aln_align(char *seq1, char *seq2, AlnParam *ap, int type);
void aln_init_score_array(uchar *seq, int len, int row, int *score_matrix, int **s_array);
void aln_apply_matrix_mean(AlnParam *ap);

AlnAln *aln_init_AlnAln();
void aln_free_AlnAln(AlnAln *aa);

/* canonical local and global alignment with speed enhancement */
AlnAln *aln_common_align(char *seq1, char *seq2, AlnParam *ap, int type);
/* banded global alignment */
int aln_global_core(unsigned char *seq1, int len1, unsigned char *seq2, int len2, AlnParam *ap,
		path_t *path, int *path_len);
/* smith-waterman alignment */
int aln_local_core(unsigned char *seq1, int len1, unsigned char *seq2, int len2, AlnParam *ap,
		path_t *path, int *path_len);

/* align amino acid sequence against nucleotide sequence with frame-shift */
AlnAln *aln_nt2aa(char *seq_nt, char *seq_aa, AlnParam *ap, int type);
void aln_output_segment(char *ont, char *oprot, path_t *path, int path_len, char *locus1, char *locus2);
char *aln_back_trans(char *aln_aa, char *seq_nt_pre, int *flaw_code);
int aln_aa2nt_global_core(unsigned char *prot, int prot_len, unsigned char *nt_trans, int nt_len,
		AlnParam *ap, path_t *path, int *path_len);
int aln_aa2nt_local_core(unsigned char *prot, int prot_len, unsigned char *nt_trans, int nt_len,
		AlnParam *ap, path_t *path, int *path_len);

/* align cDNA to genomic sequences  */
AlnAln *aln_splice(char *gen, char *est, AlnParam *ap, int type);
int aln_splice_global_core(unsigned char *est, int est_len, unsigned char *gen, int gen_len, AlnParam *ap,
		path_t *path, int *path_len);
int aln_splice_local_core(unsigned char *est, int est_len, unsigned char *gen, int gen_len, AlnParam *ap,
		path_t *path, int *path_len);
int aln_splice_bound_core(unsigned char *est, int est_len, unsigned char *gen, int gen_len, AlnParam *ap,
		int *gen_start, int *gen_stop, int *est_start, int *est_stop);
AlnSubPath *aln_splice_sub_path(path_t *path, int path_len, int *count);

uchar *aln_reverse4(uchar *seq, int len);

int pwalign_task(int argc, char *argv[]);

extern AlnParam aln_param_nt2nt, aln_param_aa2aa, aln_param_aa2nt, aln_param_splice, aln_param_splice2;
extern AlnParam aln_param_rd2rd, aln_param_rd_splice;

#ifdef __cplusplus
}
#endif

#endif /* ALIGN_H_ */
