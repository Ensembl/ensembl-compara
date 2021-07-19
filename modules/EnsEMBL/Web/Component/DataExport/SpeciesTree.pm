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

package EnsEMBL::Web::Component::DataExport::SpeciesTree;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport::GeneTree);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;

  my $settings = {
                  'Hidden' => ['align'],
                  %{$self->phyloxml_settings},
                };

  ## Options per format
  my $fields_by_format = {'PhyloXML' => $self->phyloxml_fields};

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub default_file_name {
  my $self = shift;

  my $name = $self->hub->param('gene_name').'_species_tree';
  return $name;
}

1;
