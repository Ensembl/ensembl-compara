/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#include "utilities.h"
#include "ml.h"
#include "optimiz.h"
#include "models.h"
#include "free.h"
#include "bionj.h"
#include "simu.h"

#ifdef LH3_REVISION
int lh3_revision_is_quiet = 0;
#endif

int    NODE_DEG_MAX;
int    BRENT_ITMAX;
double BRENT_CGOLD;
double BRENT_ZEPS;
double MNBRAK_GOLD;
double MNBRAK_GLIMIT;
double MNBRAK_TINY;
double ALPHA_MIN;
double ALPHA_MAX;
double BL_MIN;
double BL_START;
double BL_MAX;
double MIN_DIFF_LK;
double GOLDEN_R;
double GOLDEN_C;
int    T_MAX_FILE;
int    T_MAX_LINE;
int    T_MAX_NAME;
int    T_MAX_SEQ;
int    N_MAX_INSERT;
int    N_MAX_OTU;
int    T_MAX_ALPHABET;
double UNLIKELY;
double NJ_SEUIL;
int    MAX_TOPO_DIST;
double DIST_MAX;
int    LIM_SCALE;
double LIM_SCALE_VAL;
double AROUND_LK;
double MDBL_MAX;
double MDBL_MIN;
int    POWELL_ITMAX;
double LINMIN_TOL;

/*********************************************************/
/* NUMERICAL RECIPES ROUTINES FOR COMPUTING C(n,k)       */
/*********************************************************/

double bico(int n, int k)
{
   return floor(0.5+exp(factln(n)-factln(k)-factln(n-k)));
}

double factln(int n)
{
   static double a[101];

   if (n < 0){ Exit("Err: negative factorial in routine FACTLN"); }
   if (n <= 1) return 0.0;
   if (n <= 100) return a[n] ? a[n] : (a[n]=gammln(n+1.0));
   else return gammln(n+1.0);
}

double gammln(double xx)
{
   double x,tmp,ser;
   static double cof[6]={76.18009173,-86.50532033,24.01409822,
      -1.231739516,0.120858003e-2,-0.536382e-5};
   int j;

   x=xx-1.0;
   tmp=x+5.5;
   tmp -= (x+0.5)*log(tmp);
   ser=1.0;
   for (j=0;j<=5;j++) {
      x += 1.0;
      ser += cof[j]/x;
   }
   return -tmp+log(2.50662827465*ser);
}

/*********************************************************/
/*          END OF NUMERICAL RECIPES ROUTINES            */
/*********************************************************/

double Pbinom(int N, int ni, double p)
{
  return bico(N,ni)*pow(p,ni)*pow(1-p,N-ni);
}

/*********************************************************/

void Plim_Binom(double pH0, int N, double *pinf, double *psup)
{
  *pinf = pH0 - 1.64*sqrt(pH0*(1-pH0)/(double)N);
  if(*pinf < 0) *pinf = .0;
  *psup = pH0 + 1.64*sqrt(pH0*(1-pH0)/(double)N);
}

/*********************************************************/

double LnGamma (double alpha)
{
/* returns ln(gamma(alpha)) for alpha>0, accurate to 10 decimal places.  
   Stirling's formula is used for the central polynomial part of the procedure.
   Pike MC & Hill ID (1966) Algorithm 291: Logarithm of the gamma function.
   Communications of the Association for Computing Machinery, 9:684
*/
   double x=alpha, f=0, z;

   if (x<7) {
      f=1;  z=x-1;
      while (++z<7)  f*=z;
      x=z;   f=-log(f);
   }
   z = 1/(x*x);
   return  f + (x-0.5)*log(x) - x + .918938533204673 
	  + (((-.000595238095238*z+.000793650793651)*z-.002777777777778)*z
	       +.083333333333333)/x;  
}

/*********************************************************/

double IncompleteGamma (double x, double alpha, double ln_gamma_alpha)
{
/* returns the incomplete gamma ratio I(x,alpha) where x is the upper 
	   limit of the integration and alpha is the shape parameter.
   returns (-1) if in error
   ln_gamma_alpha = ln(Gamma(alpha)), is almost redundant.
   (1) series expansion     if (alpha>x || x<=1)
   (2) continued fraction   otherwise
   RATNEST FORTRAN by
   Bhattacharjee GP (1970) The incomplete gamma integral.  Applied Statistics,
   19: 285-287 (AS32)
*/
   int i;
   double p=alpha, g=ln_gamma_alpha;
   double accurate=1e-8, overflow=1e30;
   double factor, gin=0, rn=0, a=0,b=0,an=0,dif=0, term=0, pn[6];

   if (x==0) return (0);
   if (x<0 || p<=0) return (-1);

   factor=exp(p*log(x)-x-g);   
   if (x>1 && x>=p) goto l30;
   /* (1) series expansion */
   gin=1;  term=1;  rn=p;
 l20:
   rn++;
   term*=x/rn;   gin+=term;

   if (term > accurate) goto l20;
   gin*=factor/p;
   goto l50;
 l30:
   /* (2) continued fraction */
   a=1-p;   b=a+x+1;  term=0;
   pn[0]=1;  pn[1]=x;  pn[2]=x+1;  pn[3]=x*b;
   gin=pn[2]/pn[3];
 l32:
   a++;  b+=2;  term++;   an=a*term;
   for (i=0; i<2; i++) pn[i+4]=b*pn[i+2]-an*pn[i];
   if (pn[5] == 0) goto l35;
   rn=pn[4]/pn[5];   dif=fabs(gin-rn);
   if (dif>accurate) goto l34;
   if (dif<=accurate*rn) goto l42;
 l34:
   gin=rn;
 l35:
   for (i=0; i<4; i++) pn[i]=pn[i+2];
   if (fabs(pn[4]) < overflow) goto l32;
   for (i=0; i<4; i++) pn[i]/=overflow;
   goto l32;
 l42:
   gin=1-factor*gin;

 l50:
   return (gin);
}


/*********************************************************/

double PointChi2 (double prob, double v)
{
/* returns z so that Prob{x<z}=prob where x is Chi2 distributed with df=v
   returns -1 if in error.   0.000002<prob<0.999998
   RATNEST FORTRAN by
       Best DJ & Roberts DE (1975) The percentage points of the 
       Chi2 distribution.  Applied Statistics 24: 385-388.  (AS91)
   Converted into C by Ziheng Yang, Oct. 1993.
*/
   double e=.5e-6, aa=.6931471805, p=prob, g;
   double xx, c, ch, a=0,q=0,p1=0,p2=0,t=0,x=0,b=0,s1,s2,s3,s4,s5,s6;

   if (p<.000002 || p>.999998 || v<=0) return (-1);

   g = LnGamma (v/2);
   xx=v/2;   c=xx-1;
   if (v >= -1.24*log(p)) goto l1;

   ch=pow((p*xx*exp(g+xx*aa)), 1/xx);
   if (ch-e<0) return (ch);
   goto l4;
l1:
   if (v>.32) goto l3;
   ch=0.4;   a=log(1-p);
l2:
   q=ch;  p1=1+ch*(4.67+ch);  p2=ch*(6.73+ch*(6.66+ch));
   t=-0.5+(4.67+2*ch)/p1 - (6.73+ch*(13.32+3*ch))/p2;
   ch-=(1-exp(a+g+.5*ch+c*aa)*p2/p1)/t;
   if (fabs(q/ch-1)-.01 <= 0) goto l4;
   else                       goto l2;
  
l3: 
   x=PointNormal (p);
   p1=0.222222/v;   ch=v*pow((x*sqrt(p1)+1-p1), 3.0);
   if (ch>2.2*v+6)  ch=-2*(log(1-p)-c*log(.5*ch)+g);
l4:
   q=ch;   p1=.5*ch;
   if ((t=IncompleteGamma (p1, xx, g))<0) {
      fprintf (stderr, "\nerr IncompleteGamma");
      return (-1);
   }
   p2=p-t;
   t=p2*exp(xx*aa+g+p1-c*log(ch));   
   b=t/ch;  a=0.5*t-b*c;

   s1=(210+a*(140+a*(105+a*(84+a*(70+60*a))))) / 420;
   s2=(420+a*(735+a*(966+a*(1141+1278*a))))/2520;
   s3=(210+a*(462+a*(707+932*a)))/2520;
   s4=(252+a*(672+1182*a)+c*(294+a*(889+1740*a)))/5040;
   s5=(84+264*a+c*(175+606*a))/2520;
   s6=(120+c*(346+127*c))/5040;
   ch+=t*(1+0.5*t*s1-b*c*(s1-b*(s2-b*(s3-b*(s4-b*(s5-b*s6))))));
   if (fabs(q/ch-1) > e) goto l4;

   return (ch);
}

/*********************************************************/

double PointNormal (double prob)
{
/* returns z so that Prob{x<z}=prob where x ~ N(0,1) and (1e-12)<prob<1-(1e-12)
   returns (-9999) if in error
   Odeh RE & Evans JO (1974) The percentage points of the normal distribution.
   Applied Statistics 22: 96-97 (AS70)

   Newer methods:
     Wichura MJ (1988) Algorithm AS 241: the percentage points of the
       normal distribution.  37: 477-484.
     Beasley JD & Springer SG  (1977).  Algorithm AS 111: the percentage 
       points of the normal distribution.  26: 118-121.

*/
   double a0=-.322232431088, a1=-1, a2=-.342242088547, a3=-.0204231210245;
   double a4=-.453642210148e-4, b0=.0993484626060, b1=.588581570495;
   double b2=.531103462366, b3=.103537752850, b4=.0038560700634;
   double y, z=0, p=prob, p1;

   p1 = (p<0.5 ? p : 1-p);
   if (p1<1e-20) return (-9999);

   y = sqrt (log(1/(p1*p1)));   
   z = y + ((((y*a4+a3)*y+a2)*y+a1)*y+a0) / ((((y*b4+b3)*y+b2)*y+b1)*y+b0);
   return (p<0.5 ? -z : z);
}
/*********************************************************/

int DiscreteGamma (double freqK[], double rK[], 
    double alfa, double beta, int K, int median)
{
/* discretization of gamma distribution with equal proportions in each 
   category
*/
   int i;
   double gap05=1.0/(2.0*K), t, factor=alfa/beta*K, lnga1;

   if(K==1) 
     {
       rK[0] = 1.0;
       return 0;
     }

   if (median) {
      for (i=0; i<K; i++) rK[i]=PointGamma((i*2.0+1)*gap05, alfa, beta);
      for (i=0,t=0; i<K; i++) t+=rK[i];
      for (i=0; i<K; i++)     rK[i]*=factor/t;
   }
   else {
      lnga1=LnGamma(alfa+1);
      for (i=0; i<K-1; i++)
	 freqK[i]=PointGamma((i+1.0)/K, alfa, beta);
      for (i=0; i<K-1; i++)
	 freqK[i]=IncompleteGamma(freqK[i]*beta, alfa+1, lnga1);
      rK[0] = freqK[0]*factor;
      rK[K-1] = (1-freqK[K-2])*factor;
      for (i=1; i<K-1; i++)  rK[i] = (freqK[i]-freqK[i-1])*factor;
   }
   for (i=0; i<K; i++) freqK[i]=1.0/K;

   return (0);
}

/*********************************************************/

arbre *Read_Tree(char *s_tree)
{
  char **subs;
  int i,n_ext,n_int,n_otu;
  char *sub_tp;
  arbre *tree;
  int degree;

  
  tree=(arbre *)mCalloc(1,sizeof(arbre));

  
  n_otu=0;
  For(i,(int)strlen(s_tree)) if(s_tree[i] == ',') n_otu++;
  n_otu+=1;
  tree->n_otu = n_otu;


  Init_Tree(tree);


  tree->noeud[n_otu]=(node *)mCalloc(1,sizeof(node));
  tree->noeud[n_otu]->v = NULL;
  Make_Node_Light(tree->noeud[n_otu]);
  tree->noeud[n_otu]->num=n_otu;
  tree->noeud[n_otu]->tax=0;
  tree->noeud[n_otu]->agglo=0;
  tree->noeud[n_otu]->ni=0;



  subs = Sub_Trees(s_tree,&degree);
  Clean_Multifurcation(subs,degree,3);


  if(!strlen(subs[2])) Exit("\n. Err: unrooted tree is needed\n");
  sub_tp=(char *)mCalloc((int)strlen(s_tree),sizeof(char));


  tree->has_branch_lengths = 1;
  
  For(i,degree)
    {
        strcpy(sub_tp,subs[i]);
        strcat(sub_tp,":");
        if(strstr(s_tree,sub_tp))
            {
                tree->noeud[n_otu]->l[i] = 
                    atof((char *)strstr(s_tree,sub_tp)+strlen(subs[i])+1);
            }
        else
            tree->has_branch_lengths = 0;
    }
  Free(sub_tp);

  n_int = n_ext = 0;
  For(i,degree)
      R_rtree(subs[i],tree->noeud[n_otu],tree,&n_int,&n_ext);

  Make_All_Edges_Light(tree->noeud[0],tree->noeud[0]->v[0]);
  i = 0;
  Init_Tree_Edges(tree->noeud[0],tree->noeud[0]->v[0],tree,&i);

  For(i,NODE_DEG_MAX)
    Free(subs[i]);
  Free(subs);

  return tree;
}

/*********************************************************/

void Make_All_Edges_Light(node *a, node *d)
{
  int i;

  Make_Edge_Light(a,d);
  if(d->tax) return;
  else
    {
      For(i,3)
	{
	  if(d->v[i] != a)
	    Make_All_Edges_Light(d,d->v[i]);
	}
    }
}

/*********************************************************/

void Make_All_Edges_Lk(node *a, node *d, arbre *tree)
{
  int i;

  Make_Edge_Lk(a,d,tree);
  if(d->tax) return;
  else
    {
      For(i,3)
	{
	  if(d->v[i] != a)
	    Make_All_Edges_Lk(d,d->v[i],tree);
	}
    }
}
	    
/*********************************************************/

void R_rtree(char *s_tree, node *pere, arbre *tree, int *n_int, int *n_ext) 
{
  int i;
  char *sub_tp;
  node *fils;
  int n_otu = tree->n_otu;

  if(strstr(s_tree," ")) Exit("\n Err : tree must not contain a ' ' character\n");

  fils=(node *)mCalloc(1,sizeof(node));  
  fils->v = NULL;
  Make_Node_Light(fils);

  if(s_tree[0] == '(')  
    {
      char **subs;
      int degree;


      (*n_int)+=1;                                  
      tree->noeud[n_otu+*n_int]=fils;
      fils->num=n_otu+*n_int;
      fils->tax=0;fils->agglo=0;fils->ni=0;
      
      if(s_tree[(int)strlen(s_tree)-1] == '*') 
	{
	  fils->check_branch = 1;
	  s_tree[(int)strlen(s_tree)-1] = '\0';
	}


      For(i,3)
       {
	 if(!pere->v[i])
	   {
	     pere->v[i]=fils;
	     fils->l[0]=pere->l[i];
	     break;
	   }
       }
      
      fils->v[0]=pere;
      subs=Sub_Trees(s_tree,&degree);
        
      Clean_Multifurcation(subs,degree,2);

      sub_tp = (char *)mCalloc(T_MAX_LINE,sizeof(char));
      strcpy(sub_tp,subs[0]);
      strcat(sub_tp,":");
      if(strstr(s_tree,sub_tp))
	{
	  fils->l[1] = atof((char *)strstr(s_tree,sub_tp)
			    +(int)strlen(subs[0])+1);
	}
      
      strcpy(sub_tp,subs[1]);
      strcat(sub_tp,":");
      if(strstr(s_tree,sub_tp))
	{
	  fils->l[2] = atof((char *)strstr(s_tree,sub_tp)
			    +(int)strlen(subs[1])+1);
	}
      
      Free(sub_tp);
      R_rtree(subs[0],fils,tree,n_int,n_ext);
      R_rtree(subs[1],fils,tree,n_int,n_ext);
      For(i,NODE_DEG_MAX) Free(subs[i]);
      Free(subs);
    }

  else                                        
    {
      tree->noeud[*n_ext]=fils;
      fils->tax=1;fils->agglo=1;fils->ni=1;
      For(i,3)
	{
	 if(!pere->v[i])
	   {
	     pere->v[i]=fils;
	     fils->l[0]=pere->l[i];
	     break;
	   }
	}
      
      if(s_tree[(int)strlen(s_tree)-1] == '*') 
	{
	  fils->check_branch = 1;
	  s_tree[(int)strlen(s_tree)-1] = '\0';
	}
      

      fils->v[0]=pere;
      strcpy(fils->name,s_tree); 
      fils->num=*n_ext;
      (*n_ext)+=1;
    }
}

/*********************************************************/

void Clean_Multifurcation(char **subtrees, int current_deg, int end_deg)
{

  if(current_deg <= end_deg) return;
  else
    {
      char *s_tmp;
      int i;

      s_tmp = (char *)mCalloc(T_MAX_LINE,sizeof(char));
             
      strcat(s_tmp,"(\0");
      strcat(s_tmp,subtrees[0]);
      strcat(s_tmp,",\0");
      strcat(s_tmp,subtrees[1]);
      strcat(s_tmp,")\0");
      Free(subtrees[0]);
      subtrees[0] = s_tmp;


      for(i=1;i<current_deg-1;i++)
          {              
              strcpy(subtrees[i],subtrees[i+1]);
          }

      Clean_Multifurcation(subtrees,current_deg-1,end_deg);
    }
}

/*********************************************************/

