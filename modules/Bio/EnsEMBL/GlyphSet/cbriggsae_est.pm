package Bio::EnsEMBL::GlyphSet::cbriggsae_est;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "C.briggsae ESTs"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures( "cbriggsae_est", 80, $self->glob_bp);
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
