package Bio::EnsEMBL::GlyphSet::vertrna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "EMBL mRNAs"; }

sub features {
    my ($self) = @_;
    
    my $self->{'container'}->get_all_DnaAlignFeatures_above_score('Vertrna', 80);
}

sub href {
    my ($self, $id ) = @_;
    $id=~s/^([^\.]+)\..*/$1/;
    return $self->{'config'}->{'ext_url'}->get_url('EMBL',$id);
}
sub zmenu {
    my ($self, $id ) = @_;
    return { 'caption' => "$id", "EMBL: $id" => $self->href( $id ) };
}
1;
