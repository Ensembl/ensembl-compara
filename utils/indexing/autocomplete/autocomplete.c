/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2022] EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* autocomplete.c -- generates autocomplete suggestion dictionary. In C
 * for speed as it traverses all indices.
 *
 * link with libm (math) ie -lm
 *
 * Author: Dan Sheppard (ds23)
 */

/* This file is divided into sections identified by comments:
 * UTILS -- misc helpers used by other sections.
 * PROCESSOR -- processes words.
 * LEXER -- reads the file and breaks it into words and states.
 * CONTROLLER -- handles system interaction, logging, yadda-yadda.
 */

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <math.h>
#include <stddef.h>

#define READBUFFER 65536
int max_index_size = 100000; /* Overridden by option */

/* Fields to exclude from autocomplete altogether (with 0 on end of list) */
char * bad_fields[] = {"domain_url",0};

/************************************************************************
 * UTILS -- misc helpers used by other sections.                        *
 ************************************************************************/

struct pool {
  char **a;
  int n;
};

char * pmem(struct pool *p,int amt) {
  p->a = realloc(p->a,(p->n+1)*sizeof(char *));
  p->a[p->n] = malloc(amt);
  return p->a[p->n];
}

void pfree(struct pool *p) {
  int i;

  if(!p->a) return;
  for(i=0;i<p->n;i++)
    free(p->a[i]);
  free(p->a);
  p->a = 0;
  p->n = 0;
}

/************************************************************************
 * PROCESSOR -- processes words.                                        *
 ************************************************************************/

/* Checks for membership of list of strings. If present returns 0, else
 * returns new length with string added. Compact representation is \0
 * terminated strings, followed by extra \0. NULL is acceptable as
 * zero-length list. Cannot store empty string.
 */
int strl_member(char **str,char *data,int max) {
  char *c,*d;
  int len,n=0;
  ptrdiff_t p;

  len = strlen(data);
  if(!len)
    return 0;
  if(!*str && max) { /* Initial malloc of zero-length list */
    *str = malloc(1);
    **str = '\0';
  }
  c=*str;
  while(*c) {
    for(d=data;*c && *c == *d;c++,d++)
      ;
    if(!*c && !*d)
      return 0;
    for(;*c;c++)
      ;
    c++;
    n++;
  }
  if(max==-1 || n<max) {
    p = c-*str; /* Remap c after realloc, also = length of alloc-1 */
    *str = realloc(*str,p+len+2);
    c = *str+p;
    strcpy(c,data);
    *(c+len+1) = '\0';
    n++;
  }
  return n;
}

/* Converts to more standard string array */
char **strl_strings(char *strl) {
  int len,i;
  char **out,*d;

  if(!strl)
    return 0;
  len = 1;
  for(d=strl;*d || *(d+1);d++) {
    if(!*d)
      len++;
  }
  out = malloc(sizeof(char *)*(len+1));
  for(d=strl,i=0; *d; i++,d+=strlen(d)+1)
    out[i] = d;
  out[i] = 0;
  return out;
}

/* Simple hash function converts string into number at most mod */
int quick_hash(char *str,int seed,int mod) {
  unsigned int hash = 0;

  for(;*str;str++)
    hash = (hash * 37 + (*str ^ seed));
  return hash % mod;
}

/* "Effort" is a heuristic, supposed to correlate with the difficulty of
 * remembering (and so likelihood of entering) a term. For example, it
 * is more likely a user will enter KINASE1 than Q792Z.3X, all other things
 * being equal, in part because it's easier to remember. At the moment we
 * simply count digits as four and everything else as one, but this may
 * change.
 *
 * This method returns a prefix of its input upto the effortlimit. All
 * strings which begin with this prefix are considered muddleable-up,
 * and so are placed in the same bin. If many different words end up in
 * the same bin, then that is considered an unlikely term to memorise
 * and enter, so these are discarded.
 *
 * eg Q792Z.3X -> prefix Q792 (eff=13) -+--> two in this bin
 *    Q792G.7R -> prefix Q792 (eff=13) -'
 *    BRCA1    -> prefix BRCA1 (eff=8) ----> one in this bin
 *    BRCA2    -> prefix BRCA2 (eff=8) ----> one in this bin
 *
 * "Effort" is the primary method by which we choose which terms to add to
 * the autocomplete. (The other is "annoyingness").
 */
