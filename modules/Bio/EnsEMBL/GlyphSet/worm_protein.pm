package Bio::EnsEMBL::GlyphSet::worm_protein;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Wormpep Proteins"; }

sub features {
    my ($self) = @_;

    return $self->{'container'}->get_all_ProteinAlignFeatures('wormpep',80);
}

sub href {
    my ( $self, $id ) = @_;
    return $self->ID_URL( 'WORMPEP_ID', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return { 'caption' => "$id", "Protein homology" => $self->href( $id ) };
}
1;
