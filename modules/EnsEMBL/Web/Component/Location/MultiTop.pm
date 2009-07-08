package EnsEMBL::Web::Component::Location::MultiTop;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

use Data::Dumper;

my %SHORT = qw(
  chromosome Chr.
  supercontig S'ctg
);

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
  my $pwuc = $object->image_config_hash( "contigviewtop_$counter", 'MultiTop',  $ploc->species);
  $pwuc->set_parameters({
    'container_width' => $new_pslice->length,
    'image_width'     => $self->image_width,
    'slice_number'    => "1|2",
   });
  my $images;
  #add panel caption (displayed by scalebar glyphset)
  my $type = $pslice->coord_system_name();
  my $chr = $pslice->seq_region_name();
  my $chr_raw = $chr;
  unless( $chr =~ /^$type/i ) {
    $type = $SHORT{lc($type)} || ucfirst( $type );
    $chr = "$type $chr";
  }
  if( length($chr) > 9 ) {
    $chr = $chr_raw;
  }
  (my $abbrev = $ploc->species ) =~ s/^(\w)\w+_(\w{3})\w+$/$1$2/g;
  $chr = "$abbrev $chr"; 
  $self->{'caption'} = $chr;
  $pwuc->get_node('ruler')->set('caption', $chr );
  push @$images, ($new_pslice, $pwuc);

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
	'slice_number'    => "$counter|2",
      });
      $wuc->get_node('ruler')->set('caption', $loc->{'short_name'});
      push @$images, ($new_slice, $wuc);
    }
  }

  my $image = $self->new_image( $images );
  return if $self->_export_image( $image );
  $image->imagemap = 'yes';
  $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  $image->{'panel_number'} = 'top';
  my $html = $image->render;
  return $html;
}

1;
