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
 * I(i,j) = max { M(i,j-1), I(i,j-1)+(d-e), N(i,j-1)-g(i) } - d                   *
 * D(i,j) = max { M(i-1,j), D(i-1,j)+(d-e), N(i-1,j)-g(i) } - d                   *
 * N(i,j) = max { M(i-1,j), I(i-1,j), D(i-1,j), N(i-1,j) + f(i) } - f(i)          *
 **********************************************************************************/

static int sc_donor[16], sc_acceptor[16];

typedef struct
{
	unsigned char Mt:2, It:2, Dt:2, Nt:2;
} dpcell_t;

typedef struct
{
	int M, I, D, N;
} dpscore_t;

#define SET_INF(s) (s).M = (s).I = (s).D = (s).N = MINOR_INF

#define set_M(MM, cur, p, sc, g)	\
{	\
	int max;	\
	if ((p)->M > (p)->N - (g)) {	\
		max = (p)->M; (cur)->Mt = FROM_M;	\
	} else {	\
		max = (p)->N - (g); (cur)->Mt = FROM_N;	\
	}	\
	if ((p)->I > max) { max = (p)->I; (cur)->Mt = FROM_I; }	\
	if ((p)->D > max) { max = (p)->D; (cur)->Mt = FROM_D; }	\
	(MM) = max + sc;	\
}
#define set_I(II, cur, p, g)	\
{	\
	int max;	\
	if ((p)->M > (p)->N - (g)) {	\
		max = (p)->M; (cur)->It = FROM_M;	\
	} else {	\
		max = (p)->N - (g); (cur)->It = FROM_N;	\
	}	\
	if ((p)->I + gap_oe > max) { max = (p)->I + gap_oe; (cur)->It = FROM_I; }	\
	(II) = max - gap_open;	\
}
#define set_D(DD, cur, p, g)	\
{	\
	int max;	\
	if ((p)->M > (p)->N - (g)) {	\
		max = (p)->M; (cur)->Dt = FROM_M;	\
	} else {	\
		max = (p)->N - (g); (cur)->Dt = FROM_N;	\
	}	\
	if ((p)->D + gap_oe > max) { max = (p)->D + gap_oe; (cur)->Dt = FROM_D; }	\
	(DD) = max - gap_open;	\
}
#define set_N(NN, cur, p, f)	\
{	\
	int max;	\
	if ((p)->M > (p)->N + (f)) {	\
		max = (p)->M; (cur)->Nt = FROM_M;	\
	} else {	\
		max = (p)->N + (f); (cur)->Nt = FROM_N;	\
	}	\
	if ((p)->I > max) { max = (p)->I; (cur)->Nt = FROM_I; }	\
	if ((p)->D > max) { max = (p)->D; (cur)->Nt = FROM_D; }	\
	(NN) = max - (f);	\
}

