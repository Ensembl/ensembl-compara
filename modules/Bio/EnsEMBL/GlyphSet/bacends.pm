package Bio::EnsEMBL::GlyphSet::bacends;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "BAC ends"; }

sub features {
  my ($self) = @_;
  my $T = $self->{'container'}->get_all_SimilarityFeatures( "BACends", 0, $self->glob_bp);
  foreach( @$T ) { 
    ( my $X = $_->{'true_id'} = $_->id() ) =~ s/(\.[xyz][abc]|T7|SP6)$//;
    $_->id( $X );
  }
  return $T;
}

sub href {
  my( $self, $id ) = @_;
  return $self->ID_URL( 'DRERIO_BAC', $id );
}

sub zmenu {
    my( $self, $id ) = @_;
    return { 'caption' => "BAC end ".$id, 'Clone report' => $self->href( $id ) };
}
1;
