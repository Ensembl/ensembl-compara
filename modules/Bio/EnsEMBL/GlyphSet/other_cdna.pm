package Bio::EnsEMBL::GlyphSet::other_cdna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Other cDNAs"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_DnaAlignFeatures('other_cdna', 80);
}

sub colour {
   my( $self, $id ) = @_;
   return $self->{'colours'}->{
     $id =~/(NM_\d+)/ ? 'refseq' : ( /(RO|ZX|PX|ZA|PL)\d{5}[A-Z]\d{2}/ ? 'riken' : 'col' )
   }
}
sub href {
    my ($self, $id ) = @_;
    if ($id =~ /^(NM_\d+)/){
      return $self->{'config'}->{'ext_url'}->get_url('REFSEQ', $1);
    }
    if( $id =~ /(RO|ZX|PX|ZA|PL)\d{5}[A-Z]\d{2}/ ) {
      return $self->{'config'}->{'ext_url'}->get_url('RIKEN', $id);
    }
    return $self->{'config'}->{'ext_url'}->get_url('EMBL',$id);
}
sub zmenu {
  my ($self, $id ) = @_;
  if ($id =~ /^(NM_\d+)/){
    return { 'caption' => "$id", "REFSEQ: $id" => $self->href($id) };
  }
  if( $id =~ /(RO|ZX|PX|ZA|PL)\d{5}[A-Z]\d{2}/ ) {
    return { 'caption' => "$id", "RIKEN: $id" => $self->href($id) };
  }
  return { 'caption' => "$id", "EMBL: $id" => $self->href($id) };
}
1;
