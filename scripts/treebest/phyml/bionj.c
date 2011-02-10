/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

/*

The code below is an implementation of the building tree algorithm
described in "BIONJ: an improved version of the NJ algorithm based 
on a simple model of sequence data." (1997) O. Gascuel. Mol Biol Evol. 
14:685-95.  

*/

#include "bionj.h"

void Bionj(matrix *mat)
{
  int x,y,i;
  double vxy,lx,ly,lamda,score;

  For(i,mat->tree->n_otu)
    mat->tip_node[i] = mat->tree->noeud[i];


  while(mat->r > 3)
    {
      x = y = 0;
      vxy = .0;
      score = .0;
      Compute_Sx(mat);
      Best_Pair(mat,&x,&y,&score);
      vxy=Variance(mat,x,y);
      lx=Br_Length(mat,x,y);    
      ly=Br_Length(mat,y,x);
      lamda=Lamda(mat,x,y,vxy); 
      Update_Mat(mat,x,y,lx,ly,vxy,lamda);
      Update_Tree(mat,x,y,lx,ly,score);      
    }

  Finish(mat);
  i=0;

  Init_Tree_Edges(mat->tree->noeud[0],
		  mat->tree->noeud[0]->v[0],
		  mat->tree,&i);
}
  
/*********************************************************/

void Bionj_Scores(matrix *mat)
{
  int i;

  For(i,2*mat->n_otu-3)
    {
      if(!mat->tree->noeud[i]->tax)
	{
	  mat->tree->noeud[i]->b[0]->nj_score = 
	    mat->tree->noeud[i]->score[0];
	}
    }
}

/*********************************************************/

void Finish(matrix *mat)
{
  double dxy,dxz,dyz;
  int x,y,z;
  node *nx,*ny,*nz,*new;
  int i;

  dxy = dxz = dyz = -1.;
  x = y = z = -1;

  For(i,mat->n_otu)
    {
      if(mat->on_off[i])
	{
	  if(x < 0) x=i;
	  else if(y < 0) y = i;
	  else if(z < 0) z = i;
	}
    }

  dxy = Dist(mat,x,y);
  dxz = Dist(mat,x,z);
  dyz = Dist(mat,y,z);

  nx = mat->tip_node[x];
  ny = mat->tip_node[y];
  nz = mat->tip_node[z];

  new = mat->tree->noeud[mat->curr_int];
  new->num = mat->curr_int;
  new->v[0] = nx;
  new->v[1] = ny;
  new->v[2] = nz;


  nx->v[0] = new;
  ny->v[0] = new;
  nz->v[0] = new;
  
  Make_Edge_Light(new,nx);
  Make_Edge_Light(new,ny);
  Make_Edge_Light(new,nz);
 
  nx->b[0]->l = .5*(dxy-dyz+dxz);
  ny->b[0]->l = .5*(dyz-dxz+dxy);
  nz->b[0]->l = .5*(dxz-dxy+dyz);
   
  new->b[0]->l = nx->b[0]->l;
  new->b[1]->l = ny->b[0]->l;
  new->b[2]->l = nz->b[0]->l;
}

/*********************************************************/

void Update_Mat(matrix *mat, int x, int y, double lx, double ly, double vxy, double lamda)
{
  int i;
  int a,b;
  
  a = b = -1;
  For(i,mat->n_otu)
    {
      if((mat->on_off[i]) && (i != x) && (i != y))
	{
	  if(x > i)
	    {
	      a=x;
	      b=i;
	    }
	  else
	    {
	      a=i;
	      b=x;
	    }
	  mat->dist[a][b]=Dist_Red(mat,x,lx,y,ly,i,lamda);
	  mat->dist[b][a]=Var_Red(mat,x,y,i,lamda,vxy);
	}
    }
}

/*********************************************************/

void Update_Tree(matrix *mat, int x, int y, double lx, double ly, double score)
{
  node *new, *nx, *ny;

  nx = mat->tip_node[x];
  ny = mat->tip_node[y];
  new = mat->tree->noeud[mat->curr_int];
  nx->v[0] = new;
  ny->v[0] = new;
  new->v[1] = nx;
  new->v[2] = ny;
  
  new->num = mat->curr_int;

  Make_Edge_Light(new,nx);
  Make_Edge_Light(new,ny);

  nx->b[0]->l = lx;
  ny->b[0]->l = ly;
  
  new->b[1]->l = lx;
  new->b[2]->l = ly;
  new->score[0] = score;

  nx->l[0] = lx;
  ny->l[0] = ly;
  
  new->l[1] = lx;
  new->l[2] = ly;
 
  mat->tip_node[x] = new;
  mat->on_off[y] = 0;
  mat->curr_int++;
  mat->r--;
}

/*********************************************************/

