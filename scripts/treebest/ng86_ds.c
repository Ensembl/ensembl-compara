/***
 * Author: Du Wenfeng and liheng
 * Created: unknown
 * Last MDF: 2005-01-22
 *
 * 2005-01-22 liheng
 *
 *     * remove dm distance
 */
/*
 * written by Du Wenfeng <duwf@genomics.org.cn>, and modified by <lh3@sanger.ac.uk>
 */
#include <math.h>
#include <stdlib.h>
#include "align.h"
#include "ng86_ds.h"
#include "align_lib/table.h"

static float *ds_smut = 0;
static float *ds_nmut = 0;

void ma_init_nucl_data()
{
	int i, j;
	if (ds_smut && ds_nmut) return; /* have already been initialized */
	ds_smut = (float*)malloc(sizeof(float) * 64 * 64);
	ds_nmut = (float*)malloc(sizeof(float) * 64 * 64);
	for (i = 0; i < 64; ++i) {
		for (j = 0; j < 64; ++j) {
			if (aln_trans_table_eu[i] < 20 && aln_trans_table_eu[j] < 20) {
				if (diff_path[i][j] == 0)
					fprintf(stderr, "WARNING: Unknown error occurs to d_n/d_s initialization!\n");
				ds_smut[(i<<6)|j] = (float)diff_smut[i][j] / diff_path[i][j];
				ds_nmut[(i<<6)|j] = (float)diff_nmut[i][j] / diff_path[i][j];
			} else ds_smut[(i<<6)|j] = ds_nmut[(i<<6)|j] = 0;
		}
	}
}
void ma_free_nucl_data()
{
	free(ds_smut);
	free(ds_nmut);
	ds_smut = ds_nmut = 0;
}
/*
 * calculate nucleotide distance
 *
 * When dist_type == DIST_DM and mat_dn != 0, both mat and mat_dn will be filled with
 * dS and dN, respectively.
 */
void ma_cal_nucl_aux(Matrix *mat, const MultiAlign *ma, int is_rand, int dist_type, Matrix *mat_dn)
{
	int l, i, j, k;
	int *array;
	char *seqi, *seqj;
	float ds, max_ds;
	float dn, max_dn;
	int count;

	assert(mat); assert(ma);
	l = ma->len;
	max_ds = max_dn = -1.0;
	array = (int*)malloc(sizeof(int) * l);
	/* initialize mat and mat_dn */
	for (i = 0; i < ma->n * ma->n; ++i)
		mat->dist[i] = -1.0;
	if (dist_type == DIST_DM && mat_dn) {
		for (i = 0; i < ma->n * ma->n; ++i)
			mat_dn->dist[i] = -1.0;
	}
	for (i = 0; i < l; ++i)
#ifdef _WIN32
		if (is_rand) array[i] = (int)((double)rand() / RAND_MAX * l);
#else
		if (is_rand) array[i] = (int)(drand48() * l);
#endif
		else array[i] = i;

	for (i = 0; i < ma->n; ++i) {
		seqi = ma->seq[i];
		for (j = 0; j < i; ++j) {
			int ci, cj;
			float poti, potj, s_diff, n_diff;
			seqj = ma->seq[j];
			count = 0;
			poti = potj = s_diff = n_diff = 0.0;
			for (k = 0, count = 0; k < l; ++k) { /* core loop */
				ci = seqi[array[k]]; cj = seqj[array[k]];
				if (aln_trans_table_eu[ci] >= 20 || aln_trans_table_eu[cj] >= 20) continue;
				++count;
				poti += pot_smut[ci];
				potj += pot_smut[cj];
				if (ci != cj) {
					s_diff += ds_smut[(ci<<6)|cj];
					n_diff += ds_nmut[(ci<<6)|cj];
				}
			}
			if (count > 0 && poti + potj > 0 && count*6 - poti - potj > 0) {
				float s_avg, n_avg;
				s_avg = (poti + potj) / 2.0;
				n_avg = count * 3.0 - s_avg;
				ds = s_diff / s_avg;
				dn = n_diff / n_avg;
				if (dist_type == DIST_DN) /* calculate dn */
					mat->dist[i * ma->n + j] = mat->dist[j * ma->n + i] = dn;
				else if (dist_type == DIST_DS)
					mat->dist[i * ma->n + j] = mat->dist[j * ma->n + i] = ds;
				else if (dist_type == DIST_DM && mat_dn != 0) {
					mat->dist[i * ma->n + j] = mat->dist[j * ma->n + i] = ds;
					mat_dn->dist[i * ma->n + j] = mat_dn->dist[j * ma->n + i] = dn;
				} else mat->dist[i * ma->n + j] = mat->dist[j * ma->n + i] = 0.0;
				if (ds > max_ds) max_ds = ds;
				if (dn > max_dn) max_dn = dn;
			} /* otherwise, do nothing */
		}
	}
	max_ds *= 2.0; max_dn *= 2.0;
	if (dist_type == DIST_DN) { /* calculate dn */
		for (i = 0; i < ma->n * ma->n; ++i) /* set undefined distance as 2 * max_dn */
			if (mat->dist[i] < 0.0) mat->dist[i] = max_dn;
	} else if (dist_type == DIST_DS) {
		for (i = 0; i < ma->n * ma->n; ++i) /* set undefined distance as 2 * max_ds */
			if (mat->dist[i] < 0.0) mat->dist[i] = max_ds;
	} else if (dist_type == DIST_DM && mat_dn != 0) {
		for (i = 0; i < ma->n * ma->n; ++i) { /* set undefined distance */
			if (mat->dist[i] < 0.0) mat->dist[i] = max_ds;
			if (mat_dn->dist[i] < 0.0) mat_dn->dist[i] = max_dn;
		}
	}
	for (i = 0; i < ma->n; ++i) /* set diag as 0 */
		mat->dist[i * ma->n + i] = 0.0;
	if (dist_type == DIST_DM && mat_dn) {
		for (i = 0; i < ma->n; ++i) /* set diag as 0 */
			mat_dn->dist[i * ma->n + i] = 0.0;
	}
	free(array);
}
void ma_cal_nucl(Matrix *mat, const MultiAlign *ma, int is_rand, int dist_type)
{
	assert(mat); assert(ma);
	ma_cal_nucl_aux(mat, ma, is_rand, dist_type, 0);
}
