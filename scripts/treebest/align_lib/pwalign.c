#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "align.h"
#include "seq.h"
#include "version.h"

#ifndef MAX_NAME_LEN
#define MAX_NAME_LEN 255
#endif

extern int getopt(int nargc, char * const *nargv, const char *ostr);
extern int optind, opterr;
extern char *optarg;

int aln_pair_align(FILE *fp1, FILE *fp2, AlnParam *ap, int type, int misc_flag)
{
	seq_t seq1, seq2;
	int len1, len2, n;
	char name1[MAX_NAME_LEN], name2[MAX_NAME_LEN];
	path_t *pt, *pp;
	AlnAln *aa;

	INIT_SEQ(seq1); INIT_SEQ(seq2);

	for (n = 0; ; ++n) {
		len1 = read_fasta(fp1, &seq1, name1, 0);
		len2 = read_fasta(fp2, &seq2, name2, 0);
		if (len1 < 0 || len2 < 0) break;
		aa = aln_align((char*)seq1.s, (char*)seq2.s, ap, type);
		pp = aa->path; pt = aa->path + aa->path_len - 1;
		printf(">%s\t%d\t%d\t%d\t%s\t%d\t%d\t%d\t%d\n", name1, len1, pt->i, pp->i,
				name2, len2, pt->j, pp->j, aa->score);
		if (aa->out1) printf("%s\n", aa->out1);
		if (aa->outm) printf("%s\n", aa->outm);
		if (aa->out2) printf("%s\n", aa->out2);
		if (type != ALN_BOUND_ALIGN) printf("//\n");
		fflush(stdout);
		if (misc_flag)
			aln_output_segment((char*)seq1.s, (char*)seq2.s, aa->path, aa->path_len, name1, name2);
		aln_free_AlnAln(aa);
	}
	MYFREE(seq1.s); MYFREE(seq2.s);
	return n;
}
static void pwalign_usage(char *prog)
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Program : pwalign (PairWise ALIGNment tool)\n");
	fprintf(stderr, "Version : %s, on %s\n", aln_version, aln_date);
	fprintf(stderr, "Contact : liheng@genomics.org.cn\n\n");
	fprintf(stderr, "Usage   : %s [options] <nt2nt|aa2aa|nt2aa|splice> <seq1> <seq2>\n\n", prog);
	fprintf(stderr, "Options : -f       generate full alignment\n");
	fprintf(stderr, "          -a       do not apply matrix mean in local alignment\n");
	fprintf(stderr, "          -d       just calculate alignment boundaries\n");
	fprintf(stderr, "          -o NUM   gap open penalty\n");
	fprintf(stderr, "          -e NUM   gap extension penalty\n");
	fprintf(stderr, "          -n NUM   gap end penalty for nt2nt or aa2aa\n");
	fprintf(stderr, "          -s NUM   frame-shift penalty for aa2nt\n");
	fprintf(stderr, "          -g NUM   good splicing penalty\n");
	fprintf(stderr, "          -w NUM   band-width\n");
	fprintf(stderr, "          -b NUM   bad splicing penalty\n");
	fprintf(stderr, "          -m       output miscellaneous information\n");
	fprintf(stderr, "          -h       help\n\n");
	exit(1);
}

int pwalign_task(int argc, char *argv[])
{
	AlnParam ap;
	int gap_open, gap_ext, gap_end, fs;
	int good_splice, bad_splice, band_width;
	int c, type = ALN_LOCAL_ALIGN;
	int misc_flag = 0, matrix_mean = 1;
	FILE *fp1, *fp2;

	band_width = gap_open = gap_ext = gap_end = fs = good_splice = bad_splice = -1;
	while ((c = getopt(argc, argv, "fadhmo:e:n:s:b:g:w:")) >= 0) {
		switch (c) {
			case 'a': matrix_mean = 0; break;
			case 'd': type = ALN_BOUND_ALIGN; break;
			case 'f': type = ALN_GLOBAL_ALIGN; break;
			case 'o': gap_open = atoi(optarg); break;
			case 'e': gap_ext = atoi(optarg); break;
			case 'n': gap_end = atoi(optarg); break;
			case 'g': good_splice = atoi(optarg); break;
			case 'b': bad_splice = atoi(optarg); break;
			case 's': fs = atoi(optarg); break;
			case 'w': band_width = atoi(optarg); break;
			case 'm': misc_flag = 1; break;
			case 'h': pwalign_usage(argv[0]); break;
		}
	}
	if (optind + 3 != argc) pwalign_usage(argv[0]);
	if (!strcmp(argv[optind], "nt2nt")) {
		ap = aln_param_nt2nt;
	} else if (!strcmp(argv[optind], "aa2aa")) {
		ap = aln_param_aa2aa;
	} else if (!strcmp(argv[optind], "nt2aa")) {
		ap = aln_param_aa2nt;
	} else if (!strcmp(argv[optind], "splice")) {
		if (matrix_mean) ap = aln_param_splice2;
		else ap = aln_param_splice;
	} else {
		fprintf(stderr, "ERROR: valid types are nt2nt, aa2aa, nt2aa or splice\n");
		exit(2);
	}
	if (gap_open >= 0) ap.gap_open = gap_open;
	if (gap_ext >= 0) ap.gap_ext = gap_ext;
	if (gap_end >= 0) ap.gap_end = gap_end;
	if (fs >= 0) ap.frame_shift = fs;
	if (good_splice >= 0) ap.good_splice = good_splice;
	if (bad_splice >= 0) ap.bad_splice = bad_splice;
	if (band_width >= 0) ap.band_width = band_width;
	/* I forget what this line is for. Now I comment it. 2006-01-16 */
	/* if (matrix_mean != 0 && type != ALN_GLOBAL_ALIGN) aln_apply_matrix_mean(&ap); */
	
	fp1 = fopen(argv[optind+1], "r");
	fp2 = fopen(argv[optind+2], "r");
	if (!fp1 || !fp2) {
		fprintf(stderr, "ERROR: file open error\n");
		exit(3);
	}
	aln_pair_align(fp1, fp2, &ap, type, misc_flag);
	fclose(fp1); fclose(fp2);
	return 0;
}
