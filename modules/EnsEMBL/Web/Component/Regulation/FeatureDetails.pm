package EnsEMBL::Web::Component::Regulation::FeatureDetails;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Regulation);
use CGI qw(escapeHTML);


sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object; 
  my $Configs;

  my $object_slice = $object->get_context_slice(1000);
     $object_slice = $object_slice->invert if $object_slice->strand < 1;

  my $wuc = $object->get_imageconfig( 'reg_detail' );
  $wuc->set_parameters({
    'container_width'   => $object_slice->length,
    'image_width',      => $self->image_width || 800,
    'slice_number',     => '1|1',
  });


  my $focus_set_blocks = $object->get_focus_set_block_features($object_slice);
  if ($focus_set_blocks ) {
    $wuc->{'focus'}->{'data'}->{'block_features'} = $focus_set_blocks;
  }
  my $focus_set_wiggle = $object->get_focus_set_wiggle_features($object_slice);
  if ($focus_set_wiggle ) {
    $wuc->{'focus'}->{'data'}->{'wiggle_features'} = $focus_set_wiggle;
  }
  my $attribute_blocks = $object->get_nonfocus_block_features($object_slice);
  if ($attribute_blocks ) {
    $wuc->{'attribute'}->{'data'}->{'block_features'} = $attribute_blocks;
  }
  my $attribute_wiggle = $object->get_nonfocus_wiggle_features($object_slice);
  if ($attribute_wiggle ) {
    $wuc->{'attribute'}->{'data'}->{'wiggle_features'} = $attribute_wiggle;
  }



  my $image    = $self->new_image( $object_slice, $wuc,[$object->stable_id] );
      $image->imagemap           = 'yes';
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

return $image->render;
}

1;
