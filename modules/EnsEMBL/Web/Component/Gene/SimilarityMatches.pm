package EnsEMBL::Web::Component::Gene::SimilarityMatches;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

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
  my $html = qq(<p><strong>These are external records attached specifically to the gene; please see the transcript panel for those attached to the transcript and translation.</strong><br /><br /></p>);
  $html .= $self->_matches( 'similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', 'MISC' );

  return $html;
}

1;


