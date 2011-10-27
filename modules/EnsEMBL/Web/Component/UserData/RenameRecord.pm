# $Id$

package EnsEMBL::Web::Component::UserData::RenameRecord;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $form     = $self->new_form({ action => $hub->url({ action => 'ModifyData', function => 'rename_user_record' }, 1)->[0], method => 'post' });
  my $user     = $hub->user;
  my $method   = $hub->param('source') eq 'url' ? 'urls' : 'uploads';
  my $id       = $hub->param('id');
  my ($record) = $user->$method($id);
  
  return unless $record;

  $form->add_element(
    type  => 'String',
    name  => 'name',
    label => 'Name',
    value => $record->name,
  );
  
  $form->add_element(
    type  => 'Hidden',
    name  => 'id',
    value => $id,
  );
  
  $form->add_element(
    type  => 'Hidden',
    name  => 'source',
    value => $method,
  );
  
  $form->add_element(type => 'Submit', value => 'Save');

  return $form->render;
}

1;
