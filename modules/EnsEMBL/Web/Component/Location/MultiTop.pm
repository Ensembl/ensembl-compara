package EnsEMBL::Web::Component::Location::MultiTop;

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
  my $expansion = 1e6 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1); # get a slice corresponding to the region to be shown for Navigational Overview
  my $image_width = $self->image_width;
  my $i = 1;
  my @images;
  
  foreach (@{$object->multi_locations}) {
    my $slice = $_->{'slice'};
    my $expand = ($expansion - $slice->length) / 2;
    my $l = $_->{'start'} - $expand < 1 ? $_->{'start'} : $expand;
    my $r = $_->{'end'} + $expand > $_->{'length'} ? $_->{'length'} - $_->{'end'} : $expand;
    
    $l += $expand - $r if $r < $expand;
    $r += $expand - $l if $l < $expand;
    
    $slice = $slice->expand($l, $r) if $expand > 0 && $_->{'length'} > $expansion;
    
    my $image_config = $object->image_config_hash('contigviewtop_' . $i, 'MultiTop', $_->{'species'});
    
    $image_config->set_parameters({
      container_width => $slice->length,
      image_width     => $image_width,
      slice_number    => "$i|2",
      multi           => 1
    });
    
    $image_config->get_node('ruler')->set('caption', $_->{'short_name'});
    
    push @images, $slice, $image_config;
    $i++;
  }

  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'top';
  
  my $html = $image->render;
  
  return $html;
}

1;
