package EnsEMBL::Web::Factory::Blast;

use strict;

use base qw(EnsEMBL::Web::Factory);

sub blast_adaptor {
  my $self    = shift;
  my $species = shift || $self->species_defs->ENSEMBL_PRIMARY_SPECIES;
  my $blast_adaptor; 

  eval {
    $blast_adaptor = $self->hub->databases_species($species, 'blast')->{'blast'};
  };

  return $blast_adaptor if $blast_adaptor;

  # Still here? Something gone wrong!
  warn "Can not connect to blast database: $@";
}

sub createObjects {   
  my $self = shift;    

  ## Create a very lightweight object, as the data required for a blast page is very variable
  $self->DataObjects($self->new_object('Blast', {
    tickets => undef,
    adaptor => $self->blast_adaptor,
  }, $self->__data));
}

1;
