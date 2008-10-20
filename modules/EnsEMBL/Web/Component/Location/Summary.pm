package EnsEMBL::Web::Component::Location::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  return '' unless $object->seq_region_name;
  my $slice  = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  my $wuc = $object->image_config_hash( 'chromosome' );
     $wuc->set_parameters({
       'container_width' => $object->seq_region_length,
       'image_width'     => $self->image_width,
       'slice_number'    => '1|1'
     });


  $wuc->get_node('ideogram')->set('caption', $object->seq_region_type.' '.$object->seq_region_name );
  my $image    = $object->new_image( $slice, $wuc );
     $image->imagemap = 'yes';
     $image->{'panel_number'} = 'context';
     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return $image->render;
}

1;
