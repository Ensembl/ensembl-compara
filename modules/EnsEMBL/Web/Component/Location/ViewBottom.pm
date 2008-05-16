package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}


sub content {
  my $self   = shift;
  my $object = $self->object;

  my $threshold = 1e6 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  if( $object->length > $threshold ) {
    return "<p>This slice is too long to view in contigview...</p>";
  }

  my $slice = $object->slice;
  my $length = $slice->end - $slice->start + 1;

  my $wuc = $object->user_config_hash( 'contigviewbottom' );
     $wuc->container_width( $length );
     $wuc->set_width(       $object->param('image_width') );

  my $image    = $object->new_image( $slice, $wuc, $object->highlights );
     $image->imagemap = 'yes';

     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return $image->render;
}


1;
