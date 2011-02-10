#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.h"

#ifdef USE_KR_ALLOC
const double KR_1MB = 1048576.0;

typedef struct _header_
{
	struct _header_ *ptr; /* next free block */
	size_t size; /* size of current free block */
} HEADER;

static HEADER base;
static HEADER *allocp = 0; /* the last and also the first free block */
static size_t kr_total_allocated = 0;

void fatal_error(const char *s)
{
	fprintf(stderr, "MEMORY LEAK: %s\n", s);
	exit(1);
}
static HEADER *morecore(size_t nu)
{
	extern void kr_check_list();
	extern void kr_free(void*);
	size_t rnu;
	HEADER *up;

	rnu = (nu + 0xffff) & (~(size_t)(0xffff));
	up = (HEADER*)malloc(rnu * sizeof(HEADER));
	if (!up) {
		kr_check_list();
		fprintf(stderr, "%.3f Mbytes requested but not available.\n", rnu * sizeof(HEADER) / KR_1MB);
		exit(1);
	}
	kr_total_allocated += rnu * sizeof(HEADER);
	up->size = rnu;
	kr_free(up + 1);
	return allocp;
}
void kr_free(void *ap)
{
	HEADER *p, *q;
	
	if (!ap) return;
	p = (HEADER*)ap - 1;
	for (q = allocp; !(p > q && p < q->ptr); q = q->ptr)
		if (q >= q->ptr && (p > q || p < q->ptr)) break;
	
	if (p + p->size == q->ptr) { /* in one continuous huge block, merge */
		p->size += q->ptr->size;
		p->ptr = q->ptr->ptr;
	} else if (p + p->size > q->ptr && q->ptr >= p) {
		fatal_error("cross-linked list (kr_free[1])");
	} else p->ptr = q->ptr; /* separated blocks, do not merge */
	
	if (q + q->size == p) { /* in one continuous huge block */
		q->size += p->size;
		q->ptr = p->ptr;
	} else if (q + q->size > p && p >= q) {
		fatal_error("cross-linked list (kr_free[2])");
	} else q->ptr = p; /* separated block, do not merge */

	allocp = q;
}
void *kr_realloc(void *ap, size_t nbytes)
{
	extern void *kr_alloc(size_t);
	HEADER *p, *q;
	size_t nunits;
	
	if (!ap) return kr_alloc(nbytes);
	nunits = 1 + (nbytes + sizeof(HEADER) - 1) / sizeof(HEADER);
	p = (HEADER*)ap - 1;
	if (p->size >= nunits) return ap;
	q = (HEADER*)kr_alloc(nbytes);
	memcpy(q, ap, (p->size  - 1) * sizeof(HEADER));
	kr_free(ap);
	return q;
}
void *kr_alloc(size_t nbytes)
{
	HEADER *p, *q;
	size_t nunits;

	nunits = 1 + (nbytes + sizeof(HEADER) - 1) / sizeof(HEADER);
	if (!(q = allocp)) {
		base.ptr = allocp = q = &base;
		base.size = 0;
	}
	for (p = q->ptr;; q = p, p = p->ptr) {
		if (p->size >= nunits) {
			if (p->size == nunits) q->ptr = p->ptr;
			else {
				p->size -= nunits;
				p += p->size;
				p->size = nunits;
			}
			allocp = q;
			return p + 1;
		}
		if (p == allocp)
			if (!(p = morecore(nunits))) return 0;
	}
}
void kr_check_list()
{
	unsigned n_blocks, n_ends, n_units;
	HEADER *p, *q;
	
	p = allocp;
	n_blocks = n_ends = n_units = 0;
	do {
		q = p->ptr;
		n_units += p->size;
		if (p + p->size > q && q > p)
			fatal_error("cross-linked list (kr_check_list)");
		if (q < p) ++n_ends;
		p = q;
		++n_blocks;
	} while (p != allocp);
	
	if (n_ends != 1)
		fatal_error("Not single end in the linked list (kr_check_list)");
	fprintf(stderr, "total space: %.3f Mbytes; free space: %.3f Mbytes; fragments: %u\n",
			kr_total_allocated / KR_1MB, n_units * sizeof(HEADER) / KR_1MB, n_blocks);
}
size_t kr_size(void *ap)
{
	HEADER *p;
	p = (HEADER*)ap - 1;
	return (p->size - 1) * sizeof(HEADER);
}
#endif /* USR_KR_ALLOC */
