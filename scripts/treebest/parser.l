%{
#include <stdlib.h>
#include <string.h>
#include "y.tab.h"

#define MAX_TOKEN 4096

double lastfnum;
char lastid[MAX_TOKEN];
int lineno = 0;
int read_bootstrap = 0;

static YY_BUFFER_STATE buffer = 0;

int yylex();
void alloc_str_buffer(const char *str);
void alloc_file_buffer(FILE *fp);
void free_buffer();

int yywrap(void) { return 1; }
%}

letter		[a-zA-Z]
num			[0-9]
sign		("+"|"-")
iden		[^ \t\r\n:,;&()\[\]=]+
dist		":"{blank}*{sign}?(([0-9]+?"."[0-9]+([Ee]{sign}?[0-9]+)?)|([0-9]+[Ee]{sign}?[0-9]+)|[0-9]+)
blank		" "|"\t"|"\n"|"\r"
nhx			&&NHX
comment		\[(({blank}*)|({blank}*[^&\[\]][^\[\]]*))\]

%%

{dist}		{ lastfnum = atof(yytext + 1); return TR_DIST; }
{iden}		{
				if (strlen(yytext) >= MAX_TOKEN) yytext[MAX_TOKEN-1] = '\0';
				strcpy(lastid, yytext); return TR_ID;
			}
{nhx}		{ return TR_NHX; }
{comment}	{}
{blank}		{ if (*yytext == '\n') ++lineno; }
.			{ return *yytext; }

%%

void alloc_str_buffer(const char *str)
{
	buffer = yy_scan_string(str);
}
void alloc_file_buffer(FILE *fp)
{
	buffer = yy_create_buffer(fp, YY_BUF_SIZE);
	yy_switch_to_buffer(buffer);
}
void free_buffer()
{
	yy_delete_buffer(buffer);
	buffer = 0;
}
