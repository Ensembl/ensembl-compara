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
  my $self = shift;
  my $hub  = $self->hub;

  my $form = EnsEMBL::Web::Form->new('rename_tempdata', $hub->species_path($hub->data_species).'/UserData/SaveTempData', 'post');

  my $tempdata = $hub->session->get_data('type' => $hub->param('type'), 'code' => $hub->param('code'));

  return unless $tempdata;

  $form->add_element(
    'type'  => 'String',
    'name'  => 'name',
    'label' => 'Name',
    'value' => $tempdata->{'name'},
  );
  $form->add_element(
    'type'  => 'Hidden',
    'name'  =>  'code',
    'value' => $hub->param('code'),
  );
  $form->add_element(
    'type'  => 'Hidden',
    'name'  =>  'type',
    'value' => $hub->param('type'),
  );
  ## navigation elements
  $form->add_element('type' => 'Submit', 'value' => 'Save');

  return $form->render;
}

1;
