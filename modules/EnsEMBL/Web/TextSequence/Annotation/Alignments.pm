=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Annotation::Alignments;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self, $config, $slice_data, $markup, $seq) = @_;

  if ($config->{'region_change_display'} && $slice_data->{'name'} ne $config->{'species'}) {
    my $s = 0;
        
    # We don't want to mark the very end of the sequence, so don't loop for the last element in the array
    for (0..scalar(@{$slice_data->{'underlying_slices'}}) - 2) {
      my $end_region   = $slice_data->{'underlying_slices'}[$_];
      my $start_region = $slice_data->{'underlying_slices'}[$_+1];
          
      $s += length $end_region->seq(1);
          
      $markup->{'region_change'}{$s-1} = $end_region->name   . ' END';
      $markup->{'region_change'}{$s}   = $start_region->name . ' START';

      for ($s-1..$s) {
        $markup->{'region_change'}{$_} = "GAP $1" if $markup->{'region_change'}{$_} =~ /.*gap.* (\w+)/;
      }
    }     
  }
  
  while (($seq||'') =~  m/(\-+)[\w\s]/g) {
    my $ins_length = length $1;
    my $ins_end    = pos($seq) - 1;
        
    $markup->{'comparisons'}{$ins_end - $_}{'insert'} = "$ins_length bp" for 1..$ins_length;
  }
}

1;
