/*

PHYML :  a program that  computes maximum likelihood  phylogenies from
DNA or AA homologous sequences 

Copyright (C) Stephane Guindon. Oct 2003 onward

All parts of  the source except where indicated  are distributed under
the GNU public licence.  See http://www.opensource.org for details.

*/

#ifndef OPTIONS_H
#define OPTIONS_H

void Usage();
option *Get_Input(int argc, char **argv);
void Init_Optimiz(optimiz *s_opt);
void Get_Input_Interactive(option *input);
void Get_Input_CommandLine_DNA(option *input, int argc, char **argv);
void Get_Input_CommandLine_AA(option *input, int argc, char **argv);
void Set_Defaults(option* input);

#endif
