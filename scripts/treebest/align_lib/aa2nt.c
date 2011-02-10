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

#include <stdio.h>
#include <string.h>
#include "seq.h"
#include "table.h"
#include "align.h"

/****************************************************************************************
 * M(i,j) = max { M(i-3,j-1), I(i-3,j-1), D(i-3,j-1), O(i-3,j-1), T(i-3,j-1) } + S(i,j) *
 * I(i,j) = max { M(i,j-1)-d, I(i,j-1)-e, O(i,j-1), T(i,j-1) }                          *
 * D(i,j) = max { M(i-3,j), D(i-3,j)+(d-e), O(i-3,j), T(i-3,j) } - d                    *
 * O(i,j) = max { M(i-1,j), D(i-1,j), I(i-1,j) } - f                                    *
 * T(i,j) = max { M(i-2,j), D(i-2,j), I(i-2,j) } - f                                    *
 ****************************************************************************************/

/* Do not use BANDED_ALIGN. It still has bug now. */

#define SET_INF(s) (s).M = (s).I = (s).D = (s).O = (s).T = MINOR_INF

typedef struct
{
	unsigned short Mt:3, It:3, Dt:3, Ot:3, Tt:3;
} dpcell_t;

typedef struct
{
	int M, I, D, O, T;
} dpscore_t;

