package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use Time::HiRes qw(time);
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->configurable(  1 );
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $threshold   = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $image_width = $self->image_width;

  if( $object->length > $threshold ) {
    return $self->_warning( 'Region too large','
  <p>
    The region selected is too large to display in this view - use the navigation above to zoom in...
  </p>' );
  }

  my $slice = $object->slice;
  my $length = $slice->end - $slice->start + 1;
  my $T = time;
  my $wuc    = $object->image_config_hash( 'contigviewbottom' );
  $T = sprintf "%0.3f", time - $T;
  $wuc->tree->dump("View Bottom configuration [ time to generate $T sec ]", '([[caption]])')
    if $object->species_defs->ENSEMBL_DEBUG_FLAGS & $object->species_defs->ENSEMBL_DEBUG_TREE_DUMPS;

  $wuc->set_parameters({
    'container_width' => $length,
    'image_width'     => $image_width || 800, ## hack at the moment....
    'slice_number'    => '1|3',
  });

## Lets see if we have any das sources....
  $self->_attach_das( $wuc );
  
  my $info = $wuc->_update_missing( $object );
  my $wuc_2  = $object->image_config_hash( 'contigviewtop' );
  my $info_2 = $wuc_2->_update_missing( $object );

  my $extra_message = '';
  if( $object->param( 'panel_top' ) eq 'yes' ) {
    $extra_message .= sprintf 'You currently have the %d tracks in the overview panel and %d tracks in the main panel turned off', $info_2->{'count'}, $info->{'count'};
  } else {
    $extra_message .= sprintf 'You currently have the overview panel and %d tracks on the main panel turned off', $info->{'count'};
  }

  my $image    = $object->new_image( $slice, $wuc, $object->highlights );
     $image->{'panel_number'} = 'bottom';
     $image->imagemap = 'yes';

     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  my $html = $image->render;
  $html .= $self->_info(
    'Configuring the display',
    sprintf '
  <p>
    %s, to change the tracks you are displaying use the "<strong>Configure this page</strong>" link on the left to change the tracks you wish to see.
  </p>', $extra_message
  );
  return $html;
}


1;