char **Sub_Trees(char *tree, int *degree)
{
  char **subs;
  int posbeg,posend;
  int i;

  subs=(char **)mCalloc(NODE_DEG_MAX,sizeof(char *));

  For(i,NODE_DEG_MAX) subs[i]=(char *)mCalloc(strlen(tree)+1,sizeof(char));

  posbeg=posend=1;
  (*degree)=0;
  do
    {
      posbeg = posend;
      if(tree[posend] != '(')
	{
	  while((tree[posend] != ',' ) && 
		(tree[posend] != ':' ) &&
		(tree[posend] != ')' ))
	    posend += 1;
	  posend -= 1;
	}
      else posend=Next_Par(tree,posend);

      while((tree[posend+1] != ',') && 
	    (tree[posend+1] != ':') &&
	    (tree[posend+1] != ')')) {posend++;}


      strncpy(subs[(*degree)],tree+posbeg,posend-posbeg+1);
      strcat(subs[(*degree)],"\0");

      posend += 1;
      while((tree[posend] != ',') && 
	    (tree[posend] != ')')) {posend++;}
      posend+=1;


      (*degree)++;
      if((*degree) == NODE_DEG_MAX) 
	{
	  For(i,(*degree)) 
	    fprintf(stderr, "\n. Subtree %d : %s\n",i+1,subs[i]);

	  fprintf(stderr, "\n. The degree of a node cannot be greater than %d\n",NODE_DEG_MAX);
	  Exit("\n");
	}
    }
  while(tree[posend-1] != ')');
  
  return subs;
}


/*********************************************************/

int Next_Par(char *s, int pos)
{
  int curr;

  curr=pos+1;

  while(*(s+curr) != ')')
    {
      if(*(s+curr) == '(') curr=Next_Par(s,curr);
      curr++;
    }

  return curr; 
}

/*********************************************************/

char *Write_Tree(arbre *tree)
{

  char *s;
  int i;

  s=(char *)mCalloc(T_MAX_LINE,sizeof(char));
  
  s[0]='(';
  
  i = 0;
  while((!tree->noeud[tree->n_otu+i]->v[0]) ||
	(!tree->noeud[tree->n_otu+i]->v[1]) ||
	(!tree->noeud[tree->n_otu+i]->v[2])) i++;
  
  R_wtree(tree->noeud[tree->n_otu+i],tree->noeud[tree->n_otu+i]->v[0],s,tree);
  R_wtree(tree->noeud[tree->n_otu+i],tree->noeud[tree->n_otu+i]->v[1],s,tree);
  R_wtree(tree->noeud[tree->n_otu+i],tree->noeud[tree->n_otu+i]->v[2],s,tree);

  s[(int)strlen(s)-1]=')';
  s[(int)strlen(s)]=';';
  
  
  return s;
}

/*********************************************************/

void R_wtree(node *pere, node *fils, char *s_tree, arbre *tree)
{
  int i,p;

  p = -1;
  if(fils->tax) 
    {

      strcat(s_tree,fils->name);
      if((fils->b[0]) && (fils->b[0]->l != -1))
	{
	  strcat(s_tree,":");
	  sprintf(s_tree+(int)strlen(s_tree),"%f",fils->b[0]->l);
	  fflush(stdout);
	}
      sprintf(s_tree+(int)strlen(s_tree),",");
   }

  else
    {
      s_tree[(int)strlen(s_tree)]='(';
      For(i,3)
	{
	  if(fils->v[i] != pere)
	    R_wtree(fils,fils->v[i],s_tree,tree);
	  else p=i;
	}	
      s_tree[(int)strlen(s_tree)-1]=')';
      if(fils->b[0]->l != -1)
	{
	  if(tree->print_boot_val) 
	    sprintf(s_tree+(int)strlen(s_tree),"%d",fils->b[p]->bip_score);
	  strcat(s_tree,":");
	  sprintf(s_tree+(int)strlen(s_tree),"%f,",fils->b[p]->l);
	  fflush(stdout);
	}
    }
}

/*********************************************************/

void Init_Tree(arbre *tree)
{
  int i;

  tree->noeud              = (node **)mCalloc(2*tree->n_otu-2,sizeof(node *));
  tree->t_edges            = (edge **)mCalloc(2*tree->n_otu-3,sizeof(edge *));
  For(i,2*tree->n_otu-3) 
  tree->t_edges[i]         = NULL;
  
  tree->best_tree          = NULL;
  tree->old_tree           = NULL;

  tree->has_bip            = 0;

  tree->best_loglk         = UNLIKELY;
  tree->tot_loglk          = UNLIKELY;
  tree->n_swap             = 0;
  tree->frac_site          = 1;
  tree->min_diff_lk        = .0;

  tree->tot_dloglk         = NULL;
  tree->tot_d2loglk        = NULL;
  tree->t_best_l           = NULL;

  tree->p_lk               = NULL;
  
  tree->n_pattern          = -1;
  
  tree->print_boot_val     = 0;
}

/*********************************************************/

void Make_Edge_Light(node *a, node *d)
{
  edge *b;

  b = (edge *)mCalloc(1,sizeof(edge));

  Init_Edge_Light(b);


  b->left = a;  b->rght = d; 
  if(a->tax) {b->rght = a; b->left = d;} /* root */
  /* a tip is necessary on the right side of the edge */  

  Make_Edge_Dirs(b,a,d);

  b->l                    = a->l[b->l_r];
  if(a->tax) b->l         = a->l[b->r_l];
  if(b->l < BL_MIN)  b->l = BL_MIN;
  b->l_old                = b->l;
}

/*********************************************************/

void Init_Edge_Light(edge *b)
{
  b->in_both         = 0;
  b->bip_score       = 0;
  b->nj_score        = .0;

  b->site_dlk        = -1.;
  b->site_d2lk       = -1.;
  b->site_dlk_rr     = NULL;
  b->site_d2lk_rr    = NULL;
  b->p_lk_left       = NULL;
  b->p_lk_rght       = NULL;
  b->Pij_rr          = NULL;
  b->dPij_rr         = NULL;
  b->d2Pij_rr        = NULL;

}

/*********************************************************/

void Make_Edge_Dirs(edge *b, node *a, node *d)
{
  int i;

  b->l_r = b->r_l = -1;
  For(i,3)
    {
      if((a->v[i]) && (a->v[i] == d)) 
	{
	  b->l_r  = i;
	  a->b[i] = b;
	}
      if((d->v[i]) && (d->v[i] == a)) 
	{
	  b->r_l  = i;
	  d->b[i] = b;
	}
    }

  if(a->tax) {b->r_l = 0; For(i,3) if(d->v[i]==a) {b->l_r = i; break;}}


  b->l_v1 = b->l_v2 = b->r_v1 = b->r_v2 = -1;
  For(i,3)
    {
      if(b->left->v[i] != b->rght)
	{
	  if(b->l_v1 < 0) b->l_v1 = i;
	  else            b->l_v2 = i;
	}
     
      if(b->rght->v[i] != b->left)
	{
	  if(b->r_v1 < 0) b->r_v1 = i;
	  else            b->r_v2 = i;
	}
    }
}

/*********************************************************/

void Make_Edge_Lk(node *a, node *d, arbre *tree)
{
  int i,j;
  int len;
  edge *b;
  
  b = NULL;

  For(i,3) if((a->v[i]) && (a->v[i] == d)) {b = a->b[i]; break;}

  len = (int)tree->data->crunch_len;

  b->diff_lk   = 0.0;
  b->l_old     = b->l;

  if(!b->Pij_rr)
    {
      b->best_conf = 1;
      b->ql        = (double *)mCalloc(3,sizeof(double));


      b->Pij_rr   = (double ***)mCalloc(tree->mod->n_catg,sizeof(double **));
      b->dPij_rr  = (double ***)mCalloc(tree->mod->n_catg,sizeof(double **));
      b->d2Pij_rr = (double ***)mCalloc(tree->mod->n_catg,sizeof(double **));
      
      For(i,tree->mod->n_catg)
	{
	  b->Pij_rr[i]   = (double **)mCalloc(tree->mod->ns,sizeof(double *));
	  b->dPij_rr[i]  = (double **)mCalloc(tree->mod->ns,sizeof(double *));
	  b->d2Pij_rr[i] = (double **)mCalloc(tree->mod->ns,sizeof(double *));

	  For(j,tree->mod->ns)
	    {
	      b->Pij_rr[i][j]   = (double *)mCalloc(tree->mod->ns,sizeof(double ));
	      b->dPij_rr[i][j]  = (double *)mCalloc(tree->mod->ns,sizeof(double ));
	      b->d2Pij_rr[i][j] = (double *)mCalloc(tree->mod->ns,sizeof(double ));
	    }
	}
    
      b->site_p_lk_left = (double **)mCalloc((int)tree->mod->n_catg,sizeof(double *));
      For(i,tree->mod->n_catg) b->site_p_lk_left[i] = (double *)mCalloc(tree->mod->ns,sizeof(double));
      b->site_p_lk_rght = (double **)mCalloc((int)tree->mod->n_catg,sizeof(double *));
      For(i,tree->mod->n_catg) b->site_p_lk_rght[i] = (double *)mCalloc(tree->mod->ns,sizeof(double));

      b->site_dlk_rr  = (double *)mCalloc((int)tree->mod->n_catg,sizeof(double));
      b->site_d2lk_rr = (double *)mCalloc((int)tree->mod->n_catg,sizeof(double));
  
      b->scale_left = b->scale_rght = 0;

      b->p_lk_left   = NULL;
      b->p_lk_rght  = NULL;
      
      b->sum_scale_f_rght = NULL;
      b->sum_scale_f_left  = NULL;

      b->get_p_lk_left = 0;
      b->get_p_lk_rght = 0;
      b->ud_p_lk_left  = 0;
      b->ud_p_lk_rght  = 0;
    }
}

/*********************************************************/

void Make_Node_Light(node *n)
{

  if(n->v) return;

  n->v     = (node **)mCalloc(3,sizeof(node *));
  n->l     = (double *)mCalloc(3,sizeof(double));
  n->b     = (edge **)mCalloc(3,sizeof(edge *));
  n->name  = (char *)mCalloc(T_MAX_NAME,sizeof(char));
  n->score = (double *)mCalloc(3,sizeof(double));
  
  Init_Node_Light(n);
  
}

/*********************************************************/

void Init_Node_Light(node *n)
{
  int i;

  n->check_branch  = 0;
  n->is_attach     = 0;
  n->is_free       = 0;
  n->ni = n->agglo = 0;


  For(i,3)
    {
      n->v[i]=NULL;
      n->b[i]=NULL;
      n->l[i]=-1;
    }
}

/*********************************************************/

void Make_Node_Lk(node *n)
{
/*   n->n_ex_nodes = (int *)mCalloc(2,sizeof(int)); */
  return;
}

/*********************************************************/

seq **Get_Seq(option *input,  int rw)
{
  seq **data;
  int i,j;
  char **buff;
  int n_unkn,n_removed,pos;
  int *remove;


/*   rewind(fp_seq); */

  if(input->interleaved) data = Read_Seq_Interleaved(input->fp_seq,&(input->mod->n_otu));
  else                   data = Read_Seq_Sequential(input->fp_seq,&(input->mod->n_otu));
  
  if(data)
    {
      buff = (char **)mCalloc(input->mod->n_otu,sizeof(char *));
      For(i,input->mod->n_otu) buff[i] = (char *)mCalloc(data[0]->len,sizeof(char));
      remove = (int *)mCalloc(data[0]->len,sizeof(int));
  
      n_removed = 0;

      For(i,data[0]->len)
	{
	  For(j,input->mod->n_otu)
	    {
	      if((data[j]->state[i] == '?') ||
		 (data[j]->state[i] == '-')) data[j]->state[i] = 'X';

	      if(data[j]->state[i] == 'U') data[j]->state[i] = 'T';

	      if((!input->mod->datatype) && (data[j]->state[i] == 'N')) data[j]->state[i] = 'X';

	    }
	  
	  n_unkn = 0;
	  For(j,input->mod->n_otu) if(data[j]->state[i] == 'X') n_unkn++; 

	  if(n_unkn == input->mod->n_otu)
	    {
	      remove[i] = 1;
	      n_removed++;
	    }
	  
	  For(j,input->mod->n_otu) buff[j][i] = data[j]->state[i];
	}
      
      if(n_removed > 0) 
	{
	  if(!input->mod->datatype)
	    fprintf(stderr, "\n. %d sites are made from completely undetermined states ('X', '-', '?' or 'N')...\n",n_removed);
	  else
	    fprintf(stderr, "\n. %d sites are made from completely undetermined states ('X', '-', '?')...\n",n_removed);
	}

      pos = 0;
      For(i,data[0]->len)
	{
/* 	  if(!remove[i]) */
/* 	    { */
	      For(j,input->mod->n_otu) data[j]->state[pos] = buff[j][i];
	      pos++;
/* 	    } */
	}

      For(i,input->mod->n_otu) data[i]->len = pos;
      For(i,input->mod->n_otu) Free(buff[i]);
      Free(buff);
      Free(remove);
    }
  return data;
}

/*********************************************************/
   
seq **Read_Seq_Sequential(FILE *in, int *n_otu)
{
  int i;
  char *line;
  int len,readok;
  seq **data;
  char c;
  char *format = (char *)mCalloc(20, sizeof(char));

  line = (char *)mCalloc(T_MAX_LINE,sizeof(char));

  readok = len = 0;
  do
    {
      if(fscanf(in,"%s",line) == EOF)
	{
	  Free(line); return NULL;
	}
      else
	{
	  if(strcmp(line,"\n") && strcmp(line,"\n") && strcmp(line,"\t"))
	    {
	      *n_otu = atoi(line);
	      data = (seq **)mCalloc(*n_otu,sizeof(seq *));
	      if(*n_otu <= 0) Exit("\n. Problem with sequence format\n");
	      fscanf(in,"%s",line);
	      len = atoi(line);
	      if(len <= 0) Exit("\n. Problem with sequence format\n");
	      else readok = 1;
	    }
	}
    }while(!readok);

  
/*   while((c=fgetc(in))!='\n'); */
  while(((c=fgetc(in))!='\n') && (c != ' ') && (c != '\r') && (c != '\t'));

  For(i,*n_otu)
    {
      data[i] = (seq *)mCalloc(1,sizeof(seq));
      data[i]->len = 0;
      data[i]->name = (char *)mCalloc(T_MAX_NAME,sizeof(char));
      data[i]->state = (char *)mCalloc(T_MAX_SEQ,sizeof(char));
      sprintf(format, "%%%ds", T_MAX_NAME);
      fscanf(in, format, data[i]->name);

      while(data[i]->len < len)
	Read_One_Line_Seq(&data,i,in);
	
      if(data[i]->len != len) 
	{
	  fprintf(stderr, "\n. Err: Problem with species %s's sequence (check the format)\n",
		 data[i]->name);
	  Exit("");
	}
    }

  /*   fgets(line,T_MAX_LINE,in);  */
  /* inter data sets */

  Free(format);
  Free(line);
  return data;
}

/*********************************************************/

seq **Read_Seq_Interleaved(FILE *in, int *n_otu)
{
  int i,end,num_block;
  char *line;
  int len,readok;
  seq **data;
  char c;
  char *format;

  line = (char *)mCalloc(T_MAX_LINE,sizeof(char));
  format = (char *)mCalloc(T_MAX_NAME, sizeof(char));

  readok = len = 0;
  do
    {
      if(fscanf(in,"%s",line) == EOF)
	{
	  Free(format);
	  Free(line); return NULL;
	}
      else
	{
	  if(strcmp(line,"\n") && strcmp(line,"\r") && strcmp(line,"\t"))
	    {
	      *n_otu = atoi(line);
	      data = (seq **)mCalloc(*n_otu,sizeof(seq *));
	      if(*n_otu <= 0) Exit("\n. Problem with sequence format\n");
	      fscanf(in,"%s",line);
	      len = atoi(line);
	      if(len <= 0) Exit("\n. Problem with sequence format\n");
	      else readok = 1;
	    }
	}
    }while(!readok);


  while(((c=fgetc(in))!='\n') && (c != ' ') && (c != '\r') && (c != '\t'));

  end = 0;
  For(i,*n_otu)
    {
      data[i] = (seq *)mCalloc(1,sizeof(seq));      
      data[i]->len = 0;
      data[i]->name = (char *)mCalloc(T_MAX_NAME,sizeof(char));
      data[i]->state = (char *)mCalloc(T_MAX_SEQ,sizeof(char));
      sprintf(format, "%%%ds", T_MAX_NAME);
      fscanf(in, format, data[i]->name);
      if(!Read_One_Line_Seq(&data,i,in)) 
	{
	  end = 1;
	  if((i != *n_otu) && (i != *n_otu-1)) 
	    {
	      fprintf(stderr, "\n. Err: Problem with species %s's sequence\n",data[i]->name);
	      Exit("");
	    }
	  break;
	}
    }

  if(data[0]->len == len) end = 1;

  if(!end)
    {
      end = 0;

      num_block = 1;
      do
	{
	  num_block++;

	  /* interblock */
	  if(!fgets(line,T_MAX_LINE,in)) break;
	  
	  if(line[0] != 13 && line[0] != 10) 
	    {
                fprintf(stderr, "\n. One or more missing sequences in block %d\n",num_block-1);
                Exit("");
	    }

	  For(i,*n_otu)
	    if(data[i]->len != len)
	      break;

	  if(i == *n_otu) break;

	  
	  For(i,*n_otu)
	    {
	      if(data[i]->len > len) 
		{
		  fprintf(stderr, "\n. Err: Problem with species %s's sequence\n",data[i]->name);
		  Exit("");
		}
	      else if(!Read_One_Line_Seq(&data,i,in)) 
		{
		  end = 1;
		  if((i != *n_otu) && (i != *n_otu-1)) 
		    {
		      fprintf(stderr, "\n. Err: Problem with species %s's sequence\n",data[i]->name);
		      Exit("");
		    }
		  break;
		}
	    }
	}while(!end);
    }

  For(i,*n_otu)
    {
      if(data[i]->len != len)
	{
	  fprintf(stderr, "\n. Check sequence '%s' length...\n",data[i]->name);
	  Exit("");
	}
    }

  Free(format);
  Free(line);
  return data;
}
 
