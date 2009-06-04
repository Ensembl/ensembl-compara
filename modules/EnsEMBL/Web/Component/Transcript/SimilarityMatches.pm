package EnsEMBL::Web::Component::Transcript::SimilarityMatches;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object   = $self->object;
  my $matches =  $self->_matches( 'similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', 'MISC' );
  my $html = $matches ? $matches : '<p>No external records attached to this transcript</p>';
  return $html;
}

1;


