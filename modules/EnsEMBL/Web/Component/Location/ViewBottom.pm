package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;
use warnings;
no warnings 'uninitialized';

use Time::HiRes qw(time);

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->configurable(1);
  $self->has_image(1);
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $threshold   = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $image_width = $self->image_width;
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  
  my $slice        = $object->slice;
  my $length       = $slice->end - $slice->start + 1;
  my $T            = time;
  my $image_config = $object->get_imageconfig('contigviewbottom');
  my $s            = $object->param('panel_top') eq 'yes' ? 3 : 2;
  $T = sprintf "%0.3f", time - $T;
  
  $image_config->tree->dump("View Bottom configuration [ time to generate $T sec ]", '([[caption]])') if $object->species_defs->ENSEMBL_DEBUG_FLAGS & $object->species_defs->ENSEMBL_DEBUG_TREE_DUMPS;

  $image_config->set_parameters({
    container_width => $length,
    image_width     => $image_width || 800, # hack at the moment
    slice_number    => "1|$s"
  });

  ## Force display of individual low-weight markers on pages linked to from Location/Marker
  if (my $marker_id = $object->param('m')) {
    $image_config->modify_configs(
      [ 'marker' ],
      { marker_id => $marker_id }
    );
  }

  # Add multicell configuration
  if (keys %{$object->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}}){
    my $web_slice_obj = $self->new_object( 'Slice', $slice, $object->__data );
    my $cell_line_data = $web_slice_obj->get_cell_line_data($image_config);
    $image_config->{'data_by_cell_line'} = $cell_line_data;
  } 

  # Lets see if we have any das sources
  $self->_attach_das($image_config);
  
  my $image_config_2 = $object->get_imageconfig('contigviewtop');
  my $info           = $image_config->_update_missing($object);
  my $info_2         = $image_config_2->_update_missing($object);
  my $extra_message  = '';
  
  if ($object->param('panel_top') eq 'yes') {
    $extra_message .= "You currently have $info_2->{'count'} tracks in the overview panel and $info->{'count'} tracks in the main panel turned off";
  } else {
    $extra_message .= "You currently have the overview panel and $info->{'count'} tracks on the main panel turned off";
  }
  
  my $image = $self->new_image($slice, $image_config, $object->highlights);
  
	return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'bottom';
  $image->imagemap = 'yes';

  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  my $html = $image->render;
  $html .= $self->_info('Configuring the display', qq{<p>$extra_message. To change the tracks you are displaying, use the "<strong>Configure this page</strong>" link on the left.</p>});
  
  return $html;
}


1;
