=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::DataExport::GeneTree;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport::Alignments);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;

  my $nhx_values = [];
  my $newick_values = [];

  my %nhx = EnsEMBL::Web::Constants::NHX_OPTIONS;
  foreach my $k (sort {lc($a) cmp lc($b)} keys %nhx) {
    push @$nhx_values, {'label' => $k, 'value' => $nhx{$k}};
  }  
  my %newick = EnsEMBL::Web::Constants::NEWICK_OPTIONS;
  foreach my $k (sort {lc($a) cmp lc($b)} keys %newick) {
    push @$newick_values, {'label' => $k, 'value' => $newick{$k}};
  } 


  my $settings = {
                  'nhx_modes' => {
                                  'type'    => 'DropDown',
                                  'label'   => 'Mode for NHX tree dumping',
                                  'values'  => $nhx_values,
                                  },
                  'newick_modes' => {
                                  'type'    => 'DropDown',
                                  'label'   => 'Mode for Newick tree dumping',
                                  'values'  => $newick_values,
                                  },
                  'scale' => {
                                  'type'  => 'NonNegInt',
                                  'label' => 'Scale for text tree dump',
                                  'value' => '150',
                                  },
                };

  ## Options per format
  my $fields_by_format = {
                          'Newick'    => [['newick_modes']],
                          'NHX'       => [['nhx_modes']],
                          'Text tree' => [['scale']],
  };

  ## Add formats output by BioPerl
  foreach ($self->alignment_formats) {
    $fields_by_format->{$_} = [];
  }

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub default_file_name {
  my $self = shift;

  my $name = $self->hub->param('gene_name').'_gene_tree';
  return $name;
}

1;
