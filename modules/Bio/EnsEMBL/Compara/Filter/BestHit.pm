package Bio::EnsEMBL::Compara::Filter::BestHit;

use vars qw(@ISA);
use strict;


=head2 filter

    Title   :   filter
    Usage   :   filter(\@)
    Function:   Clean the Array of Bio::EnsEMBL::DnaDnaAlignFeature in 2 steps, 
                First, sort FeaturePairs by score descending, identity % descending
                Second, hits are kept if they do not exactly overlap the subject sequence of previous strored, 
                higher scored hits.
    Returns :   Array reference of Bio::EnsEMBL::DnaDnaAlignFeature
    Args    :   Array reference of Bio::EnsEMBL::DnaDnaAlignFeature

=cut

sub filter {
  my ($self,$DnaDnaAlignFeatures) = @_;

  @{$DnaDnaAlignFeatures} = sort {$b->score <=> $a->score ||
				    $b->percent_id <=> $a->percent_id} @{$DnaDnaAlignFeatures};
  
  my @DnaDnaAlignFeatures_filtered;

  foreach my $fp (@{$DnaDnaAlignFeatures}) {
    if ($fp->strand < 0) {
      $fp->reverse_complement;
    }

    my $add_fp = 1;
    
    foreach my $feature_filtered (@DnaDnaAlignFeatures_filtered) {

      my ($start,$end) = ($feature_filtered->start,$feature_filtered->end);

      if ($fp->start == $start && $fp->end == $end) {
	$add_fp = 0;
	last;
      }
    }
    push @DnaDnaAlignFeatures_filtered, $fp if ($add_fp);
  }
  return \@DnaDnaAlignFeatures_filtered;
}

1;
