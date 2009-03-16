package EnsEMBL::Web::Component::UserData::ShowRemote;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Save source information to your account';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = $self->modal_form('show_remote', '/'.$object->data_species.'/UserData/SaveRemote', {'wizard' => 1});

  my $has_data = 0;
  my $das = $self->object->get_session->get_all_das;
  if ($das && keys %$das) {
    $has_data = 1;
    my $fieldset = { 'elements' => [ { 'type'=>'Information',
                                       'value' => 'Choose the DAS sources you wish to save to your account',
                                       'style' => 'spaced' } ] };
    $form->add_fieldset($fieldset);

    $fieldset = { 'layout' => 'table', 'elements' => [] };
    my @values;
    foreach my $source (sort { lc $a->label cmp lc $b->label } values %$das) {
      push @{ $fieldset->{'elements'} }, { 'type' => 'DASCheckBox', 'das'  => $source };
    }

    $form->add_fieldset($fieldset);
  }

  my @urls = $self->object->get_session->get_data(type => 'url');
  if (@urls) {
    $has_data = 1;
    $form->add_element('type'=>'Information', 'value' => "You have the following URL data attached:", 'style' => 'spaced');
    foreach my $url (@urls) {
      $form->add_element('type'=>'CheckBox', 'name' => 'code', 'value' => $url->{'code'}, 'label' => $url->{'name'}, 'notes' => $url->{'url'});
    }
  }

  unless ($has_data) {
    $form->add_element('type'=>'Information', 'value' => "You have no temporary data sources to save. Click on 'Attach DAS' or 'Attach URL' in the left-hand menu to add sources.");
  }

  return $form->render;
}

1;
