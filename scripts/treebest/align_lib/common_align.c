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

#include <string.h>
#include "seq.h"
#include "align.h"

#define LOCAL_OVERFLOW_THRESHOLD 32000
#define LOCAL_OVERFLOW_REDUCE 16000
#define NT_LOCAL_SCORE int
#define NT_LOCAL_SHIFT 16
#define NT_LOCAL_MASK 0xffff

#define SET_INF(s) (s).M = (s).I = (s).D = MINOR_INF;

#define set_M(MM, cur, p, sc)							\
{														\
	if ((p)->M >= (p)->I) {								\
		if ((p)->M >= (p)->D) {							\
			(MM) = (p)->M + (sc); (cur)->Mt = FROM_M;	\
		} else {										\
			(MM) = (p)->D + (sc); (cur)->Mt = FROM_D;	\
		}												\
	} else {											\
		if ((p)->I > (p)->D) {							\
			(MM) = (p)->I + (sc); (cur)->Mt = FROM_I;	\
		} else {										\
			(MM) = (p)->D + (sc); (cur)->Mt = FROM_D;	\
		}												\
	}													\
}
#define set_I(II, cur, p)								\
{														\
	if ((p)->M - gap_open > (p)->I - gap_ext) {			\
		(cur)->It = FROM_M;								\
		(II) = (p)->M - gap_open;						\
	} else {											\
		(cur)->It = FROM_I;								\
		(II) = (p)->I - gap_ext;						\
	}													\
}
#define set_end_I(II, cur, p)							\
{														\
	if (gap_end >= 0) {									\
		if ((p)->M > (p)->I) {							\
			(cur)->It = FROM_M;							\
			(II) = (p)->M - gap_end;					\
		} else {										\
			(cur)->It = FROM_I;							\
			(II) = (p)->I - gap_end;					\
		}												\
	} else set_I(II, cur, p);							\
}
#define set_D(DD, cur, p)								\
{														\
	if ((p)->M - gap_open > (p)->D - gap_ext) {			\
		(cur)->Dt = FROM_M;								\
		(DD) = (p)->M - gap_open;						\
	} else {											\
		(cur)->Dt = FROM_D;								\
		(DD) = (p)->D - gap_ext;						\
	}													\
}
#define set_end_D(DD, cur, p)							\
{														\
	if (gap_end >= 0) {									\
		if ((p)->M > (p)->D) {							\
			(cur)->Dt = FROM_M;							\
			(DD) = (p)->M - gap_end;					\
		} else {										\
			(cur)->Dt = FROM_D;							\
			(DD) = (p)->D - gap_end;					\
		}												\
	} else set_D(DD, cur, p);							\
}

typedef struct
{
	unsigned char Mt:3, It:2, Dt:2;
} dpcell_t;

typedef struct
{
	int M, I, D;
} dpscore_t;

