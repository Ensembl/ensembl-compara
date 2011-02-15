#ifndef COMMON_H_
#define COMMON_H_

#include <stdlib.h>

typedef unsigned char uchar;

#ifdef USE_KR_ALLOC
#define MYALLOC   kr_alloc
#define MYFREE    kr_free
#define MYREALLOC kr_realloc

#ifdef __cplusplus
extern "C" {
#endif
void *kr_alloc(size_t);
void *kr_realloc(void*, size_t);
void kr_free(void*);
void kr_check_list();
size_t kr_size(void*);
#ifdef __cplusplus
}
#endif

#else /* USE_KR_ALLOC */
#define MYALLOC   malloc
#define MYFREE    free
#define MYREALLOC realloc
#endif /* USE_KR_ALLOC */

#endif /* COMMON_H_ */
