package Bio::EnsEMBL::GlyphSet::est2genome_all;

use strict;
use warnings;
no warnings 'uninitialized';

use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "EST"; }

sub features {
    my $self = shift;
    my @features;
    push @features, @{$self->{'container'}->get_all_SimilarityFeatures("est2genome_human", 80)};
    push @features, @{$self->{'container'}->get_all_SimilarityFeatures("est2genome_mouse", 80)};
    push @features, @{$self->{'container'}->get_all_SimilarityFeatures("est2genome_other", 80)};
    return \@features;
}

sub href {
    my ( $self, $id ) = @_;
    return $self->{'config'}->{'exturl'}->get_url( 'EMBL', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(^[^\.]+)\..*/$1/;
    return { 'caption' => "EST $id", "$id" => $self->href( $id ) };
}
1;
