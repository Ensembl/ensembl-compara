#include <stdlib.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include "align.h"
#include "common/hash_char.h"
#include "align_lib/table.h"

MultiAlign *ma_read(FILE *fp, int is_nucl, int is_aln)
{
	assert(fp);
	int c = fgetc(fp);
	ungetc(c, fp);
	if (is_aln < 0) is_aln = (c == 'C')? 1 : 0;
	if (is_aln) return ma_read_aln_alignment(fp, is_nucl);
	else return ma_read_alignment(fp, is_nucl);
}
MultiAlign *ma_read_aln_alignment(FILE *fp, int is_nucl)
{
	char name[256];
	hash_map_char<int> *hash;
	int n, k, l, i, b_max, *cur_len, c;
	char *buffer;
	MultiAlign *ma;

	assert(fp);
	ma = ma_alloc();
	buffer = 0;
	b_max = 0;
	cur_len = 0;
	hash = new hash_map_char<int>;
	/* skip first line */
	while ((c = fgetc(fp)) != '\n' && c != EOF);

	n = 0; cur_len = 0;
	while (!feof(fp)) {
		if (c == EOF) break;
		c = fgetc(fp);
		if (c == EOF) break;
		ungetc(c, fp);
		if (isalpha(c) || isdigit(c)) {
			fscanf(fp, "%s", name);
			l = 0;
			while ((c = fgetc(fp)) != '\n' && c != EOF) { /* read alignment */
				if (c == '.' || c == '~' || c == '-' || isalpha(c)) {
					if (c == '.' || c == '~') c = (is_nucl)? ALN_NT4_GAP : ALN_AA_GAP;
					else c = (is_nucl)? aln_nt4_table[(unsigned char)c] : aln_aa_table[(unsigned char)c];
					if (l == b_max) {
						b_max += 1024;
						buffer = (char*)realloc(buffer, sizeof(char) * b_max);
					}
					buffer[l++] = c;
				}
			}
			buffer[l] = '\0';
			if (!hash->find(name, &k)) {
				hash->insert(name, n);
				if (n == ma->max) {
					ma->max += 16;
					cur_len = (int*)realloc(cur_len, sizeof(int) * ma->max);
					ma->name = (char**)realloc(ma->name, sizeof(char*) * ma->max);
					ma->seq = (char**)realloc(ma->seq, sizeof(char*) * ma->max);
					for (i = ma->max - 16; i < ma->max; ++i) {
						cur_len[i] = 0;
						ma->name[i] = 0;
						ma->seq[i] = 0;
					}
				}
				k = ma->n = n;
				++n;
			}
			ma->name[k] = (char*)malloc(sizeof(char) * (strlen(name) + 1));
			strcpy(ma->name[k], name);
			cur_len[k] += l;
			ma->seq[k] = (char*)realloc(ma->seq[k], sizeof(char) * (cur_len[k] + 1));
			memcpy(ma->seq[k] + cur_len[k] - l, buffer, l);
		} else while ((c = fgetc(fp)) != '\n' && c != EOF);
	}
	if (n == 0) { ma_free(ma); return 0; }
	l = cur_len[0];
	for (k = 1; k < n; ++k) {
		if (cur_len[k] != l) {
			fprintf(stderr, "[ma_read_aln_alignment] fail to parse ALN format.\n");
			ma_free(ma); return 0;
		}
	}
	ma->max = ma->n = n;
	ma->len = cur_len[0];
	ma->is_nucl = is_nucl;
	free(buffer);
	free(cur_len);
	delete hash;
	return ma;
}