/*********************************************************/

int Read_One_Line_Seq(seq ***data, int num_otu, FILE *in)
{
  char c;

  c=' ';
  while(1)
    {
/*       if((c == EOF) || (c == '\n') || (c == '\r')) break; */
        if((c == EOF) || (c == 13) || (c == 10)) break;
      else if((c==' ') || (c=='\t')) {c=(char)fgetc(in); continue;}
      Uppercase(&c);
      
      /*if(strchr("ACGTUMRWSYKBDHVNXO?-.",c) == NULL)*/
      if (strchr("ABCDEFGHIKLMNOPQRSTUVWXYZ?-.", c) == NULL)
	{
	  fprintf(stderr, "\n. Err: bad symbol: \"%c\" at position %d of species %s\n",
		 c,(*data)[num_otu]->len,(*data)[num_otu]->name);
	  Exit("");
	}

      if(c == '.')
	{
	  c = (*data)[0]->state[(*data)[num_otu]->len];
	  if(!num_otu) 
	    Exit("\n. Err: Symbol \".\" should not appear in the first sequence\n");
	}
      (*data)[num_otu]->state[(*data)[num_otu]->len]=c;
      (*data)[num_otu]->len++;
/*       if(c=='U') c='T'; */
      c = (char)fgetc(in);
    }
  if(c == EOF) return 0;
  else return 1;
}
   
/*********************************************************/

void Uppercase(char *ch)
{
  /* convert ch to upper case -- either ASCII or EBCDIC */
   *ch = isupper((int)*ch) ? *ch : toupper((int)*ch);
}

/*********************************************************/

allseq *Compact_Seq(seq **data, option *input)
{
  allseq *alldata;
  int i,j,k/*,diff*/,site;
  int n_patt,which_patt,n_invar;
  char **sp_names;
  int n_otu;


  n_otu = input->mod->n_otu;

  sp_names = (char **)mCalloc(n_otu,sizeof(char *));
  For(i,n_otu) 
    {
      sp_names[i] = (char *)mCalloc(T_MAX_NAME,sizeof(char));
      strcpy(sp_names[i],data[i]->name);
    }

  alldata = Make_Seq(n_otu,data[0]->len,sp_names);

  For(i,n_otu) Free(sp_names[i]);
  Free(sp_names);

  n_patt = which_patt = 0;
  /*  diff = -1;*/


  if(data[0]->len%input->mod->stepsize) 
    {
      fprintf(stderr, "\n. Sequence length is not a multiple of %d\n",input->mod->stepsize);
      Exit("");
    }

  Fors(site,data[0]->len,input->mod->stepsize) 
    { 
      Fors(k,n_patt,input->mod->stepsize)
	{
	  For(j,n_otu)
	    {
	      if(/*!Compare_Two_States*/strncmp(alldata->c_seq[j]->state+k,
				     data[j]->state+site,
				     input->mod->stepsize))
		break;
	    }

	  if(j == n_otu)
	    {
	      which_patt = k;
	      break;
	    }
	}

      if(k == n_patt)
	{
	  For(j,n_otu) 
	    Copy_One_State(data[j]->state+site,
			   alldata->c_seq[j]->state+n_patt,
			   input->mod->stepsize);


	  for(j=0;j<n_otu;j++) 
	    {
/* 	      if((Is_Ambigu(alldata->c_seq[j]->state+n_patt,input->mod->datatype,input->mod->stepsize) ||  */
/* 		  (/\*!Compare_Two_States*\/strncmp(alldata->c_seq[j]->state+n_patt, */
/* 						  alldata->c_seq[0]->state+n_patt, */
/* 						  input->mod->stepsize)))) */
	      if(!(Are_Compatible(alldata->c_seq[j]->state+n_patt,
				  alldata->c_seq[0]->state+n_patt,
				  input->mod->stepsize,
				  input->mod->datatype)))
		  break;
	    }
 	  
	  if(j==n_otu) 
	    {
	      For(j,n_otu)
		{
		  alldata->invar[n_patt] = Assign_State(alldata->c_seq[j]->state+n_patt,
							input->mod->datatype,
							input->mod->stepsize);
		  break;
		}
	    }
	  else    
	    alldata->invar[n_patt] = -1;

/* 	  Print_Site(alldata,k,n_otu,"\n",input->mod->stepsize); */
	  
          alldata->sitepatt[site] = n_patt;
	  alldata->wght[n_patt] += 1.;
	  n_patt+=input->mod->stepsize;
	}
      else 
	{
          alldata->sitepatt[site] = which_patt;
	  alldata->wght[which_patt] += 1.;
	}
    }
  
  
  alldata->init_len = data[0]->len;
  alldata->crunch_len = n_patt;
  For(i,n_otu) alldata->c_seq[i]->len = n_patt;

/*   fprintf(stderr,"%d patterns found\n",n_patt); */

/*   For(site,alldata->crunch_len) printf("%1.0f",alldata->wght[site]); */

  n_invar=0;
  For(i,alldata->crunch_len) if(alldata->invar[i]>-1) n_invar+=(int)alldata->wght[i];

  if(!input->mod->datatype)
    Get_Base_Freqs(alldata);
  else
    Get_AA_Freqs(alldata);

/*   fprintf(stderr,"Average nucleotides frequencies : \n"); */
/*   fprintf(stderr,"%f %f %f %f\n", */
/* 	 alldata->b_frq[0], */
/* 	 alldata->b_frq[1], */
/* 	 alldata->b_frq[2], */
/* 	 alldata->b_frq[3]); */
  return alldata;
}

/*********************************************************/

allseq *Compact_CSeq(allseq *data, model *mod)
{
  allseq *alldata;
  int i,j,k,site;
  int n_patt,which_patt;
  int n_otu;

  n_otu = data->n_otu;

  alldata = (allseq *)mCalloc(1,sizeof(allseq));
  alldata->n_otu=n_otu;
  alldata->c_seq = (seq **)mCalloc(n_otu,sizeof(seq *));
  alldata->wght = (double *)mCalloc(data->crunch_len,sizeof(double));
  alldata->factw = (double *)mCalloc(data->crunch_len,sizeof(double));
  alldata->b_frq = (double *)mCalloc(mod->ns,sizeof(double));
  alldata->ambigu = (int *)mCalloc(data->crunch_len,sizeof(int));
  alldata->invar = (int *)mCalloc(data->crunch_len,sizeof(int));

  alldata->crunch_len = alldata->init_len = -1;
  For(j,n_otu)
    {
      alldata->c_seq[j] = (seq *)mCalloc(1,sizeof(seq));
      alldata->c_seq[j]->name = (char *)mCalloc(T_MAX_NAME,sizeof(char));
      strcpy(alldata->c_seq[j]->name,data->c_seq[j]->name);
      alldata->c_seq[j]->state = (char *)mCalloc(data->crunch_len,sizeof(char));
      alldata->c_seq[j]->state[0] = data->c_seq[j]->state[0];
    }
  
  n_patt = which_patt =  0;


  Fors(site,data->crunch_len,mod->stepsize) 
    {
      Fors(k,n_patt,mod->stepsize)
	{
	  For(j,n_otu)
	    {
	      if(/*!Compare_Two_States*/strncmp(alldata->c_seq[j]->state+k,
				     data->c_seq[j]->state+site,
				     mod->stepsize))
		break;
	    }

	  if(j == n_otu)
	    {
	      which_patt = k;
	      break;
	    }
	}
      
      if(k == n_patt)
	{
	  For(j,n_otu) Copy_One_State(data->c_seq[j]->state+site,
				      alldata->c_seq[j]->state+n_patt,
				      mod->stepsize);
	  
	  for(j=1;j<n_otu;j++) 
	    if(/*!Compare_Two_States*/strncmp(alldata->c_seq[j]->state+n_patt,
				   alldata->c_seq[j-1]->state+n_patt,
				   mod->stepsize)) break;
	  
	  if(j==n_otu) alldata->invar[n_patt] = 1;
	  alldata->wght[n_patt] += data->wght[site];
	  n_patt+=mod->stepsize;
	}
      else alldata->wght[which_patt] += data->wght[site];

/*       Print_Site(alldata,k,n_otu,"\n",mod->stepsize); */

    }

  alldata->init_len = data->crunch_len;
  alldata->crunch_len = n_patt;
  For(i,n_otu) alldata->c_seq[i]->len = n_patt;


  (!mod->datatype)?
    (Get_Base_Freqs(alldata)):
    (Get_AA_Freqs(alldata));

  return alldata;
}


/*********************************************************/

void Get_Base_Freqs(allseq *data)
{
  int i,j,k;
  double A,C,G,T;
  double fA,fC,fG,fT;
  double w;

  fA = fC = fG = fT = .25;

  For(k,8)
    {
      A = C = G = T = .0;
      For(i,data->n_otu)
	{
	  For(j,data->crunch_len)
	    {
	      w = data->wght[j];
	      if(w)
		{
		  switch(data->c_seq[i]->state[j]){
		  case 'A' : A+=w;
		    break;
		  case 'C' : C+=w;
		    break;
		  case 'G' : G+=w;
		    break;
		  case 'T' : T+=w;
		    break;
		  case 'U' : T+=w;
		    break;
		  case 'M' : C+=w*fC/(fC+fA); A+=w*fA/(fA+fC);
		    break;
		  case 'R' : G+=w*fG/(fA+fG); A+=w*fA/(fA+fG);
		    break;
		  case 'W' : T+=w*fT/(fA+fT); A+=w*fA/(fA+fT);
		    break;
		  case 'S' : C+=w*fC/(fC+fG); G+=w*fG/(fC+fG);
		    break;
		  case 'Y' : C+=w*fC/(fC+fT); T+=w*fT/(fT+fC);
		    break;
		  case 'K' : G+=w*fG/(fG+fT); T+=w*fT/(fT+fG);
		    break;
		  case 'B' : C+=w*fC/(fC+fG+fT); G+=w*fG/(fC+fG+fT); T+=w*fT/(fC+fG+fT);
		    break;
		  case 'D' : A+=w*fA/(fA+fG+fT); G+=w*fG/(fA+fG+fT); T+=w*fT/(fA+fG+fT);
		    break;
		  case 'H' : A+=w*fA/(fA+fC+fT); C+=w*fC/(fA+fC+fT); T+=w*fT/(fA+fC+fT);
		    break;
		  case 'V' : A+=w*fA/(fA+fC+fG); C+=w*fC/(fA+fC+fG); G+=w*fG/(fA+fC+fG);
		    break;
		  case 'N' : case 'X' : case '?' : case 'O' : case '-' : 
		    A+=w*fA; C+=w*fC; G+=w*fG; T+=w*fT; break;
		  default : break;
		  }
		}
	    }  
	}
      fA = A/(A+C+G+T);
      fC = C/(A+C+G+T);
      fG = G/(A+C+G+T);
      fT = T/(A+C+G+T);
    }

  data->b_frq[0] = fA;
  data->b_frq[1] = fC;
  data->b_frq[2] = fG;
  data->b_frq[3] = fT;
}

/*********************************************************/

void Get_AA_Freqs(allseq *data)
{
  int i,j,k;
  double A,C,D,E,F,G,H,I,K,L,M,N,P,Q,R,S,T,V,W,Y;
  double fA,fC,fD,fE,fF,fG,fH,fI,fK,fL,fM,fN,fP,fQ,fR,fS,fT,fV,fW,fY;
  double w;
  double sum;

  fA = fC = fD = fE = fF = fG = fH = fI = fK = fL = 
  fM = fN = fP = fQ = fR = fS = fT = fV = fW = fY = 1./20.;

  For(k,8)
    {

      A = C = D = E = F = G = H = I = K = L = 
      M = N = P = Q = R = S = T = V = W = Y = .0;
      
      For(i,data->n_otu)
	{
	  For(j,data->crunch_len)
	    {
	      w = data->wght[j];
	      if(w)
		{
		  switch(data->c_seq[i]->state[j]){
		  case 'A' : A+=w;		break;
		  case 'C' : C+=w;		break;
		  case 'D' : D+=w;		break;
		  case 'E' : E+=w;		break;
		  case 'F' : F+=w;		break;
		  case 'G' : G+=w;		break;
		  case 'H' : H+=w;		break;
		  case 'I' : I+=w;		break;
		  case 'K' : K+=w;		break;
		  case 'L' : L+=w;		break;
		  case 'M' : M+=w;		break;
		  case 'N' : N+=w;		break;
		  case 'P' : P+=w;		break;
		  case 'Q' : Q+=w;		break;
		  case 'R' : R+=w;		break;
		  case 'S' : S+=w;		break;
		  case 'T' : T+=w;		break;
		  case 'V' : V+=w;		break;
		  case 'W' : W+=w;		break;
		  case 'Y' : Y+=w;		break;
		  case 'Z' : Q+=w;		break;
		  case 'X' : case '?' : case 'O' : case '-' : 
		    A+=w*fA;
		    C+=w*fC; 
		    D+=w*fD; 
		    E+=w*fE; 
		    F+=w*fF; 
		    G+=w*fG; 
		    H+=w*fH; 
		    I+=w*fI; 
		    K+=w*fK; 
		    L+=w*fL; 
		    M+=w*fM; 
		    N+=w*fN; 
		    P+=w*fP; 
		    Q+=w*fQ; 
		    R+=w*fR; 
		    S+=w*fS; 
		    T+=w*fT; 
		    V+=w*fV; 
		    W+=w*fW; 
		    Y+=w*fY; 
		    break;
		  default : break;
		  }
		}
	    }  
	}
      sum = (A+C+D+E+F+G+H+I+K+L+M+N+P+Q+R+S+T+V+W+Y);
      fA = A/sum;      fC = C/sum;      fD = D/sum;      fE = E/sum;
      fF = F/sum;      fG = G/sum;      fH = H/sum;      fI = I/sum;
      fK = K/sum;      fL = L/sum;      fM = M/sum;      fN = N/sum;
      fP = P/sum;      fQ = Q/sum;      fR = R/sum;      fS = S/sum;
      fT = T/sum;      fV = V/sum;      fW = W/sum;      fY = Y/sum;
    }

  data->b_frq[0]  = fA;  data->b_frq[1]  = fR;  data->b_frq[2]  = fN;  data->b_frq[3]  = fD;
  data->b_frq[4]  = fC;  data->b_frq[5]  = fQ;  data->b_frq[6]  = fE;  data->b_frq[7]  = fG;
  data->b_frq[8]  = fH;  data->b_frq[9]  = fI;  data->b_frq[10] = fL;  data->b_frq[11] = fK;
  data->b_frq[12] = fM;  data->b_frq[13] = fF;  data->b_frq[14] = fP;  data->b_frq[15] = fS;
  data->b_frq[16] = fT;  data->b_frq[17] = fW;  data->b_frq[18] = fY;  data->b_frq[19] = fV;
}

/*********************************************************/

arbre *Read_Tree_File(FILE *fp_input_tree)
{
  char *line;
  arbre *tree;
  int i;
  char c;

  line = (char *)mCalloc(T_MAX_LINE,sizeof(char));

  do
    c=fgetc(fp_input_tree);
  while((c != '(') && (c != EOF));

  if(c==EOF) 
      {
          Free(line);
          return NULL;
      }

  i=0;
  for(;;)
    {
      if((c == ' ') || (c == '\n'))
	{
	  c=fgetc(fp_input_tree); 
	  if(c==EOF) break;
	  else continue;
	}
      
      line[i]=c;
      i++;
      c=fgetc(fp_input_tree);
      if(c==EOF || c==';') break;
    }
  
  tree = Read_Tree(line);
  Free(line);
  return tree;
}

/*********************************************************/

void Init_Tree_Edges(node *a, node *d, arbre *tree, int *cur)
{
  int i,dir_a_d;

  dir_a_d = -1;
  For(i,3) if(a->v[i] == d) {dir_a_d = i; break;}

  
  tree->t_edges[*cur] = a->b[dir_a_d];
  tree->t_edges[*cur]->num = *cur;
  *cur = *cur + 1;

  if(d->tax) return;
  else
    {
      For(i,3)
	{
	  if(d->v[i] != a)
	    Init_Tree_Edges(d,d->v[i],tree,cur);
	}
    }
}

/*********************************************************/

void Exit(char *message)
{
  fprintf(stderr,"%s",message);
  exit(1);
}

/*********************************************************/

void *mCalloc(int nb, size_t size)
{
  void *allocated;

  if((allocated = calloc((size_t)nb,(size_t)size)) != NULL)
    {
      return allocated;
    }
  else
    Exit("\n. Err: low memory\n");

  return NULL;
}

/*********************************************************/

void *mRealloc(void *p,int nb, size_t size)
{
  if((p = realloc(p,(size_t)nb*size)) != NULL)
	return p;
  else
    Exit("\n. Err: low memory\n");
  
  return NULL;
}

/*********************************************************/

