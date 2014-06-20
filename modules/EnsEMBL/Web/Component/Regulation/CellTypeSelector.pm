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
 
  $self->{'panel_type'}      = 'CellTypeSelector';
  $self->{'link_text'}       = 'Select cell types';
  $self->{'included_header'} = 'Selected cell types {category}';
  $self->{'excluded_header'} = 'Unselected cell types {category}';
  $self->{'url_param'}       = 'cell';
  $self->{'rel'}             = 'modal_select_cell_types';
}

sub content_ajax {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $params      = $hub->multi_params; 

  my @shown_cells = @{$object->cell_types||[]};
  my (%shown_cells,%cell_categories);
  $shown_cells{$shown_cells[$_]} = $_+1 for(0..$#shown_cells);
  my %cell_categories = map { $_ => 'shown' } split(',',$hub->param('pagecells'));

  my $fg = $hub->database('funcgen');
  my $fgcta = $fg->get_CellTypeAdaptor();
  my %all_cells = map { $_->name => $_->name } @{$fgcta->fetch_all()};

  $self->{'all_options'}      = \%all_cells;
  $self->{'included_options'} = \%shown_cells;
#  $self->{'categories'} = ['with data available for this page','without data for this page'];
  $self->{'categories'} = ['shown','hidden'];
  $self->{'category_titles'} = {
    shown => 'with data available for this page',
    hidden => 'without data for this page',
  };
  $self->{'default_category'} = 'hidden';
  $self->{'category_map'} = \%cell_categories;
  $self->{'param_mode'} = 'single';

  $self->SUPER::content_ajax;
}

1;
