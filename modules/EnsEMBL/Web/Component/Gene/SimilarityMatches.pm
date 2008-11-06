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
  return $self->_matches( 
           'similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', 'MISC'
         ).$self->_info( 'Transcript and protein references','
  <p>
These are external records attached specifically to the gene; please see the transcript panel for those attached to the transcript(s) and protein(s).
  </p>
'
         );
}

1;


