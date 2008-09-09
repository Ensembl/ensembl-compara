package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use Time::HiRes qw(time);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->configurable(  1 );
}


sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $threshold   = 1e6 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $image_width = $self->image_width;

  if( $object->length > $threshold ) {
    return sprintf qq(
  <div class="autocenter alert-box" style="width:%spx;">
    The region selected is too large to display in this view - use the navigation above to zoom in...
  </div>), $image_width;

  }

  my $slice = $object->slice;
  my $length = $slice->end - $slice->start + 1;
  my $T = time;
  my $wuc = $object->user_config_hash( 'contigviewbottom' );
  $T = sprintf "%0.3f", time - $T;
  $wuc->tree->dump("View Bottom configuration [ time to generate $T sec ]", '([[caption]])');

  $wuc->set_parameters({
    'container_width' => $length,
    'image_width'     => $image_width || 800, ## hack at the moment....
    'slice_number'    => '1|3',
  });

  $wuc->_update_missing( $object );
  my $image    = $object->new_image( $slice, $wuc, $object->highlights );
     $image->{'panel_number'} = 'bottom';
     $image->imagemap = 'yes';

     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return $image->render;
}


1;
