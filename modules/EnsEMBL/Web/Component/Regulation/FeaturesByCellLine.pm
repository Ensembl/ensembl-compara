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

package EnsEMBL::Web::Component::Regulation::FeaturesByCellLine;

use strict;

use base qw(EnsEMBL::Web::Component::Regulation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub; 
  my $object       = $self->object || $self->hub->core_object('regulation'); 
  my $highlight    = $self->param('opt_highlight');
  my $context      = $self->param('context') || 200;
  my $image_width  = $self->image_width     || 800;
  my $slice        = $object->get_bound_context_slice($context);
     $slice        = $slice->invert if $slice->strand < 1;
  my $slice_length = $slice->length;

  # First configure top part of image - displays tracks that are not cell-line related
  my $image_config = $hub->get_imageconfig({type => 'regulation_view', cache_code => 'top'});
  
  $image_config->set_parameters({
    container_width => $slice_length,
    image_width     => $image_width,
    slice_number    => '1|1',
    opt_highlight   => $highlight
  });
  
  my @containers_and_configs = ($slice, $image_config);

  # Next add cell line tracks
  my $image_config_cell_line = $hub->get_imageconfig({type => 'regulation_view', cache_code => 'cell_line'});
  
  $image_config_cell_line->set_parameters({
    container_width => $slice_length,
    image_width     => $image_width,
    slice_number    => '2|1',
    opt_highlight   => $highlight,
  });

  $image_config_cell_line->{'data_by_cell_line'} = $image_config->{'data_by_cell_line'} = $self->new_object('Slice', $slice, $object->__data)->get_cell_line_data($image_config);
  
  push @containers_and_configs, $slice, $image_config_cell_line;

  # Add config to draw legends and bottom ruler
  my $image_config_bottom = $hub->get_imageconfig({type => 'regulation_view', cache_code => 'bottom'});
  
  $image_config_bottom->set_parameters({
    container_width => $slice_length,
    image_width     => $image_width,
    slice_number    => '3|1',
    opt_highlight   => $highlight
  });
  
  push @containers_and_configs, $slice, $image_config_bottom;
  
  my $image = $self->new_image(\@containers_and_configs, [ $object->stable_id ]);

  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');

  return if $self->_export_image($image);
  return $image->render;
}

1;