arbre *Make_Light_Tree_Struct(int n_otu)
{
  arbre *tree;
  int i;

  tree          = (arbre *)mCalloc(1,sizeof(arbre ));
  tree->t_edges = (edge **)mCalloc(2*n_otu-3,sizeof(edge *));
  tree->noeud   = (node **)mCalloc(2*n_otu-2,sizeof(node *));
  tree->n_otu = n_otu;

  For(i,2*n_otu-3)
    {
      tree->t_edges[i] = (edge *)mCalloc(1,sizeof(edge));
      Init_Edge_Light(tree->t_edges[i]);
    }

  For(i,2*n_otu-2)
    {
      tree->noeud[i] = (node *)mCalloc(1,sizeof(node));
      tree->noeud[i]->v = NULL;
      Make_Node_Light(tree->noeud[i]);
    }
  return tree;
}

/*********************************************************/

int Sort_Double_Decrease(const void *a, const void *b)
{
    if((*(double *)(a)) >= (*(double *)(b))) return -1;
    else return 1;
}

/*********************************************************/

void qksort(double* A, int ilo, int ihi)
{
    double pivot;	// pivot value for partitioning array
    int ulo, uhi;	// indices at ends of unpartitioned region
    int ieq;		// least index of array entry with value equal to pivot
    double tempEntry;	// temporary entry used for swapping

    if (ilo >= ihi) {
	return;
    }
    // Select a pivot value.
    pivot = A[(ilo + ihi)/2];
    // Initialize ends of unpartitioned region and least index of entry
    // with value equal to pivot.
    ieq = ulo = ilo;
    uhi = ihi;
    // While the unpartitioned region is not empty, try to reduce its size.
    while (ulo <= uhi) {
	if (A[uhi] > pivot) {
	    // Here, we can reduce the size of the unpartitioned region and
	    // try again.
	    uhi--;
	} else {
	    // Here, A[uhi] <= pivot, so swap entries at indices ulo and
	    // uhi.
	    tempEntry = A[ulo];
	    A[ulo] = A[uhi];
	    A[uhi] = tempEntry;
	    // After the swap, A[ulo] <= pivot.
	    if (A[ulo] < pivot) {
		// Swap entries at indices ieq and ulo.
		tempEntry = A[ieq];
		A[ieq] = A[ulo];
		A[ulo] = tempEntry;
		// After the swap, A[ieq] < pivot, so we need to change
		// ieq.
		ieq++;
		// We also need to change ulo, but we also need to do
		// that when A[ulo] = pivot, so we do it after this if
		// statement.
	    }
	    // Once again, we can reduce the size of the unpartitioned
	    // region and try again.
	    ulo++;
	}
    }
    // Now, all entries from index ilo to ieq - 1 are less than the pivot
    // and all entries from index uhi to ihi + 1 are greater than the
    // pivot.  So we have two regions of the array that can be sorted
    // recursively to put all of the entries in order.
    qksort(A, ilo, ieq - 1);
    qksort(A, uhi + 1, ihi);
}

/********************************************************/

void Print_Site(allseq *alldata, int num, int n_otu, char *sep, int stepsize)
{
  int i,j;
  For(i,n_otu) 
    {
      fprintf(stderr, "%s   ",alldata->c_seq[i]->name);
      For(j,stepsize)
	fprintf(stderr, "%c",alldata->c_seq[i]->state[num+j]);
      fprintf(stderr, "%s",sep);
    }
  fprintf(stderr,"%s",sep);
}

/*********************************************************/

void Print_Site_Lk(arbre *tree)
{
  int site;
  fprintf(stderr, "\n\n\n. Log likelihood at individual sites\n\n");

  For(site,tree->data->init_len) 
    {
        fprintf(stderr, "  Site %4d lnL = %10f\n",
               site+1,
               tree->site_lk[tree->data->sitepatt[site]]);
    }
}

/*********************************************************/

void Print_Seq(seq **data, int n_otu)
{
  int i,j;

  fprintf(stderr, "%d\t%d\n",n_otu,data[0]->len);
  For(i,n_otu)
    {
      For(j,23)
	{
	  if(j<(int)strlen(data[i]->name))
	     putchar(data[i]->name[j]);
	  else putchar(' ');
	}
      For(j,data[i]->len) /*FLT uncommented*/
      /*      For(j,2000)*//*FLT commented*/
	{
	  fprintf(stderr, "%c",data[i]->state[j]);
	}
      fprintf(stderr, "\n");
    }
}

/*********************************************************/

void Print_CSeq(FILE *fp, allseq *alldata)
{
    int i,j,k;
  int n_otu;

  n_otu = alldata->n_otu;
  fprintf(fp,"%d\t%d\n",n_otu,alldata->init_len);
  For(i,n_otu)
    {
      For(j,23)
	{
	  if(j<(int)strlen(alldata->c_seq[i]->name))
	     fputc(alldata->c_seq[i]->name[j],fp);
	  else fputc(' ',fp);
	}

      For(j,alldata->crunch_len)
	{
	  For(k,alldata->wght[j])
	    fprintf(fp,"%c",alldata->c_seq[i]->state[j]);
	}
      fprintf(fp,"\n");
    }
  fprintf(fp,"\n");

/*   printf("\t"); */
/*   For(j,alldata->crunch_len) */
/*     printf("%.0f ",alldata->wght[j]); */
/*   printf("\n"); */
}

/*********************************************************/

void Order_Tree_Seq(arbre *tree, seq **data)
{
    int i,j,n_otu;
    seq *buff;
    
    n_otu = tree->n_otu;
    
    For(i,n_otu)
        {
            For(j,n_otu)
                {
                    if(!strcmp(tree->noeud[i]->name,data[j]->name))
                        break;
                }
            buff = data[j];
            data[j] = data[i];
            data[i] = buff;
        }
}

/*********************************************************/

void Order_Tree_CSeq(arbre *tree, allseq *data)
{
    int i,j,n_otu_tree,n_otu_seq;
    seq *buff;
    
    
    n_otu_tree = tree->n_otu;
    n_otu_seq  = data->n_otu;
    
    
    if(n_otu_tree != n_otu_seq) 
        {
            /*       printf("%d(tree) != %d(seq) \n",n_otu_tree,n_otu_seq); */
            Exit("\n. The number of tips in the tree is not the same as the number of sequences\n");
        }
    For(i,MAX(n_otu_tree,n_otu_seq))
        {
            For(j,MIN(n_otu_tree,n_otu_seq))
                {
                    if(!strcmp(tree->noeud[i]->name,data->c_seq[j]->name))
                        break;
                }
            
            if(j==MIN(n_otu_tree,n_otu_seq))
                {
                    fprintf(stderr, "\n. Err: %s is not found in sequences data set\n",
                           tree->noeud[i]->name);
                    Exit("");
                }
            buff = data->c_seq[j];
            data->c_seq[j] = data->c_seq[i];
            data->c_seq[i] = buff;
        }
}

/*********************************************************/

matrix *Make_Mat(int n_otu)
{
  matrix *mat;
  int i;

  mat = (matrix *)mCalloc(1,sizeof(matrix));

  mat->n_otu = n_otu;

  mat->P = (double **)mCalloc(n_otu,sizeof(double *));
  mat->Q = (double **)mCalloc(n_otu,sizeof(double *));
  mat->dist = (double **)mCalloc(n_otu,sizeof(double *));
  mat->on_off = (int *)mCalloc(n_otu,sizeof(int));
  mat->name = (char **)mCalloc(n_otu,sizeof(char *));
  mat->tip_node = (node **)mCalloc(n_otu,sizeof(node *));

  
  For(i,n_otu)
    {
      mat->P[i] = (double *)mCalloc(n_otu,sizeof(double));
      mat->Q[i] = (double *)mCalloc(n_otu,sizeof(double));
      mat->dist[i] = (double *)mCalloc(n_otu,sizeof(double));
      mat->name[i] = (char *)mCalloc(T_MAX_NAME,sizeof(char));
    }
     
  return mat;
}

/*********************************************************/

void Init_Mat(matrix *mat, allseq *data)
{
  int i;

  mat->n_otu = data->n_otu;
  mat->r = mat->n_otu;
  mat->curr_int = mat->n_otu;
  mat->curr_br = 0;
  mat->method = 1;

  For(i,data->n_otu)
    {
      strcpy(mat->name[i],data->c_seq[i]->name);
      mat->on_off[i] = 1;
    }
}

/*********************************************************/

arbre *Make_Tree(allseq *data)
{
    arbre *tree;
    int i;

    tree = (arbre *)mCalloc(1,sizeof(arbre ));
    tree->n_otu = data->n_otu;
    Init_Tree(tree);
    
    For(i,2*tree->n_otu-2)
        {
            tree->noeud[i] = (node *)mCalloc(1,sizeof(node));
            tree->noeud[i]->v = NULL;
            Make_Node_Light(tree->noeud[i]);
        }
    
    For(i,tree->n_otu)
        {
            strcpy(tree->noeud[i]->name,data->c_seq[i]->name);
            tree->noeud[i]->tax = 1;
            tree->noeud[i]->agglo = 1;
            tree->noeud[i]->ni = 1; 
            tree->noeud[i]->num = i;
        }
    
    return tree;
}

/*********************************************************/

void Print_Dist(matrix *mat)
{
  int i,j;

  For(i,mat->n_otu)
    {
      printf("%s ",mat->name[i]);
      
      For(j,mat->n_otu)
	printf("%9.6f ",mat->dist[i][j]);
      printf("\n");
    }
}

/*********************************************************/

void Print_Node(node *a, node *d, arbre *tree)
{
  int i;

  printf("N %2d %2d  ",a->num,d->num);
  For(i,3) if(a->v[i] == d) {printf("%2d %2d %f\n",
				    a->b[i]->num,
				    a->b[i]->check_this_one,
				    a->b[i]->nj_score); break;}
  if(d->tax) return;
  else
    For(i,3)
      if(d->v[i] != a) Print_Node(d,d->v[i],tree);
}

/*********************************************************/

void Share_Lk_Struct(arbre *t_full, arbre *t_empt)
{
  int i,n_otu;
  edge *b_e,*b_f;


  n_otu = t_full->n_otu;

  t_empt->root = t_empt->noeud[0];

  t_empt->tot_loglk_sorted = t_full->tot_loglk_sorted;
  t_empt->site_lk = t_full->site_lk;
  t_empt->tot_dloglk = t_full->tot_dloglk;
  t_empt->tot_d2loglk = t_full->tot_d2loglk;
/*   t_empt->mod = t_full->mod; */
/*   t_empt->data = t_full->data; */
/*   t_empt->mod->s_opt = t_full->mod->s_opt; */
  t_empt->p_lk = t_full->p_lk;

/*   For(i,2*n_otu-2) */
/*   t_empt->noeud[i]->n_ex_nodes = t_full->noeud[i]->n_ex_nodes; */

  For(i,2*n_otu-3)
    {
      b_f = t_full->t_edges[i];
      b_e = t_empt->t_edges[i];
      
      b_e->Pij_rr    = b_f->Pij_rr;
      b_e->dPij_rr   = b_f->dPij_rr;
      b_e->d2Pij_rr  = b_f->d2Pij_rr;
      
      b_e->p_lk_left = b_f->p_lk_left;
      b_e->p_lk_rght = b_f->p_lk_rght;
      
      b_e->sum_scale_f_left = b_f->sum_scale_f_left;
      b_e->sum_scale_f_rght = b_f->sum_scale_f_rght;
      
      b_e->site_p_lk_left = b_f->site_p_lk_left;
      b_e->site_p_lk_rght = b_f->site_p_lk_rght;

      b_e->site_dlk_rr = b_f->site_dlk_rr;
      b_e->site_d2lk_rr = b_f->site_d2lk_rr;

      b_e->ql = b_f->ql;
    }
}

/*********************************************************/

void Init_Constant()
{

  NODE_DEG_MAX =         50;
  BRENT_ITMAX =         100;
  BRENT_CGOLD =   0.3819660;
  BRENT_ZEPS  =      1.e-10;
  MNBRAK_GOLD =    1.618034;
  MNBRAK_GLIMIT =     100.0;
  MNBRAK_TINY =      1.e-20;
  ALPHA_MIN =          0.04;
  ALPHA_MAX =           100;
  BL_MIN =           1.e-10;
  BL_START =         1.e-03;
  BL_MAX =           1.e+05;
#ifdef LH3_REVISION
  /* This is a tricky issue. The author of PHYML uses this variable to perform a consistent test, which
   * check whether optimizations twice can lead to the same result. If I am right, on i686-linux systems
   * I have never experienced any exception caused by this variable. However, on alpha-osf1 or x86_64-linux
   * architecture, optimizations at different times may differ by about 5e-6, exceeding MIN_DIFF_LK. Thus
   * I decide to increase the threshold a little because I believe the exception is due to either CPU or
   * software environment (such as OS or compilers), but not to innate inconsistencies of algorithms.
   *
   * In addition, I think it may be better if PHYML could avoid optimizing the same thing for many times.
   * Firstly, it can speed up the program given my guess that 1/4 of computing time elapses on repeated
   * optimization. And secondly, in this way, we will need not to consider the problems caused by hardwares,
   * OS or compilers. */
  MIN_DIFF_LK =      1.e-05;
#else
  MIN_DIFF_LK =      1.e-06;
#endif
  GOLDEN_R =     0.61803399;
  GOLDEN_C = (1.0-GOLDEN_R);
  T_MAX_FILE =          200;
  T_MAX_LINE =       100000;
  T_MAX_NAME =          100;
  T_MAX_SEQ  =      1000000;
  N_MAX_INSERT  =        20;
  N_MAX_OTU  =         4000;
  UNLIKELY =         -1.e10;
  NJ_SEUIL =            0.1;
  ROUND_MAX =           100;
  DIST_MAX =           2.00;
  AROUND_LK =          50.0;
  PROP_STEP =           1.0;
  T_MAX_ALPHABET =      100;
  MDBL_MIN =  2.225074E-308;
  MDBL_MAX =  1.797693E+308;
  POWELL_ITMAX =        200;
  LINMIN_TOL =      2.0E-04;
  LIM_SCALE =             3;
  LIM_SCALE_VAL   =  1.E-50;
/*   LIM_SCALE =           300; */
/*   LIM_SCALE_VAL   = 1.E-500; */
}

/*********************************************************/

void Print_Mat(matrix *mat)
{
  int i,j;
 
  printf("%d",mat->n_otu);  
  printf("\n");

  For(i,mat->n_otu)
    {
      For(j,13)
	{
	  if(j>=(int)strlen(mat->name[i])) putchar(' ');
	  else putchar(mat->name[i][j]);
	}
		      
      For(j,mat->n_otu)
	{
	  if(mat->dist[i][j] == -1)
	    printf("   -     ");
	  else
	    printf("%7.8f  ",mat->dist[i][j]);
	}
      printf("\n");
    }
}

/*********************************************************/

int Sort_Edges_Diff_Lk(arbre *tree, edge **sorted_edges, int n_elem)
{
  int i,j;
  edge *buff;

  For(i,n_elem-1)
    {
      for(j=i+1;j<n_elem;j++)
	{
	  if(sorted_edges[j]->diff_lk < sorted_edges[i]->diff_lk)
	    {
	      buff = sorted_edges[j];
	      sorted_edges[j] = sorted_edges[i];
	      sorted_edges[i] = buff;
	    }
	}
    }
  return 1;
}
/*********************************************************/

