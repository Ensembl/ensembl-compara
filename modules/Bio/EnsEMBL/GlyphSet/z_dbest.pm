package Bio::EnsEMBL::GlyphSet::z_dbest;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "EST"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures( "z_dbest", 80, $self->glob_bp);
}

sub href {
    my ( $self, $id ) = @_;
    return $self->{'config'}->{'ext_url'}->get_url( 'EMBL', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(^[^\.]+)\..*/$1/;
    return { 'caption' => "EST $id", "$id" => $self->href( $id ) };
}
1;
