package EnsEMBL::Web::TextSequence::Markup::RegionChange;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub markup {
  my ($self,$sequence,$markup,$config) = @_; 

  my ($change, $class, $seq);
  my $i = 0;

  foreach my $data (@$markup) {
    $change = 1 if scalar keys %{$data->{'region_change'}};
    $seq = $sequence->[$i]->legacy;

    foreach (sort {$a <=> $b} keys %{$data->{'region_change'}}) {
      $seq->[$_]->{'class'} .= 'end ';
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? "\n" : '') . $data->{'region_change'}->{$_} if ($config->{'title_display'}||'off') ne 'off';
    }

    $i++;
  }

  $config->{'key'}->{'other'}{'align_change'} = 1 if $change;
}

1;
