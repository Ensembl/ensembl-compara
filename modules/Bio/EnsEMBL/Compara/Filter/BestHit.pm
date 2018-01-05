=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Compara::Filter::BestHit;

use vars qw(@ISA);
use strict;
use warnings;


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