void NNI(arbre *tree, edge *b_fcus, int do_swap)
{
  int l_r, r_l, l_v1, l_v2, r_v3, r_v4;
  node *v1,*v2,*v3,*v4;
  double lk1, lk2, lk3;
  double lk1_init, lk2_init, lk3_init;
  double bl_init;
  double l1,l2,l3;
  double l_infa, l_infb, l_max;
/*   double lk_infa, lk_infb, lk_max; */
  double lk_init;
  
  bl_init           = b_fcus->l;
  lk_init           = tree->tot_loglk;

  b_fcus->best_conf = 1;
  b_fcus->diff_lk   = .0;

  lk1 = lk2 = lk3   = UNLIKELY;
  v1 = v2 = v3 = v4 = NULL;
  
  l_r = r_l = l_v1 = l_v2 = r_v3 = r_v4 = -1;
    
  l_r               = b_fcus->l_r;
  r_l               = b_fcus->r_l;
    
  v1                = b_fcus->left->v[b_fcus->l_v1];
  v2                = b_fcus->left->v[b_fcus->l_v2];
  v3                = b_fcus->rght->v[b_fcus->r_v1];
  v4                = b_fcus->rght->v[b_fcus->r_v2];


  l1 = l2 = l3 = -1.;
  
#ifdef LH3_ADDON
  tree->lh3_tree.is_NNI = 1;
#endif

  /***********/
  Swap(v2,b_fcus->left,b_fcus->rght,v3,tree);
  tree->mod->s_opt->opt_bl = 0;
  tree->both_sides    = 1;
  lk2_init = Update_Lk_At_Given_Edge(b_fcus,tree);

 
  l_infa = 10.*b_fcus->l;
  l_max  = b_fcus->l;
  l_infb = BL_MIN;
 
  lk2 = Br_Len_Brent(l_infa,l_max,l_infb,
		     1.e-6,
		     &(b_fcus->l),
		     b_fcus,tree,1000);

  if(lk2 < lk2_init - MIN_DIFF_LK)
    {
      fprintf(stderr, "%f %f %f %f\n",l_infa,l_max,l_infb,b_fcus->l);
      fprintf(stderr, "%f -- %f \n",lk2_init,lk2);
#ifdef LH3_REVISION
      fprintf(stderr, "\n. Err. in NNI (1)\n");
#else
      fprintf(stderr, "\n. Err. in Optimize_Br_Len_Serie\n");
#endif
    }

  l2  = b_fcus->l;
  Swap(v3,b_fcus->left,b_fcus->rght,v2,tree); /* lh3: swap back */
  /***********/


  /***********/
  Swap(v2,b_fcus->left,b_fcus->rght,v4,tree);
  b_fcus->l = bl_init;
  tree->mod->s_opt->opt_bl = 0;
  tree->both_sides = 1;
  lk3_init = Update_Lk_At_Given_Edge(b_fcus,tree);


  l_infa = 10.*b_fcus->l;
  l_max  = b_fcus->l;
  l_infb = BL_MIN;
 
  lk3 = Br_Len_Brent(l_infa,l_max,l_infb,
		     1.e-6,
		     &(b_fcus->l),
		     b_fcus,tree,1000);

  if(lk3 < lk3_init - MIN_DIFF_LK)
    {
      fprintf(stderr, "%f %f %f %f\n",l_infa,l_max,l_infb,b_fcus->l);
      fprintf(stderr, "%f -- %f \n",lk3_init,lk3);
      fprintf(stderr, "\n. Err. in NNI (2)\n");
   }


  l3  = b_fcus->l;
  Swap(v4,b_fcus->left,b_fcus->rght,v2,tree); /* lh3: swap back */
  /***********/
   


  /***********/ /* lh3: recalculate the probability and branch length */
   b_fcus->l = bl_init;
   tree->mod->s_opt->opt_bl  = 0;
   tree->both_sides = 1;

   lk1_init = Update_Lk_At_Given_Edge(b_fcus,tree);

   if((lk1_init < lk_init - MIN_DIFF_LK) ||
      (lk1_init > lk_init + MIN_DIFF_LK)) 
       {
           fprintf(stderr, "\n\n. lk_init = %E; lk = %E\n",
                  lk_init,
                  lk1_init);
           Exit("\n. Err. in NNI (3)\n");
       }

   l_infa = 10.*b_fcus->l;
   l_max  = b_fcus->l;
   l_infb = BL_MIN;
 
   lk1 = Br_Len_Brent(l_infa,l_max,l_infb,
                      1.e-6,
                      &(b_fcus->l),
                      b_fcus,tree,1000);

   if(lk1 < lk_init - MIN_DIFF_LK)
       {
           fprintf(stderr, "\n\n%f %f %f %f\n",l_infa,l_max,l_infb,b_fcus->l);
           fprintf(stderr, "%f -- %f \n",lk1_init,lk1);
           fprintf(stderr, "\n. Err. in NNI (3)\n");
       }

   l1  = b_fcus->l;
   /***********/

#ifdef LH3_ADDON
  tree->lh3_tree.is_NNI = 0;
#endif

   b_fcus->ql[0] = l1;
   b_fcus->ql[1] = l2;
   b_fcus->ql[2] = l3;


   b_fcus->diff_lk = lk1 - MAX(lk2,lk3);
   

   
   if(lk2 > lk3) b_fcus->best_conf = 2;
   else          b_fcus->best_conf = 3;


   if((do_swap) && ((lk2 > lk1+MDBL_MIN) || (lk3 > lk1+MDBL_MIN)))
     {
      tree->n_swap++;
      printf("Swap edge %d -> %f\n",b_fcus->num,MAX(lk2,lk3));
      fflush(stdout);

      if(lk2 > lk3)
	 {
	   tree->best_loglk = lk2;
	   Swap(v2,b_fcus->left,b_fcus->rght,v3,tree);
	   b_fcus->l = l2;
	   tree->both_sides = 1;
	   Lk(tree,tree->data);
	 }
       else
	 {
	   tree->best_loglk = lk3;
	   Swap(v2,b_fcus->left,b_fcus->rght,v4,tree);
	   b_fcus->l = l3;
	   tree->both_sides = 1;
	   Lk(tree,tree->data);
	 }
     }
   else 
     {
       b_fcus->l = bl_init;
       Update_PMat_At_Given_Edge(b_fcus,tree);
       tree->tot_loglk = lk_init;
     }
}

/*********************************************************/

void Swap(node *a, node *b, node *c, node *d, arbre *tree)
{
  int ab, ba, cd, dc;
  int i;


  /* \             /d      \             /a
      \           /         \           / 
       \b__...__c/    ->     \b__...__c/  
       /         \	         /         \  
      /           \	        /           \ 
     /a            \  	   /d            \ */


  
  ab = ba = cd = dc = -1;

  For(i,3) if(a->v[i] == b) { ab = i; break; }
  For(i,3) if(b->v[i] == a) { ba = i; break; }
  For(i,3) if(c->v[i] == d) { cd = i; break; }
  For(i,3) if(d->v[i] == c) { dc = i; break; }
 
  a->v[ab] = c;
  d->v[dc] = b;
  b->v[ba] = d;
  c->v[cd] = a;
  b->b[ba] = d->b[dc];
  c->b[cd] = a->b[ab];

  (a->b[ab]->left == b)?
  (a->b[ab]->left = c):
  (a->b[ab]->rght = c);

  (d->b[dc]->left == c)?
  (d->b[dc]->left = b):
  (d->b[dc]->rght = b);
  
  For(i,3)
    {
      if(a->b[ab]->left->v[i] == a->b[ab]->rght) a->b[ab]->l_r = i;
      if(a->b[ab]->rght->v[i] == a->b[ab]->left) a->b[ab]->r_l = i;
      if(d->b[dc]->left->v[i] == d->b[dc]->rght) d->b[dc]->l_r = i;
      if(d->b[dc]->rght->v[i] == d->b[dc]->left) d->b[dc]->r_l = i;
    }
  

  a->b[ab]->l_v1 = a->b[ab]->l_v2 = 
  a->b[ab]->r_v1 = a->b[ab]->r_v2 = 
  d->b[dc]->l_v1 = d->b[dc]->l_v2 = 
  d->b[dc]->r_v1 = d->b[dc]->r_v2 = -1;
  
  For(i,3)
    {
      if(i != a->b[ab]->l_r)
	{
	  if(a->b[ab]->l_v1 < 0) a->b[ab]->l_v1 = i;
	  else a->b[ab]->l_v2 = i;
	}
      if(i != a->b[ab]->r_l)
	{
	  if(a->b[ab]->r_v1 < 0) a->b[ab]->r_v1 = i;
	  else a->b[ab]->r_v2 = i;
	}
      if(i != d->b[dc]->l_r)
	{
	  if(d->b[dc]->l_v1 < 0) d->b[dc]->l_v1 = i;
	  else d->b[dc]->l_v2 = i;
	}
      if(i != d->b[dc]->r_l)
	{
	  if(d->b[dc]->r_v1 < 0) d->b[dc]->r_v1 = i;
	  else d->b[dc]->r_v2 = i;
	}
    }
}

/*********************************************************/

void Update_All_Partial_Lk(edge *b_fcus, arbre *tree)
{

  Update_SubTree_Partial_Lk(b_fcus->left->b[b_fcus->l_v1],
			    b_fcus->left,
			    b_fcus->left->v[b_fcus->l_v1],
			    tree);

  Update_SubTree_Partial_Lk(b_fcus->left->b[b_fcus->l_v2],
			    b_fcus->left,
			    b_fcus->left->v[b_fcus->l_v2],
			    tree);

  Update_SubTree_Partial_Lk(b_fcus->rght->b[b_fcus->r_v1],
			    b_fcus->rght,
			    b_fcus->rght->v[b_fcus->r_v1],
			    tree);

  Update_SubTree_Partial_Lk(b_fcus->rght->b[b_fcus->r_v2],
			    b_fcus->rght,
			    b_fcus->rght->v[b_fcus->r_v2],
			    tree);

  tree->tot_loglk = Lk_At_Given_Edge(tree,b_fcus);
}

/*********************************************************/

void Update_SubTree_Partial_Lk(edge *b_fcus, node *a, node *d, arbre *tree)
{
  int i;

  Update_P_Lk(tree,b_fcus,a);
  if(d->tax) return;
  else For(i,3) if(d->v[i] != a) 
    Update_SubTree_Partial_Lk(d->b[i],d,d->v[i],tree);
}

/*********************************************************/

double Update_Lk_At_Given_Edge(edge *b_fcus, arbre *tree)
{

/*    if(b_fcus->l < BL_MIN) b_fcus->l = BL_MIN; */
/*    For(i,tree->mod->n_catg) */
/*      { */
/*        PMat(b_fcus->l*tree->mod->rr[i], */
/*  	   tree->mod, */
/*  	   &b_fcus->Pij_rr[i]); */
/*      } */


  /* Updating partial likelihood after branch swapping */
  Update_P_Lk(tree,b_fcus,b_fcus->left);
  Update_P_Lk(tree,b_fcus,b_fcus->rght);

  tree->tot_loglk = Lk_At_Given_Edge(tree,b_fcus);
  return tree->tot_loglk;
}

/*********************************************************/

void Update_PMat_At_Given_Edge(edge *b_fcus, arbre *tree)
{

  int i;
  double len;

  len = -1.0;

  For(i,tree->mod->n_catg)
    {
      len = b_fcus->l*tree->mod->rr[i];
      if(len < BL_MIN) len = BL_MIN;
      PMat(len,tree->mod,&b_fcus->Pij_rr[i]);
    }

}

/*********************************************************/

allseq *Make_Seq(int n_otu, int len, char **sp_names)
{
  allseq *alldata;
  int j;

  alldata                        = (allseq *)mCalloc(1,sizeof(allseq));
  alldata->n_otu                 = n_otu;
  alldata->c_seq                 = (seq **)mCalloc(n_otu,sizeof(seq *));
  alldata->wght                  = (double *)mCalloc(len,sizeof(double));
  alldata->factw                 = (double *)mCalloc(len,sizeof(double));
  alldata->b_frq                 = (double *)mCalloc(T_MAX_ALPHABET,sizeof(double));
  alldata->ambigu                = (int *)mCalloc(len,sizeof(int));
  alldata->sitepatt              = (int *)mCalloc(len,sizeof(int ));
  alldata->invar                 = (int *)mCalloc(len,sizeof(int));

  alldata->crunch_len = alldata->init_len = -1;

  For(j,n_otu)
    {
      alldata->c_seq[j]          = (seq *)mCalloc(1,sizeof(seq));
      alldata->c_seq[j]->name    = (char *)mCalloc(T_MAX_NAME,sizeof(char));
      strcpy(alldata->c_seq[j]->name,sp_names[j]);
      alldata->c_seq[j]->state    = (char *)mCalloc(len+1,sizeof(char));
    }
  return alldata;
}

/*********************************************************/

allseq *Copy_CData(allseq *ori, model *mod)
{
  allseq *new;
  int i,j,n_otu;
  char **sp_names;

  n_otu = ori->n_otu;

  sp_names = (char **)mCalloc(n_otu,sizeof(char *));
  For(i,n_otu) 
    {
      sp_names[i] = (char *)mCalloc(T_MAX_NAME,sizeof(char));
      strcpy(sp_names[i],ori->c_seq[i]->name);
    }

  new = Make_Seq(n_otu,ori->init_len,sp_names);

  For(i,n_otu) Free(sp_names[i]);
  Free(sp_names);

  For(i,ori->init_len)
    new->sitepatt[i] = ori->sitepatt[i];

  For(j,ori->crunch_len) 
    {
      For(i,ori->n_otu) 
	new->c_seq[i]->state[j] = ori->c_seq[i]->state[j];
      new->wght[j] = ori->wght[j];
      new->factw[j] = ori->factw[j];
      new->ambigu[j] = ori->ambigu[j];
      new->invar[j] = ori->invar[j];
    }

  For(i,ori->n_otu) 
    {
      new->c_seq[i]->len = ori->c_seq[i]->len;
      strcpy(new->c_seq[i]->name,ori->c_seq[i]->name);
    }

  new->init_len = ori->init_len;
  new->clean_len = ori->clean_len;
  new->crunch_len = ori->crunch_len;
  For(i,mod->ns) new->b_frq[i] = ori->b_frq[i];
  new->n_otu = ori->n_otu;
  return new;
}

/*********************************************************/

optimiz *Alloc_Optimiz()
{
  optimiz *s_opt;
  s_opt = (optimiz *)mCalloc(1,sizeof(optimiz));
  return s_opt;
}

/*********************************************************/

void Init_Optimiz(optimiz *s_opt)
{
  s_opt->print           = 1;
  s_opt->last_opt        = 1;
  s_opt->first_opt_alpha = 0;
  s_opt->first_opt_kappa = 0;
  s_opt->opt_alpha       = 0;
  s_opt->opt_kappa       = 0;
  s_opt->opt_bl          = 0;
  s_opt->opt_pinvar      = 0;
  s_opt->init_lk         = UNLIKELY;
  s_opt->n_it_max        = 1000;
}

/*********************************************************/
	
int Filexists(char *filename)
{ 
  FILE *fp;
  fp =fopen(filename,"r");
  if (fp) {
    fclose(fp);
    return 1;
  } else
    return 0;
}

/*********************************************************/

FILE *Openfile(char *filename, int mode)
{
  /* mode = 0 -> read */
  /* mode = 1 -> write */
  /* mode = 2 -> append */

  FILE *fp;
  char *s;
  int open_test=0;

/*   s = (char *)mCalloc(T_MAX_FILE,sizeof(char)); */

/*   strcpy(s,filename); */

  s = filename;

  fp = NULL;

  switch(mode)
    {
    case 0 :
      {
	while(!(fp = (FILE *)fopen(s,"r")) && ++open_test<10)
	  {
	    printf("\nCan't open file %s, enter a new name : ",s);
	    Getstring_Stdin(s);
	    fflush(stdout);
	  }
	break;
      }
    case 1 :
      {
	fp = (FILE *)fopen(s,"w");
	break;
      }
    case 2 :
      {
	fp = (FILE *)fopen(s,"a");
	break;
      }
 
    default : break;
    
    }

/*   Free(s); */

  return fp;
}

/*********************************************************/

void Print_Fp_Out(FILE *fp_out, time_t t_beg, time_t t_end, arbre *tree, option *input, int n_data_set)
{
  char *s;
  div_t hour,min;
  
  fprintf(fp_out,". Sequence file : [%s]\n\n", input->seqfile);  
  
  /*  fprintf(fp_out,". Data set [#%d]\n",n_data_set); FLT*/

  (!tree->mod->datatype)?
    (fprintf(fp_out,". Model of nucleotides substitution : %s\n\n",input->modelname)):
    (fprintf(fp_out,". Model of amino acids substitution : %s\n\n",input->modelname));

  /*was after Sequence file ; moved here FLT*/
  s = (char *)mCalloc(T_MAX_LINE,sizeof(char));
  fprintf(fp_out,". Initial tree : [%s]\n\n",
	  (!input->inputtree)?("BIONJ"):
	  (strcat(strcat(strcat(s,"user tree ("),input->inputtreefile),")")));  
  Free(s);
  
  fprintf(fp_out,". Number of taxa : %d\n\n",tree->n_otu);/*added FLT*/

  fprintf(fp_out,"\n");

  fprintf(fp_out,". Likelihood : loglk = %.5f\n\n",tree->tot_loglk);/*was last ; moved here FLT*/

  fprintf(fp_out,". Discrete gamma model : %s\n",
	  (tree->mod->n_catg>1)?("Yes"):("No\n"));
  if(tree->mod->n_catg > 1)
    {
      fprintf(fp_out,"  - Number of categories : %d\n",tree->mod->n_catg);
      fprintf(fp_out,"  - Gamma shape parameter : %.3f\n\n",tree->mod->alpha);
    }
  
  if(tree->mod->invar)
    fprintf(fp_out,". Proportion of invariant : %.3f\n\n",tree->mod->pinvar);

  /*was before Discrete gamma model ; moved here FLT*/
  if(tree->mod->whichmodel <= 5)
    {
      fprintf(fp_out,". Transition/transversion ratio : %.3f\n\n",tree->mod->kappa);
    }
  else if(tree->mod->whichmodel == 6)
    {
      fprintf(fp_out,". Transition/transversion ratio for purines :     %.3f\n",
	      tree->mod->kappa*2.*tree->mod->lambda/(1.+tree->mod->lambda));
      fprintf(fp_out,". Transition/transversion ratio for pyrimidines : %.3f\n\n",
	      tree->mod->kappa*2./(1.+tree->mod->lambda));
    }

  if(!tree->mod->datatype)
    {
      fprintf(fp_out,". Nucleotides frequencies :\n\n");
      fprintf(fp_out,"  - f(A)=%8.5f\n",tree->mod->pi[0]);
      fprintf(fp_out,"  - f(C)=%8.5f\n",tree->mod->pi[1]);
      fprintf(fp_out,"  - f(G)=%8.5f\n",tree->mod->pi[2]);
      fprintf(fp_out,"  - f(T)=%8.5f\n\n",tree->mod->pi[3]);
    }



  /*****************************************/
  if((tree->mod->whichmodel == 7) ||
     (tree->mod->whichmodel == 8))
    {
      int i,j;
      
           printf("\n");
      fprintf(fp_out,". GTR relative rate parameters : \n\n");
      fprintf(fp_out,"A <-> C   %8.5f\n",*(tree->mod->rr_param[0]));
      fprintf(fp_out,"A <-> G   %8.5f\n",*(tree->mod->rr_param[1]));
      fprintf(fp_out,"A <-> T   %8.5f\n",*(tree->mod->rr_param[2]));
      fprintf(fp_out,"C <-> G   %8.5f\n",*(tree->mod->rr_param[3]));
      fprintf(fp_out,"C <-> T   %8.5f\n",*(tree->mod->rr_param[4]));
      fprintf(fp_out,"G <-> T   1.0 (fixed)\n\n");

      
      fprintf(fp_out,"\n. Instantaneous rate matrix : \n");
      fprintf(fp_out,"\n[A---------C---------G---------T------]\n");
      For(i,4) 
	{
	  For(j,4)
	    fprintf(fp_out,"%8.5f  ",tree->mod->mat_Q[i*4+j]);
	  fprintf(fp_out,"\n");
	}
      fprintf(fp_out,"\n");
      fprintf(fp_out,"eg., the instantaneous rate of change from 'C' to 'A' is %8.5f x %8.5f = %8.5f\n\n",
	      tree->mod->pi[0],
	      *(tree->mod->rr_param[0]),
	      tree->mod->mat_Q[1*4+0]);
    }
  /*****************************************/
  

  hour = div(t_end-t_beg,3600);
  min  = div(t_end-t_beg,60  );
  
  min.quot -= hour.quot*60;
  
  fprintf(fp_out,". Time used %dh%dm%ds\n", hour.quot,min.quot,(int)(t_end-t_beg)%60);
  if(t_end-t_beg > 60)
    fprintf(fp_out,". -> %d seconds\n",(int)(t_end-t_beg));
  
  fprintf(fp_out,"\n%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n");

  fflush(fp_out);

}

