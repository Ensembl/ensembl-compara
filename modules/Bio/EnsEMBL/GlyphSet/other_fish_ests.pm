package Bio::EnsEMBL::GlyphSet::other_fish_ests;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Other fish ESTs"; }

sub features {

    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("other_fish_ests",1,$self->glob_bp,$self->strand());

}

sub href {
    my ( $self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return $self->{'config'}->{'ext_url'}->get_url( 'SG_HUM', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return { 'caption' => "$id", "$id" => $self->href( $id ) };
}

1;