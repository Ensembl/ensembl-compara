#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "align.h"
#include "align_lib/seq.h"
#include "align_lib/table.h"
#include "cpp_utils.h"

#define MA_BLOCK 64
#define MAX_NAME_LEN 255
#define SMOOTH_STEP 5
#define QUAL_CUT_OFF 10
#define MAX_FASTA_ANNO 8192

/* This is a table of estimated PAMs for a range of percentage-differences,
   ranging from 75% dissimilarity, going up in 0.1% steps, to 93%
   dissimilarity. For percentage dissimilarty outside this range, we either
   use Kimura's formula (for < 75) or give an arbitrarily high distance 
   (for > 93) */

static int dayhoff_pams[]={
  195,   /* 75.0% observed d; 195 PAMs estimated = 195% estimated d */
  196,   /* 75.1% observed d; 196 PAMs estimated */
                  197,    198,    199,    200,    200,    201,    202,  203,    
  204,    205,    206,    207,    208,    209,    209,    210,    211,  212,    
  213,    214,    215,    216,    217,    218,    219,    220,    221,  222,    
  223,    224,    226,    227,    228,    229,    230,    231,    232,  233,    
  234,    236,    237,    238,    239,    240,    241,    243,    244,  245,    
  246,    248,    249,    250,    /* 250 PAMs = 80.3% observed d */          
                                  252,    253,    254,    255,    257,  258,    
  260,    261,    262,    264,    265,    267,    268,    270,    271,  273,    
  274,    276,    277,    279,    281,    282,    284,    285,    287,  289,    
  291,    292,    294,    296,    298,    299,    301,    303,    305,  307,    
  309,    311,    313,    315,    317,    319,    321,    323,    325,  328,    
  330,    332,    335,    337,    339,    342,    344,    347,    349,  352,    
  354,    357,    360,    362,    365,    368,    371,    374,    377,  380,    
  383,    386,    389,    393,    396,    399,    403,    407,    410,  414,    
  418,    422,    426,    430,    434,    438,    442,    447,    451,  456,    
  461,    466,    471,    476,    482,    487,    493,    498,    504,  511,    
  517,    524,    531,    538,    545,    553,    560,    569,    577,  586,    
  595,    605,    615,    626,    637,    649,    661,    675,    688,  703,    
  719,    736,    754,    775,    796,    819,    845,    874,    907,  945,
         /* 92.9% observed; 945 PAMs */    
  988    /* 93.0% observed; 988 PAMs */
};