/*********************************************************/
/*FLT wrote this function*/
void Print_Fp_Out_Lines(FILE *fp_out, time_t t_beg, time_t t_end, arbre *tree, option *input, int n_data_set)
{
  char *s;
  /*div_t hour,min;*/

  if (n_data_set==1) 
      {
    
          fprintf(fp_out,". Sequence file : [%s]\n\n", input->seqfile);  

          (!tree->mod->datatype)?
              (fprintf(fp_out,". Model of nucleotides substitution : %s\n\n",input->modelname)):
              (fprintf(fp_out,". Model of amino acids substitution : %s\n\n",input->modelname));

          s = (char *)mCalloc(T_MAX_LINE,sizeof(char));
          fprintf(fp_out,". Initial tree : [%s]\n\n",
                  (!input->inputtree)?("BIONJ"):
                  (strcat(strcat(strcat(s,"user tree ("),input->inputtreefile),")")));
          Free(s);
          
          fprintf(fp_out,"\n");
          
          /*headline 1*/
          fprintf(fp_out, ". Data\t");
          
          fprintf(fp_out,"Nb of \t");
          
          fprintf(fp_out,"Likelihood\t");
          
          fprintf(fp_out, "Discrete   \t");
          
          if(tree->mod->n_catg > 1)
              fprintf(fp_out, "Number of \tGamma shape\t");
          
          fprintf(fp_out,"Proportion of\t");
          
          if(tree->mod->whichmodel <= 6)
              fprintf(fp_out,"Transition/ \t");
          
          fprintf(fp_out,"Nucleotides frequencies               \t");
          
          if(tree->mod->whichmodel == 7)
              fprintf(fp_out,"Instantaneous rate matrix              \t");
          
          /*    fprintf(fp_out,"Time\t");*/
          
          fprintf(fp_out, "\n");
          
          
          /*headline 2*/
          fprintf(fp_out, "  set\t");
          
          fprintf(fp_out,"taxa\t");
          
          fprintf(fp_out,"loglk     \t");
          
          fprintf(fp_out, "gamma model\t");
          
          if(tree->mod->n_catg > 1)
              fprintf(fp_out, "categories\tparameter  \t");
          
          fprintf(fp_out,"invariant    \t");
          
          if(tree->mod->whichmodel <= 6)
              fprintf(fp_out,"transversion\t");
          
          fprintf(fp_out,"f(A)      f(C)      f(G)      f(T)    \t");
          
          if(tree->mod->whichmodel == 7)
              fprintf(fp_out,"[A---------C---------G---------T------]\t");
          
          /*    fprintf(fp_out,"used\t");*/
          
          fprintf(fp_out, "\n");
          
          
          /*headline 3*/
          if(tree->mod->whichmodel == 6) {
              fprintf(fp_out,"    \t      \t          \t           \t");
              if(tree->mod->n_catg > 1) fprintf(fp_out,"         \t         \t");
              fprintf(fp_out,"             \t");
              fprintf(fp_out,"purines pyrimid.\t");
              
              fprintf(fp_out, "\n");
          }
          
          fprintf(fp_out, "\n");
      }
  
  
  /*line items*/

  fprintf(fp_out,"  #%d\t",n_data_set);  

  fprintf(fp_out,"%d   \t",tree->n_otu);
  
  fprintf(fp_out,"%.5f\t",tree->tot_loglk);

  fprintf(fp_out,"%s        \t",
	  (tree->mod->n_catg>1)?("Yes"):("No "));
  if(tree->mod->n_catg > 1)
    {
      fprintf(fp_out,"%d        \t",tree->mod->n_catg);
      fprintf(fp_out,"%.3f    \t",tree->mod->alpha);
    }
  
  /*if(tree->mod->invar)*/
    fprintf(fp_out,"%.3f    \t",tree->mod->pinvar);

  if(tree->mod->whichmodel <= 5)
    {
      fprintf(fp_out,"%.3f     \t",tree->mod->kappa);
    }
  else if(tree->mod->whichmodel == 6)
    {
      fprintf(fp_out,"%.3f   ",
	      tree->mod->kappa*2.*tree->mod->lambda/(1.+tree->mod->lambda));
      fprintf(fp_out,"%.3f\t",
	      tree->mod->kappa*2./(1.+tree->mod->lambda));
    }


  if(!tree->mod->datatype)
    {
      fprintf(fp_out,"%8.5f  ",tree->mod->pi[0]);
      fprintf(fp_out,"%8.5f  ",tree->mod->pi[1]);
      fprintf(fp_out,"%8.5f  ",tree->mod->pi[2]);
      fprintf(fp_out,"%8.5f\t",tree->mod->pi[3]);
    }
  /*
  hour = div(t_end-t_beg,3600);
  min  = div(t_end-t_beg,60  );
  
  min.quot -= hour.quot*60;
  
  fprintf(fp_out,"%dh%dm%ds\t", hour.quot,min.quot,(int)(t_end-t_beg)%60);
  if(t_end-t_beg > 60)
    fprintf(fp_out,". -> %d seconds\t",(int)(t_end-t_beg));
  */

  /*****************************************/
  if((tree->mod->whichmodel == 7) || (tree->mod->whichmodel == 8))
    {
      int i,j;
      
      For(i,4)
	{
	  if (i!=0) {
	    /*format*/
	    fprintf(fp_out,"      \t     \t          \t           \t");
	    if(tree->mod->n_catg > 1) fprintf(fp_out,"          \t           \t");
	    fprintf(fp_out,"             \t                                      \t");
	  }
	  For(j,4)
	    fprintf(fp_out,"%8.5f  ",tree->mod->mat_Q[i*4+j]);
	  if (i<3) fprintf(fp_out,"\n");
	}
    }
  /*****************************************/
  
  fprintf(fp_out, "\n\n");


  fflush(fp_out);

}

/*********************************************************/

void Alloc_All_P_Lk(arbre *tree)
{
  int i,j,k;


  For(i,2*tree->n_otu-3)
    {
      tree->t_edges[i]->get_p_lk_left = 1;
      tree->t_edges[i]->get_p_lk_rght = 1;

      tree->t_edges[i]->p_lk_left = 
      (double ***)mCalloc(tree->data->crunch_len,sizeof(double **));
      
      tree->t_edges[i]->p_lk_rght = 
      (double ***)mCalloc(tree->data->crunch_len,sizeof(double **));
      
      For(j,tree->data->crunch_len)
	{
	  tree->t_edges[i]->p_lk_left[j] = 
	  (double **)mCalloc(tree->mod->n_catg,sizeof(double *));
	  
	  For(k,tree->mod->n_catg)
	  tree->t_edges[i]->p_lk_left[j][k] = 
	  (double *)mCalloc(tree->mod->ns,sizeof(double ));

	  tree->t_edges[i]->p_lk_rght[j] = 
	  (double **)mCalloc(tree->mod->n_catg,sizeof(double *));
	  
	  For(k,tree->mod->n_catg)
	  tree->t_edges[i]->p_lk_rght[j][k] = 
	  (double *)mCalloc(tree->mod->ns,sizeof(double ));
	}

      tree->t_edges[i]->sum_scale_f_left = 
      (double *)mCalloc(tree->data->crunch_len,sizeof(double ));
      
      tree->t_edges[i]->sum_scale_f_rght = 
      (double *)mCalloc(tree->data->crunch_len,sizeof(double ));
      
    }
}

/*********************************************************/

matrix *K2P_dist(allseq *data, double g_shape)
{
  int i,j,k;
  int diff;
  double unc_len;
  matrix *mat;
  double **len;

  len = (double **)mCalloc(data->n_otu,sizeof(double *));
  For(i,data->n_otu)
    len[i] = (double *)mCalloc(data->n_otu,sizeof(double));

  unc_len = .0;

  mat = Make_Mat(data->n_otu);
  Init_Mat(mat,data);


  For(i,data->c_seq[0]->len)
    {
      For(j,data->n_otu-1)
	{
	  for(k=j+1;k<data->n_otu;k++)
	    {
	      if(((data->c_seq[j]->state[i] == 'A' || data->c_seq[j]->state[i] == 'G') && 
		  (data->c_seq[k]->state[i] == 'C' || data->c_seq[k]->state[i] == 'T'))|| 
		 ((data->c_seq[j]->state[i] == 'C' || data->c_seq[j]->state[i] == 'T') && 
		  (data->c_seq[k]->state[i] == 'A' || data->c_seq[k]->state[i] == 'G'))) 
		{
		  diff++;
		  mat->Q[j][k]+=data->wght[i];
		  len[j][k]+=data->wght[i];
		  len[k][j]=len[j][k];
		}
	      
	      else
		if(((data->c_seq[j]->state[i] == 'A' && data->c_seq[k]->state[i] == 'G') || 
		    (data->c_seq[j]->state[i] == 'G' && data->c_seq[k]->state[i] == 'A'))|| 
		   ((data->c_seq[j]->state[i] == 'C' && data->c_seq[k]->state[i] == 'T') || 
		    (data->c_seq[j]->state[i] == 'T' && data->c_seq[k]->state[i] == 'C'))) 
		  {
		    diff++;
		    mat->P[j][k]+=data->wght[i];
		    len[j][k]+=data->wght[i];
		    len[k][j]=len[j][k];
		  }
		else 
		  if((data->c_seq[j]->state[i] == 'A' ||
		      data->c_seq[j]->state[i] == 'C' ||
		      data->c_seq[j]->state[i] == 'G' ||
		      data->c_seq[j]->state[i] == 'T')&&
		     (data->c_seq[k]->state[i] == 'A' ||
		      data->c_seq[k]->state[i] == 'C' ||
		      data->c_seq[k]->state[i] == 'G' ||
		      data->c_seq[k]->state[i] == 'T')) 
		    {
		      len[j][k]+=data->wght[i];
		      len[k][j]=len[j][k];
		    }
	    }
	}
    }
  
  
  For(i,data->n_otu-1)
    for(j=i+1;j<data->n_otu;j++)
      {
	if(len[i][j])
	  {
	    mat->P[i][j] /= len[i][j];
	    mat->Q[i][j] /= len[i][j];
	  }
	else 
	  {
	    mat->P[i][j] = .5;
	    mat->Q[i][j] = .5;
	  }
	
	mat->P[j][i] = mat->P[i][j];
	mat->Q[j][i] = mat->Q[i][j];
	
	
	if((1-2*mat->P[i][j]-mat->Q[i][j] <= .0) || (1-2*mat->Q[i][j] <= .0)) 
	  {
	    mat->dist[i][j] = -1.;
	    mat->dist[j][i] = -1.;
	    continue;
	  }
	
	mat->dist[i][j] = (g_shape/2)*
	  (pow(1-2*mat->P[i][j]-mat->Q[i][j],-1./g_shape) + 
	   0.5*pow(1-2*mat->Q[i][j],-1./g_shape) - 1.5);
	
	
	if(mat->dist[i][j] > DIST_MAX) 
	  {
	    mat->dist[i][j] = DIST_MAX;
	  }
	mat->dist[j][i] = mat->dist[i][j];
      }
  
  For(i,data->n_otu) free(len[i]);
  free(len);
  return mat;
}

/*********************************************************/

matrix *JC69_Dist(allseq *data, model *mod)
{
  int site,i,j,k;
  double unc_len;
  matrix *mat;
  double **len;


  len = (double **)mCalloc(data->n_otu,sizeof(double *));
  For(i,data->n_otu)
    len[i] = (double *)mCalloc(data->n_otu,sizeof(double));

  unc_len = .0;

  mat = Make_Mat(data->n_otu);
  Init_Mat(mat,data);
  
  Fors(site,data->c_seq[0]->len,mod->stepsize)
    {
      For(j,data->n_otu-1)
	{
	  for(k=j+1;k<data->n_otu;k++)
	    {
	      if((!Is_Ambigu(data->c_seq[j]->state+site,mod->datatype,mod->stepsize)) && 
		 (!Is_Ambigu(data->c_seq[k]->state+site,mod->datatype,mod->stepsize)))		
		{
		  len[j][k]+=data->wght[site];
		  len[k][j]=len[j][k];
		  if(/*!Compare_Two_States*/strncmp(data->c_seq[j]->state+site,
					 data->c_seq[k]->state+site,
					 mod->stepsize))
		    mat->P[j][k]+=data->wght[site];
		}
	    }
	}
    }
  

  For(i,data->n_otu-1)
    for(j=i+1;j<data->n_otu;j++)
      {
	if(len[i][j])
	  {
	    mat->P[i][j] /= len[i][j];
	  }
	else 
	  {
	    mat->P[i][j] = 1.;
	  }

	mat->P[j][i] = mat->P[i][j];
	
	if((1.-(mod->ns)/(mod->ns-1.)*mat->P[i][j]) < .0)
	  {
	    mat->dist[i][j] = DIST_MAX;
	  }
	else
	  mat->dist[i][j] = -(mod->ns-1.)/(mod->ns)*log(1.-(mod->ns)/(mod->ns-1.)*mat->P[i][j]);


	if(mat->dist[i][j] > DIST_MAX) 
	  {	    
	    mat->dist[i][j] = DIST_MAX;
	  }
	mat->dist[j][i] = mat->dist[i][j];
      }
  
  For(i,data->n_otu) free(len[i]);
  free(len);

  return mat;
}

/*********************************************************/

matrix *Hamming_Dist(allseq *data, model *mod)
{
  int i,j,k;
  double unc_len;
  matrix *mat;
  double **len;


  len = (double **)mCalloc(data->n_otu,sizeof(double *));
  For(i,data->n_otu)
    len[i] = (double *)mCalloc(data->n_otu,sizeof(double));

  unc_len = .0;

  mat = Make_Mat(data->n_otu);
  Init_Mat(mat,data);
  
  For(i,data->c_seq[0]->len)
    {
      For(j,data->n_otu-1)
	{
	  for(k=j+1;k<data->n_otu;k++)
	    {
	      if((!Is_Ambigu(data->c_seq[j]->state+i,mod->datatype,mod->stepsize)) && 
		 (!Is_Ambigu(data->c_seq[k]->state+i,mod->datatype,mod->stepsize)))		
		{
		  len[j][k]+=data->wght[i];
		  len[k][j]=len[j][k];
		  if(data->c_seq[j]->state[i] != data->c_seq[k]->state[i])
		    mat->P[j][k]+=data->wght[i];
		}	      
	    }
	}
    }
  

  For(i,data->n_otu-1)
    for(j=i+1;j<data->n_otu;j++)
      {
	if(len[i][j])
	  {
	    mat->P[i][j] /= len[i][j];
	  }
	else 
	  {
	    mat->P[i][j] = 1.;
	  }

	mat->P[j][i] = mat->P[i][j];
	
	mat->dist[i][j] = mat->P[i][j];


	if(mat->dist[i][j] > DIST_MAX) 
	  {	    
	    mat->dist[i][j] = DIST_MAX;
	  }
	mat->dist[j][i] = mat->dist[i][j];
      }
  
  For(i,data->n_otu) free(len[i]);
  free(len);

  return mat;
}

/*********************************************************/

int Is_Ambigu(char *state, int datatype, int stepsize)
{
  int i;

  if(!datatype) 
    {
      For(i,stepsize)
	{
	  if(strchr("MRWSYKBDHVNXO?-.",state[i]))
	    return 1;
	}
    }
  else
    {
      if(strchr("X?-.",state[0])) return 1;       
    }
  
  return 0;
}

/*********************************************************/

void Check_Ambiguities(allseq *data, int datatype, int stepsize)
{
  int i,j;

  Fors(j,data->crunch_len,stepsize) For(i,data->n_otu)
    {
      if(Is_Ambigu(data->c_seq[i]->state+j,
		   datatype,
		   stepsize))
	{
	  data->ambigu[j] = 1;
	  break;
	}
    }
}

/*********************************************************/

