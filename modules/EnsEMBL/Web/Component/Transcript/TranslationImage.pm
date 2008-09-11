package EnsEMBL::Web::Component::Transcript::TranslationImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Component);

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
     $wuc->cache( 'object',       $object );
     $wuc->cache( 'image_snps',   $object->pep_snps );
     $wuc->cache( 'image_splice', $object->pep_splice_site( $object->Obj ) );

  $wuc->tree->dump("Tree", '[[caption]]' );

  my $image    = $transcript->new_image( $object->Obj, $wuc, [] );
     $image->imagemap = 'yes';
     $image->{'panel_number'} = 'translation';
     $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return $image->render;
}

1;

