package Bio::EnsEMBL::GlyphSet::unigene;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
use ExtURL;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Unigene"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("unigene.seq",80,$self->glob_bp(),$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    my $ext_url = ExtURL->new;
    my $unigeneid = $id;
    return { 'caption' => "$id", "UniGene cluster $id" => $ext_url->get_url( 'UNIGENE', $unigeneid ) };
}
1;
