package Bio::EnsEMBL::GlyphSet::human_mrna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Human mRNAs"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_above_score("human_mrna",80,$self->glob_bp),  
$self->{'container'}->get_all_SimilarityFeatures_above_score("human_mRNA",80,$self->glob_bp) ;
}

sub href {
    my ($self, $db,$id ) = @_;
    return $self->{'config'}->{'ext_url'}->get_url($db,$id);
}
sub zmenu {
    my ($self, $id ) = @_;
    if ($id =~ /^(NM_\d+)/){
	return { 'caption' => "$id", "REFSEQ: $id" => $self->href('REFSEQ', $1 ) };
    }

    return { 'caption' => "$id", "EMBL: $id" => $self->href('EMBL', $id ) };
}
1;
