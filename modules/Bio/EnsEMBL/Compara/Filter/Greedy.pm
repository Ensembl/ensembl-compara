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

package Bio::EnsEMBL::Compara::Filter::Greedy;

use vars qw(@ISA);
use strict;
use warnings;

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

  my @SortedDnaDnaAlignFeatures = sort {$b->score <=> $a->score} @{$DnaDnaAlignFeatures};
  
  my @DnaDnaAlignFeatures_filtered;
  my $ref_strand;

  foreach my $fp (@SortedDnaDnaAlignFeatures) {

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
