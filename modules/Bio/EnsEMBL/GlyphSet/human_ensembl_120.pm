package Bio::EnsEMBL::GlyphSet::human_ensembl_120;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "TBlastx Human"; }

sub features {
    my ($self) = @_;
    my @Q = $self->{'container'}->get_all_SimilarityFeatures_by_strand("human_ensembl_120",1,$self->glob_bp,$self->strand());
    print STDERR map { ">> ".$_->start.", ".$_->end.", ".$_->id.".$_->strand.", " <<\n" } grep { $_->start > $_->end } @Q;
    print STDERR map { "== ".$_->start.", ".$_->end.", ".$_->id.".$_->strand.", " ==\n" } grep { $_->start < $_->end } @Q;
    return @Q;
}

sub href {
    my ( $self, $id ) = @_;
    return $self->{'config'}->{'ext_url'}->get_url( 'HUMAN_CONTIGVIEW', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    return { 'caption' => "$id", "Human homologous sequence" => $self->href( $id ) };
}

1;