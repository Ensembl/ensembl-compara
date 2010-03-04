package EnsEMBL::Web::Data::Rose;

### NAME: EnsEMBL::Web::Data::Rose
### Base class for a Rose::DB::Object object 

### STATUS: Under Development
### You will need to uncomment the use base line in order to test this code!

### DESCRIPTION:
### This module and its children provide access to non-genomic
### databases, using the Rose::DB suite of ORM modules

use strict;
use warnings;

no warnings qw(uninitialized);

#use EnsEMBL::Web::DBSQL::RoseDB;

use base qw(Rose::DB::Object);



1;