#define EFFORTLIMIT 12
char * make_effort(char *data) {
  char *effort;
  int limit,i,num=0,len,off;

  limit = EFFORTLIMIT;
  len = strlen(data);
  off = len;
  for(i=0;i<len;i++) {
    if(isdigit(data[i]))
      num += 4;
    else
      num++;
    if(num>limit) {
      off = i+1;
      break;
    }
  }
  if(off<1) off=1;
  effort = malloc(off+1);
  strncpy(effort,data,off);
  effort[off]='\0';
  return effort;
}

/* A prefix counter is the central datastructure in implementing the
 * bins required for finding clashing prefixes in our effort calculations.
 * It is a hash table, keyed by a hash of the prefix. Each value is the
 * prefix and a list of words. Each entry in the table is a linked list.
 *
 * The hash table grows by calling boost_table which actually
 * simply creates a replacement table (delegated to make_table)
 * and then refiles the entries.
 *
 * inc_counter handles adding a word to the prefix counter and requesting
 * the table grow, when needed.
 *
 * We also use a separate instance of this structure to record sections
 * in which each word appears for later dumping.
 */

struct counter {
  char * prefix;
  char *words;
  struct counter * next;
};

struct word_table {
  int size,num;
  struct counter ** counter;
};

struct word_table *prefixes,*sections;

struct word_table * make_table(int size) {
  struct word_table *out;
  int i;

  out = malloc(sizeof(struct word_table));
  if(size) {
    out->size = size;
    out->num = 0;
    out->counter = malloc(sizeof(struct counter *)*size);
    for(i=0;i<size;i++)
      out->counter[i] = 0; 
  } else {
    *out = (struct word_table){0,0,0};
  }
  return out;
}

void boost_table(struct word_table *in) {
  struct word_table *out;
  struct counter *c,*d;
  int i,hash;

  out = make_table(in->size*3/2+16);
  for(i=0;i<in->size;i++)
    for(c=in->counter[i];c;c=d) {
      d = c->next;
      hash = quick_hash(c->prefix,0,out->size);
      c->next = out->counter[hash];
      out->counter[hash] = c;
    }
  out->num = in->num;
  *in = *out;
}

long long int stat_naughty=0,stat_good=0,stat_words=0;
#define NAUGHTY_THRESHOLD 12
/* 0 = new, 1 = old, 2 = naughty */
int inc_counter(struct word_table *pc,char *prefix,char *word) {
  int hash,num;
  struct counter *c,*rec=0;

  if(pc->num >= pc->size/3)
    boost_table(pc);
  hash = quick_hash(prefix,0,pc->size);
  for(c=pc->counter[hash];c;c=c->next) {
    if(!strcmp(c->prefix,prefix))
      rec = c;
  }
  if(!rec) {
    c = malloc(sizeof(struct counter));
    c->prefix = malloc(strlen(prefix)+1);
    strcpy(c->prefix,prefix);
    c->words = 0;
    c->next = pc->counter[hash];
    pc->counter[hash] = c;
    pc->num++;
    rec = c;
  } else if(!rec->words) {
    stat_naughty++;
    return 2;
  }
  num = strl_member(&(rec->words),word,NAUGHTY_THRESHOLD);
  if(num>=NAUGHTY_THRESHOLD) {
    free(rec->words);
    rec->words = 0;
    stat_naughty++;
    return 2;
  }
  stat_good++;
  if(num==0) {
    return 1;
  }
  return 0;
}

void add_section(struct word_table *ss,char *word,char *section) {
  int hash;
  struct counter *c,*rec=0;

  if(ss->num >= ss->size/3)
    boost_table(ss);
  hash = quick_hash(word,0,ss->size);
  for(c=ss->counter[hash];c;c=c->next) {
    if(!strcmp(c->prefix,word))
      rec = c;
  }
  if(!rec) {
    c = malloc(sizeof(struct counter));
    c->prefix = malloc(strlen(word)+1);
    strcpy(c->prefix,word);
    c->words = 0;
    c->next = ss->counter[hash];
    ss->counter[hash] = c;
    ss->num++;
    rec = c;
  }
  strl_member(&(rec->words),section,-1);
}

