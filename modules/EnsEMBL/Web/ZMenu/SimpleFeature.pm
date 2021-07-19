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

package EnsEMBL::Web::ZMenu::SimpleFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my ($display_label, $ext_url) = map $hub->param($_), qw(display_label ext_url);
  
  $self->caption($hub->param('logic_name') . ($display_label ? ": $display_label" : ''));
  
  for (qw(score bp)) {
    if (my $param = $hub->param($_)) {
      $self->add_entry({
        type  => $_,
        label => $param
      });
    }
  }
  
  if ($ext_url) {
    $self->add_entry({
      label    => $display_label,
      link     => $hub->get_ExtURL($ext_url, $display_label),
      external => 1
    });
  }
}

1;