/* build score profile for accelerating alignment, in theory */
void aln_init_score_array(uchar *seq, int len, int row, int *score_matrix, int **s_array)
{
	int *tmp, *tmp2, i, k;
	for (i = 0; i != row; ++i) {
		tmp = score_matrix + i * row;
		tmp2 = s_array[i];
		for (k = 0; k != len; ++k)
			tmp2[k] = tmp[seq[k]];
	}
}
/* banded global alignment */
int aln_global_core(unsigned char *seq1, int len1, unsigned char *seq2, int len2, AlnParam *ap,
		path_t *path, int *path_len)
{
	register int i, j;
	dpcell_t **dpcell, *q;
	dpscore_t *curr, *last, *s;
	path_t *p;
	int b1, b2, tmp_end;
	int *mat, end, max;
	unsigned char type, ctype;

	int gap_open, gap_ext, gap_end, b;
	int *score_matrix, N_MATRIX_ROW;

	/* initialize some align-related parameters. just for compatibility */
	gap_open = ap->gap_open;
	gap_ext = ap->gap_ext;
	gap_end = ap->gap_end;
	b = ap->band_width;
	score_matrix = ap->matrix;
	N_MATRIX_ROW = ap->row;
	
	if (len1 == 0 || len2 == 0) {
		*path_len = 0;
		return 0;
	}
	/* calculate b1 and b2 */
	if (len1 > len2) {
		b1 = len1 - len2 + b;
		b2 = b;
	} else {
		b1 = b;
		b2 = len2 - len1 + b;
	}
	if (b1 > len1) b1 = len1;
	if (b2 > len2) b2 = len2;
	--seq1; --seq2;

	/* allocate memory */
	end = (b1 + b2 <= len1)? (b1 + b2 + 1) : (len1 + 1);
	dpcell = (dpcell_t**)MYALLOC(sizeof(dpcell_t*) * (len2 + 1));
	for (j = 0; j <= len2; ++j)
		dpcell[j] = (dpcell_t*)MYALLOC(sizeof(dpcell_t) * end);
	for (j = b2 + 1; j <= len2; ++j)
		dpcell[j] -= j - b2;
	curr = (dpscore_t*)MYALLOC(sizeof(dpscore_t) * (len1 + 1));
	last = (dpscore_t*)MYALLOC(sizeof(dpscore_t) * (len1 + 1));
	
	/* set first row */
	SET_INF(*curr); curr->M = 0;
	for (i = 1, s = curr + 1; i < b1; ++i, ++s) {
		SET_INF(*s);
		set_end_D(s->D, dpcell[0] + i, s - 1);
	}
	s = curr; curr = last; last = s;

	/* core dynamic programming, part 1 */
	tmp_end = (b2 < len2)? b2 : len2 - 1;
	for (j = 1; j <= tmp_end; ++j) {
		q = dpcell[j]; s = curr; SET_INF(*s);
		set_end_I(s->I, q, last);
		end = (j + b1 <= len1 + 1)? (j + b1 - 1) : len1;
		mat = score_matrix + seq2[j] * N_MATRIX_ROW;
		++s; ++q;
		for (i = 1; i != end; ++i, ++s, ++q) {
			set_M(s->M, q, last + i - 1, mat[seq1[i]]); /* this will change s->M ! */
			set_I(s->I, q, last + i);
			set_D(s->D, q, s - 1);
		}
		set_M(s->M, q, last + i - 1, mat[seq1[i]]);
		set_D(s->D, q, s - 1);
		if (j + b1 - 1 > len1) { /* bug fixed, 040227 */
			set_end_I(s->I, q, last + i);
		} else s->I = MINOR_INF;
		s = curr; curr = last; last = s;
	}
	/* last row for part 1, use set_end_D() instead of set_D() */
	if (j == len2 && b2 != len2 - 1) {
		q = dpcell[j]; s = curr; SET_INF(*s);
		set_end_I(s->I, q, last);
		end = (j + b1 <= len1 + 1)? (j + b1 - 1) : len1;
		mat = score_matrix + seq2[j] * N_MATRIX_ROW;
		++s; ++q;
		for (i = 1; i != end; ++i, ++s, ++q) {
			set_M(s->M, q, last + i - 1, mat[seq1[i]]); /* this will change s->M ! */
			set_I(s->I, q, last + i);
			set_end_D(s->D, q, s - 1);
		}
		set_M(s->M, q, last + i - 1, mat[seq1[i]]);
		set_end_D(s->D, q, s - 1);
		if (j + b1 - 1 > len1) { /* bug fixed, 040227 */
			set_end_I(s->I, q, last + i);
		} else s->I = MINOR_INF;
		s = curr; curr = last; last = s;
		++j;
	}

	/* core dynamic programming, part 2 */
	for (; j <= len2 - b2 + 1; ++j) {
		SET_INF(curr[j - b2]);
		mat = score_matrix + seq2[j] * N_MATRIX_ROW;
		end = j + b1 - 1;
		for (i = j - b2 + 1, q = dpcell[j] + i, s = curr + i; i != end; ++i, ++s, ++q) {
			set_M(s->M, q, last + i - 1, mat[seq1[i]]);
			set_I(s->I, q, last + i);
			set_D(s->D, q, s - 1);
		}
		set_M(s->M, q, last + i - 1, mat[seq1[i]]);
		set_D(s->D, q, s - 1);
		s->I = MINOR_INF;
		s = curr; curr = last; last = s;
	}

	/* core dynamic programming, part 3 */
	for (; j < len2; ++j) {
		SET_INF(curr[j - b2]);
		mat = score_matrix + seq2[j] * N_MATRIX_ROW;
		for (i = j - b2 + 1, q = dpcell[j] + i, s = curr + i; i < len1; ++i, ++s, ++q) {
			set_M(s->M, q, last + i - 1, mat[seq1[i]]);
			set_I(s->I, q, last + i);
			set_D(s->D, q, s - 1);
		}
		set_M(s->M, q, last + len1 - 1, mat[seq1[i]]);
		set_end_I(s->I, q, last + i);
		set_D(s->D, q, s - 1);
		s = curr; curr = last; last = s;
	}
	/* last row */
	if (j == len2) {
		SET_INF(curr[j - b2]);
		mat = score_matrix + seq2[j] * N_MATRIX_ROW;
		for (i = j - b2 + 1, q = dpcell[j] + i, s = curr + i; i < len1; ++i, ++s, ++q) {
			set_M(s->M, q, last + i - 1, mat[seq1[i]]);
			set_I(s->I, q, last + i);
			set_end_D(s->D, q, s - 1);
		}
		set_M(s->M, q, last + len1 - 1, mat[seq1[i]]);
		set_end_I(s->I, q, last + i);
		set_end_D(s->D, q, s - 1);
		s = curr; curr = last; last = s;
	}

	/* backtrace */
	i = len1; j = len2;
	q = dpcell[j] + i;
	s = last + len1;
	max = s->M; type = q->Mt; ctype = FROM_M;
	if (s->I > max) { max = s->I; type = q->It; ctype = FROM_I; }
	if (s->D > max) { max = s->D; type = q->Dt; ctype = FROM_D; }

	p = path;
	p->ctype = ctype; p->i = i; p->j = j; /* bug fixed 040408 */
	++p;
	do {
		switch (ctype) {
			case FROM_M: --i; --j; break;
			case FROM_I: --j; break;
			case FROM_D: --i; break;
		}
		q = dpcell[j] + i;
		ctype = type;
		switch (type) {
			case FROM_M: type = q->Mt; break;
			case FROM_I: type = q->It; break;
			case FROM_D: type = q->Dt; break;
		}
		p->ctype = ctype; p->i = i; p->j = j;
		++p;
	} while (i || j);
	*path_len = p - path - 1;

	/* free memory */
	for (j = b2 + 1; j <= len2; ++j)
		dpcell[j] += j - b2;
	for (j = 0; j <= len2; ++j)
		MYFREE(dpcell[j]);
	MYFREE(dpcell);
	MYFREE(curr); MYFREE(last);
	
	return max;
}

