package EnsEMBL::Web::Component::Location::Summary;

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
  my $slice  = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  my $wuc = $object->user_config_hash( 'chromosome' );
     $wuc->container_width( $object->seq_region_length );
     $wuc->set_width( $object->param('image_width') );

  my $image    = $object->new_image( $slice, $wuc );
     $image->{'panel_number'} = 'context';
     $image->imagemap = 'yes';
     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return $image->render;
}

1;
