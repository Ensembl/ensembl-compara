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

#ifdef ALN_64BIT
typedef unsigned long bit64_t;
#else
typedef unsigned long long bit64_t;
#endif

static int sc_donor[16], sc_acceptor[16];

typedef struct
{
	int G, I;
	bit64_t Gs, Is;
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
int aln_splice_bound_core(uchar *gen, int gen_len, uchar *est, int est_len,
		AlnParam *ap, int *gen_start, int *gen_stop, int *est_start, int *est_stop)
{
	register int i, last_g;
	register dpscore_t *s;

	int **s_array, *score_array;
	dpscore_t *dpscore;
	int *donor, *acceptor;
	int j, mi, mj, max_g;
	int curr_g;
	bit64_t last_gs, curr_gs;
	int ins, del, n;
	bit64_t dels, ns, ms;
	uchar dtmp, atmp;

	int gap_open, gap_ext, gap_oe, good_splice, bad_splice, *sc_matrix;

	gap_open = ap->gap_open;
	gap_ext = ap->gap_ext;
	gap_oe = gap_open - gap_ext;
	good_splice = ap->good_splice;
	bad_splice = ap->bad_splice;
	sc_matrix = ap->matrix;
	if (*sc_donor != ap->bad_splice) est_genome_init(ap);
	
	if (gen_len < 5) return 0;

	/* memory allocation */
	s_array = (int**)MYALLOC(sizeof(int*) * ap->row);
	for (i = 0; i != ap->row; ++i)
		s_array[i] = (int*)MYALLOC(sizeof(int) * gen_len);
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
	max_g = 0; mi = mj = 0; ms = 0;
	for (i = 0, s = dpscore; i <= gen_len; ++i, ++s) {
		s->G = s->I = 0;
		s->Gs = s->Is = ((bit64_t)i<<32)|0;
	}

	/* core dynamic programming */
	for (j = 1; j <= est_len; ++j) {
		last_g = del = n = 0;
		last_gs = dels = ns = j;
		s = dpscore;
		score_array = s_array[est[j]];
		for (i = 1, s = dpscore; i <= gen_len; ++i, ++s) {
			curr_g = s->G + score_array[i];
			if (curr_g < 0) {
				curr_g = 0; curr_gs = ((bit64_t)i<<32)|j;
			} else curr_gs = s->Gs;
			if (last_g > donor[i]) {
				if (last_g - donor[i] > n) {
					n = last_g - donor[i]; ns = last_gs;
				}
				if (curr_g < n - acceptor[i+1]) {
					curr_g = n - acceptor[i+1]; curr_gs = ns;
				}
			}
			if (last_g > gap_open) {
				if (del > last_g - gap_oe) {
					del -= gap_ext;
				} else {
					del = last_g - gap_open; dels = last_gs;
				}
				if (curr_g < del) {
					curr_g = del; curr_gs = dels;
				}
			}
			if ((s+1)->G > gap_open) {
				if (s->I > (s+1)->G - gap_oe) {
					ins = s->I - gap_ext; /* s->Is = s->Is */
				} else {
					ins = (s+1)->G - gap_open; s->Is = (s+1)->Gs;
				}
				if (curr_g < ins) {
					curr_g = ins; curr_gs = s->Is;
				}
				s->I = ins;
			}
			s->G = last_g; s->Gs = last_gs;
			last_g = curr_g; last_gs = curr_gs;
			if (curr_g > max_g) {
				max_g = curr_g; mi = i; mj = j; ms = curr_gs;
			}
		}
		s->G = last_g; s->Gs = last_gs;
	}

	*gen_start = (ms>>32) + 1; *gen_stop = mi;
	*est_start = (ms&0xffffffff) + 1; *est_stop = mj;
	/* free */
	MYFREE(dpscore);
	MYFREE(acceptor); MYFREE(donor);
	for (i = 0; i != ap->row; ++i)
		MYFREE(s_array[i] + 1);
	MYFREE(s_array);
	return max_g;
}
