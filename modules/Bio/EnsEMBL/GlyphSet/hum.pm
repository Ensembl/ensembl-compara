package Bio::EnsEMBL::GlyphSet::hum;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "SpTrHuman"; }

sub features {
    my ($self) = @_;

    
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("hum",1,$self->glob_bp,$self->strand());
}

sub href {
    my ( $self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return $self->{'config'}->{'ext_url'}->get_url( 'SG_HUM', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return { 'caption' => "$id", "Protein homology" => $self->href( $id ) };
}

1;