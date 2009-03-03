package EnsEMBL::Web::Component::Transcript::TranscriptNeighbourhood;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object   = $self->object;
  my $image_width  = $object->param( 'image_width' );
  my $context      = $object->param( 'context' );
  my $extent       = $context eq 'FULL' ? 1000 : $context;

  my $master_config = $object->get_imageconfig( "transview" );
     $master_config->set( '_settings', 'width',  $image_width );
  warn "CONF $master_config";

  my $transcript_slice = $object->Obj->feature_Slice;
     $transcript_slice = $transcript_slice->invert if $transcript_slice->strand < 1; ## Put back onto correct strand!
     $transcript_slice = $transcript_slice->expand( 10e3, 10e3 );
  my $wuc = $object->get_imageconfig( 'transview' );
     $wuc->{'_no_label'} = 'true';
     $wuc->{'_add_labels'} = 'true';
     $wuc->set( 'ruler', 'str', $object->Obj->strand > 0 ? 'f' : 'r' );
     $wuc->set( $object->default_track_by_gene,'display','on');

  my $image    = $self->new_image( $transcript_slice, $wuc, [] );
  return if $self->_export_image( $image );
     $image->imagemap = 'yes';

  return $image->render;
}

1;

