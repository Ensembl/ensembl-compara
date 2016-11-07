package EnsEMBL::Web::TextSequence::Annotation::Protein::Sequence;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation::Sequence);

sub annotate {
  my ($self,$config,$slice_data,$markup,$seq,$ph,$sequence) = @_;

  my $translation = $config->{'translation'};
  my $pep_seq  = $translation->Obj->seq;
  $sequence->legacy([ map {{ letter => $_ }} split //, uc $pep_seq ]);
}

1;
