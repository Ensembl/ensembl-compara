package Bio::EnsEMBL::GlyphSet::sptr;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Proteins"; }

sub features {
    my ($self) = @_;

    return $self->{'container'}->get_all_ProteinAlignFeatures_above_score('swall',80);
}

sub href {
    my ( $self, $id ) = @_;
    return $self->{'config'}->{'ext_url'}->get_url( 'SRS_PROTEIN', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return { 'caption' => "$id", "Protein homology" => $self->href( $id ) };
}
1;
