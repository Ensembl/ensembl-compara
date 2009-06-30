package EnsEMBL::Web::Component::Location::MultiIdeogram;

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
  return 'Top Level';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;
  $Data::Dumper::Maxdepth = 2;
  my $ploc = $object->[2][0];
  my $pslice = $ploc->slice;
#  warn Dumper($pslice);
  my $counter = 1;
  my $max_count = @{$object->[2][1]} + 1;
  my $wuc = $object->image_config_hash( "chromosome_$counter","MultiIdeogram");
  warn ref($wuc);
  $wuc->set_parameters({
    'container_width' => $object->seq_region_length,
    'image_width'     => $self->image_width,
    'slice_number'    => "1|$max_count",
    'caption'         => $object->seq_region_type.' '.$object->seq_region_name,
     });

  my $image    = $self->new_image( $pslice, $wuc );
#  warn Dumper($image);
  return if $self->_export_image( $image );

#  $image->{'panel_number'} = 'ideogram1';
  $image->imagemap = 'yes';
  $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  $html = '<p>.</p>'.$image->render;

  foreach my $loc ( @{$object->[2][1]}) {
    $counter++;
    my $slice = $loc->{'slice'};
    my $wuc = $object->image_config_hash( "chromosome_$counter", 'MultiIdeogram',$ploc->{'real_species'} );
    $wuc->set_parameters({
      'container_width' => $slice->seq_region_length,
      'image_width'     => $self->image_width,
      'slice_number'    => "$counter|$max_count",
      'caption'         => $object->seq_region_type.' '.$object->seq_region_name,
    });
    my $image = $self->new_image( $slice, $wuc );
    $image->imagemap = 'yes';
    $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );

    $html .= $image->render;
    $counter++;
  }
  return $html;
}

1;
