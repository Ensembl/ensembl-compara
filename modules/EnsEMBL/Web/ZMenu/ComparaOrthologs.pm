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

# ZMenu on orthologue table (Alignment link)
package EnsEMBL::Web::ZMenu::ComparaOrthologs;

use strict;
use warnings;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $strain_url  = $hub->is_strain || $hub->param('strain') ? "Strain_" : "";
  
  my $align_url = $hub->url({
    type     => 'Gene',
    action   => $strain_url.'Compara_Ortholog',
    function => 'Alignment' . ($hub->param('cdb') =~ /pan/ ? '_pan_compara' : ''),
    hom_id   => $hub->param('dbID'),
    g1       => $hub->param('g1'),
  });
  
  $self->caption("Orthologue Aligment");

  $self->add_entry({
    'label' => 'View Protein Alignment',
    'link'  => $align_url
  });
  
  $self->add_entry({
    'label' => 'View cDNA Alignment',
    'link'  => $align_url.';seq=cDNA'
  });  
}

1;
