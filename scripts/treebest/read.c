#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "tree.h"

Matrix *tr_read_matrix(FILE *fp)
{
	int i, j, n;
	char name[256];
	Matrix *mat;
	float x;

	assert(fp);
	fscanf(fp, "%d", &n);
	mat = (Matrix*)malloc(sizeof(Matrix));
	mat->count = n;
	mat->dist = (float*)malloc(sizeof(float) * mat->count * mat->count);
	mat->name = (char**)malloc(sizeof(char*) * mat->count);

	for (i = 0; i < mat->count; ++i) {
		if (fscanf(fp, "%s", name) == 0) {
			fprintf(stderr, "[tr_read_matrix] fail to read distance matrix\n");
			tr_delete_matrix(mat);
			return 0;
		}
		mat->name[i] = (char*)malloc(sizeof(char) * (strlen(name) + 1));
		strcpy(mat->name[i], name);
		for (j = 0; j < mat->count; ++j) {
			fscanf(fp, "%f", &x);
			mat->dist[j * mat->count + i] = x;
		}
		mat->dist[i * mat->count + i] = 0.0;
	}
	return mat;
}
void tr_delete_matrix(Matrix *mat)
{
	int i;
	if (mat == 0) return;
	free(mat->dist);
	for (i = 0; i < mat->count; ++i)
		free(mat->name[i]);
	free(mat->name);
	free(mat);
}
