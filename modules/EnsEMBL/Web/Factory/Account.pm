package EnsEMBL::Web::Factory::Account;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self          = shift;

  $self->DataObjects(
    new EnsEMBL::Web::Proxy::Object(
     'Account', undef,
     $self->__data,
    ) 
  );

}

1;
