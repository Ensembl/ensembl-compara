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
  my $object = $transcript->translation_object;
  warn $object;
  my $peptideid = $object->stable_id;
  my $db        = $object->get_db ;
  my $wuc       = $object->get_userconfig( 'protview' );
  $wuc->container_width( $object->Obj->length );
  $wuc->{_object} = $object;
  my $image_width = $wuc->get('_settings', 'width');

#  my $das_collection = $object->get_DASCollection();
#  foreach my $das( @{$das_collection->Obj} ){
#    next unless $das->adaptor->active;
#   $das->adaptor->maxbins($image_width) if ($image_width);
#    my $source = $das->adaptor->name();
#    my $color  = $das->adaptor->color() || 'black';
#    my $src_label  = $das->adaptor->label() || $source;
#    $wuc->das_sources( { "genedas_$source" => { on=>'on', col=>$color, label=> $src_label, manager=>'Pprotdas' } } );
#  }


  $object->Obj->{'image_snps'}   = $object->pep_snps;
  $object->Obj->{'image_splice'} = $object->pep_splice_site( $object->Obj );

  my $image                      = $object->new_image( $object->Obj, $wuc, [], 1 ) ;
     $image->imagemap            = 'yes';

  warn "WC $wuc"; 


return $image->render;
}

1;

