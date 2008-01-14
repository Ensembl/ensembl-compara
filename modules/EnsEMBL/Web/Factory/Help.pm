package EnsEMBL::Web::Factory::Help;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self        = shift;

  ## Create a very lightweight object, as the data required for a help page is very variable
  my $modular = $self->species_defs->ENSEMBL_MODULAR_HELP;

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'Help', {
      'modular'       => $modular,
      'records'       => undef,
    }, $self->__data
  ) ); 
}

1;
