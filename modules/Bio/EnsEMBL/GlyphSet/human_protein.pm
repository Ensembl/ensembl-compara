package Bio::EnsEMBL::GlyphSet::human_protein;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Human proteins"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures(
        "human_protein", 80, $self->glob_bp
    ),$self->{'container'}->get_all_SimilarityFeatures(
        "human_refseq", 80, $self->glob_bp
    );
}

sub colour {
  my( $self, $id ) = @_; 
  return /^NP_/ ? $self->{'colours'}{'refseq'} : $self->{'colours'}{'col'};
}

sub href {
  my ( $self, $id ) = @_;
  return $self->{'config'}->{'ext_url'}->get_url( 'SRS_PROTEIN', $id );
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
