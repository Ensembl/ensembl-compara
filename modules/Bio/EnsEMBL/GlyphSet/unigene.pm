package Bio::EnsEMBL::GlyphSet::unigene;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Unigene"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("unigene.seq",80,$self->glob_bp(),$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    my $unigeneid = $id;
    $unigeneid =~ s/\./&CID=/;
    return { 'caption' => "$id",
	     "UniGene cluster $id" => "http://www.ncbi.nlm.nih.gov/UniGene/clust.cgi?ORG=$unigeneid" };

}
1;
