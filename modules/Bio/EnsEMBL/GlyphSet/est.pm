package Bio::EnsEMBL::GlyphSet::est;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "ESTs"; }

sub features {
    my ($self) = @_;
    #return grep { $_->source_tag() eq 'est' }
    #    $self->{'container'}->get_all_ExternalFeatures($self->glob_bp);

    return 
      $self->{'container'}->get_all_DnaAlignFeatures('ex_e2g_feat',
								 0);
}

sub colour {
  my ($self, $id) = @_;
  return $id =~ /^BX/ ? 'red' : 'green';
}


sub href {
    my ($self, $id ) = @_;
    my $estid = $id;
    $estid =~s/(.*?)\.\d+/$1/;
    return $self->{'config'}->{'ext_url'}->get_url( 'EST', $estid );
}

sub zmenu {
    my ($self, $id ) = @_;
    return { 'caption' => "EST $id", "$id" => $self->href( $id ) };
}
1;
