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

#ifndef TABLE_H_
#define TABLE_H_

#define ALN_NT4_A 0
#define ALN_NT4_G 1
#define ALN_NT4_C 2
#define ALN_NT4_T 3
#define ALN_NT4_N 4
#define ALN_NT4_GAP 5

/* char -> 5 (=4+1) nucleotides */
extern unsigned char aln_nt4_table[256];
extern char         *aln_nt4_rev_table;

/* char -> 17 (=16+1) nucleotides */
extern unsigned char aln_nt16_table[256];
extern char         *aln_nt16_rev_table;
extern int           aln_nt16_table_aux[16];
extern unsigned char aln_nt16_table_comp[17];

/* char -> 22 (=20+1+1) amino acids */
extern unsigned char aln_aa_table[256];
extern char         *aln_aa_rev_table;

/* translation table */
extern unsigned char aln_trans_table_eu[66];
extern char         *aln_trans_table_eu_char;

/* BLOSUM62 and BLOSUM45 */
#define ALN_AA_GAP 22
extern int           aln_sm_blosum62[], aln_sm_blosum45[];

/* human-mouse score matrix for 4 bases */
extern int           aln_sm_hs[];

/* common nucleotide score matrix for 16 bases */
extern int           aln_sm_nt[];

/* common read for 16 bases. note that read alignment is quite different from common nucleotide alignment */
extern int           aln_sm_read[];

/* fill aln_sm_nt[]. just for development. do not use it, unless you know what you are doing. */
#ifdef __cplusplus
extern "C" {
#endif
void                 aln_make_sm_nt(int row, int *score_matrix);
int					aln_trans_seq(const char *nt, int len, char *aa, int is_trans);
#ifdef __cplusplus
}
#endif

#endif /* TABLE_H_ */
