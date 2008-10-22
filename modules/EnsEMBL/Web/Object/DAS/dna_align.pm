package EnsEMBL::Web::Object::DAS::dna_align;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object::DAS::base_align);

sub Types {
  my $self = shift;

  return [
	  {
	      'REGION' => '*',
	      'FEATURES' => [
			     { 'id' => 'dna alignment'  }
			     ]
			     }
	  ];
}

sub Features {
### Return das features...
  my $self = shift;
  return $self->base_align_features( 'DnaAlignFeature', 'dna alignment' );
}

sub Stylesheet {
  my $self = shift;
  my $stylesheet_structure = {};
  return $self->_Stylesheet( $stylesheet_structure );
}
1;
