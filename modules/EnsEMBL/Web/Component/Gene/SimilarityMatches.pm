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
  my $matches = $self->_matches('similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', 'MISC', 'LIT');
  my $no_matches = qq(No external references assigned to this gene. Please see the transcript pages for references attached to this gene's transcript(s) and protein(s));
  my $html = $matches ? $matches : $no_matches;
  return $html;
}

1;


