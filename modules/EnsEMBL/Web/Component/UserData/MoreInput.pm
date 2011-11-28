# $Id$

package EnsEMBL::Web::Component::UserData::MoreInput;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $species = $hub->param('species') || $hub->data_species;
  my $form    = $self->modal_form('more_input', $hub->species_path($species) . '/UserData/UploadFile/set_format', { wizard => 1 });

  $form->add_element(type => 'Hidden', name => 'code', value => $hub->param('code'));
  $form->add_element(type => 'Information',            value => 'Your file format could not be identified - please select an option:');
  $self->add_file_format_dropdown($form, 'upload');

  return $form->render;
}

1;
