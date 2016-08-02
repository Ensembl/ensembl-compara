package EnsEMBL::Web::TextSequence::Annotation::Sequence;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub prepare_ropes {
  my ($self,$config,$slices) = @_;
 
  $self->{'ropes'} = [];
  foreach my $sl (@$slices) {
    push @{$self->{'ropes'}},$self->add_rope;
  }
}

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

sub annotate_new {
  my ($self,$config,$slice_data,$markup,$seq,$hub,$sequence) = @_;

  if ($config->{'match_display'}) {
    if ($slice_data->{'name'} eq $config->{'ref_slice_name'}) {
      $sequence->legacy([ map {{ letter => $_ }} @{$config->{'ref_slice_seq'}} ]);
    } else {
      my $i       = 0;
      my @cmp_seq = map {{ letter => ($config->{'ref_slice_seq'}[$i++] eq $_ ? '|' : ($config->{'ref_slice_seq'}[$i-1] eq uc($_) ? '.' : $_)) }} split '', $seq;
      while ($seq =~ m/([^~]+)/g) {
        my $reseq_length = length $1;
        my $reseq_end    = pos $seq;
            
        $markup->{'comparisons'}{$reseq_end - $_}{'resequencing'} = 1 for 1..$reseq_length;
      }     
      $sequence->legacy(\@cmp_seq); 
    }
  } else {
    my $i = 0;
    $sequence->legacy([ map { { letter => $_, match => (uc($config->{'ref_slice_seq'}[$i++]||'') eq uc($_||'')) }} split '', $seq ]);
  }
}

1;
