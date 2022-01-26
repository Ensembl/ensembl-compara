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

package EnsEMBL::Web::Document::HTML::Compara::BlastZ;

use strict;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

sub render { 
  my $self = shift;
  my $html;

  ## Get all the data 
  my $methods = ['BLASTZ_NET', 'LASTZ_NET'];
  my ($species_list, $data) = $self->mlss_data($methods);
  my ($synt_spec, $data_synt) = $self->mlss_data( ['SYNTENY'] );

  ## Do some munging
  my ($species_order, $info) = $self->get_species_info($species_list, 1);

  ## Output data
  foreach my $sp (@$species_order) {
    next unless $sp && $data->{$sp};
    $html .= sprintf('<h4>%s (%s)</h4><ul>', $info->{$sp}{'common_name'}, $info->{$sp}{'long_name'});

    foreach my $other (@$species_order) {
      my $values = $data->{$sp}{$other};
      next unless $values;  
        
          my $mlss_id = $values->[1];
          my $url = '/info/genome/compara/mlss.html?mlss='.$mlss_id;
          my $txt = sprintf '<a href="%s">%s</a>', $url, $self->combine_names($info->{$other}{'common_name'}, $info->{$other}{'long_name'});
          if ($sp eq $other) {
              $txt .= ' [self-alignment]';
          } elsif ($data_synt->{$sp}{$other}) {
              my $url_synt = '/info/genome/compara/mlss.html?mlss='.$data_synt->{$sp}{$other}->[1];
              $txt .= sprintf ' with <a href="%s">synteny analysis</a>', $url_synt;
          }
          $html .= '<li>'.$txt.'</li>';
    } 
    $html .= '</ul>';
  }

  return $html;
}

1;
