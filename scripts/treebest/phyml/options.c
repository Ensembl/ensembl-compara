/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#include "utilities.h"
#include "options.h"
#include "models.h"
#include "free.h"

int  T_MAX_FILE;
double MDBL_MIN;
double UNLIKELY;

#define BOLD      "\033[00;01m"
#define FLAT      "\033[00;00m"
#define LINE "\033[00;04m"

/*********************************************************/

void Usage()
{
  printf(BOLD"NAME\n"
	 FLAT"\tphyml\n"
	 FLAT"\tA simple, fast, and accurate algorithm to estimate\n"
	 FLAT"\tlarge phylogenies by maximum likelihood.\n\n"
	 FLAT"\tStephane Guindon and Olivier Gascuel,\n"
	 FLAT"\tSystematic Biology 52(5):696-704, 2003.\n"
	 FLAT"\tPlease cite this paper if you use this software in your publications.\n");

  printf(BOLD"\nCOMMAND-LINE USE\n"
	 BOLD"\tphyml "FLAT"[ "
	 LINE"sequences"FLAT" "
	 LINE"data_type"FLAT" "
	 LINE"format"FLAT" "
	 LINE"data_sets"FLAT" "
	 LINE"bootstrap_sets"FLAT" "
	 LINE"model"FLAT" "
	 LINE"\n\t\t[kappa]"FLAT" "
	 LINE"invar"FLAT" "
	 LINE"nb_categ"FLAT" "
	 LINE"alpha"FLAT" "
	 LINE"tree"FLAT" "
	 LINE"opt_topology"FLAT" "
	 LINE"opt_lengths"FLAT" "
	 "]\n");

  printf(FLAT"\n\tYou can use phyml with no arguments, in this case change the value of\n"
	 FLAT"\ta parameter by typing its corresponding character as shown on screen.\n\n"
	 FLAT"\tYou can alternatively use phyml with the following arguments :\n");

  printf(LINE"\n\tsequence_file"
	 FLAT"\tDNA or Amino-Acids sequence filename (PHYLIP format)\n"

	 LINE"\n\tdata type"
	 FLAT"\t"BOLD"0"FLAT" = DNA | "BOLD"1"FLAT" = Amino-Acids\n"

	 LINE"\n\tformat"
	 FLAT"\t\t"BOLD"i"FLAT" = interleaved sequence format | "
	 BOLD"s"FLAT" = sequential\n"

	 LINE"\n\tdata_sets"
	 FLAT"\tnumber of data sets to analyse (ex:3)\n"

	 LINE"\n\tbootstrap_sets"
	 FLAT"\tnumber of bootstrap data sets to generate (ex:2)\n"
	 FLAT"\t\t\tonly works with one data set to analyse\n"

	 LINE"\n\tmodel"
	 FLAT"\t\tsubstitution model name\n"
	 BOLD"\t\t\tJC69 | K2P | F81 | HKY | F84 | TN93 | GTR "FLAT"(DNA)\n"
	 BOLD"\t\t\tJTT | MtREV | Dayhoff | WAG "FLAT"(Amino-Acids)\n"

	 LINE"\n\tkappa"
	 FLAT"\t\ttransition/transversion ratio, only for DNA sequences,\n"
	 FLAT"\t\t\ta fixed value (ex:4.0) | "BOLD"e"FLAT" to get the maximum likelihood estimate\n"

	 LINE"\n\tinvar"
	 FLAT"\t\tproportion of invariable sites,\n"
	 FLAT"\t\t\ta fixed value (ex:0.0) | "BOLD"e"FLAT" to get the maximum likelihood estimate\n"

	 LINE"\n\tnb_categ"
	 FLAT"\tnumber of relative substitution rate categories (ex:4)\n"

	 LINE"\n\talpha"
	 FLAT"\t\tgamma distribution parameter,\n"
	 FLAT"\t\t\ta fixed value (ex:1.0) | "BOLD"e"FLAT" to get the maximum likelihood estimate\n"

	 LINE"\n\ttree"
	 FLAT"\t\tstarting tree filename (Newick format),\n"
	 FLAT"\t\t\tyour tree filename | "BOLD"BIONJ"FLAT" for a distance-based tree\n"

	 LINE"\n\topt_topology"
	 FLAT"\toptimise tree topology ? "BOLD"y | n\n"

	 LINE"\n\topt_lengths"
	 FLAT"\toptimise branch lengths and rate parameters ? "BOLD"y | n\n");

printf(  FLAT"\n\tExamples\n"
	 FLAT"\tDNA sequences : "BOLD"  ./phyml seqs1 0 i 2 0 HKY 4.0 e 1 1.0 BIONJ y n \n"
	 FLAT"\n\tAA sequences :  "BOLD"  ./phyml seqs2 1 i 1 5 JTT 0.0 4 1.0 BIONJ n n \n"FLAT);
  Exit("");
}

/*********************************************************/

#define N_SEQUENCEFILE 1
#define N_DATATYPE 2
#define N_FORMAT 3
#define N_DATASETS 4
#define N_BOOTSTRAPSETS 5
#define N_MODELNAME 6
#define N_KAPPA 7
#define N_PROPORTIONINVAR 7 /*same as kappa*/
#define N_NBCATG 8
#define N_ALPHA 9
#define N_STARTINGTREE 10
#define N_OPT_TOPO 11
#define N_OPT_LENGTHSRATES 12

#define N_NB_PARAMS_DNA 13
#define N_NB_PARAMS_AA 12

