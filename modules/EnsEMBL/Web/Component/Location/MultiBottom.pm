package EnsEMBL::Web::Component::Location::MultiBottom;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my $slice = $object->slice;
  my $image_width = $self->image_width;
  my $slices = $object->multi_locations;
  my $max = scalar @$slices;
  my $i = 1;
  my @images;
  my $primary_image_config;
  
  my $base_url = $object->_url($object->multi_params);
  
  foreach (@$slices) {
    my $image_config = $object->image_config_hash('contigview_bottom_' . $i, 'MultiBottom', $_->{'species'});
    
    $image_config->set_parameters({
      container_width => $_->{'slice'}->length,
      image_width     => $image_width,
      slice_number    => "$i|3",
      caption         => $object->seq_region_type . ' ' . $object->seq_region_name,
      multi           => 1,
      compara         => $i == 1 ? 'primary' : 'secondary',
      base_url        => $base_url
    });
    
    $image_config->get_node('scalebar')->set('caption', $_->{'short_name'});
    $image_config->mult;
    
    if ($i == 1) {
      $primary_image_config = $image_config;
      push @images, $slice, $primary_image_config unless $max > 2;
    } else {
      push @images, $_->{'slice'}, $image_config;
      push @images, $slice, $primary_image_config if $max > 2 && $i < $max;
    }
    
    $i++;
  }
  
  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'bottom';
  
  my $html = $image->render;
  
  $html .= $self->_info(
    'Configuring the display',
    '<p>To change the tracks you are displaying, use the "<strong>Configure this page</strong>" link on the left.</p>'
  );
  
  return $html;
}

1;