/* local alignment combined with banded strategy */
int aln_local_core(unsigned char *seq1, int len1, unsigned char *seq2, int len2, AlnParam *ap,
		path_t *path, int *path_len)
{
	register NT_LOCAL_SCORE *s;
	register int i;
	int q, r, qr, tmp_len, qr_shift;
	int **s_array, *score_array;
	int e, f;
	int is_overflow, of_base;
	NT_LOCAL_SCORE *eh, curr_h, last_h, curr_last_h;
	int j, start_i, start_j, end_i, end_j;
	path_t *p;
	int score_f, score_r, score_g;
	int start, end, max_score;

	int gap_open, gap_ext, gap_end, b;
	int *score_matrix, N_MATRIX_ROW;

	/* initialize some align-related parameters. just for compatibility */
	gap_open = ap->gap_open;
	gap_ext = ap->gap_ext;
	gap_end = ap->gap_end;
	b = ap->band_width;
	score_matrix = ap->matrix;
	N_MATRIX_ROW = ap->row;

	if (len1 == 0 || len2 == 0) return -1;

	/* allocate memory */
	eh = (NT_LOCAL_SCORE*)MYALLOC(sizeof(NT_LOCAL_SCORE) * (len1 + 1));
	s_array = (int**)MYALLOC(sizeof(int*) * N_MATRIX_ROW);
	for (i = 0; i != N_MATRIX_ROW; ++i)
		s_array[i] = (int*)MYALLOC(sizeof(int) * len1);
	/* initialization */
	aln_init_score_array(seq1, len1, N_MATRIX_ROW, score_matrix, s_array);
	q = gap_open - gap_ext;
	r = gap_ext;
	qr = q + r;
	qr_shift = (qr+1) << NT_LOCAL_SHIFT;
	tmp_len = len1 + 1;
	start_i = start_j = end_i = end_j = 0;
	for (i = 0, max_score = 0; i != N_MATRIX_ROW * N_MATRIX_ROW; ++i)
		if (max_score < score_matrix[i]) max_score = score_matrix[i];
	/* convert the coordinate */
	--seq1; --seq2;
	for (i = 0; i != N_MATRIX_ROW; ++i) --s_array[i];

	/* forward dynamic programming */
	for (i = 0, s = eh; i != tmp_len; ++i, ++s) *s = 0;
	score_f = 0;
	is_overflow = of_base = 0;
	for (j = 1; j <= len2; ++j) {
		last_h = f = 0;
		score_array = s_array[seq2[j]];
		if (is_overflow) { /* adjust eh[] array if overflow occurs. */
			/* If LOCAL_OVERFLOW_REDUCE is too small, optimal alignment might be missed.
			 * If it is too large, this block will be excuted frequently and therefore
			 * slow down the whole program.
			 * Acually, smaller LOCAL_OVERFLOW_REDUCE might also help to reduce the
			 * number of assignments because it sets some cells to zero when overflow
			 * happens. */
			int tmp, tmp2;
			score_f -= LOCAL_OVERFLOW_REDUCE;
			of_base += LOCAL_OVERFLOW_REDUCE;
			is_overflow = 0;
			for (i = 1, s = eh; i <= tmp_len; ++i, ++s) {
				tmp = *s >> NT_LOCAL_SHIFT; tmp2 = *s & NT_LOCAL_MASK;
				if (tmp2 < LOCAL_OVERFLOW_REDUCE) tmp2 = 0;
				else tmp2 -= LOCAL_OVERFLOW_REDUCE;
				if (tmp < LOCAL_OVERFLOW_REDUCE) tmp = 0;
				else tmp -= LOCAL_OVERFLOW_REDUCE;
				*s = (tmp << NT_LOCAL_SHIFT) | tmp2;
			}
		}
		for (i = 1, s = eh; i != tmp_len; ++i, ++s) {
			/* prepare for calculate current h */
			curr_h = (*s >> NT_LOCAL_SHIFT) + score_array[i];
			if (curr_h < 0) curr_h = 0;
			if (last_h > qr) { /* initialize f */
				f = (f > last_h - q)? f - r : last_h - qr;
				if (curr_h < f) curr_h = f;
			}
			if (*(s+1) >= qr_shift) { /* initialize e */
				curr_last_h = *(s+1) >> NT_LOCAL_SHIFT;
				e = ((*s & NT_LOCAL_MASK) > curr_last_h - q)? (*s & NT_LOCAL_MASK) - r : curr_last_h - qr;
				if (curr_h < e) curr_h = e;
				*s = (last_h << NT_LOCAL_SHIFT) | e;
			} else *s = last_h << NT_LOCAL_SHIFT; /* e = 0 */
			last_h = curr_h;
			if (score_f < curr_h) {
				score_f = curr_h; end_i = i; end_j = j;
				if (score_f > LOCAL_OVERFLOW_THRESHOLD) is_overflow = 1;
			}
		}
		*s = last_h << NT_LOCAL_SHIFT;
	}
	score_f += of_base;

	if (path == 0) goto end_func; /* skip path-filling */

	/* reverse dynamic programming */
	for (i = end_i, s = eh + end_i; i >= 0; --i, --s) *s = 0;
	score_r = score_matrix[seq1[end_i] * N_MATRIX_ROW + seq2[end_j]];
	is_overflow = of_base = 0;
	start_i = end_i; start_j = end_j;
	eh[end_i] = ((NT_LOCAL_SCORE)(qr + score_r)) << NT_LOCAL_SHIFT; /* in order to initialize f and e, 040408 */
	start = end_i - 1;
	end = end_i - 3;
	if (end <= 0) end = 0;

	/* second pass DP can be done in a band, speed will thus be enhanced */
	for (j = end_j - 1; j != 0; --j) {
		last_h = f = 0;
		score_array = s_array[seq2[j]];
		if (is_overflow) { /* adjust eh[] array if overflow occurs. */
			int tmp, tmp2;
			score_r -= LOCAL_OVERFLOW_REDUCE;
			of_base += LOCAL_OVERFLOW_REDUCE;
			is_overflow = 0;
			for (i = start, s = eh + start + 1; i >= end; --i, --s) {
				tmp = *s >> NT_LOCAL_SHIFT; tmp2 = *s & NT_LOCAL_MASK;
				if (tmp2 < LOCAL_OVERFLOW_REDUCE) tmp2 = 0;
				else tmp2 -= LOCAL_OVERFLOW_REDUCE;
				if (tmp < LOCAL_OVERFLOW_REDUCE) tmp = 0;
				else tmp -= LOCAL_OVERFLOW_REDUCE;
				*s = (tmp << NT_LOCAL_SHIFT) | tmp2;
			}
		}
		for (i = start, s = eh + start + 1; i != end; --i, --s) {
			/* prepare for calculate current h */
			curr_h = (*s >> NT_LOCAL_SHIFT) + score_array[i];
			if (curr_h < 0) curr_h = 0;
			if (last_h > qr) { /* initialize f */
				f = (f > last_h - q)? f - r : last_h - qr;
				if (curr_h < f) curr_h = f;
			}
			if (*(s-1) >= qr_shift) { /* initialize e */
				curr_last_h = *(s-1) >> NT_LOCAL_SHIFT;
				e = ((*s & NT_LOCAL_MASK) > curr_last_h - q)? (*s & NT_LOCAL_MASK) - r : curr_last_h - qr;
				if (curr_h < e) curr_h = e;
				*s = (last_h << NT_LOCAL_SHIFT) | e;
			} else *s = last_h << NT_LOCAL_SHIFT; /* e = 0 */
			last_h = curr_h;
			if (score_r < curr_h) {
				score_r = curr_h; start_i = i; start_j = j;
				if (score_r + of_base - qr == score_f) {
					j = 1; break;
				}
				if (score_r > LOCAL_OVERFLOW_THRESHOLD) is_overflow = 1;
			}
		}
		*s = last_h << NT_LOCAL_SHIFT;
		/* recalculate start and end, the boundaries of the band */
		if ((eh[start] >> NT_LOCAL_SHIFT) <= qr) --start;
		if (start <= 0) start = 0;
		end = start_i - (start_j - j) - (score_r + of_base + (start_j - j) * max_score) / r - 1;
		if (end <= 0) end = 0;
	}

	if (path_len == 0) {
		path[0].i = start_i; path[0].j = start_j;
		path[1].i = end_i; path[1].j = end_j;
		goto end_func;
	}

	score_r += of_base;
	score_r -= qr;

#ifdef DEBUG
	/* this seems not a bug */
	if (score_f != score_r)
		fprintf(stderr, "[aln_local_core] unknown flaw occurs: score_f(%d) != score_r(%d)\n", score_f, score_r);
#endif

	/* call global alignment to fill the path */
	r = gap_end; /* backup gap_end, for we do not need this */
	gap_end = -1;
	score_g = 0;
	j = ap->band_width;
	for (i = j; i < 1000; i <<= 1) {
		ap->band_width = i;
		score_g = aln_global_core(seq1 + start_i, end_i - start_i + 1, seq2 + start_j,
				end_j - start_j + 1, ap, path, path_len);
		if (score_g == score_r || score_f == score_g) break;
	}
	if (score_r > score_g && score_f > score_g)
		fprintf(stderr, "[aln_local_core] can find reasonable band width.\n");
	score_f = score_g;
	gap_end = r;
	ap->band_width = j;

	/* convert coordinate */
	for (p = path + *path_len - 1; p >= path; --p) {
		p->i += start_i - 1;
		p->j += start_j - 1;
	}

end_func:
	/* free */
	MYFREE(eh);
	for (i = 0; i != N_MATRIX_ROW; ++i) {
		++s_array[i];
		MYFREE(s_array[i]);
	}
	MYFREE(s_array);
	return score_f;
}
AlnAln *aln_common_align(char *seq1, char *seq2, AlnParam *ap, int full)
{
	uchar *seq11, *seq22;
	int len1, len2;
	int score;
	int i, j, l;
	path_t *p;
	char *out1, *out2, *outm;
	AlnAln *aa;

	len1 = strlen(seq1);
	len2 = strlen(seq2);

	aa = aln_init_AlnAln();
	seq11 = (uchar*)MYALLOC(sizeof(uchar) * len1);
	seq22 = (uchar*)MYALLOC(sizeof(uchar) * len2);
	aa->path = (path_t*)MYALLOC(sizeof(path_t) * (len1 + len2 + 1));

	if (ap->row < 10) { /* 4-nucleotide alignment */
		for (i = 0; i < len1; ++i)
			seq11[i] = aln_nt4_table[(int)seq1[i]];
		for (j = 0; j < len2; ++j)
			seq22[j] = aln_nt4_table[(int)seq2[j]];
	} else if (ap->row < 20) { /* 16-nucleotide alignment */
		for (i = 0; i < len1; ++i)
			seq11[i] = aln_nt16_table[(int)seq1[i]];
		for (j = 0; j < len2; ++j)
			seq22[j] = aln_nt16_table[(int)seq2[j]];
	} else { /* amino acids */
		for (i = 0; i < len1; ++i)
			seq11[i] = aln_aa_table[(int)seq1[i]];
		for (j = 0; j < len2; ++j)
			seq22[j] = aln_aa_table[(int)seq2[j]];
	}
	
	if (full) score = aln_global_core(seq11, len1, seq22, len2, ap, aa->path, &aa->path_len);
	else score = aln_local_core(seq11, len1, seq22, len2, ap, aa->path, &aa->path_len);
	aa->score = score;

	out1 = aa->out1 = (char*)MYALLOC(sizeof(char) * (aa->path_len + 1));
	out2 = aa->out2 = (char*)MYALLOC(sizeof(char) * (aa->path_len + 1));
	outm = aa->outm = (char*)MYALLOC(sizeof(char) * (aa->path_len + 1));

	--seq1; --seq2;
	--seq11; --seq22;

	p = aa->path + aa->path_len - 1;

	for (l = 0; p >= aa->path; --p, ++l) {
		switch (p->ctype) {
			case FROM_M: out1[l] = seq1[p->i]; out2[l] = seq2[p->j];
						 outm[l] = (seq11[p->i] == seq22[p->j] && seq11[p->i] != ap->row)? '|' : ' ';
						 break;
			case FROM_I: out1[l] = '-'; out2[l] = seq2[p->j]; outm[l] = ' '; break;
			case FROM_D: out1[l] = seq1[p->i]; out2[l] = '-'; outm[l] = ' '; break;
		}
	}
	out1[l] = out2[l] = outm[l] = '\0';
	++seq11; ++seq22;

	MYFREE(seq11);
	MYFREE(seq22);
	return aa;
}
