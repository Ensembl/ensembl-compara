=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