char ** get_sections(struct word_table *ss,char *word) {
  struct counter *c,*rec=0;
  int hash;
 
  if(!ss->size)
    return 0; 
  hash = quick_hash(word,0,ss->size);
  for(c=ss->counter[hash];c;c=c->next) {
    if(!strcmp(c->prefix,word))
      rec = c;
  }
  if(rec && rec->words) {
    return strl_strings(rec->words);
  }
  return 0;
}

/* "annoyingness" is an heuristic supposed to correlate with the difficulty
 * in speaking or typing a search term. We assume that if a term is a
 * pain to type then we will not use it if an easier term is
 * available. For example, if a gene is known as CHEESE3, GDTDRF7 and
 * Q450163 then even if all three of these are well known and disitinctive,
 * (such that the "effort" heuristic accepts them) all other things
 * being equal, a user is more likely to enter or communicate "CHEESE3".
 *
 * The heuristic assumes that English words are easy, letters are quite
 * easy, and everything else isn't. "English" is approximated by looking
 * for an approximately alternating pattern of vowels and consonants.
 *
 * The second kind of annoyingness handled here is that it's most annoying
 * to have to type in longer words as shorter words can be entered easily
 * without its aid. Therefore we penalise short words by dividing by
 * overall length.
 *
 * We use annoyngness as a post-filter on our terms (unlike effort, which
 * is applied during parsing). We remember the annoyingness of each term
 * and consider the number of terms which a user requested in determining
 * the correct threshold.
 */

/* -100*log(letter_frequency in english). Add scores and divide by length
 * to get an accurate score for unlikeliness of a letter sequence in
 * English.
 */
int freq[] = {
  109,182,156,136, 92,163,169,122,113,298,216,140,158,
  115,111,174,294,122,120,104,154,195,167,276,167,315
};

int annoyingness(char *data) {
  int n=0,len=0,v=0,f=0,letlen=0;
  char *c;

  for(c=data;*c;c++) {
    len++;
    if(!isalpha(*c))
      n+=100;
    if(strspn(c,"aeiou") > 2)
      n+=50; /* Too many vowels in a row */
    if(strcspn(c,"aeiou") > 3)
      n+=10; /* Too many consonants in a row */
    if(strspn(c,"aeiou"))
      v=1;
    if(*c>='a' && *c<='z') {
      f += freq[*c-'a'];
      letlen++;
    }
  }
  if(len) n/=len;
  if(letlen) f/= letlen; else f = 500;
  if(f>150)
    n += (f-150); /* unusual letters */
  else
    n += f/20; /* Mainly to avoid ties */
  if(!v)
    n += 30; /* no vowels */

  if(!len) return 0;
  n = (n*20)/len; /* Reward long matches, painful to type */
  return n;
}

#define MAX_ANNOYINGNESS 200

int annoyingness_size[MAX_ANNOYINGNESS];

void reset_annoyingness() {
  int i;

  for(i=0;i<MAX_ANNOYINGNESS;i++)
    annoyingness_size[i] = 0;
}

void register_annoyingness(int ann) {
  int i;

  for(i=ann;i<MAX_ANNOYINGNESS;i++)
    annoyingness_size[i]++;
}

int last_val = -1;
int annoyingness_threshold(int num) {
  int i;

  /* This method is on the critical path, so use a cache */
  if(last_val>=0) {
    if(last_val == MAX_ANNOYINGNESS-1 && annoyingness_size[MAX_ANNOYINGNESS-1]<num)
      return MAX_ANNOYINGNESS-1;
    if(annoyingness_size[last_val]<=num && annoyingness_size[last_val+1]>num)
      return last_val;
  }

  for(i=1;i<MAX_ANNOYINGNESS;i++) {
    if(annoyingness_size[i]>num) {
      last_val = i-1;
      return i-1;
    }
  }
  last_val = MAX_ANNOYINGNESS-1;
  return MAX_ANNOYINGNESS-1;
}