option *Get_Input(int argc, char **argv)
{

  option* input               = (option *)mCalloc(1,sizeof(option));
  putchar('\n');

  input->fp_seq               = NULL;
  input->fp_input_tree              = NULL;
  input->mod                  = Make_Model_Basic();
  input->seqfile              = (char *)mCalloc(T_MAX_FILE,sizeof(char));
  input->modelname            = (char *)mCalloc(50,sizeof(char));
  input->nt_or_cd             = (char *)mCalloc(50,sizeof(char));
  input->inputtreefile        = (char *)mCalloc(T_MAX_FILE,sizeof(char));
  input->phyml_tree_file      = (char *)mCalloc(T_MAX_FILE,sizeof(char));
  input->phyml_stat_file      = (char *)mCalloc(T_MAX_FILE,sizeof(char));
  input->phyml_lk_file        = (char *)mCalloc(T_MAX_FILE,sizeof(char));
  

  Set_Defaults_Input(input);
  Set_Defaults_Model(input->mod);
  Set_Defaults_Optimiz(input->mod->s_opt);

  Translate_Custom_Mod_String(input->mod);
  Init_Optimiz(input->mod->s_opt);

  switch (argc)
    {
    case 1:
      Get_Input_Interactive(input);
      break;
    case 2:
      Usage();
      break;
    default:
      if (isdigit((int)argv[N_DATATYPE][0]))
	{
	  if (atoi(argv[N_DATATYPE])==0 && argc-1==N_NB_PARAMS_DNA)
	    Get_Input_CommandLine_DNA(input, argc, argv);
	  else if (atoi(argv[N_DATATYPE])==1 && argc-1==N_NB_PARAMS_AA)
	    Get_Input_CommandLine_AA(input, argc, argv);
	  else
	    Usage();
	}
      else
	Usage();
    }

  /*print the parameter values*/
  printf("\n\n\n");

  printf("Sequence filename : \t\t\t\t %s\n", input->seqfile);

  printf("Data type :             \t\t\t %s\n", (input->mod->datatype ? "aa" : "dna"));

  printf("Sequence format : \t\t\t\t %s\n", input->interleaved ? "interleaved" : "sequential");

  printf("Number of data sets : \t\t\t\t %d\n", input->n_data_sets);

  printf("Nb of bootstrapped data sets : \t\t\t %d\n", input->mod->bootstrap);

  printf("Model name : \t\t\t\t\t %s\n", input->modelname);

  if (0==input->mod->datatype) {
    if (input->mod->s_opt->opt_kappa)
      printf("ts/tv ratio : \t\t\t\t\t estimated\n");
    else
      {
	if ((input->mod->whichmodel == 2)|| 
	   (input->mod->whichmodel == 4)||  
	   (input->mod->whichmodel == 5)||
	   (input->mod->whichmodel == 6))
	  printf("ts/tv ratio : \t\t\t\t\t %f\n", input->mod->kappa);
      }
  }

  if (input->mod->s_opt->opt_pinvar)
    printf("Proportion of invariable sites :\t\t estimated\n");
  else
    printf("Proportion of invariable sites :\t\t %f\n", input->mod->pinvar);

  printf("Number of subst. rate categs : \t\t\t %d\n", input->mod->n_catg);

  if (input->mod->s_opt->opt_alpha)
    printf("Gamma distribution parameter : \t\t\t estimated\n");
  else
    printf("Gamma distribution parameter : \t\t\t %f\n", input->mod->alpha);

  printf("Starting tree : \t\t\t\t %s\n", (!input->inputtree) ? "BIONJ" : input->inputtreefile);

  printf("Optimise tree topology : \t\t\t %s\n", (input->mod->s_opt->opt_topo) ? "yes" : "no");

  printf("Optimise branch lengths and rate parameters : \t %s\n", (input->mod->s_opt->opt_free_param) ? "yes" : "no");
  

  return input;
}



void Get_Input_CommandLine_Common(option *input, int argc, char **argv)
{
  char* p;



  p = argv[N_SEQUENCEFILE];
  

#ifdef PHYML

  strcpy(input->seqfile, p);
  input->fp_seq = Openfile(input->seqfile,0);

#endif


  input->phyml_stat_file_open_mode = 1; /* stands for the "R" (Replacement) interactive option */

  input->phyml_tree_file_open_mode = 1; /* stands for the "R" (Replacement) interactive option */


#ifdef PHYML
  strcpy(input->phyml_stat_file,input->seqfile);
  strcat(input->phyml_stat_file,"_phyml_stat.txt");

  strcpy(input->phyml_tree_file,input->seqfile);
  strcat(input->phyml_tree_file,"_phyml_tree.txt");

  strcpy(input->phyml_lk_file,input->seqfile);
  strcat(input->phyml_lk_file,"_phyml_lk.txt");
#endif



  p = argv[N_FORMAT];
  input->interleaved = (!strcmp(p,"i")) ? 1 : 0;


  p = argv[N_DATASETS];
  if (!atoi(p) || (input->n_data_sets = atoi(p)) < 0)
    Exit("\nThe number of data sets should be a positive integer\n");


  p = argv[N_BOOTSTRAPSETS];
  if ((input->mod->bootstrap = atoi(p)) < 0)
    Exit("\nThe number of bootstrapped data sets should be a positive or null integer\n");

  if(!input->mod->bootstrap)
    {
      input->print_boot_trees = 0;
      input->fp_boot_tree  = NULL;
      input->fp_boot_stats = NULL;

    }
  else
    {
      char *r;
      r = (char *)mCalloc(T_MAX_LINE, sizeof(char));
      strcpy(r,input->seqfile);
      input->print_boot_trees = 1;
      input->fp_boot_tree  = Openfile(strcat(r,"_phyml_boot_trees.txt"),1);
      strcpy(r,input->seqfile);
      input->fp_boot_stats = Openfile(strcat(r,"_phyml_boot_stats.txt"),1);
      Free(r);
    }


  p = argv[N_PROPORTIONINVAR];
  if (!strcmp(p,"e"))
    {
      input->mod->s_opt->opt_pinvar = 1; 
      input->mod->pinvar = 0.2;
      input->mod->invar  = 1;
    }
  else
    {
      if((atof(p) < 0.0) || (atof(p) > 1.0))
	{
	  Exit("\nErr : the proportion of invariable sites must be a positive number between 0.0 and 1.0\n");
	}
      else
	{
	  input->mod->s_opt->opt_pinvar = 0;
	  input->mod->pinvar = (double)atof(p);
	  input->mod->invar = (input->mod->pinvar > 0.0+MDBL_MIN) ? 1 : 0;
	}
    }


  p = argv[N_NBCATG];
  if (!atoi(p) || (input->mod->n_catg = atoi(p)) < 0)
    Exit("\nThe number of categories should be a positive integer\n");


  p = argv[N_ALPHA];
  if (!strcmp(p,"e"))
    {
      input->mod->s_opt->opt_alpha = 1; 
    }
  else
    {
      input->mod->s_opt->opt_alpha = 0;
      input->mod->alpha = 1.0;

      if(!atof(p) || (input->mod->alpha = (double)atof(p)) < .0)
	Exit("\nAlpha must be a positive number\n");
    }


  p = argv[N_STARTINGTREE];
  if (!strcmp(p,"BIONJ"))
    {
      input->inputtree = 0;
    }
  else
    {
      input->inputtree = 1;
      strcpy(input->inputtreefile, p);
      input->fp_input_tree = Openfile(input->inputtreefile,0);
    }


  p = argv[N_OPT_TOPO];
  input->mod->s_opt->opt_topo = (!strcmp(p,"y")) ? 1 : 0;


  p = argv[N_OPT_LENGTHSRATES];
  input->mod->s_opt->opt_free_param = (!strcmp(p,"y")) ? 1 : 0;

}

