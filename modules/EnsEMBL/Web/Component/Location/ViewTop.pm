package EnsEMBL::Web::Component::Location::ViewTop;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use EnsEMBL::Web::Proxy::Object;
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub _extra {
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;

  return if $object->param('panel_top') eq 'no';
  my $threshold = 1e6 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);

  my $slice = $object->slice;

  if( $object->length > $threshold ) {
    my $slice = $object->slice;
  } elsif( $object->seq_region_length < $threshold ) {
    $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
      $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
    );
    warn "... ".$object->seq_region_length.' ...';
  } else {
    my $c = int($object->centrepoint);
    my $s = $c - $threshold/2;
    $s = 1 if $s<1;
    my $e = $s + $threshold - 1;
    if( $e > $object->seq_region_length ) {
      $e = $object->seq_region_length;
      $s = $e - $threshold + 1;
    }
    warn "$s - $e..";
    $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
      $object->seq_region_type, $object->seq_region_name, $s, $e, 1
    );
  }
  my $length = $slice->end - $slice->start + 1;

  my $wuc = $object->image_config_hash( 'contigviewtop' );
  $wuc->set_parameters({
    'container_width' => $length,
    'image_width'     => $self->image_width,
    'slice_number'    => '1|2'
  });
  my $s_o = new EnsEMBL::Web::Proxy::Object( 'Location', {
    'seq_region_name'    => $slice->seq_region_name,
    'seq_region_type'    => $slice->coord_system->name(),
    'seq_region_start'   => $slice->start,
    'seq_region_end'     => $slice->end,
    'seq_region_strand'  => $slice->strand
  }, $object->__data );

  $self->_extra( $wuc, $slice );

  $wuc->_update_missing( $s_o  );
  my $image    = $object->new_image( $slice, $wuc, $object->highlights );
     $image->imagemap = 'yes';
     $image->{'panel_number'} = 'top';
     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return $image->render;
}

1;
