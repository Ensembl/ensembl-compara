package EnsEMBL::Web::Component::Location::MultiBottom;

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
  return 'Detailed View';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;
  my $ploc = $object->[2][0];
  my $pslice = $ploc->slice;
  my $counter = 1;
  my $other_locs = $object->other_locations;
  my $base_url = $object->_url();
#  warn $base_url;
  my $max_count = @{$other_locs} + 1;
  my $pwuc = $object->image_config_hash( "contigviewbottom_$counter", 'MultiBottom', $ploc->species);
  $pwuc->set_parameters({
    'container_width' => $object->length,
    'image_width'     => $self->image_width,
    'slice_number'    => 0,
    'caption'         => $object->seq_region_type.' '.$object->seq_region_name,
    'multi'           => 1,
    'compara'         => 'primary',
    'base_url'        => $base_url,
  });
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
  $pwuc->get_node('scalebar')->set('caption', $chr );

  $pwuc->mult;
#  $ploc->slice->{_config_file_name_} = $loc->real_species;
  my $images = [];
  push @$images, ($pslice, $pwuc) unless ($max_count > 2);

  #add secondary slices
  if (@$other_locs) {
    foreach my $loc ( @{$other_locs}) {
      $counter++;
      my $slice = $loc->{'slice'};
      my $wuc = $object->image_config_hash( "contigview_bottom_$counter", 'MultiBottom', $loc->{'real_species'} );
      $wuc->set_parameters({
	'container_width' => $slice->length,
	'image_width'     => $self->image_width,
	'slice_number'    => $counter,
	'caption'         => $object->seq_region_type.' '.$object->seq_region_name,
	'multi'           => 1,
	'compara'         => 'secondary',
      });

      #add panel caption (displayed by scalebar glyphset)
      my $type = $slice->coord_system_name();
      my $chr = $slice->seq_region_name();
      my $chr_raw = $chr;
      unless( $chr =~ /^$type/i ) {
	$type = $SHORT{lc($type)} || ucfirst( $type );
	$chr = "$type $chr";
      }
      if( length($chr) > 9 ) {
	$chr = $chr_raw;
      }
      (my $abbrev = $loc->{'real_species'} ) =~ s/^(\w)\w+_(\w{3})\w+$/$1$2/g;
      $chr = "$abbrev $chr"; 
      $self->{'caption'} = $chr;
      $wuc->get_node('scalebar')->set('caption', $chr );

      $wuc->mult;
#      $loc->slice->{_config_file_name_} = $loc->{'real_species'};
      push @$images, ($slice, $wuc);
      push @$images, ($pslice, $pwuc) if ( ($max_count > 2) && ($counter < $max_count));
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