/* Dump the appropriate number of words (by calculating the correct
 * annoyingness threshold).
 */
void dump_words(struct word_table *pc,int threshold) {
  struct counter *c;
  int i,thresh,ann;
  double value; 
  char *d,**ss,**s;

  thresh = annoyingness_threshold(max_index_size);
  for(i=0;i<pc->size;i++)
    for(c=pc->counter[i];c;c=c->next) {
      d=c->words;
      if(d) {
        while(*d) {
          ann = annoyingness(d);
          if(ann<thresh) {
            value = ann*strlen(d);
            if(value > 0.5) {
              value = 12.0 - log10(value);
            } else {
              value = 12.0;
            }
            if(strlen(d)>6)
              value -= 0.1 * (strlen(d)-6);
            if(value >= threshold) {
              ss = get_sections(sections,d);
              if(ss) {
                for(s=ss;*s;s++)
                  printf("%s%s\t%1.1f\n",*s,d,value);
                free(ss);
              } else {
                printf("%s\t%1.1f\n",d,value);
              }
            }
          }
          d += strlen(d)+1;
        }
      }
    }
}

/* What we do to each word */
void process_word(char **ss,char *data) {
  char *effort,**s;
  int thresh,ann,i;

  if(!*data)
    return;
  stat_words++;
  effort = make_effort(data);
  i = inc_counter(prefixes,effort,data);
  if(i==0 || i==1) {
    if(ss)
      for(s=ss;*s;s++)
        add_section(sections,data,*s);
  }
  if(!i) {
    thresh = annoyingness_threshold(max_index_size);
    ann = annoyingness(data);
    if(ann<thresh) {
      register_annoyingness(ann);
    }
  }
  free(effort);
}


/***************************************************************
 * LEXER - reads the file and breaks it into words and states. *
 ***************************************************************/

/* A good field is a field which should not be ignored for the purposes
 * of autocomplete. It uses a fixed array.
 */
int in_good_field = 0;
int good_field(char *name) {
  char **b;

  for(b=bad_fields;*b;b++)
    if(!strcmp(name,*b))
      return 0;
  return 1;
}

/* Here's a tag. Set whether or not we are in a good field. This is a
 * one-bit state which determines whether any textual content in the XML
 * should be added to the autocomplete index.
 */
void process_tag(char *data) {
  char * field,*f;

  if(!strncmp(data,"field ",6)) {
    /* FIELD */
    if((field = strstr(data,"name=\""))) {
      f = index(field+6,'"');
      if(f)
        *f = '\0';
      if(good_field(field+6))
        in_good_field = 1;
    }
  } else if(!strcmp(data,"/field")) {
    in_good_field = 0;
  }
}

/* Punctuation which tends to separate words */
int isseparator(char c) {
  return c == '/' || c == ':' || c == ';' || c == '-' || c == '_' || c == '(' || c == ')';
}

/* Split some XML text into words and call process_word on each */
void process_text(char **ss,char *data) {
  char *c,*d;

  if(!in_good_field)
    return;
  /* Remove punctuation attached to starts and ends of words */
  d = data;
  for(c=data;*c;c++) {
    if(ispunct(*c)) {
      if(c==data || !*(c+1) ||
         !isalnum(*(c-1)) || !isalnum(*(c+1)) ||
         isseparator(*c))
        *c = ' ';
    }
    if(isspace(*c)) {
      *c = '\0';
      if(*d)
        process_word(ss,d);
      d = c+1;
    } else {
      *c = tolower(*c);
    }
  }
  process_word(ss,d);
}

int tag_mode=0;
char *tagstr = 0;

/* Process this text which is either the contents of <...> or else some
 * text between such.
 *
 * eg <a>hello <b>world</b></a> =>
 * lex_part("a",1); lex_part("hello ",0); lex_part("b",1);
 * lex_part("world",0); lex_part("/b",1); lex_part("/a",1);
 */