#define set_M(MM, cur, p, sc) \
{ \
	int max; \
	if ((p)->M > (p)->I) { \
		max = (p)->M; (cur)->Mt = FROM_M; \
	} else { \
		max = (p)->I; (cur)->Mt = FROM_I; \
	} \
	if ((p)->D > max) { max = (p)->D; (cur)->Mt = FROM_D; } \
	if ((p)->O > max) { max = (p)->O; (cur)->Mt = FROM_O; } \
	if ((p)->T > max) { max = (p)->T; (cur)->Mt = FROM_T; } \
	(MM) = max + sc; \
}
#define set_I(II, cur, p) \
{ \
	int max; \
	if ((p)->M - gap_open > (p)->I - gap_ext) { \
		max = (p)->M - gap_open; (cur)->It = FROM_M; \
	} else { \
		max = (p)->I - gap_ext; (cur)->It = FROM_I; \
	} \
	if ((p)->O > max) { max = (p)->O; (cur)->It = FROM_O; } \
	if ((p)->T > max) { max = (p)->T; (cur)->It = FROM_T; } \
	(II) = max; \
}
#define set_D(DD, cur, p) \
{ \
	int max; \
	if ((p)->M > (p)->D + gap_oe) { \
		max = (p)->M; (cur)->Dt = FROM_M; \
	} else { \
		max = (p)->D + gap_oe; (cur)->Dt = FROM_D; \
	} \
	if ((p)->O > max) { max = (p)->O; (cur)->Dt = FROM_O; } \
	if ((p)->T > max) { max = (p)->T; (cur)->Dt = FROM_T; } \
	(DD) = max - gap_open; \
}
#define set_O(OO, cur, p) \
{ \
	int max; \
	if ((p)->M > (p)->I) { \
		max = (p)->M; (cur)->Ot = FROM_M; \
	} else { \
		max = (p)->I; (cur)->Ot = FROM_I; \
	} \
	if ((p)->D > max) { max = (p)->D; (cur)->Ot = FROM_D; } \
	(OO) = max - frame_shift; \
}
#define set_T(TT, cur, p) \
{ \
	int max; \
	if ((p)->M > (p)->I) { \
		max = (p)->M; (cur)->Tt = FROM_M; \
	} else { \
		max = (p)->I; (cur)->Tt = FROM_I; \
	} \
	if ((p)->D > max) { max = (p)->D; (cur)->Tt = FROM_D; } \
	(TT) = max - frame_shift; \
}
static int back_trace(dpcell_t **cell, dpscore_t *last, int prot_len, int nt_len,
		path_t *path, int *path_len)
{
	uchar type, ctype;
	int i, j, max;
	dpcell_t *q;
	path_t *p;

	i = nt_len; j = prot_len;
	q = cell[j] + i;
	max = last->M; ctype = FROM_M; type = q->Mt;
	if (last->I > max) { max = last->I; ctype = FROM_I; type = q->It; }
	if (last->D > max) { max = last->D; ctype = FROM_D; type = q->Dt; }
	if (last->O > max) { max = last->O; ctype = FROM_O; type = q->Ot; }
	if (last->T > max) { max = last->T; ctype = FROM_T; type = q->Tt; }

	p = path;
	p->ctype = ctype; p->i = i; p->j = j;
	++p;
	do {
		switch (ctype) {
			case FROM_M: --j; i -= 3; break;
			case FROM_I: --j; break;
			case FROM_D: i -= 3; break;
			case FROM_O: --i; break;
			case FROM_T: i -= 2; break;
		}
		q = cell[j] + i;
		ctype = type;
		switch (type) {
			case FROM_M: type = q->Mt; break;
			case FROM_I: type = q->It; break;
			case FROM_D: type = q->Dt; break;
			case FROM_O: type = q->Ot; break;
			case FROM_T: type = q->Tt; break;
		}
		p->ctype = ctype; p->i = i; p->j = j;
		++p;
	} while (i || j);
	*path_len = p - path - 1;
	return max;
}
/* 
static int back_trace_M(dpcell_t **cell, int i, int j, uchar *prot, uchar *nt_trans, AlnParam *ap,
		path_t *path, int *path_len)
{
	uchar type, ctype;
	int max_M, score;
	dpcell_t *q;
	path_t *p, *mp;

	ctype = FROM_M;
	p = mp = path;
	max_M = MINOR_INF;
	score = 0;
	q = cell[j] + i;
	type = q->Mt;
	do {
		switch (ctype) {
			case FROM_M: score += ap->matrix[prot[j] * ap->row + nt_trans[i]];
						 break;
			case FROM_I: if (type != FROM_I) score -= ap->gap_open;
						 else score -= ap->gap_ext;
						 break;
			case FROM_D: if (type != FROM_D) score -= ap->gap_open;
						 else score -= ap->gap_ext;
						 break;
			case FROM_O:
			case FROM_T: score -= ap->frame_shift; break;
		}
		if (score > max_M) { max_M = score; mp = p; }
		p->ctype = ctype; p->i = i; p->j = j;
		++p;
		switch (ctype) {
			case FROM_M: --j; i -= 3; break;
			case FROM_I: --j; break;
			case FROM_D: i -= 3; break;
			case FROM_O: --i; break;
			case FROM_T: i -= 2; break;
		}
		q = cell[j] + i;
		ctype = type;
		switch (type) {
			case FROM_M: type = q->Mt; break;
			case FROM_I: type = q->It; break;
			case FROM_D: type = q->Dt; break;
			case FROM_O: type = q->Ot; break;
			case FROM_T: type = q->Tt; break;
		}
	} while (i || j);
	*path_len = mp - path + 1;
	return score;
}*/
int aln_aa2nt_global_core(uchar *prot, int prot_len, uchar *nt_trans, int nt_len, AlnParam *ap,
		path_t *path, int *path_len)
{
	register dpscore_t *s;
	dpscore_t *array[2], *curr, *last;
	dpcell_t **cell, *q;
	int *line, i, j, score;
	int max_M, mi, mj;

#ifdef BANDED_ALIGN
	int bn, bp, end;
#endif

	int gap_open, gap_ext, gap_end, gap_oe, band_width;
	int *sc_matrix, N_ROW, frame_shift;

	/* initialize some align-related parameters. just for compatibility */
	gap_open = ap->gap_open;
	gap_ext = ap->gap_ext;
	gap_end = ap->gap_end;
	frame_shift = ap->frame_shift;
	gap_oe = gap_open - gap_ext;
	band_width = ap->band_width;
	sc_matrix = ap->matrix;
	N_ROW = ap->row;

#ifdef BANDED_ALIGN
	/* calculate bn and bp */
	end = nt_len / 3;
	if (end > prot_len) {
		bn = end - prot_len + band_width;
		bp = band_width;
	} else {
		bn = band_width;
		bp = prot_len - end + band_width;
	}
	if (bn > end) bn = end;
	if (bp > prot_len) bp = prot_len;
	bn = bn * 3 + nt_len % 3;
#endif

	/* memory allocation. note that no memory optimization for banded alignment here */
	array[0] = (dpscore_t*)MYALLOC(sizeof(dpscore_t) * (nt_len + 1));
	array[1] = (dpscore_t*)MYALLOC(sizeof(dpscore_t) * (nt_len + 1));
	cell = (dpcell_t**)MYALLOC(sizeof(dpcell_t*) * (prot_len + 1));
	for (j = 0; j <= prot_len; ++j)
		cell[j] = (dpcell_t*)MYALLOC(sizeof(dpcell_t) * (nt_len + 1));

	--prot; --nt_trans;
	curr = array[0]; last = array[1];
	
	/* first row */
	q = cell[0]; SET_INF(curr[0]); curr->M = 0;
	++q; SET_INF(curr[1]); set_O(curr[1].O, q, curr);
	++q; SET_INF(curr[2]); set_T(curr[1].T, q, curr);
#ifdef BANDED_ALIGN
	for (i = 3, q = cell[0] + 3, s = curr + 3;  i < bn; ++i, ++q, ++s) {
#else
	for (i = 3, q = cell[0] + 3, s = curr + 3;  i <= nt_len; ++i, ++q, ++s) {
#endif
		SET_INF(*s);
		set_D(s->D, q, s - 3);
		set_O(s->O, q, s - 1);
		set_T(s->T, q, s - 2);
	}
	s = last; last = curr; curr = s;

	max_M = MINOR_INF; mi = mj = 0;
#ifdef BANDED_ALIGN
	/* core dynamic programming, part 1 */
	for (j = 1; j <= bp; ++j) {
		q = cell[j]; s = curr;
		SET_INF(*s); set_I(s->I, q, last);
		++q; ++s; SET_INF(*s); set_O(s->O, q, curr);
		++q; ++s; SET_INF(*s); set_T(s->T, q, curr);
		end = (j * 3 + bn <= nt_len + 1) ? (j * 3 + bn - 1) : nt_len;
		line = sc_matrix + prot[j] * N_ROW;
		++q; ++s;
		for (i = 3; i <= end - 3; ++i, ++q, ++s) {
			set_M(s->M, q, last + i - 3, line[nt_trans[i]]);
			set_I(s->I, q, last + i);
			set_D(s->D, q, s - 3);
			set_O(s->O, q, s - 1);
			set_T(s->T, q, s - 2);
			if (s->M > max_M) { max_M = s->M; mi = i; mj = j; }
		}
		for (; i <= end; ++i, ++q, ++s) {
			set_M(s->M, q, last + i - 3, line[nt_trans[i]]);
			if (j * 3 + bn - 3 <= nt_len) s->I = MINOR_INF;
			else set_I(s->I, q, last + i);
			set_D(s->D, q, s - 3);
			set_O(s->O, q, s - 1);
			set_T(s->T, q, s - 2);
			if (s->M > max_M) { max_M = s->M; mi = i; mj = j; }
		}
		s = last; last = curr; curr = s;
	}
	/* core dynamic programming, part 2 */
	for (; j <= prot_len - bp + 1; ++j) {
		s = curr + (j - bp) * 3;
		SET_INF(*s);
		--s; SET_INF(*s);
		--s; SET_INF(*s);
		line = sc_matrix + prot[j] * N_ROW;
		end = j * 3 + bn - 3;
		i = (j - bp) * 3 + 3;
		q = cell[j] + i; s = curr + i;
		for (; i <= end - 3; ++i, ++s, ++q) {
			set_M(s->M, q, last + i - 3, line[nt_trans[i]]);
			set_I(s->I, q, last + i);
			set_D(s->D, q, s - 3);
			set_O(s->O, q, s - 1);
			set_T(s->T, q, s - 2);
			if (s->M > max_M) { max_M = s->M; mi = i; mj = j; }
		}
		for (; i <= end; ++i, ++q, ++s) {
			set_M(s->M, q, last + i - 3, line[nt_trans[i]]);
			s->I = MINOR_INF;
			set_D(s->D, q, s - 3);
			set_O(s->O, q, s - 1);
			set_T(s->T, q, s - 2);
			if (s->M > max_M) { max_M = s->M; mi = i; mj = j; }
		}
		s = last; last = curr; curr = s;
	}
	/* core dynamic programming, part 3 */
	for (; j <= prot_len; ++j) {
		s = curr + (j - bp) * 3;
		SET_INF(*s);
		--s; SET_INF(*s);
		--s; SET_INF(*s);
		line = sc_matrix + prot[j] * N_ROW;
		i = (j - bp) * 3 + 3;
		q = cell[j] + i; s = curr + i;
		for (; i <= nt_len; ++i, ++s, ++q) {
			set_M(s->M, q, last + i - 3, line[nt_trans[i]]);
			set_I(s->I, q, last + i);
			set_D(s->D, q, s - 3);
			set_O(s->O, q, s - 1);
			set_T(s->T, q, s - 2);
			if (s->M > max_M) { max_M = s->M; mi = i; mj = j; }
		}
		s = last; last = curr; curr = s;
	}
#else /* BANDED_ALIGN */
	for (j = 1; j <= prot_len; ++j) {
		q = cell[j];
		SET_INF(curr[0]); set_I(curr[0].I, q, last);
		++q; SET_INF(curr[1]); set_O(curr[1].O, q, curr);
		++q; SET_INF(curr[2]); set_T(curr[2].T, q, curr);
		line = sc_matrix + prot[j] * N_ROW;
		++q;
		for (i = 3, s = curr + 3; i <= nt_len; ++i, ++q, ++s) {
			set_M(s->M, q, last + i - 3, line[nt_trans[i]]);
			set_I(s->I, q, last + i);
			set_D(s->D, q, s - 3);
			set_O(s->O, q, s - 1);
			set_T(s->T, q, s - 2);
			if (s->M > max_M) { max_M = s->M; mi = i; mj = j; }
		}
		s = last; last = curr; curr = s;
	}
#endif /* BANDED_ALIGN */

	score = back_trace(cell, last + nt_len, prot_len, nt_len, path, path_len);
	/* score = back_trace_M(cell, mi, mj, prot, nt_trans, ap, path, path_len); */
	
	/* free */
	MYFREE(array[0]); MYFREE(array[1]);
	for (j = 0; j <= prot_len; ++j)
		MYFREE(cell[j]);
	MYFREE(cell);
	return score;
}
