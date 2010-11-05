package EnsEMBL::Web::Component::Regulation::FeaturesByCellLine;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Regulation);


sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object; 

  my $Configs;

  my $context      = $object->param( 'context' ) || 200;
  my $object_slice = $object->get_bound_context_slice($context);
     $object_slice = $object_slice->invert if $object_slice->strand < 1;

  # First configure top part of image - displays tracks that are not cell-line related
  my $image_config_top = $object->get_imageconfig( 'regulation_view' );
  $image_config_top->set_parameters({
    'container_width'   => $object_slice->length,
    'image_width',      => $self->image_width || 800,
    'slice_number',     => '1|1',
    'opt_highlight'    => $object->param('opt_highlight')
  });
  my @containers_and_configs = ( $object_slice, $image_config_top);


  # Next add cell line tracks
  my $image_config_cell_line = $object->get_imageconfig( 'reg_detail_by_cell_line' );
  $image_config_cell_line->set_parameters({
    'container_width'   => $object_slice->length,
    'image_width',      => $self->image_width || 800,
    'slice_number',     => '2|1',
    'opt_highlight'     => $object->param('opt_highlight'),
    'opt_empty_tracks'  => $object->param('opt_empty_tracks')
  });


  my $web_slice_obj = $self->new_object( 'Slice', $object_slice, $object->__data );
  my $cell_line_data = $web_slice_obj->get_cell_line_data($image_config_cell_line);
  my @all_reg_objects = @{$object->fetch_all_objs_by_slice($object_slice)};


  $image_config_cell_line->{'data_by_cell_line'} = $cell_line_data; 
  push @containers_and_configs, $object_slice, $image_config_cell_line;

  # Add config to draw legends and bottom ruler
  my $wuc_regulation_bottom = $object->get_imageconfig( 'regulation_view_bottom' );
  $wuc_regulation_bottom->set_parameters({
      'container_width'   => $object_slice->length,
      'image_width',      => $self->image_width || 800,
      'slice_number'      => '3|1',
      'opt_highlight'     => $object->param('opt_highlight')
    });
  $wuc_regulation_bottom->{'fg_regulatory_features_legend_features'}->{'fg_regulatory_features'} = {'priority' =>1020, 'legend' => [] };
  push @containers_and_configs, $object_slice, $wuc_regulation_bottom; 

  my $image    = $self->new_image(
    [ @containers_and_configs,],
    [$object->stable_id],
  );

  $image->imagemap           = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

return $image->render;
}

1;
