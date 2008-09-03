package Bio::EnsEMBL::GlyphSet::comparafake;

use strict;
use Bio::EnsEMBL::GlyphSet;
our @ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  $self->errorTrack( "no match with ".$self->{'container'}{web_species} );
}

1;
        
