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
