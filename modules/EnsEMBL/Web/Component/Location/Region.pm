package EnsEMBL::Web::Component::Location::Region;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self   = shift;
  my $object = $self->object;

  my $slice = $object->slice;
  my $length = $slice->end - $slice->start + 1;

  my $wuc = $object->user_config_hash( 'cytoview' );
  $wuc->set_parameters({
    'container_width' => $length,
    'image_width'     => $self->image_width || 800,
    'slice_number'    => '1|2'
  });
  my $image    = $object->new_image( $slice, $wuc, $object->highlights );
     $image->imagemap = 'yes';
     $image->{'panel_number'} = 'top';
     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return $image->render;
}

1;
