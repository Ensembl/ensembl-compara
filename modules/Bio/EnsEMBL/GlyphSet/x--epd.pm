package Bio::EnsEMBL::GlyphSet::epd;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "EPD"; }

sub features {
    my ($self) = @_;

    return $self->{'container'}->get_all_DnaAlignFeatures("BLAST_FUGU_EPD",1);
}

sub href {
    my ( $self, $id ) = @_;
    $id =~ s/(\w+)\.\S+/$1/g;
    return $self->{'config'}->{'ext_url'}->get_url( 'SG_EPD', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(\w+)\.\S+/$1/g;
    return { 'caption' => "$id", "Promoter Sequence" => $self->href( $id ) };
}

1;
