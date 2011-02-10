#ifndef MAKE_DS_H_
#define MAKE_DS_H_

int seq[64][3];

const int aa[65] = {
	11,11, 2, 2,  1, 1,15,15, 16,16,16,16,  9,12, 9, 9,
	 6, 6, 3, 3,  7, 7, 7, 7,  0, 0, 0, 0, 19,19,19,19,
	 5, 5, 8, 8,  1, 1, 1, 1, 14,14,14,14, 10,10,10,10,
	20,20,18,18, 20,17, 4, 4, 15,15,15,15, 10,10,13,13, 21,
};
/* A, T, G, C */
/*const int aa[64] = {
 8, 11,  8, 11,  7,  7, 10,  7, 14, 15, 14, 15, 16, 16, 16, 16,
20, 19, 20, 19,  9,  4,  9,  4, 20,  1, 18,  1, 15, 15, 15, 15,
 3,  2,  3,  2, 17, 17, 17, 17,  5,  5,  5,  5,  0,  0,  0,  0,
13,  6, 13,  6,  9,  9,  9,  9, 14, 14, 14, 14, 12, 12, 12, 12
};*/
const int stopcodon = 20;
const int other[4][3] = {{1,2,3},{0,2,3},{0,1,3},{0,1,2}};


struct dsresult {
	int ns, nn, np;
	double s1, s2;
};

int substitution(int *, int [][3][3]);
struct dsresult calc_ds(int, int, int);
int readcodon(int *, int, int);
void potential_mut(int *, double *);
int mut(int *, int *, int *, int, int *, int, int *);
int calc_codon(int *);

#endif /* #ifndef DS_H */
