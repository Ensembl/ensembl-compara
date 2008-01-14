package EnsEMBL::Web::Factory::User;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self          = shift;

  $self->DataObjects(
    new EnsEMBL::Web::Proxy::Object(
     'User',
     {id => $ENV{'ENSEMBL_USER_ID'}},
     $self->__data,
    ) 
  );

}

1;
