package Bio::EnsEMBL::GlyphSet::unigene;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Unigene"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_above_score("unigene.seq",80,$self->glob_bp());
}

sub href { 
    my ($self, $id ) = @_;
    return $self->{'config'}->{'ext_url'}->get_url( 'UNIGENE', $id );
}    
sub zmenu {
    my ($self, $id ) = @_;
    return { 'caption' => "$id", "UniGene cluster $id" => $self->href( $id ) };
}
1;
