package Bio::EnsEMBL::GlyphSet::human_orestes;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Human ORESTES"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_DnaAlignFeatures("TBLASTX_HUM_ORF",1);
}

sub href {
    my ( $self, $id ) = @_;
    return $self->{'config'}->{'ext_url'}->get_url( 'HUMAN_ORESTES', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return { 'caption' => "$id", "$id homology" => $self->href( $id ) };
}


1;

