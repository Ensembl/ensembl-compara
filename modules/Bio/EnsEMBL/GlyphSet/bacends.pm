package Bio::EnsEMBL::GlyphSet::bacends;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "BAC ends"; }

sub features {
  my ($self) = @_;
  my $T = $self->{'container'}->get_all_SimilarityFeatures( "BACends", 0);
  foreach( @$T ) { 
    ( my $X = $_->{'true_id'} = $_->hseqname() ) =~ s/(\.?[xyz][abc]|T7|SP6)$//;
    $_->hseqname( $X );
  }
  return $T;
}

sub href {
  my( $self, $id ) = @_;
  return $self->ID_URL( 'DRERIO_BAC', $id );
}

sub zmenu {
  my( $self, $id ) = @_;
#  (my $truncated_id = $id) =~ s/(T7|SP6)$//;
  return { 
    'caption' => "BAC end ".$id,
#   'Clone report' => $self->href( $truncated_id ),
    'Trace' => $self->ID_URL( 'TRACEVIEW', $id )
  };
}
1;
