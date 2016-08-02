package EnsEMBL::Web::TextSequence::Markup::Exons;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub markup {
  my ($self, $sequence, $markup, $config) = @_; 
  my $i = 0;
  my (%exon_types, $exon, $type, $s, $seq);
  
  my $class = { 
    exon0   => 'e0',
    exon1   => 'e1',
    exon2   => 'e2',
    eu      => 'eu',
    intron  => 'ei',
    other   => 'eo',
    gene    => 'eg',
    compara => 'e2',
  };  

  if ($config->{'exons_case'}) {
    $class->{'exon1'} = 'el';
  }
 
  foreach my $data (@$markup) {
    $seq = $sequence->[$i]->legacy;
    
    foreach (sort { $a <=> $b } keys %{$data->{'exons'}}) {
      $exon = $data->{'exons'}{$_};
      $seq->[$_]{'title'} .= ($seq->[$_]{'title'} ? "\n" : '') . $exon->{'id'} if ($config->{'title_display'}||'off') ne 'off';
    
      foreach $type (@{$exon->{'type'}}) {
        $seq->[$_]{'class'} .= "$class->{$type} " unless $seq->[$_]{'class'} and $seq->[$_]{'class'} =~ /\b$class->{$type}\b/;
        $exon_types{$type} = 1;
      }   
    }   
       
    $i++;
  }
  
  $config->{'key'}{'exons'}{$_} = 1 for keys %exon_types;
}

1;