void lex_part(char **ss,char *part,int tag) {
  if(tag_mode != tag) {
    /* Do stuff */
    if(tag_mode) {
      process_tag(tagstr);
    } else {
      process_text(ss,tagstr);
    }
    free(tagstr);
    tagstr = 0;
    tag_mode = tag;
  }
  if(!tagstr) {
    tagstr = malloc(1);
    tagstr[0] = '\0';
  }
  if(strlen(part)) {
    tagstr = realloc(tagstr,strlen(tagstr)+strlen(part)+1);
    strcat(tagstr,part);
  }
}

/* Take a string and call lext_part the right number of times, with the
 * right fragments.
 */
int in_tag = 0;
/* at top level we just extract tag / non-tag and pass it down */
void lex(char **ss,char *data) {
  char *hit;

  while(*data) {
    hit = index(data,in_tag?'>':'<');
    if(hit)
      *hit = '\0';
    lex_part(ss,data,in_tag);
    if(hit) {
      in_tag = !in_tag;
      data = hit+1;
    } else {
      break;
    }
  }
}

/*******************************************************************
 * CONTROLLER -- handles system interaction, logging, yadda-yadda. *
 *******************************************************************/

/* Used by string returning functions: remember to free it! */
struct pool smem = {0,0};

/* Abbreviated filename for log messages */
char * short_name(char *in) {
  char *out,*c,*d,*e;

  out = malloc(strlen(in)+1);
  e = rindex(in,'.');
  c = rindex(in,'/');
  if(!c) c = in;
  for(d=out;*c && c!=e;c++)
    if(c==in || isdigit(*c))
      *(d++) = *c;
    else if(isupper(*c))
      *(d++) = tolower(*c);
    else if(isalpha(*c) && !isalpha(*(c-1)))
      *(d++) = *c;
    else if(ispunct(*c) && !isalpha(*(c-1)))
      *(d++) = '-';
  *d = '\0';
  return out;
}

/* Display a number of bytes with appropriate multiplier eg 1024 -> 1k */
char *mult = " kMGTPE";
char * size(off_t amt) {
  char *out;
  int i;

  out = pmem(&smem,10);
  for(i=0;mult[i];i++) {
    if(amt<1024) {
      sprintf(out,"%ld%c",amt,mult[i]);
      return out;
    }
    amt /= 1024;
  }
  sprintf(out,"lots");
  return out;
}

/* Display a time in H:M:S */
#define MAXTIME 256
char * time_str(time_t when) {
  struct tm tm;
  char *out;

  if(!localtime_r(&when,&tm))
    return "";
  out = pmem(&smem,MAXTIME);
  strftime(out,MAXTIME-1,"%H:%M:%S",&tm);
  return out; 
}

/* Get file size */
off_t file_size(char *fn) {
  struct stat sb;
  off_t size;

  if(stat(fn,&sb) == -1) {
    fprintf(stderr,"Cannot stat '%s': %s\n",fn,strerror(errno));
    exit(1);
  }
  size = sb.st_size;
  return size;
}

/* Read and call lex on a file */
int meg=0,bytes=0,repmeg=0;
time_t all_start,block_start,block_end;
off_t stat_all=0;
off_t stat_read = 0;
#define MEG (1024*1024)
void process_file(char **ss,char *fn) {
  int r,fd;
  char buf[READBUFFER];
  long long int total;
  time_t eta;

  fprintf(stderr,"File: %-15s %10s\n",short_name(fn),size(file_size(fn)));
  pfree(&smem);
  fd = open(fn,O_RDONLY);
  if(fd==-1) {
    fprintf(stderr,"Cannot open '%s': %s\n",fn,strerror(errno));
    exit(1);
  }
  while(1) {
    r = read(fd,buf,READBUFFER-1);
    if(r>0) {
      stat_read += r;
      buf[r] = '\0';
      lex(ss,buf);
      bytes += r;
      if(bytes > MEG) {
        meg += bytes/MEG;
        bytes -= (bytes/MEG)*MEG;
      }
    } else if(r==0) {
      break;
    } else {
      perror("Read of stdin failed");
      exit(1);
    }
    if(!(meg%100) && repmeg != meg) {
      block_end = time(0);
      total = (stat_naughty+stat_good+1);
      fprintf(stderr,"Run : %dMb in %lds (%lds).\nMem : "
             "n/g(%%)=%s/%s (%lld) p/s=%s/%s. a=%d.\n",
             meg,block_end-all_start,block_end-block_start,
             size(stat_good),size(stat_naughty),
             stat_good*100/total,
             size(prefixes->num),size(stat_words),
             annoyingness_threshold(max_index_size));
      eta = all_start+(block_end-all_start)*stat_all/stat_read;
      fprintf(stderr,"ETA : read/all = %s/%s (%ld%%) at %s\n",
             size(stat_read),size(stat_all),stat_read*100/stat_all,
             time_str(eta));
      pfree(&smem);
      block_start = block_end;
      repmeg=meg;
    }
  }
  lex_part(ss,"",0);
  close(fd);
}

