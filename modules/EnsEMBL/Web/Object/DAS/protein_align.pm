package EnsEMBL::Web::Object::DAS::protein_align;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object::DAS::dna_align);

sub Types {
  my $self = shift;
  return [
    { 'id' => 'protein alignment'  }
  ];
}

sub Features {
  my $self = shift;
  return $self->_features( 'ProteinAlignFeature', 'protein_alignment' );
}

1;
