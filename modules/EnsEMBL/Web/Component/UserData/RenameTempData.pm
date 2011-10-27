# $Id$

package EnsEMBL::Web::Component::UserData::RenameTempData;

use strict;

use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $form   = $self->new_form({ action => $hub->url({ action => 'ModifyData', function => 'rename_session_record' }, 1)->[0], method => 'post' });
  my $type   = $hub->param('source') eq 'url' ? 'url' : 'upload';
  my $record = $hub->session->get_data(type => $type, code => $hub->param('code'));

  return unless $record;

  $form->add_element(
    type  => 'String',
    name  => 'name',
    label => 'Name',
    value => $record->{'name'},
  );
  
  $form->add_element(
    type  => 'Hidden',
    name  => 'code',
    value => $hub->param('code'),
  );
  
  $form->add_element(
    type  => 'Hidden',
    name  => 'source',
    value => $type,
  );
  
  $form->add_element(type => 'Submit', value => 'Save');

  return $form->render;
}

1;
