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

package EnsEMBL::Web::ZMenu::SupportingEvidenceAlignmentLegend;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $hit_name   = $hub->param('id');
  my $hit_db     = $self->object->get_sf_hit_db_name($hit_name);
  my $link_name  = $hit_db eq 'RFAM' ? [ split '-', $hit_name ]->[0] : $hit_name;
  my $hit_length = $hub->param('hit_length');

  $self->caption("$hit_name ($hit_db)");
  
  $self->add_entry({
    label_html => $hub->param('havana') || $hub->species_defs->ENSEMBL_SITETYPE eq 'Vega' ? 'Supporting evidence from Havana' : 'Supporting evidence from Ensembl'
  });
  
  $self->add_entry({
    type    => 'View record',
    label   => $hit_name,
    link    => $hub->get_ExtURL_link($link_name, $hit_db, $link_name),
    abs_url => 1
  });
}

1;
