# $Id$

package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->configurable(1);
  $self->has_image(1);
}

sub _add_object_track {
  my $self = shift;

  my $extra = '';
  my $hub = $self->hub;
  my $image_config = $hub->get_imageconfig('contigviewbottom');
  # Add track for gene if not on by default
  if (my $gene = $hub->core_objects->{'gene'}) {
    my $key  = $image_config->get_track_key('transcript', $gene);
    my $node = $image_config->get_node(lc $key);
 
    if($node && $node->get("display") eq 'off') { 
      # Check user has not explicitly dimissed track in this session.
      my $flag = $hub->session->get_data(type => 'auto_add', code => lc $key);
      unless($flag->{'data'}) {
        $image_config->update_track_renderer(lc $key,'transcript_label');
        $extra .= $self->_info("Information","The track containing the highlighted gene has been added to your display.")."<br/>";
        $hub->session->set_data(type => 'auto_add' , code => lc $key, data => 1); 
        $hub->session->store();
      }
    }
  }
  return $extra;
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $threshold   = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $image_width = $self->image_width;
  my $info = '';
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  
  my $slice        = $object->slice;
  my $length       = $slice->end - $slice->start + 1;
  my $image_config = $hub->get_imageconfig('contigviewbottom');
  my $s            = $hub->get_viewconfig('ViewTop')->get('show_top_panel') eq 'yes' ? 3 : 2;
  
  $image_config->set_parameters({
    container_width => $length,
    image_width     => $image_width || 800, # hack at the moment
    slice_number    => "1|$s"
  });

  ## Force display of individual low-weight markers on pages linked to from Location/Marker
  if (my $marker_id = $hub->param('m')) {
    $image_config->modify_configs(
      [ 'marker' ],
      { marker_id => $marker_id }
    );
  }

  $info .= $self->_add_object_track();

  # Add multicell configuration
  if (keys %{$hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'}}){
    my $web_slice_obj = $self->new_object( 'Slice', $slice, $object->__data );
    my $cell_line_data = $web_slice_obj->get_cell_line_data($image_config);
    $image_config->{'data_by_cell_line'} = $cell_line_data;
  } 

  $image_config->_update_missing($object);
  
  my $image = $self->new_image($slice, $image_config, $object->highlights);
  
	return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'bottom';
  $image->imagemap         = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  return $info.$image->render;
}


1;
