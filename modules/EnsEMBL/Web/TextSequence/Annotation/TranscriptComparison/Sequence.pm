package EnsEMBL::Web::TextSequence::Annotation::TranscriptComparison::Sequence;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation::Sequence);

sub annotate {
  my ($self,$config,$slice_data,$markup,$seq,$ph,$sequence) = @_;

  my $slice = $slice_data->{'slice'};
  my @gene_seq = split '', $slice->seq;
  $sequence->legacy([ map {{ letter => $_ }} @gene_seq ]);
}

1;
