package Bio::EnsEMBL::GlyphSet::human_mrna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Human mRNAs"; }

sub features {
    my ($self) = @_;
       my $T = $self->{'container'}->get_all_DnaAlignFeatures('embl_vertrna', 80) || [];
    push @$T, @{$self->{'container'}->get_all_DnaAlignFeatures("refseq_cdna",80)};
    return $T;
}

sub href {
    my ($self, $id ) = @_;
    if ($id =~ /^(NM_\d+)/){
      return $self->{'config'}->{'ext_url'}->get_url('REFSEQ', $1);
    }
    return $self->{'config'}->{'ext_url'}->get_url('EMBL',$id);
}
sub zmenu {
    my ($self, $id ) = @_;
    if ($id =~ /^(NM_\d+)/){
	return { 'caption' => "$id", "REFSEQ: $id" => $self->href($id) };
    }

    return { 'caption' => "$id", "EMBL: $id" => $self->href($id) };
}
1;