int Assign_State(char *c, int datatype, int stepsize)
{
  int state[3];
  int i;

  state[0] = -1;
  if(!datatype)
    {	  
      For(i,stepsize)
	{
	  switch(c[i])
	    {
	    case 'A' : state[i]=0; break;
	    case 'C' : state[i]=1; break;
	    case 'G' : state[i]=2; break;
	    case 'T' : state[i]=3; break;
	    case 'U' : state[i]=3; break;
	      
	    default  : state[i]=-1;
	      break;
	    }
	}
      return (stepsize>1)?(state[0]*16+state[1]*4+state[2]):(state[0]);
    }
  else
    {
      switch(c[0]){
      case 'A' : state[0]=0;  break;
      case 'R' : state[0]=1;  break;
      case 'N' : state[0]=2;  break;
      case 'D' : state[0]=3;  break;
      case 'C' : state[0]=4;  break;
      case 'Q' : state[0]=5;  break;
      case 'E' : state[0]=6;  break;
      case 'G' : state[0]=7;  break;
      case 'H' : state[0]=8;  break;
      case 'I' : state[0]=9;  break;
      case 'L' : state[0]=10; break;
      case 'K' : state[0]=11; break;
      case 'M' : state[0]=12; break;
      case 'F' : state[0]=13; break;
      case 'P' : state[0]=14; break;
      case 'S' : state[0]=15; break;
      case 'T' : state[0]=16; break;
      case 'W' : state[0]=17; break;
      case 'Y' : state[0]=18; break;
      case 'V' : state[0]=19; break;
	
      case 'B' : state[0] = 2; break;
      case 'Z' : state[0] = 5; break;
	
      default : state[0]=-1;
	break;
      }
      return state[0];
    }
  return -1;
}

/*********************************************************/

void Bootstrap(arbre *tree)
{
  int *site_num, n_site;
  int replicate,j,k;
  int position,init_len;
  double buff;
  allseq *boot_data;
  arbre *boot_tree;
  model *boot_mod;
  matrix *boot_mat;
  char *s;
/*   double rf; */



  tree->mod->s_opt->last_opt = 0;
  tree->print_boot_val       = 1;

  Alloc_Bip(tree);
  
  Get_Bip(tree->noeud[0],
	  tree->noeud[0]->v[0],
	  tree);

  site_num = (int *)mCalloc(tree->data->init_len,sizeof(int));
  
  n_site = 0;
  For(j,tree->data->crunch_len) For(k,tree->data->wght[j]) 
    {
      site_num[n_site] = j;
      n_site++;
    }

  boot_data = Copy_CData(tree->data,tree->mod);

  boot_tree = NULL;
  
  fprintf(stderr, "\n\n. Non parametric bootstrap analysis \n\n");
  fprintf(stderr, "  ["); fflush(NULL);

  For(replicate,tree->mod->bootstrap)
    {
      For(j,boot_data->crunch_len) boot_data->wght[j] = .0;

      init_len = 0;
      For(j,boot_data->init_len)
	{
	  buff  = rand();
	  buff /= (RAND_MAX+1.);
	  buff *= tree->data->init_len;
	  position = (int)floor(buff);
	  boot_data->wght[site_num[position]] += 1.;
	  init_len++;
	}
      
      if(init_len != tree->data->init_len) Exit("\n. Pb in copying sequences\n");


      (!tree->mod->datatype)?
	(Get_Base_Freqs(boot_data)):
	(Get_AA_Freqs(boot_data));

      boot_mod = Copy_Model(tree->mod);

      Init_Model(boot_data,boot_mod);


      if(tree->input->inputtree)
	{
            rewind(tree->input->fp_input_tree);
	  
            boot_tree = Read_Tree_File(tree->input->fp_input_tree);
	}
      else
	{
	  boot_mat = ML_Dist(boot_data,boot_mod);
	    
	  boot_mat->tree = Make_Tree(boot_data);

	  Bionj(boot_mat);
	  
	  boot_tree = boot_mat->tree;
	  	  
	  Free_Mat(boot_mat);
	}
      
      
      boot_tree->mod        = boot_mod;
      boot_tree->input      = tree->input;
      boot_tree->data       = boot_data;
      boot_tree->both_sides = 1;
      boot_tree->n_pattern  = boot_tree->data->crunch_len/
	                      boot_tree->mod->stepsize;

      boot_tree->mod->s_opt->print = 0;

      Order_Tree_CSeq(boot_tree,boot_data);

      Share_Lk_Struct(tree,boot_tree);


      Init_P_Lk_Tips(boot_tree);


      if(boot_tree->mod->s_opt->opt_topo)
          Simu(boot_tree,1000);
      else
          {
              if(boot_tree->mod->s_opt->opt_free_param)
                  Round_Optimize(boot_tree,boot_tree->data);
              else 
                  Lk(boot_tree,boot_data);
          }
      
      
      Alloc_Bip(boot_tree);
      
      Get_Bip(boot_tree->noeud[0],
	      boot_tree->noeud[0]->v[0],
	      boot_tree);
      
      Compare_Bip(tree,boot_tree);


      if(tree->input->print_boot_trees)
	{
	  s = Write_Tree(boot_tree);
	  fprintf(tree->input->fp_boot_tree,"%s\n",s);
	  Free(s);
          Print_Fp_Out_Lines(tree->input->fp_boot_stats,0,0,boot_tree,tree->input,replicate+1);
	}


/*       rf = .0; */
/*       For(j,2*tree->n_otu-3)  */
/* 	rf += tree->t_edges[j]->bip_score; */


      fprintf(stderr, "."); 
      if(!((replicate+1)%10)) 
	{
	  fprintf(stderr, "] %d/%d\n  ",replicate+1,tree->mod->bootstrap);
	  if(replicate != tree->mod->bootstrap-1) fprintf(stderr, "[");
	}
      fflush(NULL);
      

      Free_Tree(boot_tree);

      Free_Model(boot_mod);

    }
  if(((replicate)%10)) fprintf(stderr, "] %d/%d\n ",replicate,tree->mod->bootstrap);

  if(tree->input->print_boot_trees) 
      {
          fclose(tree->input->fp_boot_tree);
          fclose(tree->input->fp_boot_stats);
      }

  Free_Cseq(boot_data);

  Free(site_num);
}

/*********************************************************/

void Update_BrLen_Invar(arbre *tree)
{
  int i;
  For(i,2*tree->n_otu-3) tree->t_edges[i]->l*=(1.0-tree->mod->pinvar);
}

/*********************************************************/

void Getstring_Stdin(char *file_name)
{ 
  fgets(file_name,T_MAX_LINE,stdin);
  if (strchr(file_name, '\n') != NULL)
    *strchr(file_name, '\n') = '\0';
}

/*********************************************************/

void Print_Freq(arbre *tree)
{
  
  switch(tree->mod->datatype)
    {
    case 0:
      {
	printf("A : %f\n",tree->mod->pi[0]);
	printf("C : %f\n",tree->mod->pi[1]);
	printf("G : %f\n",tree->mod->pi[2]);
	printf("T : %f\n",tree->mod->pi[3]);

	printf("U : %f\n",tree->mod->pi[4]);
	printf("M : %f\n",tree->mod->pi[5]);
	printf("R : %f\n",tree->mod->pi[6]);
	printf("W : %f\n",tree->mod->pi[7]);
	printf("S : %f\n",tree->mod->pi[8]);
	printf("Y : %f\n",tree->mod->pi[9]);
	printf("K : %f\n",tree->mod->pi[10]);
	printf("B : %f\n",tree->mod->pi[11]);
	printf("D : %f\n",tree->mod->pi[12]);
	printf("H : %f\n",tree->mod->pi[13]);
	printf("V : %f\n",tree->mod->pi[14]);
	printf("N : %f\n",tree->mod->pi[15]);
	break;
      }
    case 1:
      {
	printf("A : %f\n",tree->mod->pi[0]);
	printf("R : %f\n",tree->mod->pi[1]);
	printf("N : %f\n",tree->mod->pi[2]);
	printf("D : %f\n",tree->mod->pi[3]);
	printf("C : %f\n",tree->mod->pi[4]);
	printf("Q : %f\n",tree->mod->pi[5]);
	printf("E : %f\n",tree->mod->pi[6]);
	printf("G : %f\n",tree->mod->pi[7]);
	printf("H : %f\n",tree->mod->pi[8]);
	printf("I : %f\n",tree->mod->pi[9]);
	printf("L : %f\n",tree->mod->pi[10]);
	printf("K : %f\n",tree->mod->pi[11]);
	printf("M : %f\n",tree->mod->pi[12]);
	printf("F : %f\n",tree->mod->pi[13]);
	printf("P : %f\n",tree->mod->pi[14]);
	printf("S : %f\n",tree->mod->pi[15]);
	printf("T : %f\n",tree->mod->pi[16]);
	printf("W : %f\n",tree->mod->pi[17]);
	printf("Y : %f\n",tree->mod->pi[18]);
	printf("V : %f\n",tree->mod->pi[19]);

	printf("N : %f\n",tree->mod->pi[20]);
	break;
      }
    default : {break;}
    }
}

/*********************************************************/

double Num_Derivatives_One_Param(double (*func)(arbre *tree), arbre *tree, 
				 double f0, double *param, double stepsize, 
				 double *err, int precise)
{
  int i,j;
  double errt,fac,hh,**a,ans;
  int n_iter;
  a = (double **)mCalloc(11,sizeof(double *));
  For(i,11) a[i] = (double *)mCalloc(11,sizeof(double));
  

  n_iter = 10; /* */

  ans  = .0;

  if (stepsize == 0.0) Exit("\n. h must be nonzero in Dfridr.");

  hh=stepsize;
  
  if(!precise)
    {

      *param   = *param+hh;
      a[0][0]  = (*func)(tree);
      a[0][0]  -= f0;
      a[0][0]  /= hh;
      *param   = *param-hh;
      
      ans =  a[0][0];
    }
  else
    {
      *param   = *param+hh;
      a[0][0]  = (*func)(tree);
      /*   *param   = *param-2*hh; */
      /*   a[0][0] -= (*func)(tree); */
      /*   a[0][0] /= (2.0*hh); */
      /*   *param   = *param+hh; */
      a[0][0]  -= f0;
      a[0][0]  /= hh;
      *param   = *param-hh;
      
      
      *err=1e30;
      for(i=1;i<n_iter;i++)
	{
	  hh /= 1.4;
     
	  /*       *param   = *param+hh; */
	  /*       a[0][i]  = (*func)(tree); */
	  /*       *param   = *param-2*hh; */
	  /*       a[0][i] -= (*func)(tree); */
	  /*       a[0][i] /= (2.0*hh); */
	  /*       *param   = *param+hh; */
	  
	  
	  *param   = *param+hh;
	  a[0][i]  = (*func)(tree);
	  /*   *param   = *param-2*hh; */
	  /*   a[0][i] -= (*func)(tree); */
	  /*   a[0][i] /= (2.0*hh); */
	  /*   *param   = *param+hh; */
	  a[0][i]  -= f0;
	  a[0][i]  /= hh;
	  *param   = *param-hh;
	  
	  
	  fac=1.4*1.4;
	  for (j=1;j<=i;j++) 
	    {
	      a[j][i]=(a[j-1][i]*fac-a[j-1][i-1])/(fac-1.0);
	      fac=1.4*1.4*fac;
	      
	      errt=MAX(fabs(a[j][i]-a[j-1][i]),fabs(a[j][i]-a[j-1][i-1]));
	      
	      if (errt <= *err)
		{
		  *err=errt;
		  ans=a[j][i];
		}
	    }
	  
	  if(fabs(a[i][i]-a[i-1][i-1]) >= 2.0*(*err))
	    break;
	}
    }
  For(i,11) Free(a[i]);
  Free(a);
  
  return ans;
}

/*********************************************************/

void Num_Derivative_Several_Param(arbre *tree, double *param, int n_param, double stepsize, 
				   double (*func)(arbre *tree), double *derivatives)
{
  int i;
  double err,f0;
  
  f0 = (*func)(tree);

  For(i,n_param) 
    {
      derivatives[i] = Num_Derivatives_One_Param(func,
						 tree,
						 f0,
						 param+i,
						 stepsize,
						 &err,
						 0
						 );
    }
}

/*********************************************************/

int Compare_Two_States(char *state1, char *state2, int state_size)
{
  /* 1 the two states are identical */
  /* 0 the two states are different */
  int i;

  For(i,state_size) if(state1[i] != state2[i]) break;
  
  return (i==state_size)?(1):(0);
}

/*********************************************************/

void Copy_One_State(char *from, char *to, int state_size)
{
  int i;
  For(i,state_size) to[i] = from[i];
}

/*********************************************************/

model *Make_Model_Basic()
{
  model *mod;
  int i;

  mod                     = (model *)mCalloc(1,sizeof(model));
  
  mod->custom_mod_string  = (char *)mCalloc(T_MAX_LINE,sizeof(char));
  mod->user_b_freq        = (double *)mCalloc(4,sizeof(double));

  mod->rr_param           = (double **)mCalloc(6,sizeof(double *));
  mod->rr_param_values    = (double *)mCalloc(6,sizeof(double));
  mod->rr_param_num       = (int **)mCalloc(6,sizeof(int *));
  mod->n_rr_param_per_cat = (int *)mCalloc(6,sizeof(int));
  mod->s_opt              = (optimiz *)Alloc_Optimiz();

  For(i,6) 
    mod->rr_param_num[i]  = (int *)mCalloc(6,sizeof(int));

  return mod;
}

/*********************************************************/

void Make_Model_Complete(model *mod)
{
  int i,j;

  mod->pi       = (double *)mCalloc(mod->ns,sizeof(double));
  mod->r_proba  = (double *)mCalloc(mod->n_catg,sizeof(double));
  mod->rr       = (double *)mCalloc(mod->n_catg,sizeof(double));

  mod->Pij_rr   = (double ***)mCalloc(mod->n_catg,sizeof(double **));
  mod->dPij_rr  = (double ***)mCalloc(mod->n_catg,sizeof(double **));
  mod->d2Pij_rr = (double ***)mCalloc(mod->n_catg,sizeof(double **));

  For(i,mod->n_catg)
    {
      mod->Pij_rr[i]   = (double **)mCalloc(mod->ns,sizeof(double *));
      mod->dPij_rr[i]  = (double **)mCalloc(mod->ns,sizeof(double *));
      mod->d2Pij_rr[i] = (double **)mCalloc(mod->ns,sizeof(double *));

      For(j,mod->ns)
	{
	  mod->Pij_rr[i][j]   = (double *)mCalloc(mod->ns,sizeof(double));
	  mod->dPij_rr[i][j]  = (double *)mCalloc(mod->ns,sizeof(double));
	  mod->d2Pij_rr[i][j] = (double *)mCalloc(mod->ns,sizeof(double));
	}
    }

  mod->mat_Q    = (double *)mCalloc(mod->ns*mod->ns,sizeof(double));
  mod->mat_Vr   = (double *)mCalloc(mod->ns*mod->ns,sizeof(double)); 
  mod->mat_Vi   = (double *)mCalloc(mod->ns*mod->ns,sizeof(double)); 
  mod->vct_eDmr = (double *)mCalloc(mod->ns        ,sizeof(double)); 
  mod->vct_ev   = (double *)mCalloc(mod->ns        ,sizeof(double)); 
}

/*********************************************************/

model *Copy_Model(model *ori)
{
  int i,j;
  model *cpy;


  cpy = Make_Model_Basic();
  
  Copy_Optimiz(ori->s_opt,cpy->s_opt); 
/*   cpy->c_code                = ori->c_code; */


  cpy->ns                    = ori->ns;
  cpy->n_catg                = ori->n_catg;


  Make_Model_Complete(cpy);


  cpy->datatype         = ori->datatype;
  cpy->n_otu            = ori->n_otu;
  cpy->alpha_opt        = ori->alpha_opt;
  cpy->alpha_old        = ori->alpha_old;
  cpy->kappa_old        = ori->alpha_old;
  cpy->lambda_old       = ori->lambda_old;
  cpy->pinvar_old       = ori->pinvar_old;
  cpy->whichmodel       = ori->whichmodel;
  cpy->seq_len          = ori->seq_len;
  cpy->update_eigen     = ori->update_eigen;
  cpy->omega            = ori->omega;
  cpy->kappa            = ori->kappa;
  cpy->alpha            = ori->alpha;
  cpy->lambda           = ori->lambda;
  cpy->bootstrap        = ori->bootstrap;
  cpy->invar            = ori->invar;
  cpy->pinvar           = ori->pinvar;
  cpy->stepsize         = ori->stepsize;
  cpy->n_diff_rr_param  = ori->n_diff_rr_param;



  For(i,cpy->n_diff_rr_param) 
      {
          cpy->n_rr_param_per_cat[i] = ori->n_rr_param_per_cat[i];
          For(j,cpy->n_rr_param_per_cat[i])
              {
                  cpy->rr_param_num[i][j] = ori->rr_param_num[i][j]; 
              }
      }
  
  For(i,6) 
      {
          cpy->rr_param_values[i]  = ori->rr_param_values[i];
          cpy->rr_param[i] = cpy->rr_param_values+i;
      }
#ifndef LH3_REVISION
  For(i,cpy->ns) 
      {
          cpy->pi[i]          = ori->pi[i];
          cpy->user_b_freq[i] = ori->user_b_freq[i];
      }
#else
  For(i,cpy->ns) 
      {
          cpy->pi[i]          = ori->pi[i];
	  }
  For(i,4)
      {
          cpy->user_b_freq[i] = ori->user_b_freq[i];
      }
#endif
  For(i,cpy->n_catg) 
      {
          cpy->r_proba[i] = ori->r_proba[i]; 
          cpy->rr[i]      = ori->rr[i];
      }
  
  return cpy;
}

/*********************************************************/

void Set_Defaults_Input(option* input)
{

  input->mod->datatype              = 0;
  strcpy(input->modelname,"HKY");
  strcpy(input->nt_or_cd,"nucleotides");
  input->n_data_sets                = 1;
  input->interleaved                = 1;
  input->end_opt                    = 0;
  input->inputtree                  = 0;
  input->tree                       = NULL;
  input->phyml_tree_file_open_mode  = 1;
  input->phyml_stat_file_open_mode  = 1;
  input->seq_len                    = -1;
  input->n_data_set_asked           = -1;
  input->print_boot_trees           = 1;


}

