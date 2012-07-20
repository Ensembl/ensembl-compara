package EnsEMBL::Web::Component::Gene::UserAnnotation;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $user = $object->user;
  my $html;  
  
  if ($user) {
    my $id = $object->param('g');
    my $type = 'Gene';
    my $species = $object->species;

    my @annotations = $user->annotations;
    my @gene_annotations;
    foreach my $record (@annotations) {
      next unless $record->stable_id eq $id;
      push @gene_annotations, $record;
    }
    if (scalar(@gene_annotations)) {
      foreach my $annotation (@gene_annotations) {
        $html = '<h2>'.$annotation->title.'</h2><pre>'.$annotation->annotation.'</pre>';
        $html .= qq(<p><a href="/Account/Annotation/Edit?id=).$annotation->id.qq(;species=$species" class="modal_link">Edit this annotation</a>.</p>);
      }
    }
    else {
      $html = qq(<p>You don't have any annotation on this gene. <a href="/Account/Annotation/Add?stable_id=$id;ftype=$type;species=$species" class="modal_link">Add an annotation</a>.</p>);
    }
  }
  else {
    $html = $self->_info('User Account', '<p>You need to be logged in to save your own annotation</p>');
  }

  return $html;
}

1;
