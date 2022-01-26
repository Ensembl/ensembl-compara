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

package EnsEMBL::Web::Component::Regulation::CellTypeSelector;

use strict;

use EnsEMBL::Web::Utils::Sanitize qw(clean_id);

use base qw(EnsEMBL::Web::Component::CloudMultiSelector EnsEMBL::Web::Component::Regulation);

sub _init {
  my $self = shift;

  $self->SUPER::_init;

  $self->{'panel_type'}      = 'CellTypeSelector';
  $self->{'link_text'}       = 'Select cell types';
  $self->{'included_header'} = 'Cell types';
  $self->{'excluded_header'} = 'Cell types';
  $self->{'url_param'}       = 'cell';
  $self->{'rel'}             = 'modal_select_cell_types';
}

sub content_ajax {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $params      = $hub->multi_params;

  my $context       = $self->hub->param('context') || 200;
  my ($shown_cells,$partial) = $self->shown_cells($hub->param('image_config'));

  my (%shown_cells,%cell_categories);
  $shown_cells{$shown_cells->[$_]} = $_+1 for(0..$#$shown_cells);

  my $fg = $hub->database('funcgen');
  my %all_cells = map { (my $k = $_) =~ s/:\w+$//; 
                        my $v = $k;
                        clean_id($k) => $v;
                      } keys %{$object->regbuild_epigenomes};

  $self->{'all_options'}      = \%all_cells;
  $self->{'included_options'} = \%shown_cells;
  $self->{'partial_options'}  =  { map { $_ => 1 } @$partial };
  $self->{'param_mode'} = 'single';
  $self->{'extra_params'} = { image_config => $hub->param('image_config') };

  $self->SUPER::content_ajax;
}

1;