/*Attention phyml compilé avec les symboles de compilation EVOLVE et OPTIMIZ n'est utilisable qu'en mode interactif */
void Get_Input_CommandLine_DNA(option *input, int argc, char **argv)
{
  char* p;

  /*convert into AA syntax to have a common code with the AA case*/
  char** argvbis;
  int i;
  char kappa[30];
  model *mod;


  mod = input->mod;


  argvbis = (char**)calloc(argc-1, sizeof(char*));
  for (i=0; i<N_KAPPA; i++)
    {
      argvbis[i] = (char*)malloc(T_MAX_FILE);
      strcpy(argvbis[i], argv[i]);
    }
  strcpy(kappa, argv[N_KAPPA]);
  for (i=N_KAPPA; i<argc-1; i++)
    {
      argvbis[i] = (char*)malloc(T_MAX_FILE);
      strcpy(argvbis[i], argv[i+1]);
    }

  Get_Input_CommandLine_Common(input, argc-1, argvbis); /*argv must not change*/


  input->mod->datatype         = 0;


  p = argvbis[N_MODELNAME];
  strcpy(input->modelname, p);
  if      (!strcmp(p,"JC69")) mod->whichmodel = 1;
  else if (!strcmp(p,"K2P"))  mod->whichmodel = 2;
  else if (!strcmp(p,"F81"))  mod->whichmodel = 3;
  else if (!strcmp(p,"HKY"))  mod->whichmodel = 4;
  else if (!strcmp(p,"F84"))  mod->whichmodel = 5;
  else if (!strcmp(p,"TN93")) mod->whichmodel = 6;
  else if (!strcmp(p,"GTR"))  mod->whichmodel = 7;

  else Exit("\nUnknown model \n");

  mod->ns = 4;

  p = kappa;
  if (!strcmp(p,"e"))
    {
      mod->s_opt->opt_kappa = 1;
      mod->kappa = 4.0;

      if(mod->whichmodel == 6)
	mod->s_opt->opt_lambda = 1;
      if((mod->whichmodel == 1) ||
	 (mod->whichmodel == 3) ||
	 (mod->whichmodel == 7) ||
	 (mod->whichmodel == 8))
	mod->s_opt->opt_kappa = 0;
    }
  else
    {
      mod->s_opt->opt_kappa = 0;
      mod->s_opt->opt_lambda = 0;

      if(!atof(p) || (mod->kappa = (double)atof(p)) < .0)
	Exit("\nThe ts/tv ratio should be a positive number\n");
    }


  if(
     (mod->whichmodel == 1) ||
     (mod->whichmodel == 3) ||
     (mod->whichmodel == 7) ||
     (mod->whichmodel == 8))
    {
      mod->s_opt->opt_kappa  = 0;
      mod->s_opt->opt_lambda = 0;
    }

  if(mod->whichmodel != 6) mod->s_opt->opt_lambda = 0;


  for (i=0; i<argc-1; i++)
    free(argvbis[i]);
  free(argvbis);
}


/*Attention phyml compilé avec les symboles de compilation EVOLVE et OPTIMIZ n'est utilisable qu'en mode interactif */
void Get_Input_CommandLine_AA(option *input, int argc, char **argv)
{
  char* p;

  Get_Input_CommandLine_Common(input, argc, argv);

  input->mod->datatype         = 1;


  p = argv[N_MODELNAME];
  strcpy(input->modelname, p);
  if      (!strcmp(p,"Dayhoff")) input->mod->whichmodel = 11;
  else if (!strcmp(p,"JTT"))     input->mod->whichmodel = 12;
  else if (!strcmp(p,"MtREV"))   input->mod->whichmodel = 13;
  else if (!strcmp(p,"WAG"))     input->mod->whichmodel = 14;
  else if (!strcmp(p,"DCMut"))   input->mod->whichmodel = 15;
  else if (!strcmp(p,"RtREV"))   input->mod->whichmodel = 16;
  else if (!strcmp(p,"CpREV"))   input->mod->whichmodel = 17;
  else if (!strcmp(p,"VT"))      input->mod->whichmodel = 18;
  else if (!strcmp(p,"Blosum62"))input->mod->whichmodel = 19;
  else if (!strcmp(p,"MtMam"))   input->mod->whichmodel = 20;
  else Exit("\nUnknown model name\n");

  input->mod->ns = 20;

  if(input->mod->whichmodel != 6) input->mod->s_opt->opt_lambda = 0;
}

