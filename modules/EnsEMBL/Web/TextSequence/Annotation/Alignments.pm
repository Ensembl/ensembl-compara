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
