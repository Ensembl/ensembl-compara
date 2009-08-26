package EnsEMBL::Web::Component::Regulation::FeatureSummary;

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

  my $object_slice = $object->get_context_slice(25000);
     $object_slice = $object_slice->invert if $object_slice->strand < 1; 


  my $fsets = $object->get_feature_sets;

  my $wuc = $object->get_imageconfig( 'reg_summary' ); 
  $wuc->cache( 'feature_sets', $fsets);

  $wuc->set_parameters({
    'container_width'   => $object_slice->length,
    'image_width',      => $self->image_width || 800,
    'slice_number',     => '1|1',
  });


  my $image    = $self->new_image( $object_slice, $wuc, [$object->stable_id] );
      $image->imagemap           = 'yes';
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

  return $image->render;
}

1;
