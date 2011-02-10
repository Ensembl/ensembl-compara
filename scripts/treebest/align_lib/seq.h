/*
 * libalign -- alignment utilities
 *
 * Copyright (c) 2003-2004, Li Heng <liheng@genomics.org.cn>
 *                                  <lihengsci@yahoo.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#ifndef SEQ_H_
#define SEQ_H_

#include <stdio.h>
#include "common/common.h"

#define SEQ_BLOCK_SIZE 512
#define SEQ_MAX_NAME_LEN 255

#define INIT_SEQ(seq) (seq).s = 0; (seq).l = (seq).m = 0

#define CHAR2QUAL(c) \
	((isdigit(c))? ((c)-'0') : ((islower(c))? ((c)-'a'+10) : ((isupper(c))? ((c)-'A'+36) : 0)))
#define QUAL2CHAR(q) \
	(((q)<10)? ((q)+'0') : (((q)<36)? ((q)-10+'a') : (((q)<62)? ((q)-36+'A') : 'Z')))

typedef struct
{
	int l, m; /* length and maximum buffer size */
	char *s; /* sequence */
} seq_t;

#ifdef __cplusplus
extern "C" {
#endif

int read_fasta(FILE*, seq_t*, char*, char*);
int read_fasta_str(char *buffer, seq_t*, char*, char*, char **ptr);
int read_qual(FILE*, seq_t*, char*, char*);

#ifdef __cplusplus
}
#endif

#endif /* SEQ_H_ */
