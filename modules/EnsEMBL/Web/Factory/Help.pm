package EnsEMBL::Web::Factory::Help;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::ParameterSet;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self        = shift;

  ## Create a very lightweight object, as the data required for a help page is very variable

  my $adaptor = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->helpAdaptor;
  my $modular = $self->species_defs->ENSEMBL_MODULAR_HELP;

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'Help', {
      'adaptor'       => $adaptor,
      'modular'       => $modular,
      'records'       => undef,
    }, $self->__data
  ) ); 
}

1;
