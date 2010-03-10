package EnsEMBL::Web::Component::Gene::RegulationImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content { 
  my $self = shift;
  my $object = $self->object; 
  my $extended_slice = $object->get_extended_reg_region_slice;
  my $offset = $extended_slice->start -1;
  my $fsets = $object->feature_sets;
  my $trans = $object->get_all_transcripts;
  my $gene_track_name =$trans->[0]->default_track_by_gene;

  my $wuc = $object->get_imageconfig( 'generegview' );
 
 $wuc->set_parameters({
       'container_width'   => $extended_slice->length,
       'image_width',      => $self->image_width || 800,
     });

  ## We now need to select the correct track to turn on....

  my $key = $wuc->get_track_key( 'transcript', $object );
  ## Then we turn it on....
  $wuc->modify_configs( [$key], {qw(display transcript)} );
  $wuc->cache( 'feature_sets', $fsets);  
  $wuc->cache('gene', $object);
  
  my $image    = $self->new_image( $extended_slice, $wuc, [] );
      $image->imagemap           = 'yes';
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

return $image->render;
}

1;
