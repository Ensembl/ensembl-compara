package EnsEMBL::Web::Component::Location::MultiTop;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

use Data::Dumper;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  my $self = shift;
  return 'Navigational Overview';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;
  my $ploc = $object->[2][0];
  my $pslice = $ploc->slice; #slice for region in detail

  #get a slice corresponding to the region to be shown for Navigational Overview
  my $new_length = 1000000;
  my $length = $pslice->length;
  my $to_add = int(($new_length - $length) / 2);
  my $new_pslice = $pslice->expand($to_add,$to_add);
  my $counter = 1;
  my $other_locs = $object->other_locations;
  my $max_count = @{$other_locs} + 1;
  my $wuc = $object->image_config_hash( "contigviewtop_$counter", 'MultiTop',  $ploc->species);
  $wuc->set_parameters({
    'container_width' => $new_pslice->length,
    'image_width'     => $self->image_width,
    'slice_number'    => "1|$max_count",
    'caption'         => $object->seq_region_type.' '.$object->seq_region_name,
  });
  my $images;
  push @$images, ($new_pslice, $wuc);

  #add secondary slices
  if (@$other_locs) {
    foreach my $loc ( @{$other_locs} ) {
      $counter++;
      my $slice = $loc->{'slice'};
      my $length = $slice->length;
      my $to_add = ($new_length - $length) / 2;
      my $new_slice = $slice->expand($to_add,$to_add);
      my $wuc = $object->image_config_hash( "contigviewtop_$counter", 'MultiTop', $loc->{'real_species'} );
      $wuc->set_parameters({
	'container_width' => $new_slice->length,
	'image_width'     => $self->image_width,
	'slice_number'    => "$counter|$max_count",
	'caption'         => $object->seq_region_type.' '.$object->seq_region_name,
      });
      push @$images, ($new_slice, $wuc);
      $counter++;
    }
  }

  my $image = $self->new_image( $images );
  $image->imagemap = 'yes';
  $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return if $self->_export_image( $image );
  $html .= $image->render;
  return $html;
}

1;
