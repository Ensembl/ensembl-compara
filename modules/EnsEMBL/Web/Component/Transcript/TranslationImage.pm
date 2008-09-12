package EnsEMBL::Web::Component::Transcript::TranslationImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $transcript = $self->object;
  my $object     = $transcript->translation_object;
  my $wuc        = $object->get_userconfig( 'protview' );
     $wuc->set_parameters({
       'container_width' => $object->Obj->length,
       '_object'         => $object,
       'image_width'     => $self->image_width || 800,
       'slice_number'    => '1|1'
     });
  $transcript->timer_push( 'Cacheing object', 5);
     $wuc->cache( 'object',       $object );
  $transcript->timer_push( 'Cacheing snps', 5);
     $wuc->cache( 'image_snps',   $object->pep_snps );
  $transcript->timer_push( 'Cacheing splice sites', 5);
     $wuc->cache( 'image_splice', $object->pep_splice_site( $object->Obj ) );
  $transcript->timer_push( 'Cacheing dumping tree', 5);

  $wuc->tree->dump("Tree", '[[caption]]' );

  my $image    = $transcript->new_image( $object->Obj, $wuc, [] );
     $image->imagemap = 'yes';
     $image->{'panel_number'} = 'translation';
     $image->set_button( 'drag', 'title' => 'Drag to select region' );
  warn "IN IMAGE RENDER";
  return $image->render;
  warn "OUT OF IMAGE RENDER";
}

1;

