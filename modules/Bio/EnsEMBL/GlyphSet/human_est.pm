package Bio::EnsEMBL::GlyphSet::human_est;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Human ESTs"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures( "human_est", 80, $self->glob_bp);
}

sub href {
    my ( $self, $id ) = @_;
    return $self->ID_URL( 'EMBL', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(^[^\.]+)\..*/$1/;
    return { 'caption' => "EST $id", "$id" => $self->href( $id ) };
}
1;
