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

/**********************************************************************
 * I(i,j) = max { G(i,j-1)-d, I(i,j-1)-e, O(i,j-1), T(i,j-1) }        *
 * D(i,j) = max { G(i-3,j)-d, D(i-3,j)-e }                            *
 * O(i,j) = G(i-1,j) - f                                              *
 * T(i,j) = G(i-2,j) - f                                              *
 * G(i,j) = max { G(i-3,j-1)+S(i,j), I(i,j), D(i,j), O(i,j), T(i,j) } *
 *                                                                    *
 * G(i,j) = max { M(i,j), I(i,j), D(i,j), O(i,j), T(i,j) }            *
 * M(i,j) = G(i-3,j-1) + S(i,j)                                       *
 **********************************************************************/

#define SET_ZERO(s) ((s).G = (s).I = (s).D = (s).O = (s).T = 0)

#define NA_FROM_G 0
#define NA_FROM_D 1
#define NA_FROM_I 2
#define NA_FROM_O 3
#define NA_FROM_T 4
#define NA_FROM_M 5
#define NA_FROM_0 7

static uchar from_table[8] = { FROM_G, FROM_D, FROM_I, FROM_O, FROM_T, FROM_M, 0, FROM_0 };

typedef struct
{
	unsigned char Gt:3, It:3, Dt:2;
} dpcell_t;

typedef struct
{
	int G, I, D, O, T;
} dpscore_t;

#define set_G(GG, cur, p0, p, sc) \
{ \
	int max; \
	if ((p0)->G + (sc) > 0) { \
		max = (p0)->G + (sc); (cur)->Gt = NA_FROM_M; \
	} else { \
		max = 0; (cur)->Gt = NA_FROM_0; \
	} \
	if ((p)->I > max) { max = (p)->I; (cur)->Gt = NA_FROM_I; } \
	if ((p)->D > max) { max = (p)->D; (cur)->Gt = NA_FROM_D; } \
	if ((p)->O > max) { max = (p)->O; (cur)->Gt = NA_FROM_O; } \
	if ((p)->T > max) { max = (p)->T; (cur)->Gt = NA_FROM_T; } \
	(GG) = max; \
}
#define set_I(II, cur, p) \
{ \
	int max; \
	if ((p)->G - gap_oe > (p)->I) { \
		max = (p)->G - gap_open; (cur)->It = NA_FROM_G; \
	} else { \
		max = (p)->I - gap_ext; (cur)->It = NA_FROM_I; \
	} \
	if ((p)->O > max) { max = (p)->O; (cur)->It = NA_FROM_O; } \
	if ((p)->T > max) { max = (p)->T; (cur)->It = NA_FROM_T; } \
	(II) = max; \
}
#define set_D(DD, cur, p) \
{ \
	if ((p)->G - gap_oe > (p)->D) { \
		(DD) = (p)->G - gap_open; (cur)->Dt = NA_FROM_G; \
	} else { \
		(DD) = (p)->D - gap_ext; (cur)->Dt = NA_FROM_D; \
	} \
}

