package Bio::EnsEMBL::GlyphSet::mouse_mrna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Mouse mRNAs"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_above_score("mouse_mrna",80,$self->glob_bp);
}

sub href {
    my ($self, $id ) = @_;
    return $self->{'config'}->{'ext_url'}->get_url('EMBL',$id);
}
sub zmenu {
    my ($self, $id ) = @_;
    return { 'caption' => "$id", "EMBL: $id" => $self->href( $id ) };
}
1;
