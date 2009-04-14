package EnsEMBL::Web::Component::Transcript::UserAnnotation;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return 'Annotation';
}

sub content {
  my $self = shift;
  my $html;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  if ($user) {
    my $id = $self->object->param('t');
    my $type = 'Transcript';
    my $species = $self->object->species;

    my @annotations = $user->annotations;
    my $annotation;
    foreach my $record (@annotations) {
      next unless $record->stable_id eq $id;
      $annotation = $record;
      last;
    }
    if ($annotation) {
      $html = '<h2>'.$annotation->title.'</h2><pre>'.$annotation->annotation.'</pre>';
      $html .= qq(<p><a href="/Account/Annotation/Edit?id=).$annotation->id.qq(;species=$species" class="modal_link">Edit this annotation</a>.</p>);
    }
    else {
      $html = qq(<p>You don't have any annotation on this transcript. <a href="/Account/Annotation/Add?stable_id=$id;ftype=$type;species=$species" class="modal_link">Add an annotation</a>.</p>);
    }
  }
  else {
    $html = $self->_info('User Account', 'You need to be logged in to save your own annotation');
  }

  return $html;
}

1;
