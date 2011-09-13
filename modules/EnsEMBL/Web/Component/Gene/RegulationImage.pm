package EnsEMBL::Web::Component::Gene::RegulationImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->has_image(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $extended_slice = $object->get_extended_reg_region_slice;

  my $wuc = $object->get_imageconfig( 'generegview' );
  $wuc->set_parameters({
    'container_width'   => $extended_slice->length,
    'image_width',      => $self->image_width || 800,
  });

  ## Turn gene display on....
  my $key = $wuc->get_track_key( 'transcript', $object );
  $wuc->modify_configs( [$key], {qw(display transcript)} );

  my $image    = $self->new_image( $extended_slice, $wuc, [] );
  $image->imagemap           = 'yes';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

  return $image->render;
}
1;
