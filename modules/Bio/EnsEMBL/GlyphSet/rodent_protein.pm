package Bio::EnsEMBL::GlyphSet::rodent_protein;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Rodent proteins"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures(
        "rodent_protein", 80, $self->glob_bp
    );
}

sub colour {
  my( $self, $id ) = @_; 
  return /^NP_/ ? $self->{'colours'}{'refseq'} : $self->{'colours'}{'col'};
}

sub href {
  my ( $self, $id ) = @_;
  return $self->ID_URL( 'SRS_PROTEIN', $id );
}

sub zmenu {
  my ($self, $id ) = @_;
  $id =~ s/(.*)\.\d+/$1/o;
  return {
    'caption' => "$id",
    "Protein homology" => $self->href( $id )
  };
}
1;
