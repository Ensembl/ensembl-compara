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

package EnsEMBL::Web::Component::Regulation::CellTypeSelector;

use strict;

use base qw(EnsEMBL::Web::Component::MultiSelector);

sub _init {
  my $self = shift;
 
  $self->SUPER::_init;
 
  $self->{'link_text'}       = 'Select cell types';
  $self->{'included_header'} = 'Selected cell types';
  $self->{'excluded_header'} = 'Unselected cell types';
  $self->{'url_param'}       = 'cell';
  $self->{'rel'}             = 'modal_select_cell_types';
}

sub content_ajax {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $params      = $hub->multi_params; 

  my @shown_cells = split(',',$hub->param('cell'));
  my %shown_cells;
  $shown_cells{$shown_cells[$_]} = $_ for(0..$#shown_cells);

  my $fg = $hub->database('funcgen');
  my $fgcta = $fg->get_CellTypeAdaptor();
  my %all_cells = map { $_->name => $_->name } @{$fgcta->fetch_all()};

  my $slice       = $hub->database('core')->get_SliceAdaptor->fetch_by_region($object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1);
  my $ld_adaptor  = $hub->database('variation')->get_LDFeatureContainerAdaptor;
  my $populations = $ld_adaptor->get_populations_hash_by_Slice($slice);
  my %shown       = map { $params->{"pop$_"} => $_ } grep s/^pop(\d+)$/$1/, keys %$params;

  $self->{'all_options'}      = \%all_cells;
  $self->{'included_options'} = \%shown_cells;
  $self->{'param_mode'} = 'single';

  $self->SUPER::content_ajax;
}

1;
