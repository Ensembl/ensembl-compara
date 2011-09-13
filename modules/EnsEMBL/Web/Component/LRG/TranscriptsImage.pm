package EnsEMBL::Web::Component::LRG::TranscriptsImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::LRG);

sub _init { 
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub caption { return 'Transcripts'; }

sub content {
  my $self         = shift;
  my $object       = $self->object;
  my $slice        = $object->Obj;
  my $gene         = $object->gene;
  my $image_config = $object->get_imageconfig('lrg_summary');
  
  $image_config->set_parameters({
    container_width => $slice->length,
    image_width     => $self->image_width || 800,
    slice_number    => '1|1'
  });
  
  my $image = $self->new_image($slice, $image_config, [ $gene->stable_id ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  my $html = $image->render;
  $html   .= $self->_info(
    'Configuring the display',
    '<p>Tip: use the "<strong>Configure this page</strong>" link on the left to show additional data in this region.</p>'
  );
  
  return $html;
}

1;
