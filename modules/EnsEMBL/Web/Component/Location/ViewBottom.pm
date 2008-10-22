package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use Time::HiRes qw(time);
use EnsEMBL::Web::RegObj;
use Bio::EnsEMBL::ExternalData::DAS::Coordinator;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->configurable(  1 );
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $threshold   = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $image_width = $self->image_width;

  if( $object->length > $threshold ) {
    return $self->_warning( 'Region too large','
  <p>
    The region selected is too large to display in this view - use the navigation above to zoom in...
  </p>' );
  }

  my $slice = $object->slice;
  my $length = $slice->end - $slice->start + 1;
  my $T = time;
  my $wuc = $object->image_config_hash( 'contigviewbottom' );
  $T = sprintf "%0.3f", time - $T;
  $wuc->tree->dump("View Bottom configuration [ time to generate $T sec ]", '([[caption]])');

  $wuc->set_parameters({
    'container_width' => $length,
    'image_width'     => $image_width || 800, ## hack at the moment....
    'slice_number'    => '1|3',
  });

## Lets see if we have any das sources....
  my @das_nodes = map { $_->get('glyphset') eq '_das' && $_->get('display') ne 'off' ? @{ $_->get('logicnames')||[] } : () }  $wuc->tree->nodes;
  if( @das_nodes ) {
    my %T         = %{ $ENSEMBL_WEB_REGISTRY->get_all_das( $object->species ) || {}  };
    my @das_sources = @T{ @das_nodes };
    if( @das_sources ) {
      my $das_co = Bio::EnsEMBL::ExternalData::DAS::Coordinator->new(
        -sources => \@das_sources,
        -proxy   => $object->species_defs->ENSEMBL_WWW_PROXY,
        -noproxy => $object->species_defs->ENSEMBL_NO_PROXY,
        -timeout => $object->species_defs->ENSEMBL_DAS_TIMEOUT
      );
      $wuc->cache( 'das_coord', $das_co );
    }
  } 
  
#  warn "DAS SOURCES @das_sources";
  
  $wuc->_update_missing( $object );
  my $image    = $object->new_image( $slice, $wuc, $object->highlights );
     $image->{'panel_number'} = 'bottom';
     $image->imagemap = 'yes';

     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return $image->render;
}


1;
