package EnsEMBL::Web::Component::Location::MultiBottom;

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
  return 'Detailed View';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;
  my $ploc = $object->[2][0];
  my $pslice = $ploc->slice;
  my $counter = 1;
  my $max_count = @{$object->[2][1]} + 1;
  my $pwuc = $object->image_config_hash( "contigviewbottom_$counter", 'MultiBottom');
  $pwuc->set_parameters({
    'container_width' => $object->seq_region_length,
    'image_width'     => $self->image_width,
    'slice_number'    => "1|$max_count",
    'caption'         => $object->seq_region_type.' '.$object->seq_region_name,
     });
  my $images;
  push @$images, ($pslice, $pwuc) unless ($max_count > 2);

  foreach my $loc ( @{$object->[2][1]}) {
    $counter++;
    my $slice = $loc->{'slice'};
    my $wuc = $object->image_config_hash( "contigview_bottom_$counter", 'MultiBottom',$ploc->{'real_species'} );
    $wuc->set_parameters({
      'container_width' => $slice->seq_region_length,
      'image_width'     => $self->image_width,
      'slice_number'    => "$counter|$max_count",
      'caption'         => $object->seq_region_type.' '.$object->seq_region_name,
    });
    push @$images, ($slice, $wuc);
    push @$images, ($pslice, $pwuc) if ($max_count > 2);
    $counter++;
  }
  my $image = $self->new_image( $images );
  $image->imagemap = 'yes';
  $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return if $self->_export_image( $image );
  $html .= $image->render;
  return $html;
}

1;
