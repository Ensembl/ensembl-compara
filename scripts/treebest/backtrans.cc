#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include "align.h"
#include "utils.h"
#include "align_lib/align.h"
#include "align_lib/table.h"
#include "align_lib/seq.h"
#include "common/hash_char.h"

extern "C" {
//char *aln_back_trans(char *aln_aa, char *seq_nt_pre, int *flaw_code);
int ma_backtrans_task(int argc, char *argv[]);
FILE *tr_get_fp(const char *fn);
}

hash_map_char<char*> *ta_read_fa(FILE *fp)
{
	hash_map_char<char*> *hash;
	char name[256];
	seq_t seq;

	assert(fp);
	INIT_SEQ(seq);
	hash = new hash_map_char<char*>;
	while ((read_fasta(fp, &seq, name, 0)) >= 0) {
		char *s = (char*)malloc(sizeof(char) * (seq.l+1));
		strcpy(s, seq.s);
		hash->insert(name, s);
	}
	MYFREE(seq.s);
	return hash;
}
MultiAlign *ma_back_trans_core(MultiAlign *aa, hash_map_char<char*> *hash, float threshold)
{
	char *aln_aa, *aln_nt_pre, *aln_nt, *seq_nt;
	int flaw;
	int i, j, k, l;
	MultiAlign *nt;

	nt = ma_alloc();
	nt->len = aa->len * 3;
	nt->max = aa->n;
	nt->is_nucl = 1;
	nt->name = (char**)malloc(sizeof(char*) * aa->n);
	nt->seq = (char**)malloc(sizeof(char*) * aa->n);
	nt->gene = (char**)malloc(sizeof(char*) * aa->n);
	nt->comment = (char**)malloc(sizeof(char*) * aa->n);
	for (i = 0; i < aa->n; ++i)
		nt->name[i] = nt->seq[i] = nt->gene[i] = nt->comment[i] = 0;
	aln_aa = (char*)malloc(sizeof(char) * (aa->len + 1));
	for (i = k = 0; i < aa->n; ++i) {
		if (hash->find(aa->name[i], &seq_nt)) {
			for (j = 0; j < aa->len; ++j)
				aln_aa[j] = aln_aa_rev_table[aa->seq[i][j]];
			aln_aa[j] = '\0';
			aln_nt_pre = aln_back_trans(aln_aa, seq_nt, &flaw);
			/* fprintf(stderr, "%d\t%-30s\t%d\t%d\t%s\n", i, aa->name[i], nt->len, strlen(aln_nt_pre), aln_nt_pre); */
			if ((flaw & 0xff)/100.0 > threshold) {
				if (flaw & 0xff00)
					fprintf(stderr, "<ma_back_trans_core> flaw code %x for sequence %s\n", flaw&0xff00, aa->name[i]);
				nt->name[k] = cpystr(aa->name[i]);
				if (aa->gene && aa->gene[i]) nt->gene[k] = cpystr(aa->gene[i]);
				if (aa->comment && aa->comment[i]) nt->comment[k] = cpystr(aa->comment[i]);
				aln_nt = nt->seq[k] = (char*)malloc(sizeof(char) * nt->len);
				for (l = 0; l < nt->len; ++l)
					aln_nt[l] = aln_nt4_table[(int)aln_nt_pre[l]];
				++k;
			} else fprintf(stderr, "<ma_back_trans_core> poor nt2aa alignment for %s (%d%% < %d%%)\n",
					aa->name[i], flaw&0xff, (int)(threshold*100.0+0.5));
			free(aln_nt_pre);
		} else fprintf(stderr, "<ma_back_trans_core> fail to find sequence %s\n", aa->name[i]);
	}
	nt->n = k;
	free(aln_aa);
	return nt;
}
MultiAlign *ma_back_trans(MultiAlign *aa, FILE *fp, float threshold)
{
	hash_map_char<char*> *hash;
	hash_map_char<char*>::iterator iter;
	MultiAlign *ma;
	hash = ta_read_fa(fp);
	ma = ma_back_trans_core(aa, hash, threshold);
	for (iter = hash->begin(); iter < hash->end(); ++iter)
		if (isfilled(iter)) MYFREE(iter->val);
	delete hash;
	return ma;
}
static int ma_backtrans_usage()
{
	fprintf(stderr, "Usage: treebest backtrans [-t <thres>] <aa_aln> <nt_seq>\n");
	return 1;
}
int ma_backtrans_task(int argc, char *argv[])
{
	int c;
	FILE *fp_aa, *fp_nt;
	float thres = 0.90;
	MultiAlign *aa, *nt;
	while ((c = getopt(argc, argv, "t:")) >= 0) {
		switch (c) {
			case 't': thres = atof(optarg); break;
		}
	}
	if (argc-1 <= optind) return ma_backtrans_usage();
	fp_aa = tr_get_fp(argv[optind]);
	fp_nt = tr_get_fp(argv[optind+1]);
	aa = ma_read_alignment(fp_aa, 0);
	nt = ma_back_trans(aa, fp_nt, thres);
	tr_align_output(stdout, nt);
	fclose(fp_aa); fclose(fp_nt);
	ma_free(aa); ma_free(nt);
	return 0;
}
