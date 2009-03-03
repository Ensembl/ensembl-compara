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

  $object->DBConnection->get_databases( 'core', 'compara' );
  my $slice = $object->slice;
  my $length = $slice->end - $slice->start + 1;

  my $wuc = $object->image_config_hash( 'cytoview' );
  $wuc->set_parameters({
    'container_width' => $length,
    'image_width'     => $self->image_width || 800,
    'slice_number'    => '1|2'
  });

  $wuc->modify_configs(
    ['user_data'],
    {'strand'=>'r'}
  );
  $self->_attach_das( $wuc );

  my $info = $wuc->_update_missing( $object );

  my $image    = $self->new_image( $slice, $wuc, $object->highlights );
  return if $self->_export_image( $image );
     $image->imagemap = 'yes';
     $image->{'panel_number'} = 'top';
     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );

  my $html = $image->render;
  $html .= $self->_configure_display( $info->{'count'} );
  return $html;

}

1;
