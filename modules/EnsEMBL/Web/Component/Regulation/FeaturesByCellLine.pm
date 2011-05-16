# $Id$

package EnsEMBL::Web::Component::Regulation::FeaturesByCellLine;

use strict;

use base qw(EnsEMBL::Web::Component::Regulation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub; 
  my $object       = $self->object; 
  my $highlight    = $hub->param('opt_highlight');
  my $context      = $hub->param('context') || 200;
  my $image_width  = $self->image_width     || 800;
  my $slice        = $object->get_bound_context_slice($context);
     $slice        = $slice->invert if $slice->strand < 1;
  my $slice_length = $slice->length;

  # First configure top part of image - displays tracks that are not cell-line related
  my $image_config = $hub->get_imageconfig('regulation_view', 'top');
  
  $image_config->set_parameters({
    container_width => $slice_length,
    image_width     => $image_width,
    slice_number    => '1|1',
    opt_highlight   => $highlight
  });
  
  my @containers_and_configs = ($slice, $image_config);

  # Next add cell line tracks
  my $image_config_cell_line = $hub->get_imageconfig('regulation_view', 'cell_line');
  
  $image_config_cell_line->set_parameters({
    container_width  => $slice_length,
    image_width      => $image_width,
    slice_number     => '2|1',
    opt_highlight    => $highlight,
    opt_empty_tracks => $hub->param('opt_empty_tracks')
  });

  $image_config_cell_line->{'data_by_cell_line'} = $self->new_object('Slice', $slice, $object->__data)->get_cell_line_data($image_config_cell_line); 
  
  push @containers_and_configs, $slice, $image_config_cell_line;

  # Add config to draw legends and bottom ruler
  my $image_config_bottom = $hub->get_imageconfig('regulation_view', 'bottom');
  
  $image_config_bottom->set_parameters({
    container_width => $slice_length,
    image_width     => $image_width,
    slice_number    => '3|1',
    opt_highlight   => $highlight
  });
    
  $image_config_bottom->{'fg_regulatory_features_legend_features'}->{'fg_regulatory_features'} = { priority => 1020, legend => [] };
  
  push @containers_and_configs, $slice, $image_config_bottom; 

  my $image = $self->new_image(
    \@containers_and_configs,
    [ $object->stable_id ],
  );

  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  return if $self->_export_image($image);
  return $image->render;
}

1;
