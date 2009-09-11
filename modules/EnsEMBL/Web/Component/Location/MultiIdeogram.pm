package EnsEMBL::Web::Component::Location::MultiIdeogram;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my $image_width = $self->image_width;
  my $i = 1;
  my @images;
  
  my $slices = $object->multi_locations;
  
  foreach (@$slices) {
    my $image_config = $object->image_config_hash('chromosome_' . $i, 'MultiIdeogram', $_->{'species'});
    my $chromosome = $_->{'slice'}->adaptor->fetch_by_region(undef, $_->{'name'});
    
    $image_config->set_parameters({
      container_width => $chromosome->seq_region_length,
      image_width     => $image_width,
      slice_number    => "$i|1",
      multi           => 1
    });
    
    $image_config->get_node('ideogram')->set('caption', $_->{'short_name'});
    
    push @images, $chromosome, $image_config;
    $i++;
  }
  
  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'ideogram';
  
  my $html = $image->render;
  
  return $html;
}

1;
