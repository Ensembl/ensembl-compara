package Bio::EnsEMBL::GlyphSet::vertrna;
use strict;
use vars qw(@ISA);
use ExtURL;
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "mRNA"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("embl_vertrna",80,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    my $urls = ExtURL->new;
    return { 'caption' => "$id",
	     "EMBL: $id" => $urls->get_url('EMBL',$id) };
}
1;