/* List of files we need to process */

struct file {
  char *filename;
  char *sections;
  struct file *next;
};

char * global_sections = 0;
struct file *files = 0;
void add_file(char *fn) {
  struct file *f;
  char *fn2;

  fn2 = malloc(strlen(fn)+1);
  strcpy(fn2,fn);
  f = malloc(sizeof(struct file));
  f->filename = fn2;
  f->sections = 0;
  f->next = files;
  files = f;
}

void add_file_section(char *section) {
  if(files)
    strl_member(&(files->sections),section,-1);
  else
    strl_member(&global_sections,section,-1);
}

void add_file_spec(char *spec) {
  char *at,*at2,**ss,**s,*in;

  in = malloc(strlen(spec)+1);
  strcpy(in,spec);
  ss = strl_strings(global_sections);
  at = index(in,'@');
  if(at) *at = '\0';
  add_file(in);
  if(ss)
    for(s=ss;*s;s++)
      add_file_section(*s);
  while(at) {
    at2 = index(at+1,'@');
    if(at2) *at2 = '\0';
    add_file_section(at+1);
    at = at2;
  }
  free(in);
  free(ss);
}

/* Handle options, read in list of files and submit one-by-one */

/* max bytes of filename on stdin */
#define MAXLINE 16384
int main(int argc,char *argv[]) {
  int idx,c,from_stdin=0,threshold=6;
  char *fn,*p,**ss;
  struct file *f;

  all_start = block_start = time(0);
  while((c = getopt(argc,argv,"cn:s:t:")) != -1) {
    switch (c) {
      case 'n':
        max_index_size = atoi(optarg);
        if(max_index_size < 1) {
          fprintf(stderr,"Bad index size '%s'\n",optarg);
          return 1;
        }
        break;
      case 'c':
        from_stdin = 1;
        break;
      case 's':
        add_file_section(optarg);
        break;
      case 't':
        threshold = atoi(optarg);
        if(threshold<1) {
          fprintf(stderr,"Bad threshold '%s'\n",optarg);
          return 1;
        }
        break;
      case '?':
        fprintf(stderr,"Bad command line options\n");
        return 1;
      default:
        abort();
    }
  }
  reset_annoyingness();
  prefixes = make_table(0);
  sections = make_table(0);

  if(from_stdin) {
    while(1) {
      fn = malloc(MAXLINE);
      if(!fgets(fn,MAXLINE,stdin)) {
        if(ferror(stdin)) {
          perror("Could not read from stdin\n");
          exit(1);
        }
        free(fn);
        break;
      }
      for(p=fn;*p && !isspace(*p);p++)
        ;
      *p = '\0';
      add_file_spec(fn);
    }
  } else {
    for (idx=optind;idx<argc;idx++) {
      add_file_spec(argv[idx]);
    }
  }
  for(f=files;f;f=f->next)
    stat_all += file_size(f->filename);
  for(f=files;f;f=f->next) {
    ss = strl_strings(f->sections);
    process_file(ss,f->filename);
    free(ss);
  }
  dump_words(prefixes,threshold);

  fprintf(stderr,"Success.\n");
  return 0;
}

