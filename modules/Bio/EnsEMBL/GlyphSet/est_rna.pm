package Bio::EnsEMBL::GlyphSet::est_rna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "ESTs (RNA)"; }

sub features {
    my ($self) = @_;

    return $self->{'container'}->get_all_DnaAlignFeatures('RNA', 80 );
}

sub colour {
  my ($self, $id) = @_;
  return $id =~ /^BX/ ? $self->{'colours'}{'genoscope'} : $self->{'colours'}{'col'};
}


sub href {
    my ($self, $id ) = @_;
    ( my $estid = $id ) =~ s/(.*?)\.\d+/$1/ ;
    return $self->ID_URL( 'EST', $estid );
}

sub zmenu {
    my ($self, $id ) = @_;
    return { 'caption' => "EST $id", "$id" => $self->href( $id ) };
}
1;
