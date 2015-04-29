#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>

MODULE = EnsEMBL::Web::XS::Test		PACKAGE = EnsEMBL::Web::XS::Test		

void
hello_planet(planet = 0)
    const char * planet
  CODE:
    if(!planet || !*planet)
      planet = "Commander Powell";
    fprintf(stderr,"Hello, %s!\n",planet);

