package EnsEMBL::Web::Component::Location::Region;

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self         = shift;
  my $object       = $self->object;
  my $slice        = $object->slice;
  my $length       = $slice->end - $slice->start + 1;
  my $image_config = $object->get_imageconfig('cytoview');
  
  $image_config->set_parameters({
    container_width => $length,
    image_width     => $self->image_width || 800,
    slice_number    => '1|2'
  });

  $image_config->modify_configs(
    [ 'user_data' ],
    { strand => 'r' }
  );
  
  $image_config->_update_missing($object);
  
  my $image = $self->new_image($slice, $image_config, $object->highlights);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');

  return $image->render;
}

1;