static void est_genome_init(AlnParam *ap)
{
	int i;
	for (i = 0; i < 16; ++i) {
		sc_donor[i] = ap->bad_splice;
		sc_acceptor[i] = ap->bad_splice - ap->good_splice;
	}
	sc_donor[(1<<2)|3]    = ap->good_splice; /* GT */
	sc_acceptor[(0<<2)|1] = 0; /* AG */
}
static int back_trace(dpcell_t **dpcell, dpscore_t *dplast, int est_len, int gen_len,
		path_t *path, int *path_len)
{
	uchar type, ctype;
	int i, j, max;
	dpcell_t *q;
	path_t *p;

	i = gen_len; j = est_len;
	q = dpcell[j] + i;
	max = dplast->M; type = q->Mt; ctype = FROM_M;
	if (dplast->I > max) { max = dplast->I; type = q->It; ctype = FROM_I; }
	if (dplast->D > max) { max = dplast->D; type = q->Dt; ctype = FROM_D; }
	if (dplast->N > max) { max = dplast->N; type = q->Nt; ctype = FROM_N; }
	
	p = path;
	p->ctype = ctype; p->i = i; p->j = j;
	++p;
	do {
		switch (ctype) {
			case FROM_M: --i; --j; break;
			case FROM_I: --j; break;
			case FROM_D:
			case FROM_N: --i; break;
		}
		q = dpcell[j] + i;
		ctype = type;
		switch (type) {
			case FROM_M: type = q->Mt; break;
			case FROM_I: type = q->It; break;
			case FROM_D: type = q->Dt; break;
			case FROM_N: type = q->Nt; break;
		}
		if ((p-1)->ctype != FROM_N || ctype != FROM_N) {
			p->ctype = ctype; p->i = i; p->j = j;
			++p;
		}
	} while (i || j);
	
	*path_len = p - path - 1;
	
	return max;
}
int aln_splice_global_core(uchar *gen, int gen_len, uchar *est, int est_len,
		AlnParam *ap, path_t *path, int *path_len)
{
	register dpcell_t *q;
	register int i;
	register dpscore_t *s;
	dpcell_t **dpcell, *p;
	dpscore_t *dpscore, curr, last;
	int j, *donor, *acceptor, score, *mat;
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
	dpcell = (dpcell_t**)MYALLOC(sizeof(dpcell_t*) * (est_len + 1));
	for (j = 0; j <= est_len; ++j)
		dpcell[j] = (dpcell_t*)MYALLOC(sizeof(dpcell_t) * (gen_len + 1));
	donor = (int*)MYALLOC(sizeof(int) * (gen_len + 1));
	acceptor = (int*)MYALLOC(sizeof(int) * (gen_len + 1));
	dpscore = (dpscore_t*)MYALLOC(sizeof(dpscore_t) * (gen_len + 1));
	
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
	acceptor[0] = acceptor[1] = acceptor[2] = sc_acceptor[0xf];
	atmp = gen[1] & 0x3;
	for (i = 3; i <= gen_len; ++i) {
		if (gen[i] > 3 || gen[i-1] > 3) acceptor[i] = bad_splice;
		else {
			atmp = ((atmp<<2) | gen[i-1]) & 0xf;
			acceptor[i] = sc_acceptor[atmp];
		}
	}
	
	/* first row */
	SET_INF(*dpscore); dpscore->M = 0;
	q = dpcell[0]; q->Mt = 0;
	for (i = 1, q = dpcell[0] + 1; i <= gen_len; ++i, ++q) {
		s = dpscore + i;
		SET_INF(*s);
		set_D(s->D, q, s - 1, bad_splice); /* regardless of the splice site in the head */
		set_N(s->N, q, s - 1, 0);
	}

	/* core dynamic programming */
	for (j = 1; j <= est_len; ++j) {
		p = dpcell[j];
		SET_INF(last);
		set_I(last.I, p, dpscore, acceptor[1]);
		mat = sc_matrix + est[j] * ap->row;
		for (i = 1, q = p + 1; i <= gen_len; ++i, ++q) {
			score = acceptor[i];
			s = dpscore + i - 1;
			set_M(curr.M, q, s, mat[gen[i]], score);
			set_I(curr.I, q, s + 1, score);
			set_D(curr.D, q, &last, score);
			set_N(curr.N, q, &last, donor[i]);
			*s = last; last = curr;
		}
		dpscore[gen_len] = curr;
	}

	score = back_trace(dpcell, dpscore + gen_len, est_len, gen_len, path, path_len);

	/* free */
	MYFREE(dpscore);
	MYFREE(acceptor); MYFREE(donor);
	for (j = 0; j <= est_len; ++j)
		MYFREE(dpcell[j]);
	MYFREE(dpcell);
	return score;
}
AlnSubPath *aln_splice_sub_path(path_t *path, int path_len, int *count)
{
	AlnSubPath *ap, *q;
	path_t *p;
	int l;

	p = path + path_len - 1;
	for (l = 0, *count = 0; p >= path; --p) {
		if (p->ctype == FROM_N && l != 0) {
			l = 0; ++(*count);
		} else if (p->ctype != FROM_N) ++l;
	}
	if (l != 0) ++(*count);

	ap = (AlnSubPath*)MYALLOC(sizeof(AlnSubPath) * (*count));
	p = path + path_len - 1;
	q = ap;
	for (l = 0; p >= path; --p) {
		if (p->ctype == FROM_N && l != 0) {
			q->path = p + 1;
			q->path_len = l;
			++q; l = 0;
		} else if (p->ctype != FROM_N) ++l;
	}
	if (l != 0) {
		q->path = path;
		q->path_len = l;
	}

	return ap;
}
AlnAln *aln_splice(char *gen, char *est, AlnParam *ap, int type)
{
	uchar *best, *bgen;
	int est_len, gen_len;
	int l, i, m;
	path_t *pt, *pp, *p;
	char *o1, *o2, *om, *outm;
	AlnAln *aa;

	est_len = strlen(est);
	gen_len = strlen(gen);

	aa = aln_init_AlnAln();
	best = (uchar*)MYALLOC(sizeof(uchar) * est_len);
	bgen = (uchar*)MYALLOC(sizeof(uchar) * gen_len);
	aa->path = (path_t*)MYALLOC(sizeof(path_t) * (est_len + gen_len + 2));

	if (ap->row > 10) {
		for (i = 0; i < est_len; ++i)
			best[i] = aln_nt16_table[(int)est[i]];
		for (i = 0; i < gen_len; ++i)
			bgen[i] = aln_nt16_table[(int)gen[i]];
	} else {
		for (i = 0; i < est_len; ++i)
			best[i] = aln_nt4_table[(int)est[i]];
		for (i = 0; i < gen_len; ++i)
			bgen[i] = aln_nt4_table[(int)gen[i]];
	}

	if (type == ALN_GLOBAL_ALIGN)
		aa->score = aln_splice_global_core(bgen, gen_len, best, est_len, ap, aa->path, &aa->path_len);
	else if (type == ALN_LOCAL_ALIGN)
		aa->score = aln_splice_local_core(bgen, gen_len, best, est_len, ap, aa->path, &aa->path_len);
	else if (type == ALN_BOUND_ALIGN) {
		aa->score = aln_splice_bound_core(bgen, gen_len, best, est_len, ap,
				&aa->path[1].i, &aa->path[0].i, &aa->path[1].j, &aa->path[0].j);
		aa->path_len = 2;
		MYFREE(best); MYFREE(bgen);
		return aa;
	}
	aa->asp = aln_splice_sub_path(aa->path, aa->path_len, &aa->n_sub_path);

	aa->out1 = aa->out2 = 0;
	outm = aa->outm = (char*)MYALLOC(sizeof(char) * (3 * (aa->path_len + 1) + 80 * aa->n_sub_path));

	o1 = (char*)MYALLOC(sizeof(char) * (aa->path_len + 1));
	o2 = (char*)MYALLOC(sizeof(char) * (aa->path_len + 1));
	om = (char*)MYALLOC(sizeof(char) * (aa->path_len + 1));
	--est; --gen; --best; --bgen;

	for (i = 0, l = 0; i < aa->n_sub_path; ++i) {
		pt = aa->asp[i].path; pp = aa->asp[i].path + aa->asp[i].path_len - 1;
		l += sprintf(outm + l, "%d\t%d\t%d\t%d\t", pp->i, pt->i, pp->j, pt->j);
		if (pp->i > 2)
			l += sprintf(outm + l, "%c%c\t", gen[pp->i-2], gen[pp->i-1]);
		else l += sprintf(outm + l, "--\t");
		if (pt->i <= gen_len - 2)
			l += sprintf(outm + l, "%c%c\n", gen[pt->i+1], gen[pt->i+2]);
		else l += sprintf(outm + l, "--\n");
		for (m = 0, p = pp; p >= pt; --p, ++m) {
			switch (p->ctype) {
				case FROM_M: o1[m] = gen[p->i]; o2[m] = est[p->j];
							 if (bgen[p->i] == best[p->j]) om[m] = '|';
							 else if (bgen[p->i] != 4 && (bgen[p->i] & 0x2) == (best[p->j] & 0x2))
								 om[m] = '.';
							 else om[m] = ' ';
							 break;
				case FROM_I: o1[m] = '-'; o2[m] = est[p->j]; om[m] = ' '; break;
				case FROM_D: o1[m] = gen[p->i]; o2[m] = '-'; om[m] = ' '; break;
			}
		}
		o1[m] = o2[m] = om[m] = '\0';
		l += sprintf(outm + l, "%s\n%s\n%s\n", o1, om, o2);
	}

	aa->outm[l-1] = '\0'; /* remove last '\n' */
	++best; ++bgen;
	MYFREE(best); MYFREE(bgen);
	MYFREE(o1); MYFREE(o2); MYFREE(om);
	return aa;
}