void Best_Pair(matrix *mat, int *x, int *y,double *score)
{
  int i,j;
  double Qij,Qmin,Qmin2;
  double **t_Qij;

  t_Qij = (double **)mCalloc(mat->n_otu,sizeof(double *));
  For(i,mat->n_otu)
    t_Qij[i] = (double *)mCalloc(mat->n_otu,sizeof(double));

  Qmin = 1.e+10;
  Qij = Qmin;

  For(i,mat->n_otu)
    {
      if(mat->on_off[i])
	{
	  for(j=0;j<i;j++)
	    {
	      if(mat->on_off[j])
		{
		  Qij = Q_Agglo(mat,i,j);
		  t_Qij[i][j] = Qij;

		  if(Qij < Qmin)
		    {
		      *x = i;
		      *y = j;
		      Qmin = Qij;
		    }
		}
	    }
	}
    }

  Qmin2 = 1e+10;

  For(i,mat->n_otu)
    {
      if((i != *y) && (i != *x) && (t_Qij[*x][i] < Qmin2)) Qmin2 = t_Qij[*x][i];
    }

  For(i,mat->n_otu)
    {
      if((i != *y) && (i != *x) && (t_Qij[i][*y] < Qmin2)) Qmin2 = t_Qij[i][*y];
    }

  *score = fabs(Qmin2 - Qmin)/fabs(Qmin);
  
  For(i,mat->n_otu) free(t_Qij[i]);
  free(t_Qij);
}
/*********************************************************/

void Compute_Sx(matrix *mat)
{
  int i,j;
  
  For(i,mat->n_otu)
    {
      mat->dist[i][i] = .0;
      if(mat->on_off[i])
	{
	  For(j,mat->n_otu)
	    {
	      if((i != j) && (mat->on_off[j]))
		{
		  mat->dist[i][i] += Dist(mat,i,j);
		}
	    }
	}
    }
}
	      
/*********************************************************/

double Sum_S(matrix *mat, int i)
{
  return mat->dist[i][i];
}

/*********************************************************/

double Dist(matrix *mat, int x, int y)
{
    if(x > y)
      return(mat->dist[x][y]);
    else
      return(mat->dist[y][x]);
}

/*********************************************************/

double Variance(matrix *mat, int x, int y)
{
    if(x > y)
      {
	return(mat->dist[y][x]);
      }
    else
      {
	return(mat->dist[x][y]);
      }
}

/*********************************************************/

double Br_Length(matrix *mat, int x, int y)
{
    return .5*(Dist(mat,x,y)+
		(Sum_S(mat,x)-Sum_S(mat,y))/(double)(mat->r-2.)); 
}

/*********************************************************/

double Dist_Red(matrix *mat, int x, double lx, int y, double ly, int i, double lamda)
{
  double Dui;
  Dui=lamda*(Dist(mat,x,i)-lx)
     +(1.-lamda)*(Dist(mat,y,i)-ly);
  return(Dui);
}

/*********************************************************/

double Var_Red(matrix *mat, int x, int y, int i, double lamda, double vxy)
{
  double Vui;
  Vui=lamda*(Variance(mat,x,i))
     +(1.-lamda)*(Variance(mat,y,i))
    -lamda*(1.-lamda)*vxy;
  return(Vui);
}

/*********************************************************/

double Lamda(matrix *mat, int x, int y, double vxy)
{
    double lamda=0.0;
    int i;
    
    if(mat->method == 0) /* NJ (Saitou & Nei, 1987) */
      lamda = 0.5;
    else /* BioNJ (Gascuel, 1997) */
      {
	if(vxy==0.0)
	  lamda=0.5;
	else
	  {
	    For(i,mat->n_otu)
	      {
		if((x != i) && (y != i) && (mat->on_off[i]))
		  lamda = lamda + Variance(mat,y,i) - Variance(mat,x,i);
	      }
	    lamda = 0.5 + lamda/(2.*(mat->r-2)*vxy);
	  }
	
	if(lamda > 1.0)
	  lamda = 0.5;/*1.0;*/
	else if(lamda < 0.0)
	  lamda = 0.5;/*0.0;*/
      }

    return(lamda);
}

/*********************************************************/

double Q_Agglo(matrix *mat, int x, int y)
{
  double Qxy;

  Qxy = .0;

  Qxy=(mat->r-2.)*Dist(mat,x,y)
    -Sum_S(mat,x)
    -Sum_S(mat,y); 
  return(Qxy);                       
}

/*********************************************************/

void Bionj_Br_Length(matrix *mat)
{
  int x;

  x = Bionj_Br_Length_Post(mat->tree->noeud[0],
			   mat->tree->noeud[0]->v[0],
			   mat);
  mat->tree->noeud[0]->b[0]->l = Dist(mat,0,x);
}

/*********************************************************/

int Bionj_Br_Length_Post(node *a, node *d, matrix *mat)
{
  int i;

  if(d->tax)
    {
      return d->num;
    }
  else
    {
      int d_v1, d_v2;
      double lx, ly, vxy,lamda;
      int x,y;

      d_v1 = d_v2 = -1;
      For(i,3)
	if(d->v[i] != a) {(d_v1 < 0)?(d_v1 = i):(d_v2 = i);}
      

      x = Bionj_Br_Length_Post(d,d->v[d_v1],mat);
      y = Bionj_Br_Length_Post(d,d->v[d_v2],mat);

      vxy = .0;
      Compute_Sx(mat);
      vxy=Variance(mat,(x),(y));
      lx=Br_Length(mat,(x),(y));    
      ly=Br_Length(mat,(y),(x));
      lamda=Lamda(mat,(x),(y),vxy); 
      Update_Mat(mat,(x),(y),lx,ly,vxy,lamda);

      d->b[d_v1]->l = lx;
      d->b[d_v2]->l = ly;
      
      mat->on_off[y] = 0;
      mat->r--;

      return x;
    }
}

/*********************************************************/






