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
