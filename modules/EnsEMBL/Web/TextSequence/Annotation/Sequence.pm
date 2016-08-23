package EnsEMBL::Web::TextSequence::Annotation::Sequence;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self,$config,$slice_data,$markup,$seq,$hub,$sequence) = @_;

  if ($config->{'match_display'}) {
    if ($slice_data->{'name'} eq $config->{'ref_slice_name'}) {
      push @$sequence, [ map {{ letter => $_ }} @{$config->{'ref_slice_seq'}} ];    } else {
      my $i       = 0;
      my @cmp_seq = map {{ letter => ($config->{'ref_slice_seq'}[$i++] eq $_ ? '|' : ($config->{'ref_slice_seq'}[$i-1] eq uc($_) ? '.' : $_)) }} split '', $seq;
      while ($seq =~ m/([^~]+)/g) {
        my $reseq_length = length $1;
        my $reseq_end    = pos $seq;
            
        $markup->{'comparisons'}{$reseq_end - $_}{'resequencing'} = 1 for 1..$reseq_length;
      }     
      
      push @$sequence, \@cmp_seq;
    }
  } else {
    push @$sequence, [ map {{ letter => $_ }} split '', $seq ];
  }
}

1;
