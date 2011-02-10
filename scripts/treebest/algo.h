#ifndef ALGORITHM_H_
#define ALGORITHM_H_

#define ALGO_LOG2 0.69314718
#ifndef ALGO_EQUAL
#define ALGO_EQUAL(a,b) ((a)=(b))
#endif /* ALGO_EQUAL */
#ifndef ALGO_CMP
#define ALGO_CMP(a,b) ((a)<(b))
#endif /* ALGO_CMP */
#define ALGO_SWAP(a,b) { ALGO_EQUAL(swap_tmp,a);ALGO_EQUAL(a,b);ALGO_EQUAL(b,swap_tmp); }

#ifdef ALGO_TYPE
#ifdef ALGO_QSORT
typedef struct
{
	size_t left,right;
} ALGO_QSortStack;

static void algo_qsort(ALGO_TYPE a[], size_t n)
{
	extern double log(double);
	extern void *malloc(size_t);
	extern void free();

	size_t s, t, i, j, k;
	ALGO_QSortStack *top, *stack;
	ALGO_TYPE rp, swap_tmp;

	if (n == 0) return;
	stack = (ALGO_QSortStack*)malloc(sizeof(ALGO_QSortStack) * (size_t)((sizeof(size_t)*log(n)/ALGO_LOG2)+2));

	top = stack; s = 0; t = n-1;
	while (1) {
		if (s < t) {
			i = s; j = t; k = (i+j)>>1; rp = a[k];
			ALGO_SWAP(a[k], a[t]);
			do {
				do { ++i; } while (ALGO_CMP(a[i], rp));
				do { --j; } while (j && ALGO_CMP(rp, a[j]));
				ALGO_SWAP(a[i], a[j]);
			} while (i < j);
			ALGO_SWAP(a[i], a[j]);
			ALGO_SWAP(a[i], a[t]);
			if (i-s > t-i) {
				if (i-s > 9) { top->left = s; top->right = i-1; ++top; }
				if (t-i > 9) s = i+1;
				else s = t;
			} else {
				if (t-i > 9) { top->left = i+1; top->right = t; ++top; }
				if (i-s > 9) t = i-1;
				else t = s;
			}
		} else {
			if (top == stack) {
				free(stack);
				for (i = 1; i < n; ++i)
					for (j = i; j > 0 && ALGO_CMP(a[j], a[j-1]); --j)
						ALGO_SWAP(a[j], a[j-1]);
				return;
			} else { --top; s = top->left; t = top->right; }
		}
	}
}
#endif /* ALGO_QSORT */
#ifdef ALGO_KSMALL
static ALGO_TYPE algo_ksmall(ALGO_TYPE array[], size_t n, size_t k)
/* Return the kth smallest value in array array[0..n-1], The input array will be rearranged
 * to have this value in array[k-1], with all smaller elements moved to arr[0..k-2] (in
 * arbitrary order) and all larger elements in arr[k..n] (also in arbitrary order) */
{
	ALGO_TYPE *arr, a, swap_tmp;
	size_t i, ir, j, l, mid;

	arr = array - 1;
	l = 1;
	ir = n;
	for (;;) {
		if (ir <= l + 1) { /* Active partition contains 1 or 2 elements */
			if (ir == l + 1 && ALGO_CMP(arr[ir], arr[l])) /* Case of 2 elements */
				ALGO_SWAP(arr[l], arr[ir]);
			return arr[k];
		} else {
			mid = (l + ir) >> 1;
			ALGO_SWAP(arr[mid], arr[l+1]);
			if (ALGO_CMP(arr[ir], arr[l])) ALGO_SWAP(arr[l], arr[ir]);
			if (ALGO_CMP(arr[ir], arr[l+1])) ALGO_SWAP(arr[l+1], arr[ir]);
			if (ALGO_CMP(arr[l+1], arr[l])) ALGO_SWAP(arr[l], arr[l+1]);
			i = l + 1; /* initialize pointers for partitioning */
			j = ir;
			a = arr[l+1]; /* partition element */
			for (;;) { /* beginning of innermost loop */
				do ++i; while (ALGO_CMP(arr[i], a)); /* scan up to find element > a */
				do --j; while (ALGO_CMP(a, arr[j])); /* scan down to find element < a */
				if (j < i) break; /* Pointers crossed. Partitioning complete. */
				ALGO_SWAP(arr[i], arr[j]);
			}
			arr[l+1] = arr[j];	/* insert partitioning element */
			arr[j] = a;
			if (j >= k) ir = j - 1; /* Keep active the partition that contains the kth element */
			if (j <= k) l = i;
		}
	}
}
#endif /* ALGO_KSMALL */
#ifdef ALGO_HEAP
void algo_heap_adjust(ALGO_TYPE l[], int i, int n)
{
	ALGO_TYPE tmp;
	int k;

	ALGO_EQUAL(tmp, l[i]);
	for (;;) {
		k = (i << 1) + 1;
		if (k >= n) {
			ALGO_EQUAL(l[i], tmp);
			return;
		}
		if (k < n - 1 && ALGO_CMP(l[k+1], l[k])) ++k;
		if (ALGO_CMP(l[k], tmp)) {
			ALGO_EQUAL(l[i], l[k]);
			i = k;
		} else {
			ALGO_EQUAL(l[i], tmp);
			return;
		}
	}
}
void algo_heap_make(ALGO_TYPE l[], int lsize)
{
	int i;
	for (i = (lsize >> 1) - 1; i >= 0; --i)
		algo_heap_adjust(l, i, lsize);
}
void algo_heap_sort(ALGO_TYPE l[], int lsize)
{
	ALGO_TYPE swap_tmp;
	int i;

	for (i = lsize - 1; i > 0; --i) {
		ALGO_SWAP(l[0], l[i]);
		algo_heap_adjust(l, 0, i);
	}
}
#endif /* ALGO_HEAP */
#endif /* ALGO_TYPE */

#endif /* ALGORITHM_H_ */
