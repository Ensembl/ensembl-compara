package EnsEMBL::Web::Component::Location::MultiIdeogram;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

#use Data::Dumper;

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
  return 'Top Level';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;
  my $ploc = $object->[2][0];
  my $pslice = $ploc->slice;
  my $counter = 1;
  my $other_locs = $object->other_locations;
  my $max_count = @{$other_locs} + 1;
  my $species = $ploc->species;

  #add panel caption (displayed by ideogram glyphset) - go into factory ?
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

  my $pwuc = $object->image_config_hash( "chromosome_$counter", 'MultiIdeogram', $species );

  $pwuc->container_width( $pslice->seq_region_length );
  $pwuc->set_parameters({
    'container_width' => $object->seq_region_length,
    'image_width'     => $self->image_width,
    'slice_number'    => "1|$max_count",
  });

#  warn "1. ",$self->image_width;
#  warn "2. ",$object->param('image_width');

  #send panel name to the ideogram glyphset
  $pwuc->get_node('ideogram')->set('caption', $chr );

  my $images;
  push @$images, ( $pslice, $pwuc);

  #add secondary slices
  if (@{$other_locs}) {
    foreach my $loc ( @{$other_locs}) {
      $counter++;
      my $slice = $loc->{'slice'}; 
      my $species = $loc->{'real_species'};

      my $wuc = $object->image_config_hash( "chromosome_$counter", 'MultiIdeogram', $species );
      $wuc->container_width( $slice->seq_region_length );

      $wuc->set_parameters({
	'container_width' => $slice->seq_region_length,
	'image_width'     => $self->image_width,
	'slice_number'    => "$counter|$max_count",
      });
      $wuc->get_node('ideogram')->set('caption', $loc->{'short_name'} );
      push @$images, ( $slice, $wuc);
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
