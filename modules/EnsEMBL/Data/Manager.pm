package EnsEMBL::Data::Manager;

### NAME: EnsEMBL::Data::Manager
### Base class for a Rose::DB::Object::Manager object 

### STATUS: Under Development
### You will need to uncomment the use base line in order to test this code!

### DESCRIPTION:
### This module and its children enable easy instantiation of EnsEMBL::Data
### objects

### At the moment this base class doesn't really do anything apart from
### inheritance, but it avoids having to comment out the use lines
### on multiple modules when running on pre-Lenny boxes...

use strict;
use warnings;

no warnings qw(uninitialized);

#use base qw(Rose::DB::Object::Manager);


1;