/*********************************************************/

void Set_Defaults_Model(model *mod)
{
  int i;

  strcpy(mod->custom_mod_string,"000000");
  mod->whichmodel            = 4;
  mod->n_catg                = 1;
  mod->kappa                 = 4.0;
  mod->alpha                 = 2.0;
  mod->lambda                = 1.0;
  mod->bootstrap             = 0;
  mod->invar                 = 0;
  mod->pinvar                = 0.0;
  mod->stepsize              = 1;
  mod->ns                    = 4;
  mod->n_diff_rr_param       = 0;

  For(i,6) 
    {
      mod->rr_param_values[i]  = 1.0;
      mod->rr_param[i] = mod->rr_param_values+i;
    }

  For(i,4) mod->user_b_freq[i] = -1.;

}

/*********************************************************/

void Set_Defaults_Optimiz(optimiz *s_opt)
{
  s_opt->opt_alpha      = 0;
  s_opt->opt_kappa      = 0;
  s_opt->opt_lambda     = 0;
  s_opt->opt_bl         = 0;
  s_opt->opt_pinvar     = 0;
  s_opt->opt_rr_param   = 0;
  s_opt->opt_topo       = 1;
  s_opt->opt_free_param = 1;
}

/*********************************************************/

void Copy_Optimiz(optimiz *ori, optimiz *cpy)
{
  cpy->print = ori->print;
  cpy->first_opt_alpha = ori->first_opt_alpha;
  cpy->first_opt_alpha = ori->first_opt_alpha;
  cpy->opt_alpha = ori->opt_alpha;
  cpy->opt_kappa = ori->opt_kappa;
  cpy->opt_lambda = ori->opt_lambda;
  cpy->opt_pinvar = ori->opt_pinvar;
  cpy->opt_rr_param = ori->opt_rr_param;
  cpy->opt_free_param = ori->opt_free_param;
  cpy->opt_bl = ori->opt_bl;
  cpy->init_lk = ori->init_lk;
  cpy->n_it_max = ori->n_it_max;
  cpy->opt_topo = ori->opt_topo;
}

/*********************************************************/

void Get_Bip(node *a, node *d, arbre *tree)
{
  if(d->tax) 
    {
      d->bip_node[0][0] = d;
      d->bip_size[0]    = 1;
      return;
    }
  else
    {
      int i,j,k;
      int d_a;


      d_a = -1;

      For(i,3)
	{
	  if(d->v[i] != a)
	    Get_Bip(d,d->v[i],tree);
	  else d_a = i;
	}

      d->bip_size[d_a] = 0;
      For(i,3)
	if(d->v[i] !=a )
	  {
	    For(j,3)
	      {
		if(d->v[i]->v[j] == d)
		  {
		    For(k,d->v[i]->bip_size[j])
		      {
			d->bip_node[d_a][d->bip_size[d_a]] = d->v[i]->bip_node[j][k];
			strcpy(d->bip_name[d_a][d->bip_size[d_a]],d->v[i]->bip_node[j][k]->name);
			d->bip_size[d_a]++;			
		      }
		    break;
		  }
	      }
	  }

      qsort(d->bip_name[d_a],d->bip_size[d_a],sizeof(char *),Sort_String);

      For(i,3)
	if(a->v[i] == d)
	  {
	    a->bip_size[i] = 0;
	    For(j,tree->n_otu)
	      {
		For(k,d->bip_size[d_a])
		  {
		    if(d->bip_node[d_a][k] == tree->noeud[j])
		      break;
		  }
		
		if(k == d->bip_size[d_a])
		  {
		    a->bip_node[i][a->bip_size[i]] = tree->noeud[j];
		    strcpy(a->bip_name[i][a->bip_size[i]],tree->noeud[j]->name);
		    a->bip_size[i]++;
		  }
	      }
	    
	    qsort(a->bip_name[i],a->bip_size[i],sizeof(char *),Sort_String);

	    if(a->bip_size[i] != tree->n_otu - d->bip_size[d_a])
	      {
		fprintf(stderr, "%d %d \n",a->bip_size[i],tree->n_otu - d->bip_size[d_a]);
		Exit("\n. Problem in counting bipartitions \n");
	      }
	    break;
	  }
    }
}

/*********************************************************/

void Alloc_Bip(arbre *tree)
{
  int i,j,k;

  tree->has_bip = 1;
  
  For(i,2*tree->n_otu-2)
    {
      tree->noeud[i]->bip_size = (int *)mCalloc(3,sizeof(int));
      tree->noeud[i]->bip_node = (node ***)mCalloc(3,sizeof(node **));
      tree->noeud[i]->bip_name = (char ***)mCalloc(3,sizeof(char **));
      For(j,3)
	{
	  tree->noeud[i]->bip_node[j] = 
	    (node **)mCalloc(tree->n_otu,sizeof(node *));

	  tree->noeud[i]->bip_name[j] = 
	    (char **)mCalloc(tree->n_otu,sizeof(char *));
	  
	  For(k,tree->n_otu)
	    tree->noeud[i]->bip_name[j][k] = 
	    (char *)mCalloc(T_MAX_NAME,sizeof(char ));	  
	}
    }
}

/*********************************************************/

int Sort_Double_Increase(const void *a, const void *b)
{
  if((*(double *)(a)) <= (*(double *)(b))) return -1;
  else return 1;
}

/*********************************************************/

int Sort_String(const void *a, const void *b)
{
  return(strcmp((*(const char **)(a)), (*(const char **)(b))));
}

/*********************************************************/

void Compare_Bip(arbre *tree1, arbre *tree2)
{
    int i,j,k;
    edge *b1,*b2;
    char **bip1,**bip2;
    int bip_size;
    
    
    For(i,2*tree1->n_otu-3)
        {
            if((!tree1->t_edges[i]->left->tax) &&
               (!tree1->t_edges[i]->rght->tax))
                {
                    
                    b1 = tree1->t_edges[i];
                    
                    For(j,2*tree2->n_otu-3)
                        {
                            if((!tree2->t_edges[j]->left->tax) &&
                               (!tree2->t_edges[j]->rght->tax))
                                {
                                    
                                    b2 = tree2->t_edges[j];
                                    
                                    if(MIN(b1->left->bip_size[b1->l_r],b1->rght->bip_size[b1->r_l]) ==
                                       MIN(b2->left->bip_size[b2->l_r],b2->rght->bip_size[b2->r_l]))
                                        {
                                            bip_size = MIN(b1->left->bip_size[b1->l_r],b1->rght->bip_size[b1->r_l]);
                                            
                                            if(b1->left->bip_size[b1->l_r] == b1->rght->bip_size[b1->r_l])
                                                {
                                                    if(b1->left->bip_name[b1->l_r][0][0] < b1->rght->bip_name[b1->r_l][0][0])
                                                        {
                                                            bip1 = b1->left->bip_name[b1->l_r];
                                                        }
                                                    else
                                                        {
                                                            bip1 = b1->rght->bip_name[b1->r_l];
                                                        }
                                                }
                                            else if(b1->left->bip_size[b1->l_r] < b1->rght->bip_size[b1->r_l])
                                                {
                                                    bip1 = b1->left->bip_name[b1->l_r];
                                                }
                                            else
                                                {
                                                    bip1 = b1->rght->bip_name[b1->r_l];
                                                }
                                            
                                            
                                            if(b2->left->bip_size[b2->l_r] == b2->rght->bip_size[b2->r_l])
                                                {
                                                    if(b2->left->bip_name[b2->l_r][0][0] < b2->rght->bip_name[b2->r_l][0][0])
                                                        {
                                                            bip2 = b2->left->bip_name[b2->l_r];
                                                        }
                                                    else
                                                        {
                                                            bip2 = b2->rght->bip_name[b2->r_l];
                                                        }
                                                }
                                            else if(b2->left->bip_size[b2->l_r] < b2->rght->bip_size[b2->r_l])
                                                {
                                                    bip2 = b2->left->bip_name[b2->l_r];
                                                }
                                            else
                                                {
                                                    bip2 = b2->rght->bip_name[b2->r_l];
                                                }
                                            
                                            if(bip_size == 1) Exit("\n. Problem in Compare_Bip\n");
                                            
                                            
                                            For(k,bip_size) 
                                                {
                                                    if(strcmp(bip1[k],bip2[k])) break;
                                                }
                                            
                                            if(k == bip_size)
                                                {
                                                    b1->bip_score++;
                                                    b2->bip_score++;
                                                    break;
                                                }
                                        }
                                }
                        }
                }
        }
}

/*********************************************************/

void Test_Multiple_Data_Set_Format(option *input)
{
  char *line;
  
  line = (char *)mCalloc(T_MAX_LINE,sizeof(char));

  input->n_trees = 0;
  
  while(fgets(line,T_MAX_LINE,input->fp_input_tree)) if(strstr(line,";")) input->n_trees++;

  Free(line);
  
/*   if((input->n_trees != input->n_data_sets) &&  */
/*      (input->n_data_sets > 1))  */
/*     Exit("\n. The number of trees should be the same as\n  the number of data sets\n\n"); */

  if((input->mod->bootstrap > 1) && (input->n_trees > 1))
    Exit("\n. Bootstrap option is not allowed with multiple trees\n");


  rewind(input->fp_input_tree);

  return;
}

/*********************************************************/

int Are_Compatible(char *statea, char *stateb, int stepsize, int datatype)
{
  int i,j;
  char a,b;


  if(!datatype) 
    {
      For(i,stepsize)
	{
	  a = statea[i];
	  For(j,stepsize)
	    {
	      b = stateb[j];

	      switch(a)
		{
		case 'A':
		  {
		    switch(b)
		      {
		      case 'A' : 
		      case 'M' : 
		      case 'R' : 
		      case 'W' : 
		      case 'D' : 
		      case 'H' : 
		      case 'V' : 
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		case 'G':
		  {
		    switch(b)
		      {
		      case 'G' : 
		      case 'R' : 
		      case 'S' : 
		      case 'K' : 
		      case 'B' : 
		      case 'D' : 
		      case 'V' : 
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		case 'C':
		  {
		    switch(b)
		      {
		      case 'C' : 
		      case 'M' : 
		      case 'S' : 
		      case 'Y' : 
		      case 'B' : 
		      case 'H' : 
		      case 'V' : 
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		case 'T':
		  {
		    switch(b)
		      {
		      case 'T' : 
		      case 'W' : 
		      case 'Y' : 
		      case 'K' : 
		      case 'B' : 
		      case 'D' : 
		      case 'H' : 
		      case 'X' : 
			{b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		case 'M' : 
		  {
		    switch(b)
		      {
		      case 'M' : 
		      case 'A' :
		      case 'C' :
		      case 'R' : 
		      case 'W' : 
		      case 'S' : 
		      case 'Y' : 
		      case 'B' : 
		      case 'D' : 
		      case 'H' : 
		      case 'V' : 
		      case 'X' :
			{b=b; break;}
		      default : return 0;
		      }	
		    break;
		  }
		case 'R' :
		  {
		    switch(b)
		      {
		      case 'R' :
		      case 'A' :
		      case 'G' :
		      case 'M' :
		      case 'W' :
		      case 'S' :
		      case 'K' :
		      case 'B' :
		      case 'D' :
		      case 'H' :
		      case 'V' :
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		  
		case 'W' :
		  {
		    switch(b)
		      {
		      case 'W' :
		      case 'A' :
		      case 'T' :
		      case 'M' :
		      case 'R' :
		      case 'Y' :
		      case 'K' :
		      case 'B' :
		      case 'D' :
		      case 'H' :
		      case 'V' :
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		  
		case 'S' :
		  {
		    switch(b)
		      {
		      case 'S' :
		      case 'C' :
		      case 'G' :
		      case 'M' :
		      case 'R' :
		      case 'Y' :
		      case 'K' :
		      case 'B' :
		      case 'D' :
		      case 'H' :
		      case 'V' :
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		  
		case 'Y' :
		  {
		    switch(b)
		      {
		      case 'Y' :
		      case 'C' :
		      case 'T' :
		      case 'M' :
		      case 'W' :
		      case 'S' :
		      case 'K' :
		      case 'B' :
		      case 'D' :
		      case 'H' :
		      case 'V' :
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		  
		case 'K' :
		  {
		    switch(b)
		      {
		      case 'K' :
		      case 'G' :
		      case 'T' :
		      case 'R' :
		      case 'W' :
		      case 'S' :
		      case 'Y' :
		      case 'B' :
		      case 'D' :
		      case 'H' :
		      case 'V' :
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		case 'B' :
		  {
		    switch(b)
		      {
		      case 'B' :
		      case 'C' :
		      case 'G' :
		      case 'T' :
		      case 'M' :
		      case 'R' :
		      case 'W' :
		      case 'S' :
		      case 'Y' :
		      case 'K' :
		      case 'D' :
		      case 'H' :
		      case 'V' :
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		case 'D' :
		  {
		    switch(b)
		      {
		      case 'D' :
		      case 'A' :
		      case 'G' :
		      case 'T' :
		      case 'M' :
		      case 'R' :
		      case 'W' :
		      case 'S' :
		      case 'Y' :
		      case 'K' :
		      case 'B' :
		      case 'H' :
		      case 'V' :
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		case 'H' :
		  {
		    switch(b)
		      {
		      case 'H' :
		      case 'A' :
		      case 'C' :
		      case 'T' :
		      case 'M' :
		      case 'R' :
		      case 'W' :
		      case 'S' :
		      case 'Y' :
		      case 'K' :
		      case 'B' :
		      case 'D' :
		      case 'V' :
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		case 'V' :
		  {
		    switch(b)
		      {
		      case 'V' :
		      case 'A' :
		      case 'C' :
		      case 'G' :
		      case 'M' :
		      case 'R' :
		      case 'W' :
		      case 'S' :
		      case 'Y' :
		      case 'K' :
		      case 'B' :
		      case 'D' :
		      case 'H' :
		      case 'X' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		case 'X' :
		  {
		    switch(b)
		      {
		      case 'X' :
		      case 'A' :
		      case 'C' :
		      case 'G' :
		      case 'T' :
		      case 'M' :
		      case 'R' :
		      case 'W' :
		      case 'S' :
		      case 'Y' :
		      case 'K' :
		      case 'B' :
		      case 'D' :
		      case 'H' :
		      case 'V' : {b=b; break;}
		      default : return 0;
		      }
		    break;
		  }
		default : 
		  {
                      fprintf(stderr, "\n. Err. in Are_Compatible\n");
                      fprintf(stderr, "\n. Please check that characters `%c` and `%c`\n",a,b);
                      fprintf(stderr, "  correspond to existing amino-acids.\n");
                      Exit("\n");
                      return 0;
		  }
		}
	    }
	}
    }
  else
    {
      a = statea[0]; b = stateb[0];
      switch(a)
	{
	case 'A' :
	  {
	    switch(b)
	      {
	      case 'A' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'R' :
	  {
	    switch(b)
	      {
	      case 'R' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'N' :
	  {
	    switch(b)
	      {
	      case 'N' :
	      case 'B' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'B' :
	  {
	    switch(b)
	      {
	      case 'N' :
	      case 'B' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'D' :
	  {
	    switch(b)
	      {
	      case 'D' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'C' :
	  {
	    switch(b)
	      {
	      case 'C' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'Q' :
	  {
	    switch(b)
	      {
	      case 'Q' :
	      case 'Z' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'Z' :
	  {
	    switch(b)
	      {
	      case 'Q' :
	      case 'Z' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'E' :
	  {
	    switch(b)
	      {
	      case 'E' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'G' :
	  {
	    switch(b)
	      {
	      case 'G' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'H' :
	  {
	    switch(b)
	      {
	      case 'H' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'I' :
	  {
	    switch(b)
	      {
	      case 'I' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'L' :
	  {
	    switch(b)
	      {
	      case 'L' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'K' :
	  {
	    switch(b)
	      {
	      case 'K' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'M' :
	  {
	    switch(b)
	      {
	      case 'M' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'F' :
	  {
	    switch(b)
	      {
	      case 'F' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'P' :
	  {
	    switch(b)
	      {
	      case 'P' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'S' :
	  {
	    switch(b)
	      {
	      case 'S' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'T' :
	  {
	    switch(b)
	      {
	      case 'T' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'W' :
	  {
	    switch(b)
	      {
	      case 'W' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'Y' :
	  {
	    switch(b)
	      {
	      case 'Y' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'V' :
	  {
	    switch(b)
	      {
	      case 'V' :
	      case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	case 'X' :
	  {
	    switch(b)
	      {
	      case 'A':case 'R':case 'N' :case 'B' :case 'D' :
	      case 'C':case 'Q':case 'Z' :case 'E' :case 'G' :
	      case 'H':case 'I':case 'L' :case 'K' :case 'M' :
	      case 'F':case 'P':case 'S' :case 'T' :case 'W' :
	      case 'Y':case 'V': case 'X' : {b=b; break;}
	      default : return 0;
	      }
	    break;
	  }
	default : 
	  {
	    fprintf(stderr, "\n. Err. in Are_Compatible\n");
            fprintf(stderr, "\n. Please check that characters `%c` and `%c`\n",a,b);
            fprintf(stderr, "  correspond to existing amino-acids.\n");
            Exit("\n");
	    return 0;
	  }
	}
    }
  return 1;
}

/*********************************************************/

void Hide_Ambiguities(allseq *data)
{
  int i;

  For(i,data->crunch_len)
    {
      if(data->ambigu[i]) 
	{
	  data->wght[i] = 0.0;
	}
    }
}

/*********************************************************/
/*********************************************************/
/*********************************************************/
/*********************************************************/
/*********************************************************/
