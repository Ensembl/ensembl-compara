package EnsEMBL::Web::Factory::UserAccount;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::DBSQL::UserDB;
our @ISA = qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self          = shift;

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'UserAccount', {}, $self->__data
  ) ); 

}

1;
