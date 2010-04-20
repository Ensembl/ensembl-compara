package EnsEMBL::Web::Component::Location::Ideogram;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->has_image(1);
}

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my $slice  = $object->database('core')->get_SliceAdaptor->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  
  my $image_config = $object->get_imageconfig('chromosome');
  $image_config->container_width($object->seq_region_length);
  $image_config->set_width($object->param('image_width'));

  my $image = $self->new_image($slice, $image_config);
  
  return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'ideogram';
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');

  return '<p>.</p>' . $image->render;

}

1;
