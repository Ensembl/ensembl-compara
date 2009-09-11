package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use Time::HiRes qw(time);
use EnsEMBL::Web::RegObj;

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
  my $image_config = $object->image_config_hash('contigviewbottom');
  $T = sprintf "%0.3f", time - $T;
  
  $image_config->tree->dump("View Bottom configuration [ time to generate $T sec ]", '([[caption]])') if $object->species_defs->ENSEMBL_DEBUG_FLAGS & $object->species_defs->ENSEMBL_DEBUG_TREE_DUMPS;

  $image_config->set_parameters({
    container_width => $length,
    image_width     => $image_width || 800, # hack at the moment
    slice_number    => '1|3'
  });

  # Lets see if we have any das sources
  $self->_attach_das($image_config);
  
  my $image_config_2 = $object->image_config_hash('contigviewtop');
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
