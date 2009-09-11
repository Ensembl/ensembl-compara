package EnsEMBL::Web::Component::Location::Region;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;

  $object->DBConnection->get_databases('core', 'compara');
  
  my $slice = $object->slice;
  my $length = $slice->end - $slice->start + 1;
  my $image_config = $object->image_config_hash('cytoview');
  
  $image_config->set_parameters({
    container_width => $length,
    image_width     => $self->image_width || 800,
    slice_number    => '1|2'
  });

  $image_config->modify_configs(
    [ 'user_data' ],
    { strand => 'r' }
  );
  
  $self->_attach_das($image_config);

  my $info = $image_config->_update_missing($object);
  my $image = $self->new_image($slice, $image_config, $object->highlights);
  
  return if $self->_export_image($image);
  
   $image->imagemap = 'yes';
   $image->{'panel_number'} = 'top';
   $image->set_button('drag', 'title' => 'Click or drag to centre display');

  my $html = $image->render . $self->_configure_display($info->{'count'});
  
  return $html;
}

1;
