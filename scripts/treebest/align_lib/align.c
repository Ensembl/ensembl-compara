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
#include "align.h"
#include "table.h"
#include "seq.h"

#define ALN_REVERSE4(c) (((c) > 3)? c : 4 - c)
AlnParam aln_param_nt2nt   = {  10,  2,  2, -1,   -1,   -1,  -1, aln_sm_nt, 16, 75 };
AlnParam aln_param_rd2rd   = {  20, 19, 19, -1,   -1,   -1,  -1, aln_sm_read, 16, 75 };
AlnParam aln_param_aa2aa   = {  12,  2,  2, -1,   -1,   -1,  -1, aln_sm_blosum62, 22, 50 };
AlnParam aln_param_aa2nt   = {  12,  2,  2, 20,   -1,   -1,  -1, aln_sm_blosum62, 22, 50 };
AlnParam aln_param_splice  = { 500, 50, 50, -1, 1500, 2200, -43, aln_sm_hs, 5, -1 };
AlnParam aln_param_splice2 = { 900, 50, 50, -1, 1900, 2900, -43, aln_sm_hs, 5, -1 };
/* this parameter is optimized for HLA typing */
AlnParam aln_param_rd_splice = { 20, 19, 19, -1, 50, 70, -10, aln_sm_read, 16, -1 };

AlnAln *aln_init_AlnAln()
{
	AlnAln *aa;
	aa = (AlnAln*)MYALLOC(sizeof(AlnAln));
	aa->path = 0;
	aa->out1 = aa->out2 = aa->outm = 0;
	aa->asp = 0;
	aa->path_len = 0;
	aa->n_sub_path = 0;
	return aa;
}
void aln_free_AlnAln(AlnAln *aa)
{
	MYFREE(aa->path);
	MYFREE(aa->out1);
	MYFREE(aa->out2);
	MYFREE(aa->outm);
	MYFREE(aa->asp);
	aa->path = 0; aa->out1 = aa->out2 = aa->outm = 0;
	aa->asp = 0;
	aa->path_len = 0;
	aa->n_sub_path = 0;
	MYFREE(aa);
}
void aln_apply_matrix_mean(AlnParam *ap)
{
	int i;

	for (i = 0; i != ap->row * ap->row; ++i)
		ap->matrix[i] -= ap->matrix_mean;
}
AlnAln *aln_align(char *seq1, char *seq2, AlnParam *ap, int type)
{
	AlnAln *aa;

	if (ap->good_splice > 0)
		aa = aln_splice(seq1, seq2, ap, type);
	else if (ap->row < 20) /* nucleotide */
		aa = aln_common_align(seq1, seq2, ap, type);
	else if (ap->frame_shift > 0)
		aa = aln_nt2aa(seq1, seq2, ap, type);
	else aa = aln_common_align(seq1, seq2, ap, type);

	return aa;
}
uchar *aln_reverse4(uchar *seq, int len)
{
	int i;
	uchar tmp;
	for (i = 0; i != len >> 1; ++i) {
		tmp = ALN_REVERSE4(seq[i]);
		seq[i] = ALN_REVERSE4(seq[len - i - 1]);
		seq[len - i - 1] = tmp;
	}
	if (len & 0x1) seq[len>>1] = ALN_REVERSE4(seq[len>>1]);
	return seq;
}
