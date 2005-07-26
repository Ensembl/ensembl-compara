package EnsEMBL::Web::Object::Server;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);

sub get_all_species {
  my $self = shift;
  my @species = @{ $self->species_defs->ENSEMBL_SPECIES };
  my @data = ();
  foreach my $species (@species) {
    (my $name = $species ) =~ s/_/ /g;
    push @data, {
      'species'  => $name,
      'common'   => $self->species_defs->other_species( $species, 'SPECIES_COMMON_NAME' ),
      'link'     => $self->full_URL( 'species'=>$species ),
      'gp'       => $self->species_defs->other_species( $species, 'ENSEMBL_GOLDEN_PATH' ),
      'version'  => $self->species_defs->other_species( $species, 'SPECIES_RELEASE_VERSION' ),
    };
  }
  return @data;
}

1;
