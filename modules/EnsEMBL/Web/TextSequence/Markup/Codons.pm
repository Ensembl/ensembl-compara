package EnsEMBL::Web::TextSequence::Markup::Codons;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub markup {
  my ($self, $sequence, $markup, $config) = @_; 

  my $i = 0;
  my ($class, $seq);

  foreach my $data (@$markup) {
    $seq = $sequence->[$i]->legacy;
    
    foreach (sort { $a <=> $b } keys %{$data->{'codons'}}) {
      $class = $data->{'codons'}{$_}{'class'} || 'co';
    
      $seq->[$_]{'class'} .= "$class ";
      $seq->[$_]{'title'} .= ($seq->[$_]{'title'} ? "\n" : '') . $data->{'codons'}{$_}{'label'} if ($config->{'title_display'}||'off') ne 'off';
    
      if ($class eq 'cu') {
        $config->{'key'}{'other'}{'utr'} = 1;
      } else {
        $config->{'key'}{'codons'}{$class} = 1;
      }   
    }   
    
    $i++;
  }
}

1;
