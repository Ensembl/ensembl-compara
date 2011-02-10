#include <math.h>
#ifdef ALN_MATRIX_DEBUG
#include <stdio.h>
#include <stdlib.h>

extern int getopt(int nargc, char * const *nargv, const char *ostr);
extern int optind, opterr;
extern char *optarg;

#endif

double aln_gen_nt_score_matrix(int *matrix, double t, double gc, double R, double beta)
{
	double theta1, theta2;
	double u, v, x, y;
	double alpha;
	double mat[25];
	double theta_tmp[4];
	double tmp, ident;
	int i, j;

	theta1 = gc;
	theta2 = 1.0 - gc;
	alpha = 2.0 * beta * R;
	theta_tmp[0] = theta_tmp[3] = theta2 / 2.0;
	theta_tmp[1] = theta_tmp[2] = theta1 / 2.0;
	u = 0.5 * (1.0 + exp(-2.0 * beta * t) - 2.0 * exp(-(alpha + beta) * t));
	v = 0.5 * (1.0 - exp(-2.0 * beta * t));
	x = (1.0 - u * theta1 - v) / theta2;
	y = (1.0 - u * theta2 - v) / theta1;
#ifdef ALN_MATRIX_DEBUG
	printf("(x,y,u,v) (%f,%f,%f,%f)\n", x, y, u, v);
#endif
	ident = x * theta2 * theta2 + y * theta1 * theta1;
	/* calculate "AGCT" score */
	for (i = 0; i != 25; ++i)
		mat[i] = log(2.0 * v);
	mat[0 * 5 + 0] = mat[3 * 5 + 3] = log(2.0 * x);
	mat[1 * 5 + 1] = mat[2 * 5 + 2] = log(2.0 * y);
	mat[0*5+1] = mat[1*5+0] = mat[2*5+3] = mat[3*5+2] = log(2.0 * u);
	/* calculate 'N' score */
	for (i = 0; i != 4; ++i) {
		for (j = 0, tmp = 0.0; j != 4; ++j)
			tmp += mat[i * 5 + j] * theta_tmp[j];
		mat[i * 5 + 4] = mat[4 * 5 + i] = tmp;
	}
	for (j = 0, tmp = 0.0; j != 4; ++j)
		tmp += mat[4 * 5 + j] * theta_tmp[j];
	mat[4 * 5 + 4] = tmp;
	/* fill matrix */
	for (i = 0, tmp = 0.0; i != 25; ++i)
		if (tmp < mat[i]) tmp = mat[i];
	for (i = 0; i != 25; ++i)
		matrix[i] = (int)(mat[i] / tmp * 100.0 + 0.5);
	return ident;
}
#ifdef ALN_MATRIX_DEBUG
void usage(const char *prog)
{
	fprintf(stderr, "Usage: %s [-t time] [-b beta] [-r R] [-c GC] [-h]\n", prog);
	exit(1);
}
int main(int argc, char *argv[])
{
	int matrix[25];
	int i, j, c;
	double id;
	double R = 1.5;
	double gc = 0.52;
	double beta = 0.18;
	double t = 1.0;

	while ((c = getopt(argc, argv, "r:b:t:c:h")) >= 0) {
		switch (c) {
			case 'r': R = atof(optarg); break;
			case 'b': beta = atof(optarg); break;
			case 't': t = atof(optarg); break;
			case 'c': gc = atof(optarg); break;
			case 'h': usage(argv[0]); break;
		}
	}
	id = aln_gen_nt_score_matrix(matrix, t, gc, R, beta);
	printf("\n");
	printf("      A     G     C     T     N\n");
	for (i = 0; i != 5; ++i) {
		printf("%c", "AGCTN"[i]);
		for (j = 0; j != 5; ++j)
			printf("%6d", matrix[i * 5 + j]);
		printf("\n");			
	}
	printf("\npercent identities = %.1f%%\n\n", id*100.0);

	return 0;
}
#endif
