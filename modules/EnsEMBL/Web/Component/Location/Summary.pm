package EnsEMBL::Web::Component::Location::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  
  return '' unless $object && $object->seq_region_name && $self->hub->action ne 'Genome';
  
  my $slice = $object->database('core')->get_SliceAdaptor->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  
  my $image_config = $object->get_imageconfig('chromosome');
  
  $image_config->set_parameters({
    container_width => $object->seq_region_length,
    image_width     => $self->image_width,
    slice_number    => '1|1'
  });

  if ($image_config->get_node('annotation_status')) {
    $image_config->get_node('annotation_status')->set('caption', '');
    $image_config->get_node('annotation_status')->set('menu', 'no');
  };

  $image_config->get_node('ideogram')->set('caption', $object->seq_region_type . ' ' . $object->seq_region_name );
  
  my $image = $self->new_image($slice, $image_config);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->{'panel_number'} = 'context';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  return $image->render;
}

1;