static void back_trace(dpcell_t **cell, int i, int j, path_t *path, int *path_len)
{
	uchar type, ctype;
	dpcell_t *q;
	path_t *p;

	q = cell[j] + i;
	type = ctype = q->Gt; /* should be NA_FROM_M */
	p = path;
	do {
		p->ctype = from_table[ctype]; p->i = i; p->j = j;
		++p;
		switch (ctype) {
			case NA_FROM_M: --j; i -= 3; break;
			case NA_FROM_I: --j;         break;
			case NA_FROM_D: i -= 3;      break;
			case NA_FROM_O: --i;         break;
			case NA_FROM_T: i -= 2;      break;
		}
		q = cell[j] + i;
		if (q->Gt == NA_FROM_0) break; /* end loop */
		ctype = type;
		switch (type) {
			case NA_FROM_M: type = cell[j-1][i-3].Gt; break;
			case NA_FROM_I: type = q->It; if (type == NA_FROM_G) type = cell[j-1][i].Gt; break;
			case NA_FROM_D: type = q->Dt; if (type == NA_FROM_G) type = cell[j][i-3].Gt; break;
			case NA_FROM_O: type = cell[j][i-1].Gt; break;
			case NA_FROM_T: type = cell[j][i-2].Gt; break;
		}
	} while (i || j);
	*path_len = p - path;
}
int aln_aa2nt_local_core(uchar *prot, int prot_len, uchar *nt_trans, int nt_len, AlnParam *ap,
		path_t *path, int *path_len)
{
	register dpscore_t *s;
	dpscore_t *array[2], *curr, *last;
	dpcell_t **cell, *q;
	int *line, i, j, score;
	int max_G, mi, mj;

	int gap_open, gap_ext, gap_end, gap_oe;
	int *sc_matrix, N_ROW, frame_shift;

	/* initialize some align-related parameters. just for compatibility */
	gap_open = ap->gap_open;
	gap_ext = ap->gap_ext;
	gap_end = ap->gap_end;
	gap_oe = gap_open - gap_ext;
	frame_shift = ap->frame_shift;
	sc_matrix = ap->matrix;
	N_ROW = ap->row;

	/* memory allocation. note that no memory optimization for banded alignment here */
	array[0] = (dpscore_t*)MYALLOC(sizeof(dpscore_t) * (nt_len + 1));
	array[1] = (dpscore_t*)MYALLOC(sizeof(dpscore_t) * (nt_len + 1));
	cell = (dpcell_t**)MYALLOC(sizeof(dpcell_t*) * (prot_len + 1));
	for (j = 0; j <= prot_len; ++j)
		cell[j] = (dpcell_t*)MYALLOC(sizeof(dpcell_t) * (nt_len + 1));

	--prot; --nt_trans;
	curr = array[0]; last = array[1];
	
	/* first row */
	for (i = 0, s = curr, q = cell[0]; i <= nt_len; ++i, ++s, ++q) {
		SET_ZERO(*s);
		q->Gt = NA_FROM_0;
	}
	s = last; last = curr; curr = s;

	max_G = 0; mi = mj = 0;
	for (j = 1; j <= prot_len; ++j) {
		s = curr; q = cell[j];
		SET_ZERO(s[0]); SET_ZERO(s[1]); SET_ZERO(s[2]);
		q[0].Gt = q[1].Gt = q[2].Gt = NA_FROM_0;
		q += 3;
		line = sc_matrix + prot[j] * N_ROW;
		for (i = 3, s = curr + 3; i <= nt_len; ++i, ++q, ++s) {
			set_I(s->I, q, last + i);
			set_D(s->D, q, s - 3);
			s->O = (s-1)->G - frame_shift;
			s->T = (s-2)->G - frame_shift;
			set_G(s->G, q, last + i - 3, s, line[nt_trans[i]]);
			if (s->G > max_G) { max_G = s->G; mi = i; mj = j; }
		}
		s = last; last = curr; curr = s;
	}

	score = max_G;
	back_trace(cell, mi, mj, path, path_len);

	/* free */
	MYFREE(array[0]); MYFREE(array[1]);
	for (j = 0; j <= prot_len; ++j)
		MYFREE(cell[j]);
	MYFREE(cell);
	return score;
}
AlnAln *aln_nt2aa(char *seq_nt, char *seq_aa, AlnParam *ap, int full)
{
	uchar *aa, *nt, *nt_trans;
	int nt_len, aa_len, i, l, c;
	int score;
	char *out1, *out2, *outm;
	uchar utmp;
	path_t *p;
	AlnAln *aA;

	nt_len = strlen(seq_nt);
	aa_len = strlen(seq_aa);

	aA = aln_init_AlnAln();
	nt = (uchar*)MYALLOC(sizeof(uchar) * nt_len);
	aa = (uchar*)MYALLOC(sizeof(uchar) * aa_len);
	nt_trans = (uchar*)MYALLOC(sizeof(uchar) * nt_len);

	for (i = 0, l = 0; i != nt_len; ++i) {
		c = aln_nt4_table[(int)seq_nt[i]];
		if (c <= 4) nt[l++] = c; /* not a gap '-' */
	}
	nt_len = l;
	for (i = 0, l = 0; i != aa_len; ++i) {
		c = aln_aa_table[(int)seq_aa[i]];
		if (c <= 21) aa[l++] = c;
	}
	aa_len = l;

	/* translation */
	utmp = (nt[0]<<2)|nt[1];
	for (i = 2; i != nt_len; ++i) {
		utmp = ((utmp<<2)|nt[i])&0x3f;
		nt_trans[i] = aln_trans_table_eu[(nt[i-2] == 4 || nt[i-1] == 4 || nt[i] == 4)? 64 : utmp];
	}

	aA->path = (path_t*)MYALLOC(sizeof(path_t) * (aa_len + nt_len + 1));
	if (full) score = aln_aa2nt_global_core(aa, aa_len, nt_trans, nt_len, ap, aA->path, &aA->path_len);
	else score = aln_aa2nt_local_core(aa, aa_len, nt_trans, nt_len, ap, aA->path, &aA->path_len);
	out1 = aA->out1 = (char*)MYALLOC(sizeof(char) * (aA->path_len * 3 + 1));
	out2 = aA->out2 = (char*)MYALLOC(sizeof(char) * (aA->path_len * 3 + 1));
	outm = aA->outm = (char*)MYALLOC(sizeof(char) * (aA->path_len * 3 + 1));

	--nt_trans; --nt; --aa;
	--seq_nt; --seq_aa;

	p = aA->path + aA->path_len - 1;

	for (l = 0; p >= aA->path; --p) {
		switch (p->ctype) {
			case FROM_M: out1[l]   = seq_nt[p->i-2];
						 out1[l+1] = seq_nt[p->i-1];
						 out1[l+2] = seq_nt[p->i];
						 outm[l]   = outm[l+1] = ' ';
						 if (nt_trans[p->i] == aa[p->j]) outm[l+2] = seq_aa[p->j];
						 else if (ap->matrix[nt_trans[p->i] * ap->row + aa[p->j]] > 0)
							 outm[l+2] = '+';
						 else outm[l+2] = ' ';
						 out2[l]   = out2[l+1] = '.';
						 out2[l+2] = seq_aa[p->j];
						 l += 3; break;
			case FROM_I: out1[l] = out1[l+1] = out1[l+2] = '-';
						 outm[l] = outm[l+1] = outm[l+2] = ' ';
						 out2[l] = out2[l+1] = '.'; out2[l+2] = seq_aa[p->j];
						 l += 3; break;
			case FROM_D: out1[l]   = seq_nt[p->i-2];
						 out1[l+1] = seq_nt[p->i-1];
						 out1[l+2] = seq_nt[p->i];
						 outm[l] = outm[l+1] = outm[l+2] = ' '; 
						 out2[l] = out2[l+1] = '.'; out2[l+2] = '-';
						 l += 3; break;
			case FROM_O: out1[l] = seq_nt[p->i];
						 outm[l] = out2[l] = '!';
						 ++l; break;
			case FROM_T: out1[l] = seq_nt[p->i-1]; out1[l+1] = seq_nt[p->i];
						 outm[l] = outm[l+1] = '!';
						 out2[l] = out2[l+1] = '!';
						 l += 2; break;
		}
	}
	++nt_trans; ++nt; ++aa;
	out1[l] = outm[l] = out2[l] = '\0';

	MYFREE(nt); MYFREE(aa); MYFREE(nt_trans);
	return aA;
}
void aln_output_segment(char *ont, char *oprot, path_t *path, int path_len, char *locus1, char *locus2)
{
	path_t *p;
	char *prot, *nt, *pnt, *pprot;
	int nt_start, nt_stop, prot_start, prot_stop;
	int nt_len, prot_len;

	if (path_len == 0) return;
	prot_len = strlen(oprot);
	nt_len = strlen(ont);
	nt = (char*)MYALLOC(sizeof(char) * (nt_len + 1));
	prot = (char*)MYALLOC(sizeof(char) * (prot_len + 1));
	
	--oprot; --ont;
	p = path + path_len - 1;
	nt_start = p->i - 2;
	nt_stop = p->i;
	prot_start = p->j;
	prot_stop = p->j;
	pnt = nt; pprot = prot;
	*pnt = *pprot = '\0';
	for (; p >= path; --p) {
		switch (p->ctype) {
			case FROM_M: *pnt++ = ont[p->i - 2]; *pnt++ = ont[p->i - 1]; *pnt++ = ont[p->i];
						 *pprot++ = oprot[p->j];
						 nt_stop = p->i; prot_stop = p->j;
						 break;
			case FROM_I: *pprot++ = oprot[p->j]; prot_stop = p->j;
						 break;
			case FROM_D: *pnt++ = ont[p->i - 2]; *pnt++ = ont[p->i - 1]; *pnt++ = ont[p->i];
						 break;
			case FROM_O:
			case FROM_T: *pprot = *pnt = '\0';
						 fprintf(stderr, "NT %s\t%d\t%d\t%s\n", locus1, nt_start, nt_stop, nt);
						 fprintf(stderr, "PT %s\t%d\t%d\t%s\n", locus2, prot_start, prot_stop, prot);
						 nt_start = p->i + 1;
						 prot_start = p->j + 1;
						 pnt = nt; pprot = prot;
						 break;
		}
	}
	*pprot = *pnt = '\0';
	fprintf(stderr, "NT %s\t%d\t%d\t%s\n", locus1, nt_start, nt_stop, nt);
	fprintf(stderr, "PT %s\t%d\t%d\t%s\n", locus2, prot_start, prot_stop, prot);
	MYFREE(nt); MYFREE(prot);
}
