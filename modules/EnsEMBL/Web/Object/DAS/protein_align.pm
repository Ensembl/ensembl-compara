package EnsEMBL::Web::Object::DAS::protein_align;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object::DAS::base_align);

sub Types {
  my $self = shift;
  return [
	  {
	      'REGION' => '*',
	      'FEATURES' => [
			     { 'id' => 'protein alignment'  }
			     ]
			     }
	  ];
}

sub Features {
  my $self = shift;
  return $self->base_align_features( 'ProteinAlignFeature', 'protein_alignment' );
}

sub Stylesheet {
  my $self = shift;
  my $stylesheet_structure = {};
  return $self->_Stylesheet( $stylesheet_structure );
}
1;