MultiAlign *ma_alloc()
{
	MultiAlign *ma;
	ma = (MultiAlign*)malloc(sizeof(MultiAlign));
	ma->n = ma->max = 0;
	ma->len = 0;
	ma->name = 0;
	ma->seq = 0;
	ma->gene = 0;
	ma->comment = 0;
	ma->is_nucl = 0;
	ma->ori_nucl = 0;
	return ma;
}
void ma_free(MultiAlign *ma)
{
	int i;
	if (ma == 0) return;
	for (i = 0; i < ma->n; ++i) {
		if (ma->name) free(ma->name[i]); /* ma->name might be freed elsewhere */
		if (ma->gene) free(ma->gene[i]);
		if (ma->comment) free(ma->comment[i]);
		free(ma->seq[i]);
	}
	free(ma->name);
	free(ma->seq);
	free(ma->gene);
	free(ma->comment);
	free(ma);
}
static void ma_add_to_ma(MultiAlign *ma, seq_t *seq, char *name, char *comment)
{
	int len = seq->l;
	int is_nucl = ma->is_nucl;
	int i, c;
	char *p;

	if (ma->len < 0) ma->len = len;
	else if (ma->len != len) {
		fprintf(stderr, "[ma_add_to_ma] variable length in multialignment! skip!\n");
		return;
	}
	if (ma->n == ma->max) {
		ma->max += MA_BLOCK;
		ma->seq = (char**)realloc(ma->seq, sizeof(char*) * ma->max);
		ma->name = (char**)realloc(ma->name, sizeof(char*) * ma->max);
		ma->gene = (char**)realloc(ma->gene, sizeof(char*) * ma->max);
		ma->comment = (char**)realloc(ma->comment, sizeof(char*) * ma->max);
		for (i = ma->n; i < ma->max; ++i)
			ma->seq[i] = ma->name[i] = ma->gene[i] = ma->comment[i] = 0;
	}
	ma->name[ma->n] = (char*)malloc(sizeof(char) * (strlen(name) + 1));
	strcpy(ma->name[ma->n], name);
	if (comment[0]) { /* has gene name */
		ma->comment[ma->n] = cpystr(comment);
		for (p = comment; *p && *p != '\t' && *p != ' ' && *p != '\r'; ++p);
		*p = '\0';
		ma->gene[ma->n] = cpystr(comment);
	}
	p = ma->seq[ma->n] = (char*)malloc(sizeof(char) * (seq->l + 1));
	if (!is_nucl) { /* protein alignment */
		for (i = 0; i < seq->l; ++i) {
			c = seq->s[i];
			if (c == '.' || c == '~') p[i] = ALN_AA_GAP; /* a gap. '-' will be handled next line. */
			else p[i] = aln_aa_table[(unsigned char)seq->s[i]];
		}
	} else { /* nucleotide alignment */
		for (i = 0; i < seq->l; ++i) {
			c = seq->s[i];
			if (c == '.' || c == '~') p[i] = ALN_NT4_GAP; /* gap */
			else p[i] = aln_nt4_table[(unsigned char)seq->s[i]];
		}
	}
	p[i] = '\0';
	++(ma->n);
}
MultiAlign *ma_read_alignment(FILE *fp, int is_nucl)
{
	MultiAlign *ma;
	seq_t seq;
	char name[MAX_NAME_LEN], *buffer;

	assert(fp);
	INIT_SEQ(seq);
	ma = ma_alloc(); ma->is_nucl = is_nucl; ma->len = -1;
	buffer = (char*)malloc(sizeof(char) * MAX_FASTA_ANNO);
	while (read_fasta(fp, &seq, name, buffer) >= 0)
		ma_add_to_ma(ma, &seq, name, buffer);
	free(seq.s); free(buffer);
	cpp_check_align_name(ma);
	return ma;
}
MultiAlign *ma_read_alignment_str(char *buffer, int is_nucl)
{
	MultiAlign *ma;
	seq_t seq;
	char name[MAX_NAME_LEN], *comment, *ptr;

	assert(buffer);
	INIT_SEQ(seq);
	ma = ma_alloc(); ma->is_nucl = is_nucl; ma->len = -1;
	comment = (char*)malloc(sizeof(char) * MAX_FASTA_ANNO);
	ptr = buffer;
	while (read_fasta_str(ptr, &seq, name, buffer, &ptr) >= 0)
		ma_add_to_ma(ma, &seq, name, comment);
	free(seq.s); free(comment);
	cpp_check_align_name(ma);
	return ma;
}
AlignQual *ma_alloc_AlignQual(const MultiAlign *ma)
{
	AlignQual *aq;
	int i;
	assert(ma);
	aq = (AlignQual*)malloc(sizeof(AlignQual));
	aq->n = ma->n;
	aq->len = ma->len;
	aq->pos_qual = (int*)malloc(sizeof(int) * aq->len);
	aq->seq_qual = (double*)malloc(sizeof(double) * aq->n);
	for (i = 0; i < aq->len; ++i)
		aq->pos_qual[i] = 0.0;
	for (i = 0; i < aq->n; ++i)
		aq->seq_qual[i] = 0.0;
	return aq;
}
void ma_free_AlignQual(AlignQual *aq)
{
	if (aq == 0) return;
	free(aq->seq_qual);
	free(aq->pos_qual);
	free(aq);
}
/* Calculate multi-alignment quality for each sequence and each position.
 * Positional score is almost exactly the same as that as implemented in
 * ClustalX with score_scale equal to 5. Sequence score is actually the
 * profile score with simple gap model. */
