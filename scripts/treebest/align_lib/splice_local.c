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
#include <stdlib.h>
#include <string.h>
#include "seq.h"
#include "align.h"
#include "table.h"

/**********************************************************************************
 * M(i,j) = max { M(i-1,j-1), I(i-1,j-1), D(i-1,j-1), N(i-1,j-1)-g(i) } + S(i,j)  *
 * I(i,j) = max { M(i,j-1), I(i,j-1)+(d-e) } - d                                  *
 * D(i,j) = max { M(i-1,j), D(i-1,j)+(d-e), N(i-1,j)-g(i) } - d                   *
 * N(i,j) = max { M(i-1,j), I(i-1,j), D(i-1,j), N(i-1,j) + f(i) } - f(i)          *
 **********************************************************************************/

/*********************************************************************
 * I(i,j) = max { G(i,j-1)-d, I(i,j-1)-e }                           *
 * D(i,j) = max { G(i-1,j)-d, D(i-1,j)-e }                           *
 * N(i,j) = max { G(i-1,j)-f(i), N(i-1,j) }                          *
 * G(i,j) = max { G(i-1,j-1)+S(i,j), I(i,j), D(i,j), N(i,j)-g(i+1) } *
 *                                                                   *
 * G(i,j) = max { M(i,j), I(i,j), D(i,j), N(i,j)-g(i+1) }            *
 * M(i,j) = G(i-1,j-1) + S(i,j)                                      *
 *                                                                   *
 * f(): donor g(): acceptor                                          *
 *********************************************************************/

static int sc_donor[16], sc_acceptor[16];

#define SL_FROM_G 0
#define SL_FROM_N 1
#define SL_FROM_I 2
#define SL_FROM_D 3
#define SL_FROM_M 4
#define SL_FROM_0 7

static uchar from_table[8] = { FROM_G, FROM_N, FROM_I, FROM_D, FROM_M, 0, 0, FROM_0 };

typedef struct
{
	unsigned char Gt:3, It:2, Dt:2, Nt:1;
} dpcell_t;

typedef struct
{
	int G, I;
} dpscore_t;