void Get_Input_Interactive(option *input)
{
  char choix;
  char *s    = (char *)mCalloc(T_MAX_LINE,sizeof(char));
  char *buff = (char *)mCalloc(T_MAX_LINE,sizeof(char));
  int n_trial;

#ifdef EVOLVE

  char *n_data_sets;

  printf("Enter the tree file name > "); fflush(NULL);
  Getstring_Stdin(input->inputtreefile);
  input->fp_input_tree = Openfile(input->inputtreefile,0);
  printf("\n");

  printf("Enter the reference sequence file name > "); fflush(NULL);
  Getstring_Stdin(input->seqfile);
  input->fp_seq = Openfile(input->seqfile,0);
  printf("\n");

  printf("Number of data sets > ");
  n_data_sets = (char *)mCalloc(T_MAX_LINE,sizeof(char));
  Getstring_Stdin(n_data_sets);
  n_trial = 0;
  while((!atoi(n_data_sets)) || (atoi(n_data_sets) < 0))
    {
      if(++n_trial > 10) Exit("\nErr : the number of sets must be a positive integer\n");
      printf("\nThe number of sets must be a positive integer\n");
      printf("Enter a new value > ");
      Getstring_Stdin(n_data_sets);
    }
  input->n_data_set_asked = atoi(n_data_sets);
  Free(n_data_sets);

#elif OPTIMIZ

  printf("Enter the tree file name > "); fflush(NULL);
  Getstring_Stdin(input->inputtreefile);
  input->fp_input_tree = Openfile(input->inputtreefile,0);
  printf("\n");

  printf("Enter the reference sequence file name > "); fflush(NULL);
  Getstring_Stdin(input->seqfile);
  input->fp_seq = Openfile(input->seqfile,0);
  printf("\n");

#elif PHYML

  printf("Enter the sequence file name > "); fflush(NULL);
  Getstring_Stdin(input->seqfile);
  input->fp_seq = Openfile(input->seqfile,0);

#endif


#ifdef PHYML
  strcpy(input->phyml_stat_file,input->seqfile);
  strcat(input->phyml_stat_file,"_phyml_stat.txt");

  strcpy(input->phyml_tree_file,input->seqfile);
  strcat(input->phyml_tree_file,"_phyml_tree.txt");

  strcpy(input->phyml_lk_file,input->seqfile);
  strcat(input->phyml_lk_file,"_phyml_lk.txt");
#endif


#ifdef WIN32
#ifdef EVOLVE
  if(Filexists("evolve_out.txt"));
#elif OPTIMIZ
  if(Filexists("optimiz_out.txt")) 
#elif PHYML
  if(Filexists(input->phyml_stat_file)) 
#endif
#elif UNIX
#ifdef EVOLVE
  if(Filexists("evolve_out"));
#elif OPTIMIZ
  if(Filexists("optimiz_out"))
#elif PHYML
  if(Filexists(input->phyml_stat_file))
#endif
#endif
    {
      printf("\n");
#ifdef EVOLVE
      printf("A file 'evolve_out' already exists\n");
#elif OPTIMIZ
      printf("A file 'optimiz_out' already exists\n");
#elif PHYML
      printf("A file '%s' already exists\n",input->phyml_stat_file);
#endif
      printf("Do you want to Replace it or Append to it ?\n");
      n_trial = 0;
      do
	{
	  printf("Please type R or A > ");
	  scanf("%c",&choix);
	  if(choix == '\n') choix = 'r'; 
	  else getchar();
	  if(++n_trial>10) Exit("\n");
	  Uppercase(&choix);
	}
      while((choix != 'R') && (choix != 'A'));
      if(choix == 'R') input->phyml_stat_file_open_mode = 1;
      else             input->phyml_stat_file_open_mode = 2;
    }

#ifdef WIN32
#ifdef EVOLVE
  if(Filexists("evolve_seq.txt"))   
#elif OPTIMIZ
  if(Filexists("optimiz_tree.txt")) 
#elif PHYML
  if(Filexists(input->phyml_tree_file)) 
#endif
#elif UNIX
#ifdef EVOLVE
  if(Filexists("evolve_seq")) 
#elif OPTIMIZ
  if(Filexists("optimiz_tree")) 
#elif PHYML
  if(Filexists(input->phyml_tree_file)) 
#endif
#endif
    {
      printf("\n");
#ifdef EVOLVE
      printf("A file 'evolve_seq' already exists\n");
#elif OPTIMIZ
      printf("A file 'optimiz_tree' already exists\n");
#elif PHYML
      printf("A file '%s' already exists\n",input->phyml_tree_file);
#endif
      printf("Do you want to Replace it or Append to it ?\n");
      n_trial = 0;
      do
	{
	  printf("Please type R or A > ");
	  scanf("%c",&choix);
	  if(choix == '\n') choix = 'X'; 
	  else getchar();
	  Uppercase(&choix);
	  if(++n_trial>10) Exit("\n");
	}
      while((choix != 'R') && (choix != 'A'));
      if(choix == 'R') input->phyml_tree_file_open_mode = 1;
      else             input->phyml_tree_file_open_mode = 2;
    }

  choix                    = 0;


  do
    {
#ifdef WIN32
      system("cls");
#elif UNIX
      printf("\033[2J\033[H");
#endif


#ifdef EVOLVE
      printf("\n - EVOLVE - \n\n\n");
#elif OPTIMIZ
      printf("\n - OPTIMIZ - \n\n\n");
#elif PHYML
      printf("\n - PHYML %s - \n\n\n",VERSION);
#endif

      printf("Settings for this run:\n\n");


      printf("  D "
	     "                                Data type (DNA/AA) "
	     " %-15s \n",
	     (input->mod->datatype)?("AA"):("DNA"));


      printf("  I "
	     "       Input sequences interleaved (or sequential) "
	     " %-15s \n",
	     (input->interleaved)?("interleaved"):("sequential"));


      strcpy(s,"");
      sprintf(s," (%d sets)",input->n_data_sets);
      strcpy(buff,(input->n_data_sets > 1)?("yes"):("no"));
      buff=strcat(buff,(input->n_data_sets > 1)?(s):("\0"));
      printf("  S "
	     "                        Analyze multiple data sets "
	     " %-15s \n",buff);

      strcpy(buff,(input->mod->bootstrap > 0)?("yes"):("no"));
      if(input->mod->bootstrap > 0) sprintf(buff+strlen(buff)," (%d replicate%s)",
					    input->mod->bootstrap,
					    (input->mod->bootstrap>1)?("s"):(""));

      printf("  B "
	     "                 Non parametric bootstrap analysis "
	     " %-15s \n",buff);

      if (!input->mod->datatype)
	{
	  if(!strcmp(input->nt_or_cd,"nucleotides"))
	    {
	      printf("  M  "
		     "                 Model of nucleotide substitution "
		     " %-15s \n", input->modelname);

	      if((input->mod->whichmodel < 8) && (input->mod->whichmodel > 2))
		printf("  E "
		       "           Base frequency estimates (empirical/ML) "
		       " %-15s \n",
		       (input->mod->s_opt->opt_bfreq)?("ML"):("empirical"));

	      else if(input->mod->whichmodel == 8)
		{

		printf("  E "
		       "                 Optimise equilibrium frequencies  "
		       " %-15s \n",
		       (input->mod->s_opt->opt_bfreq)?("yes"):("no"));

		}


	      if(input->mod->whichmodel == 8)
		{
		  printf("  F  "
			 "                          Equilibrium frequencies "
			 " %-15s \n",
			 (input->mod->user_b_freq[0]<.0)?("empirical"):("user defined"));

		  printf("  K  "
			 "                             Current custom model "
			 " %-15s \n", input->mod->custom_mod_string);
		
		  printf("  W  "
			 "                Optimise relative rate parameters "
			 " %-15s \n",(input->mod->s_opt->opt_rr_param)?("yes"):("no"));

		}
	      

	    }
	  else
	      printf("  M  "
		     "                      Model of codon substitution "
		     " %-15s \n", input->modelname);
	}
      else
	{
	  printf("  M  "
		 "                Model of amino-acids substitution "
		 " %-15s \n", input->modelname);
	}
      

      if ((!input->mod->datatype) && 
	  ((input->mod->whichmodel == 2)|| 
	   (input->mod->whichmodel == 4)||  
	   (input->mod->whichmodel == 5)||
	   (input->mod->whichmodel == 6)))
	{
	  strcpy(s,(input->mod->s_opt->opt_kappa)?("estimated"):("fixed"));
	  (input->mod->s_opt->opt_kappa)?(strcat(s, "")):(strcat(s," (ts/tv = "));
	  (input->mod->s_opt->opt_kappa)?(strcat(s, "")):((char *)sprintf(s+(int)strlen(s),"%3.2f)",input->mod->kappa));

	  printf("  T "
		 "                     Ts/tv ratio (fixed/estimated) "
		 " %-15s \n",s);
	}
      

      (input->mod->s_opt->opt_pinvar)?(strcpy(s,"estimated")):(strcpy(s,"fixed"));
      (input->mod->s_opt->opt_pinvar)?(strcat(s,"")):(strcat(s," (p-invar = "));
      (input->mod->s_opt->opt_pinvar)?(strcat(s,"")):((char *)sprintf(s+strlen(s),"%3.2f)",input->mod->pinvar));
      printf("  V  "
	     " Proportion of invariable sites (fixed/estimated)"
	     "  %-15s \n",s);


      printf("  R "
	     "        One category of substitution rate (yes/no) "
	     " %-15s \n",
	     (input->mod->n_catg > 1)?("no"):("yes"));

      if(input->mod->n_catg > 1)
	{
	  printf("  C "
		 "            Number of substitution rate categories "
		 " %-15d \n",
		 input->mod->n_catg);
	}


      if(input->mod->n_catg > 1)
	{
	  strcpy(s,(input->mod->s_opt->opt_alpha)?("estimated"):("fixed"));
	  (input->mod->s_opt->opt_alpha)?(strcat(s, "")):(strcat(s," (alpha = "));
	  (input->mod->s_opt->opt_alpha)?(strcat(s, "")):((char *)sprintf(s+strlen(s),"%3.2f)",input->mod->alpha));
  
	  printf("  A "
		 "    Gamma distribution parameter (fixed/estimated) "
		 " %-15s \n",s);
	}


#ifdef PHYML
      printf("  U "
	     "                      Input tree (BIONJ/user tree) "
	     " %-15s \n",
	     (!input->inputtree)?("BIONJ"):("user tree"));

      printf("  O "
	     "                            Optimise tree topology "
	     " %-15s \n",
	     (input->mod->s_opt->opt_topo)?("yes"):("no"));


#endif

#ifdef EVOLVE
      strcpy(s,"");
      (input->seq_len==-1)?((int)strcpy(s,"Reference data set length")):((int)sprintf(s,"l = %d",input->seq_len));
      
      printf("  L "
	     "                                  Sequence length "
	     " %-15s \n",s);
#elif PHYML
      if(!input->mod->s_opt->opt_topo)
	{
	  printf("  L "
		 "         Optimise branch lengths & rate parameters "
		 " %-15s \n",
		 (input->mod->s_opt->opt_free_param)?("yes"):("no"));
	}
#endif


      printf("\n");

      printf("\nAre these settings correct? "
	     "(type  Y  or letter for one to change)  ");

      scanf("%c",&choix);
      if(choix == '\n') choix = 'X'; 
      else getchar(); /* \n */

      Uppercase(&choix);

      if ((choix == 'Y') || (choix == 'y'))
	break;

      switch(choix)
	{
	
#ifdef PHYML
	case 'B' :
	  {
	    if(input->mod->bootstrap > 0) input->mod->bootstrap = 0;
	    else
	      {
		char *r;
		char answer;


		if(input->n_data_sets > 1)
		  Exit("\n. Bootstrap option is not allowed with multiple data sets\n");

		printf("Number of replicates > ");
		r = (char *)mCalloc(T_MAX_LINE,sizeof(char));
		Getstring_Stdin(r);
		n_trial = 0;
		while((!atoi(r)) || (atoi(r) < 0))
		  {
		    if(++n_trial > 10) Exit("\nErr : the number of replicates must be a positive integer\n");
		    printf("\nThe number of replicates must be a positive integer\n");
		    printf("Enter a new value > ");
		    Getstring_Stdin(r);
		  }
		input->mod->bootstrap = atoi(r);

		printf("Print bootstrap trees (and statistics) ? (%s) > ",
		       (input->print_boot_trees)?("Y/n"):("y/N"));
		
		scanf("%c",&answer);
		if(answer == '\n') answer = (input->print_boot_trees)?('Y'):('N');
		else getchar();
		
		switch(answer)
		  {
		  case 'Y' : case 'y' : 
		    {
		      input->print_boot_trees = 1;
                      strcpy(r,input->seqfile);
		      input->fp_boot_tree  = Openfile(strcat(r,"_phyml_boot_trees.txt"),1);
                      strcpy(r,input->seqfile);
		      input->fp_boot_stats = Openfile(strcat(r,"_phyml_boot_stats.txt"),1);
		      break;
		    }
		  case 'N' : case 'n' : 
		    {
		      input->print_boot_trees = 0;
		      input->fp_boot_tree  = NULL;
		      input->fp_boot_stats = NULL;
		      break;
		    }
		  }
		Free(r);
	      }
	    break;
	  }


	case 'U' :
	  {
	    if(!input->inputtree) 
	      {
		input->inputtree = 1;
		printf("Enter the name of the tree file > ");
		Getstring_Stdin(input->inputtreefile);
		input->fp_input_tree = Openfile(input->inputtreefile,0);
	      }
	    else input->inputtree = 0;
	    break;
	  }
#endif
	case 'O' :
	  {
	    input->mod->s_opt->opt_topo = 
	      (input->mod->s_opt->opt_topo)?(0):(1);
	  }
	case 'W' :
	  {
	    input->mod->s_opt->opt_rr_param = 
	    (input->mod->s_opt->opt_rr_param)?(0):(1);
	    break;
	  }

	case 'K' :
	  {
	    int i,j;
	    char **rr_param,*rr;
	    model *mod;
	    int curr_param;
	    
	    if(input->mod->whichmodel == 8)
	      {
		rr_param = (char **)mCalloc(5,sizeof(char *));
		For(i,5) rr_param[i] = (char *)mCalloc(10,sizeof(char));
		rr = (char *)mCalloc(T_MAX_LINE,sizeof(char));
		
		mod = input->mod;
		
		n_trial = 0;
		do
		  {
		    printf("Enter a new custom model > ");
		    Getstring_Stdin(input->mod->custom_mod_string);
		    if(strlen(input->mod->custom_mod_string) == 6)
		      {
			For(i,6)
			  {
			    while(!isdigit((int)input->mod->custom_mod_string[i]))
			      {
				if(++n_trial > 10) Exit("\nErr : this string is not valid !\n");
				printf("\nThis string is not valid\n");
				printf("Enter a new model > ");
				Getstring_Stdin(input->mod->custom_mod_string);
			      }
			  }
			if(i == 6) break;
		      }
		    else 
		      {
			printf("\nThe string should be of length 6\n");
			n_trial++;
		      }
		  }while(n_trial < 10);
		if(n_trial == 10) Exit("");
		
		Translate_Custom_Mod_String(input->mod);
		
		strcpy(rr_param[0],"A<->C");	  
		strcpy(rr_param[1],"A<->G");
		strcpy(rr_param[2],"A<->T");
		strcpy(rr_param[3],"C<->G");
		strcpy(rr_param[4],"C<->T");
		
		printf("\nSet the relative rate values (G<->T is fixed to 1.0) \n");
		curr_param = 0;
		For(i,mod->n_diff_rr_param)
		  {
		    For(j,mod->n_rr_param_per_cat[i]) 
		      if(mod->rr_param_num[i][j] == 5) break;
		    
		    if(j == mod->n_rr_param_per_cat[i])
		      {
			printf("[");
			For(j,mod->n_rr_param_per_cat[i])
			  {
			    printf("%s",rr_param[mod->rr_param_num[i][j]]);
			    if(j<mod->n_rr_param_per_cat[i]-1) printf(" = ");
			  }
			printf("]");
			
			printf("  (current=%.2f) > ",mod->rr_param_values[i]);
			
			Getstring_Stdin(rr);
			
			if(rr[0] != '\0')
			  {
			    n_trial = 0;
			    while((atof(rr) < .0))
			      {
				if(++n_trial > 10) 
				  Exit("\nErr : the value of this parameter must be a positive number\n");
				printf("The value of this parameter must be a positive number\n");
				printf("Enter a new value > ");
				Getstring_Stdin(rr);
			      }
			    input->mod->rr_param_values[curr_param] = (double)atof(rr);
			  }
			For(j,mod->n_rr_param_per_cat[i])
                            mod->rr_param[mod->rr_param_num[i][j]] =
                            mod->rr_param_values+curr_param;
			curr_param++;
		      }
		    else
		      {
			For(j,mod->n_rr_param_per_cat[i])
			  mod->rr_param_values[mod->rr_param_num[i][j]] = 1.0;
			For(j,mod->n_rr_param_per_cat[i])
			  mod->rr_param[mod->rr_param_num[i][j]] =
			  mod->rr_param_values+5;
		      }
		  }
		
		For(i,5) Free(rr_param[i]);
		Free(rr_param);
		Free(rr);
	      }
	    break;
	  }

	case 'F' :
	  {
	    int i;
	    
	    if(input->mod->whichmodel == 8)
	      {
		if(input->mod->user_b_freq[0] >= .0)
		  For(i,4) input->mod->user_b_freq[i] = -1.;
		else
		  {
		    char **bases;
		    char *bs;
		    double sum;

		    bases = (char **)mCalloc(4,sizeof(char *));
		    For(i,4) bases[i] = (char *)mCalloc(50,sizeof(char));
		    bs = (char *)mCalloc(T_MAX_LINE,sizeof(char));
		    
		    strcpy(bases[0],"f(A) > ");
		    strcpy(bases[1],"f(C) > ");
		    strcpy(bases[2],"f(G) > ");
		    strcpy(bases[3],"f(T) > ");
		    
		    printf("Set nucleotide frequencies \n");
		    sum = .0;
		    For(i,4)
		      {
			printf("%s",bases[i]);
		       
			Getstring_Stdin(bs);
			
			n_trial = 0;

			while((atof(bs) < .0001) ||
			      (bs[0] == '\0'))
			  {
			    if(++n_trial > 10) 
			      Exit("\nErr : the value of this parameter must be a positive number\n");
			    printf("The value of this parameter must be a positive number\n");
			    printf("Enter a new value > ");
			    Getstring_Stdin(bs);
			  }
			input->mod->user_b_freq[i] = (double)atof(bs);
			sum += input->mod->user_b_freq[i];
		      }
		    
		    For(i,4)
		      {
			input->mod->user_b_freq[i] /= sum;			
		      }

		    For(i,4) Free(bases[i]);
		    Free(bases);
		    Free(bs);
		  }
	      }
	    break;
	  }

	case 'E' :
	  {
	    if((input->mod->whichmodel > 10) ||
	       (input->mod->whichmodel < 3)) Exit("\n. Invalid choice...\n");
	    input->mod->s_opt->opt_bfreq = (input->mod->s_opt->opt_bfreq)?(0):(1);
	    break;
	    }

	case 'D' :
	  {
	    if(!input->mod->datatype)
	      {
		input->mod->datatype = 1;
		input->mod->stepsize = 1;
		input->mod->ns = 20;
		input->mod->whichmodel    = 12;
		strcpy(input->modelname,"JTT");
	      }
	    else
	      {
		input->mod->ns = 4;
		input->mod->datatype  = 0;
		input->mod->stepsize = 1;
		input->mod->whichmodel = 4;
		strcpy(input->modelname,"HKY");
		strcpy(input->nt_or_cd,"nucleotides");
	      }
	    break;
	  }

	case 'M' :
	  {
	    if(!input->mod->datatype)
	      {
		if(!strcmp(input->nt_or_cd,"nucleotides"))
		  {
		    if(input->mod->whichmodel == 1)
		      {
			input->mod->whichmodel = 2;
			strcpy(input->modelname,"K2P");
		      }
		    else if(input->mod->whichmodel == 2)
		      {
			input->mod->whichmodel = 3;
			strcpy(input->modelname,"F81");
			input->mod->s_opt->opt_kappa = 0;
		      }
		    else if(input->mod->whichmodel == 3)
		      {
			input->mod->whichmodel = 4;
			strcpy(input->modelname,"HKY");
		      }
		    else if(input->mod->whichmodel == 4)
		      {
			input->mod->whichmodel = 5;
			strcpy(input->modelname,"F84");
		      }
		    else if(input->mod->whichmodel == 5)
		      {
			input->mod->whichmodel = 6;
			strcpy(input->modelname,"TN93");
			if(input->mod->s_opt->opt_kappa) input->mod->s_opt->opt_lambda = 1;
		      }
		    else if(input->mod->whichmodel == 6)
		      {
			input->mod->whichmodel = 7;
			strcpy(input->modelname,"GTR");
			input->mod->s_opt->opt_kappa = 0;
		      }
		    else if(input->mod->whichmodel == 7)
		      {
			input->mod->whichmodel = 8;
			strcpy(input->modelname,"custom");
			input->mod->s_opt->opt_kappa = 0;
		      }

		    else if(input->mod->whichmodel == 8)
		      {
			input->mod->whichmodel = 1;
			strcpy(input->modelname,"JC69");
			input->mod->s_opt->opt_kappa = 0;
		      }
		  }
	      }
	    else
	      {
		if(input->mod->whichmodel == 11)
		  {
		    input->mod->whichmodel = 12;
		    strcpy(input->modelname,"JTT");
		  }
		else if(input->mod->whichmodel == 12)
		  {
		    input->mod->whichmodel = 13;
		    strcpy(input->modelname,"MtREV");
		  }
		else if(input->mod->whichmodel == 13)
		  {
		    input->mod->whichmodel = 14;
		    strcpy(input->modelname,"WAG");
		  }
		else if(input->mod->whichmodel == 14)
		  {
		    input->mod->whichmodel = 15;
		    strcpy(input->modelname,"DCMut");
		  }
		else if(input->mod->whichmodel == 15)
		  {
		    input->mod->whichmodel = 16;
		    strcpy(input->modelname,"RtREV");
		  }
		else if(input->mod->whichmodel == 16)
		  {
		    input->mod->whichmodel = 17;
		    strcpy(input->modelname,"CpREV");
		  }
		else if(input->mod->whichmodel == 17)
		  {
		    input->mod->whichmodel = 18;
		    strcpy(input->modelname,"VT");
		  }
		else if(input->mod->whichmodel == 18)
		  {
		    input->mod->whichmodel = 19;
		    strcpy(input->modelname,"Blosum62");
		  }
		else if(input->mod->whichmodel == 19)
		  {
		    input->mod->whichmodel = 20;
		    strcpy(input->modelname,"MtMam");
		  }
		else if(input->mod->whichmodel == 20)
		  {
		    input->mod->whichmodel = 11;
		    strcpy(input->modelname,"Dayhoff");
		  }
	      }
	    break;
	  }

	case 'R' :
	    {
	      (input->mod->n_catg == 1)?(input->mod->n_catg = 4):(input->mod->n_catg = 1);
	      break;
	    }
	  
	case 'C' :
	  {
	    char *c;
	    printf("Enter your number of categories > ");
	    c = (char *)mCalloc(T_MAX_LINE,sizeof(char));
	    Getstring_Stdin(c);
	    n_trial = 0;
	    while((!atoi(c)) || (atoi(c) < 0))
	      {
		if(++n_trial > 10) Exit("\nErr : the number of categories must be a positive integer\n");
		printf("\nThe number of categories must be a positive integer\n");
		printf("Enter a new value > ");
		Getstring_Stdin(c);
	      }
	    input->mod->n_catg = atoi(c);
	    Free(c);
	    break;
	  }
	  
	  
	case 'A' :
	  {
	    char answer;
	    
	    switch(input->mod->s_opt->opt_alpha)
	      {
	      case 0 : 
		{
		  printf("Optimise alpha ? [Y/n] ");
		  scanf("%c",&answer);
		  if(answer == '\n') answer = 'Y';
		  else getchar();
		  break;
		}
	      case 1 : 
		{
		  printf("Optimise alpha ? [N/y] ");
		  scanf("%c",&answer);
		  if(answer == '\n') answer = 'N';
		  else getchar();
		  break;
		}
	      default : Exit("\n");
	      }
		
	    n_trial = 0;
	    while((answer != 'Y') && (answer != 'y') &&
		  (answer != 'N') && (answer != 'n'))  
	      {
		if(++n_trial > 10) Exit("\nErr : wrong answers !");
		printf("Optimise alpha ? [N/y] ");
		scanf("%c",&answer);
		if(answer == '\n') answer = 'N';
		else getchar();
	      }

	    switch(answer)
	      {
	      case 'Y' : case 'y' : 
		{
		  input->mod->s_opt->opt_alpha = 1; 
		  input->mod->s_opt->opt_free_param = 1;
		  break;
		}
	      case 'N' : case 'n' : 
		{
		  char *a;
		  a = (char *)mCalloc(T_MAX_LINE,sizeof(char));
		  input->mod->alpha = 10.0;
		  input->mod->s_opt->opt_alpha = 0; 
		  printf("Enter your value of alpha > ");
		  Getstring_Stdin(a);
		  n_trial = 0;
		  while((!atof(a)) || (atof(a) < .0))
		    {
		      if(++n_trial > 10) Exit("\nErr : alpha must be a positive number\n");
		      printf("Alpha must be a positive number\n");
		      printf("Enter a new value > ");
		      Getstring_Stdin(a);
		    }
		  input->mod->alpha = (double)atof(a);
		  Free(a);
		  input->mod->s_opt->opt_alpha  = 0;
		  break;
		}
	      }	 
	    break;
	  }

	case 'T' :
	  {
	    char answer;
	    
	    if((input->mod->datatype)   || 
	       (input->mod->whichmodel == 1) ||
	       (input->mod->whichmodel == 3) ||
	       (input->mod->whichmodel == 7)) 
	      Exit("\n 'T' is not a valid choice for this model\n");
	    
	    switch(input->mod->s_opt->opt_kappa)
	      {
	      case 0 : 
		{
		  printf("Optimise ts/tv ratio ? [Y/n] ");
		  scanf("%c", &answer);
		  if(answer == '\n') answer = 'Y';
		  else getchar();
		  break;
		}
	      case 1 : 
		{
		  printf("Optimise ts/tv ratio ? [N/y] ");
		  scanf("%c", &answer);
		  if(answer == '\n') answer = 'N';
		  else getchar();
		  break;
		}
	      default : Exit("\n");
	      }

	    n_trial = 0;
	    while((answer != 'Y') && (answer != 'y') &&
		  (answer != 'N') && (answer != 'n'))  
	      {
		if(++n_trial > 10) Exit("\nErr : wrong answers !");
		printf("Optimise ts/tv ratio ? [N/y] ");
		scanf("%c", &answer);
		if(answer == '\n') answer = 'N';
		else getchar();
	      }

	    switch(answer)
	      {
	      case 'Y' : case 'y' : 
		{
		  input->mod->kappa = 4.0;
		  input->mod->s_opt->opt_free_param = 1;
		  input->mod->s_opt->opt_kappa = 1; 
		  input->mod->s_opt->opt_kappa = 1;
		  if(input->mod->whichmodel == 6) 
		    input->mod->s_opt->opt_lambda = 1;
		  break;
		}
	      case 'N' : case 'n' : 
		{
		  char *t;
		  t = (char *)mCalloc(T_MAX_LINE,sizeof(char));
		  input->mod->s_opt->opt_kappa = 0; 
		  printf("Enter your value of the ts/tv ratio > ");
		  Getstring_Stdin(t);
		  n_trial = 0;
		  while((!atof(t)) || (atof(t) < .0))
		    {
		      if(++n_trial > 10) Exit("\nErr : the ts/tv ratio must be a positive number\n");
		      printf("The ratio must be a positive number\n");
		      printf("Enter a new value > ");
		      Getstring_Stdin(t);
		    }
		  input->mod->kappa = (double)atof(t);
		  input->mod->s_opt->opt_kappa  = 0;
		  input->mod->s_opt->opt_lambda = 0;
		  Free(t);		
		  break;
		}
	      }	 
	    break;
	  }	  

	case 'I' : 
	  {
	    if(input->interleaved)
	      input->interleaved = 0;
	    else input->interleaved = 1;
	    break;
	  }
	  
	case 'S' :
	  {
	    char *c;

	    printf("How many data sets > ");
	    c = (char *)mCalloc(T_MAX_LINE,sizeof(char));
	    Getstring_Stdin(c);
	    n_trial = 0;
	    while((!atoi(c)) || (atoi(c) < 0))
	      {
		if(++n_trial > 10) Exit("\nErr : The number of data sets must be a positive integer\n");
		printf("\nThe number of data sets must be a positive integer\n");
		printf("Enter a new value > ");
		Getstring_Stdin(c);
	      }
	    input->n_data_sets = atoi(c);

	    if((input->mod->bootstrap > 1) && (input->n_data_sets > 1))
	      Exit("\n. Bootstrap option is not allowed with multiple data sets\n");
	    
	    Free(c);
	    break;
	  }

	case 'V' : 
	  {
	    char answer;
	    
	    switch(input->mod->s_opt->opt_pinvar)
	      {
	      case 0 : 
		{
		  printf("Optimise p-invar ? [Y/n] ");
		  scanf("%c", &answer);
		  if(answer == '\n') answer = 'Y';
		  else getchar();
		  break;
		}
	      case 1 : 
		{
		  printf("Optimise p-invar ? [N/y] ");
		  scanf("%c", &answer);
		  if(answer == '\n') answer = 'N';
		  else getchar();
		  break;
		}
	      default : Exit("\n");
	      }

	    n_trial = 0;
	    while((answer != 'Y') && (answer != 'y') &&
		  (answer != 'N') && (answer != 'n'))  
	      {
		if(++n_trial > 10) Exit("\nErr : wrong answers !");
		printf("Optimise p-invar ? [N/y] ");
		scanf("%c", &answer);
		if(answer == '\n') answer = 'N';
		else getchar();
	      }

	    switch(answer)
	      {
	      case 'Y' : case 'y' : 
		{
		  input->mod->s_opt->opt_free_param = 1;
		  input->mod->s_opt->opt_pinvar = 1; 
		  input->mod->pinvar = 0.2;
		  input->mod->invar  = 1;
		  break;
		}
	      case 'N' : case 'n' : 
		{
		  char *p;
		  p = (char *)mCalloc(T_MAX_LINE,sizeof(char));
		  printf("Enter your value of p-invar > ");
		  Getstring_Stdin(p);
		  n_trial = 0;
		  while((atof(p) < 0.0) || (atof(p) > 1.0))
		    {
		      if(++n_trial > 10)
			Exit("\nErr : the proportion of invariable sites must be a positive number between 0.0 and 1.0\n");
		      printf("The proportion must be a positive number between 0.0 and 1.0\n");
		      printf("Enter a new value > ");
		      Getstring_Stdin(p);
		    }
		  input->mod->pinvar = (double)atof(p);
		  
		  if(input->mod->pinvar > 0.0+MDBL_MIN) input->mod->invar = 1;
		  else                             input->mod->invar = 0;

		  Free(p);

		  input->mod->s_opt->opt_pinvar = 0;
		  break;
		}
	      }	 
	    break;
	  }

#ifdef EVOLVE
	case 'L' :
	  {
	    char *len;
	    len = (char *)mCalloc(T_MAX_LINE,sizeof(char));
	    printf("Enter the sequence length > ");
	    Getstring_Stdin(len);
	    n_trial = 0;
	    while((!atof(len)) || (atof(len) < 0.0-MDBL_MIN))
	      {
		if(++n_trial > 10)
		  Exit("\nErr : sequence length must be a positive integer \n");
		printf("Sequence length must be a positive integer \n");
		printf("Enter a new value > ");
		Getstring_Stdin(len);
	      }
	    input->seq_len = (double)atoi(len);	    
	    Free(len);
	    break;
	  }
#elif PHYML
	case 'L' : 
	  {
	    input->mod->s_opt->opt_free_param = 
	      (input->mod->s_opt->opt_free_param)?(0):(1);
	    
	    if(!input->mod->s_opt->opt_free_param)
	      {
		input->mod->s_opt->opt_alpha      = 0;
		input->mod->s_opt->opt_kappa      = 0;
		input->mod->s_opt->opt_lambda     = 0;
		input->mod->s_opt->opt_bl         = 0;
		input->mod->s_opt->opt_pinvar     = 0;
		input->mod->s_opt->opt_rr_param   = 0;
		input->mod->s_opt->opt_topo       = 0;
	      }
	    break;
	  }

#endif
	  
	default : 
	  {
	    printf("Not a valid choice\n");
	    break;
	  }
	}
    }while(1);
  
  if((input->mod->whichmodel == 1) || (input->mod->whichmodel == 3))
    {
      input->mod->s_opt->opt_kappa  = 0;
      input->mod->s_opt->opt_lambda = 0;
    }

  if(input->mod->whichmodel != 6) input->mod->s_opt->opt_lambda = 0;


  Free(s);
  Free(buff);

}

/*********************************************************/
