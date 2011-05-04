# $Id$

package EnsEMBL::Web::Component::Location::MultiIdeogram;

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $image_width = $self->image_width;
  my $i           = 1;
  my @images;
  
  foreach (@{$self->object->multi_locations}) {
    my $image_config      = $hub->get_imageconfig('chromosome', "chromosome_$i", $_->{'species'});
    my $chromosome        = $_->{'slice'}->adaptor->fetch_by_region(undef, $_->{'name'});
    my $annotation_status = $image_config->get_node('annotation_status');
    
    $image_config->set_parameters({
      container_width => $chromosome->seq_region_length,
      image_width     => $image_width,
      slice_number    => "$i|1",
      multi           => 1
    });
    
    if ($annotation_status) {
      $annotation_status->set('caption', '');
      $annotation_status->set('menu', 'no');
    };

    $image_config->get_node('ideogram')->set('caption', $_->{'short_name'});
    
    push @images, $chromosome, $image_config;
    $i++;
  }
  
  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'ideogram';
  
  return $image->render;
}

1;
