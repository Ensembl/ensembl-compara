package EnsEMBL::Web::Component::Regulation::FeatureDetails;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Regulation);


sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self = shift;
  my $object = $self->object; 
  my $Configs;

  my $context      = $object->param( 'context' ) || 200; 
  my $object_slice = $object->get_bound_context_slice($context);
     $object_slice = $object_slice->invert if $object_slice->strand < 1;

  my $wuc = $object->get_imageconfig( 'reg_detail' );
  $wuc->set_parameters({
    'container_width'   => $object_slice->length,
    'image_width',      => $self->image_width || 800,
    'slice_number',     => '1|1',
    'opt_highlight'    => $object->param('opt_highlight')
  });

  my $focus_set_blocks = $object->get_focus_set_block_features($object_slice);
  if ($focus_set_blocks ) {
    $wuc->{'focus'}->{'data'}->{'block_features'} = $focus_set_blocks;
  }

  if ($object->param('opt_focus') eq 'yes'){ 
    $wuc->modify_configs(
      [ 'reg_feats_core_MultiCell'],
      {qw(display compact)}
    );
    my ($focus_set_blocks, $colours) = $object->get_focus_set_block_features($object_slice);
    $wuc->{'data_by_cell_line'}{'MultiCell'}{'core'}{'block_features'} = $focus_set_blocks;
    $wuc->{'data_by_cell_line'}{'colours'} = $colours; 
  }

  my $image    = $self->new_image( $object_slice, $wuc,[$object->stable_id] );
      $image->imagemap           = 'yes';
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

return $image->render;
}

1;