static void est_genome_init(AlnParam *ap) /* different from est_genome_init() in splice.c */
{
	int i;
	for (i = 0; i < 16; ++i) {
		sc_donor[i] = ap->bad_splice;
		sc_acceptor[i] = ap->bad_splice - ap->good_splice;
	}
	sc_donor[(1<<2)|3]    = ap->good_splice; /* GT */
	sc_acceptor[(0<<2)|1] = 0; /* AG */
}
static void back_trace(dpcell_t **cell, int i, int j, path_t *path, int *path_len)
{
	uchar type, ctype;
	dpcell_t *q;
	path_t *p;

	q = cell[j] + i;
	type = ctype = q->Gt;
	p = path;
	do {
		if ((p > path && (p-1)->ctype != FROM_N) || ctype != SL_FROM_N) {
			p->ctype = from_table[ctype]; p->i = i; p->j = j;
			++p;
		}
		switch (ctype) {
			case SL_FROM_M: --i; --j; break;
			case SL_FROM_I: --j; break;
			case SL_FROM_D:
			case SL_FROM_N: --i; break;
		}
		q = cell[j] + i;
		if (q->Gt == SL_FROM_0) break;
		ctype = type;
		switch (type) {
			case SL_FROM_M: type = cell[j-1][i-1].Gt; break;
			case SL_FROM_I: type = q->It; if (type == SL_FROM_G) type = cell[j-1][i].Gt; break;
			case SL_FROM_D: type = q->Dt; if (type == SL_FROM_G) type = cell[j][i-1].Gt; break;
			case SL_FROM_N: type = q->Nt; if (type == SL_FROM_G) type = cell[j][i-1].Gt; break;
		}
	} while (i || j);
	*path_len = p - path;
}
int aln_splice_local_core(uchar *gen, int gen_len, uchar *est, int est_len,
		AlnParam *ap, path_t *path, int *path_len)
{
	register dpcell_t *q;
	register int i;
	register dpscore_t *s;

	int **s_array, *score_array;
	dpcell_t **dpcell;
	dpscore_t *dpscore;
	int *donor, *acceptor;
	int j, mi, mj, max_g;
	int last_g, curr_g, curr_last_g;
	int ins, del, n;
	uchar dtmp, atmp;

	int gap_open, gap_ext, gap_oe, good_splice, bad_splice, *sc_matrix;

	gap_open = ap->gap_open;
	gap_ext = ap->gap_ext;
	gap_oe = gap_open - gap_ext;
	good_splice = ap->good_splice;
	bad_splice = ap->bad_splice;
	sc_matrix = ap->matrix;
	if (*sc_donor != ap->bad_splice) est_genome_init(ap);
	
	if (gen_len < 5) return MINOR_INF;

	/* memory allocation */
	s_array = (int**)MYALLOC(sizeof(int*) * ap->row);
	for (i = 0; i != ap->row; ++i)
		s_array[i] = (int*)MYALLOC(sizeof(int) * gen_len);
	dpcell = (dpcell_t**)MYALLOC(sizeof(dpcell_t*) * (est_len + 1));
	for (j = 0; j <= est_len; ++j)
		dpcell[j] = (dpcell_t*)MYALLOC(sizeof(dpcell_t) * (gen_len + 1));
	donor = (int*)MYALLOC(sizeof(int) * (gen_len + 2));
	acceptor = (int*)MYALLOC(sizeof(int) * (gen_len + 2));
	dpscore = (dpscore_t*)MYALLOC(sizeof(dpscore_t) * (gen_len + 1));
	
	aln_init_score_array(gen, gen_len, ap->row, sc_matrix, s_array);
	for (i = 0; i != ap->row; ++i) --s_array[i];
	--est; --gen;
	
	/* set donor-acceptor array */
	donor[gen_len - 1] = donor[gen_len] = sc_donor[0xf];
	dtmp = gen[1] & 0x3;
	for (i = 1; i <= gen_len - 1; ++i) {
		if (gen[i+1] > 3 || gen[i] > 3) donor[i] = bad_splice; /* N is encountered */
		else {
			dtmp = ((dtmp<<2) | gen[i+1]) & 0xf;
			donor[i] = sc_donor[dtmp];
		}
	}
	acceptor[gen_len+1] = acceptor[0] = acceptor[1] = acceptor[2] = sc_acceptor[0xf];
	atmp = gen[1] & 0x3;
	for (i = 3; i <= gen_len; ++i) {
		if (gen[i] > 3 || gen[i-1] > 3) acceptor[i] = bad_splice;
		else {
			atmp = ((atmp<<2) | gen[i-1]) & 0xf;
			acceptor[i] = sc_acceptor[atmp];
		}
	}
	
	/* first row */
	max_g = 0; mi = mj = 0;
	for (i = 0, q = dpcell[0], s = dpscore; i <= gen_len; ++i, ++q, ++s) {
		s->G = s->I = 0;
		q->Gt = FROM_0;
	}
	/* core dynamic programming */
	for (j = 1; j <= est_len; ++j) {
		last_g = del = n = 0;
		score_array = s_array[est[j]];
		q = dpcell[j];
		q->Gt = SL_FROM_0;
		++q;
		for (i = 1, s = dpscore; i <= gen_len; ++i, ++s, ++q) {
			curr_g = s->G + score_array[i];
			if (curr_g < 0) {
				curr_g = 0;
				q->Gt = SL_FROM_0;
			} else q->Gt = SL_FROM_M;
			if (last_g > donor[i]) {
				if (last_g - donor[i] > n) {
					n = last_g - donor[i];
					q->Nt = SL_FROM_G;
				} else q->Nt = SL_FROM_N;
				if (curr_g < n - acceptor[i+1]) {
					curr_g = n - acceptor[i+1];
					q->Gt = SL_FROM_N;
				}
			} else q->Nt = SL_FROM_N;
			if (last_g > gap_open) {
				if (del > last_g - gap_oe) {
					del -= gap_ext;
					q->Dt = SL_FROM_D;
				} else {
					del = last_g - gap_open;
					q->Dt = SL_FROM_G;
				}
				if (curr_g < del) {
					curr_g = del;
					q->Gt = SL_FROM_D;
				}
			}
			curr_last_g = (s+1)->G;
			if (curr_last_g > gap_open) {
				if (s->I > curr_last_g - gap_oe) {
					ins = s->I - gap_ext;
					q->It = SL_FROM_I;
				} else {
					ins = curr_last_g - gap_open;
					q->It = SL_FROM_G;
				}
				if (curr_g < ins) {
					curr_g = ins;
					q->Gt = SL_FROM_I;
				}
				s->I = ins;
			} else s->I = 0;
			s->G = last_g;
			last_g = curr_g;
			if (curr_g > max_g) {
				max_g = curr_g; mi = i; mj = j;
			}
		}
		s->G = last_g;
	}

	back_trace(dpcell, mi, mj, path, path_len);

	/* free */
	MYFREE(dpscore);
	MYFREE(acceptor); MYFREE(donor);
	for (j = 0; j <= est_len; ++j)
		MYFREE(dpcell[j]);
	for (i = 0; i != ap->row; ++i)
		MYFREE(s_array[i] + 1);
	MYFREE(s_array);
	MYFREE(dpcell);
	return max_g;
}
