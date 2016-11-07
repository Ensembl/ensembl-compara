package EnsEMBL::Web::TextSequence::Markup::Comparisons;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub markup {
  my ($self, $sequence, $markup, $config) = @_; 
  my $i          = 0;
  my ($seq, $comparison);

  my $view = $self->view;

  foreach my $data (@$markup) {
    $seq = $sequence->[$i]->legacy;
    
    foreach (sort {$a <=> $b} keys %{$data->{'comparisons'}}) {
      $comparison = $data->{'comparisons'}{$_};
    
      $seq->[$_]{'title'} .= ($seq->[$_]{'title'} ? "\n" : '') . $comparison->{'insert'} if $comparison->{'insert'} && ($config->{'title_display'}||'on') ne 'off';
    }   
    
    $i++;
  }
}

1;
