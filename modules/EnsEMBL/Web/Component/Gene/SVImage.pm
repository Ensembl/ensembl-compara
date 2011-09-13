package EnsEMBL::Web::Component::Gene::SVImage;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $slice  = $object->slice;
     $slice  = $slice->invert if $object->seq_region_strand < 0;
     
  # Get the web_image_config
  my $image_config = $object->get_imageconfig('gene_sv_view');
  
  $image_config->set_parameters({
    container_width => $slice->length,
    image_width     => $object->param('i_width') || $self->image_width || 800,
    slice_number    => '1|1',
  });
  
  # Transcript track
  my $key  = $image_config->get_track_key('transcript', $object);
  my $node = $image_config->get_node(lc $key);
  $node->set('display', 'transcript_label') if $node && $node->get('display') eq 'off';

  my $image = $self->new_image($slice, $image_config, [ $object->stable_id ]);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  return $image->render;
}

1;
