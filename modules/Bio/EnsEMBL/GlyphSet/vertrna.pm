package Bio::EnsEMBL::GlyphSet::vertrna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "EMBL mRNAs"; }

sub features {
    my ($self) = @_;
    $self->{'container'}->get_all_DnaAlignFeatures('Vertrna', 80);
}

sub href {
    my ($self, $id ) = @_;
    $id=~s/^([^\.]+)\..*/$1/;
    return $self->ID_URL('EMBL',$id);
}
sub zmenu {
    my ($self, $id ) = @_;
    return { 'caption' => "$id", "EMBL: $id" => $self->href( $id ) };
}
1;