AlignQual *ma_cal_qual(const MultiAlign *ma)
{
	AlignQual *aq;
	int i, j, k, l, n, len, sum;
	int F[ALN_AA_GAP+1], *row;
	char **seq;
	double fsum, X[ALN_AA_GAP], *dist;
	int *tmp_mat, n_row;
	int *smooth_array;

	assert(ma);
	n_row = ALN_AA_GAP + 1; /* number of characters in tmp_mat */
	len = ma->len;
	n = ma->n;
	seq = ma->seq;
	aq = ma_alloc_AlignQual(ma);
	tmp_mat = (int*)malloc(sizeof(int) * n_row * n_row);
	dist = (double*)malloc(sizeof(double) * n);
	smooth_array = (int*)malloc(sizeof(int) * len);

	/* make a positive matrix from BLOSUM62 and add gap penalty */
	for (i = 0; i < ALN_AA_GAP; ++i) /* copy blosum62+4 */
		for (j = 0; j < ALN_AA_GAP; ++j)
			tmp_mat[i * n_row + j] = aln_sm_blosum62[i * ALN_AA_GAP + j] + 4;
	for (i = 0; i < ALN_AA_GAP; ++i) /* set gap penalty */
		tmp_mat[i * n_row + ALN_AA_GAP] = tmp_mat[ALN_AA_GAP * n_row + i] = 0;
	tmp_mat[ALN_AA_GAP * n_row + ALN_AA_GAP] = 4; /* equivalent to S['-']['-'] = 0 */

	/* core loop */
	for (j = 0; j < len; ++j) {
		for (k = 0; k < n_row; ++k) F[k] = 0; /* clear */
		for (i = 0; i < n; ++i) /* count */
			++F[(int)seq[i][j]];
		for (i = 0; i < n; ++i) {
			/* compute X[] array */
			for (k = 0; k < ALN_AA_GAP; ++k) { /* no X['-'] here */
				row = tmp_mat + k * n_row;
				for (l = 0, sum = 0; l < ALN_AA_GAP; ++l)
					sum += F[l] * row[l];
				X[k] = (double)sum / n;
			}
			row = tmp_mat + seq[i][j] * n_row;
			for (k = 0, fsum = 0.0; k < ALN_AA_GAP; ++k) /* NB: not count gap */
				fsum += (X[k] - row[k]) * (X[k] - row[k]);
			/* NB: if seq[i][j] == ALN_AA_GAP, dist[i] will not be counted in 're-scale' step */
			dist[i] = sqrt(fsum);
		}
		/* re-scale */
		for (i = 0, fsum = 0.0, k = 0; i < n; ++i) {
			if (seq[i][j] != ALN_AA_GAP) {
				fsum += dist[i];
				++k;
			}
		}
		/* calculate positional quality */
		aq->pos_qual[j] = (k == 0)? 0 : (int)(exp(-fsum/k/QUAL_SCALE) * 100.0 * k / n + 0.5);
	}
	/* triangular smooth */
	k = SMOOTH_STEP / 2;
	for (j = k; j < len - k; ++j) {
		fsum = aq->pos_qual[j];
		for (i = j-k; i < j; ++i)
			fsum += aq->pos_qual[i] * (1 - (j-i) / (k + 1.0));
		for (i = j+1; i <= j + k; ++i)
			fsum += aq->pos_qual[i] * (1 - (i-j) / (k + 1.0));
		fsum /= k + 1.0;
		smooth_array[j] = (int)(fsum + 0.5);
		/* sometimes, a nearly gapped column might has a quality over QUAL_CUT_OFF
		 * due to this smooth strategy. So we add an additional condition: */
		if (smooth_array[j] >= QUAL_CUT_OFF) {
			for (l = 0, sum = 0; l < n; ++l)
				if (seq[l][j] != ALN_AA_GAP) ++sum;
			if ((double)sum / n < QUAL_MIN_RES) /* there should not be so many '-'. */
				smooth_array[j] = QUAL_CUT_OFF - 1;
		}
	}
	for (j = k; j < len - k; ++j)
		aq->pos_qual[j] = smooth_array[j];
	/* calculate seq_qual */
	for (j = 0; j < len; ++j) {
		if (aq->pos_qual[j] < QUAL_CUT_OFF) continue;
		for (k = 0; k < n_row; ++k) F[k] = 0; /* clear */
		for (i = 0; i < n; ++i) /* count */
			++F[(int)seq[i][j]];
		for (i = 0; i < n; ++i) {
			/* calculate i-th sequence score based on the profile */
			row = tmp_mat + seq[i][j] * n_row;
			for (k = 0, fsum = 0.0; k < n_row; ++k)
				fsum += (double)((row[k]-4) * F[k]) / n; /* use the original BLOSUM score */
			aq->seq_qual[i] += fsum;
		}
	}

	free(smooth_array);
	free(tmp_mat);
	free(dist);
	return aq;
}
void ma_debug_qual(const MultiAlign *ma, const AlignQual *aq)
{
	int i, j;
	assert(ma); assert(aq);
	for (i = 0; i < ma->n; ++i) {
		fprintf(stderr, "%-11.6f ", aq->seq_qual[i]);
		for (j = 0; j < ma->len; ++j)
			fputc(aln_aa_rev_table[(int)ma->seq[i][j]], stderr);
		fprintf(stderr, " %-40s\t%s\n", ma->name[i], ma->gene[i]);
	}
	fprintf(stderr, "*********** ");
	for (j = 0; j < ma->len; ++j)
		fprintf(stderr, "%c", (char)('0'+(int)(aq->pos_qual[j]/10.0)));
}
Matrix *ma_init_small_matrix(MultiAlign *ma)
{
	Matrix *mat;
	mat = (Matrix*)malloc(sizeof(Matrix));
	mat->count = ma->n;
	mat->name = ma->name;
	mat->dist = (float*)malloc(sizeof(float) * ma->n * ma->n);
	return mat;
}
/* note here does not return a Matrix */
void ma_cal_mm_dist(Matrix *mat, const MultiAlign *ori_ma, int is_rand, int is_kimura, int *pre_array)
{
	int l, i, j, k;
	int *array;
	char *seqi, *seqj;
	float d, max_d;
	int count, match;
	int max_num;
	const MultiAlign *ma = (ori_ma->ori_nucl)? ori_ma->ori_nucl : ori_ma;

	assert(mat); assert(ma);
	max_num = (ma->is_nucl)? 4 : 20;
	if (ma->is_nucl) is_kimura = 0;
	l = ma->len;
	max_d = -1.0;
	for (i = 0; i < ma->n * ma->n; ++i)
		mat->dist[i] = -1.0;
	if (pre_array == 0) {
		array = (int*)malloc(sizeof(int) * l);
		for (i = 0; i < l; ++i)
#ifdef _WIN32
			if (is_rand) array[i] = (int)((double)rand() / RAND_MAX * l);
#else
			if (is_rand) array[i] = (int)(drand48() * l);
#endif
			else array[i] = i;
	} else array = pre_array;

	for (i = 0; i < ma->n; ++i) {
		seqi = ma->seq[i];
		for (j = 0; j < i; ++j) {
			int tmp;
			seqj = ma->seq[j];
			for (k = 0, count = match = 0; k < l; ++k) {
				tmp = array[k];
				if (seqi[tmp] >= max_num || seqj[tmp] >= max_num) continue; /* one is a gap. */
				if (seqi[tmp] != seqj[tmp]) ++match;
				++count;
			}
			if (count > 0) {
				d = (float)match / count;
				if (is_kimura) { /* kimura correction */
					if (d < 0.75)
						d = -log(1.0 - d - (d * d * 0.2));
					else if (d > 0.930) d = 10.0;
					else {
						d = (float)dayhoff_pams[(int)(d * 1000.0 - 750.0 + 0.5)];
						d /= 100.0;
					}
				}
				mat->dist[i * ma->n + j] = mat->dist[j * ma->n + i] = d;
				if (d > max_d) max_d = d;
			} /* otherwise, do nothing */
		}
	}
	if (pre_array == 0) { /* do not do this when the array is given. */
		max_d *= 2.0;
		for (i = 0; i < ma->n * ma->n; ++i) /* set undefined distance as 2 * max_d */
			if (mat->dist[i] < 0.0) mat->dist[i] = max_d;
		for (i = 0; i < ma->n; ++i) /* set diag as 0 */
			mat->dist[i * ma->n + i] = 0.0;
		free(array);
	}
}
MultiAlign *ma_trans_align(const MultiAlign *ma, int is_trans)
{
	MultiAlign *tma;
	int i, n, ret;

	assert(ma);
	if (ma->len%3 != 0 || ma->is_nucl == 0) {
		fprintf(stderr, "[ma_trans_align] not seem to be a nucleotide alignment (%d).\n", ma->len);
		return 0;
	}
	tma = ma_alloc();
	tma->max = tma->n = n = ma->n;
	tma->len = ma->len/3;
	tma->is_nucl = 0;
	tma->name = (char**)malloc(sizeof(char*) * n);
	tma->seq = (char**)malloc(sizeof(char*) * n);
	if (ma->gene) tma->gene = (char**)malloc(sizeof(char*) * n);
	else tma->gene = 0;
	if (ma->comment) tma->comment = (char**)malloc(sizeof(char*) * n);
	else tma->comment = 0;
	for (i = 0; i < n; ++i) {
		tma->name[i] = cpystr(ma->name[i]);
		if (ma->gene && ma->gene[i]) tma->gene[i] = cpystr(ma->gene[i]);
		else tma->gene[i] = 0;
		if (ma->comment && ma->comment[i]) tma->comment[i] = cpystr(ma->comment[i]);
		else tma->comment[i] = 0;
		tma->seq[i] = (char*)malloc(sizeof(char) * (tma->len + 1));
		if ((ret = aln_trans_seq(ma->seq[i], ma->len, tma->seq[i], is_trans))) {
			if (ret == 2) fprintf(stderr, "[ma_trans_align] phase error in translating %s\n", ma->name[i]);
			tma->n = i;
			ma_free(tma);
			return 0;
		}
	}
	tma->ori_nucl = (MultiAlign*)ma;
	return tma;
}
Matrix *ma_init_matrix(const MultiAlign *ma)
{
	Matrix *mat;
	int i;

	assert(ma);
	mat = (Matrix*)malloc(sizeof(Matrix));
	mat->count = ma->n;
	mat->name = (char**)malloc(sizeof(char*) * ma->n);
	for (i = 0; i < ma->n; ++i)
		mat->name[i] = cpystr(ma->name[i]);
	mat->dist = (float*)malloc(sizeof(float) * ma->n * ma->n);
	return mat;
}
