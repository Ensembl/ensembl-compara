#include <ctype.h>
#include <string.h>
#include "align.h"

char *aln_back_trans(char *aln_aa, char *seq_nt_pre, int *flaw_code)
{
	AlnAln *aA;
	char *t, *s, *seq_aa, *aln_nt_pre, *aln_nt, *seq_nt;
	path_t *p;
	int l, count, flaw, base, tmp;

	seq_aa = (char*)MYALLOC(sizeof(char) * (strlen(aln_aa) + 1));
	seq_nt = (char*)MYALLOC(sizeof(char) * (strlen(seq_nt_pre) + 1));

	for (s = aln_aa, t = seq_aa; *s; ++s)
		if (isalpha(*s)) *t++ = *s;
	*t = '\0';
	for (s = seq_nt_pre, t = seq_nt; *s; ++s)
		if (isalpha(*s)) *t++ = *s;
	*t = '\0';
	aA = aln_nt2aa(seq_nt, seq_aa, &aln_param_aa2nt, 0);

	count = base = 0; flaw = 0;
	aln_nt = (char*)MYALLOC(sizeof(char) * (strlen(aln_aa)*3 + 1));
	aln_nt_pre = (char*)MYALLOC(sizeof(char) * (strlen(aln_aa)*3 + 1));
	/* check head */
	p = aA->path + aA->path_len - 1;
	s = aln_nt_pre;
	if (p->j-1 != 0) {
		flaw |= FLAW_NO_HEAD;
		for (l = 0; l < p->j-1; ++l) {
			*s++ = 'X'; *s++ = 'X'; *s++ = 'X';
		}
		base += p->j-1;
	}
	/* check alignment */
	p = aA->path + aA->path_len - 1;
	for (l = 0; p >= aA->path; --p) {
		switch (p->ctype) {
			case FROM_M:
				*s++ = seq_nt[p->i-3]; *s++ = seq_nt[p->i-2]; *s++ = seq_nt[p->i-1];
				if (isalpha(aA->outm[l+2])) ++count;
				l += 3;
				break;
			case FROM_I: *s++ = 'X'; *s++ = 'X'; *s++ = 'X'; flaw |= FLAW_INS; l += 3; break;
			case FROM_D: flaw |= FLAW_DEL; l += 3; break;
			case FROM_O: flaw |= FLAW_FRAME_SHIFT; l += 1; break;
			case FROM_T: flaw |= FLAW_FRAME_SHIFT; l += 2; break;
		}
	}
	base += aA->path_len;
	/* check tail */
	p = aA->path;
	tmp = strlen(seq_aa);
	if (p->j != tmp) {
		flaw |= FLAW_NO_TAIL;
		for (l = p->j; l < tmp; ++l) {
			*s++ = 'X'; *s++ = 'X'; *s++ = 'X';
		}
		base += tmp - p->j;
	}
	*s = '\0';
	/* make alignment */
	for (l = 0, t = aln_nt, s = aln_aa; *s; ++s) {
		if (isalpha(*s)) {
			*t++ = aln_nt_pre[l++];
			*t++ = aln_nt_pre[l++];
			*t++ = aln_nt_pre[l++];
		} else {
			*t++ = *s; *t++ = *s; *t++ = *s;
		}
	}
	*t = '\0';
	flaw |= (int)(100.0*count/base+0.5);

	aln_free_AlnAln(aA);
	MYFREE(seq_nt); MYFREE(seq_aa); MYFREE(aln_nt_pre);

	if (flaw_code) *flaw_code = flaw;
	return aln_nt;
}
