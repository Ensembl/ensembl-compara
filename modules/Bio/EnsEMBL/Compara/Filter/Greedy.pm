package Bio::EnsEMBL::Compara::Filter::Greedy;

use vars qw(@ISA);
use strict;

#use Bio::EnsEMBL::DnaDnaAlignFeature;

=head2 filter

    Title   :   filter
    Usage   :   filter(\@)
    Function:   Clean the Array of Bio::EnsEMBL::FeaturePairs in three steps, 
                First, determines the highest scored hit, and fix the expected strand hit
                Second, hits on expected strand are kept if they do not overlap, 
                either on query or subject sequence, previous strored, higher scored hits.
                If hit goes trough the second step, the third test makes sure that the hit
                is coherent position according to previous ones. 
    Returns :   Array reference of Bio::EnsEMBL::FeaturePairs
    Args    :   Array reference of Bio::EnsEMBL::FeaturePairs

=cut

sub filter {
  my ($self,$DnaDnaAlignFeatures) = @_;

  my @{$DnaDnaAlignFeatures} = sort {$b->score <=> $a->score} @{$DnaDnaAlignFeatures};
  
  my @DnaDnaAlignFeatures_filtered;
  my $ref_strand;

  foreach my $fp (@{$DnaDnaAlignFeatures}) {

    if ($fp->strand < 0) {
      $fp->reverse_complement;
    }

    if (! scalar @DnaDnaAlignFeatures_filtered) {
        push @DnaDnaAlignFeatures_filtered, $fp;
	$ref_strand = $fp->hstrand;
        next;
    }

    next if ($fp->hstrand != $ref_strand);

    my $add_fp = 1;

    foreach my $feature_filtered (@DnaDnaAlignFeatures_filtered) {

      my ($start,$end,$hstart,$hend) = ($feature_filtered->start,$feature_filtered->end,$feature_filtered->hstart,$feature_filtered->hend);

      if (($fp->start >= $start && $fp->start <= $end) ||
	  ($fp->end >= $start && $fp->end <= $end) ||
	  ($fp->hstart >= $hstart && $fp->hstart <= $hend) ||
	  ($fp->hend >= $hstart && $fp->hend <= $hend)) {
	$add_fp = 0;
	last;
      }

      if ($ref_strand == 1) {
	unless (($fp->start > $end && $fp->hstart > $hend) ||
		($fp->end < $start && $fp->hend < $hend)) {
	  $add_fp = 0;
	  last;
	}
      } elsif ($ref_strand == -1) {
	unless (($fp->start > $end && $fp->hstart < $hend) ||
		($fp->end < $start && $fp->hend > $hend)) {
	  $add_fp = 0;
	  last;
	}
      }
    }
    push @DnaDnaAlignFeatures_filtered, $fp if ($add_fp);
  }
  return \@DnaDnaAlignFeatures_filtered;
}

1;
