package EnsEMBL::Web::Component::Interface::Account;

### Module to create custom forms for the Account modules

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component::Interface);

sub add_form {
  ### Builds an empty HTML form for a new record
  my($panel, $object) = @_;
  my $script = $object->script;
  if ($panel->interface->script_name) {
    $script = $panel->interface->script_name;
  }
  my $form = EnsEMBL::Web::Form->new('add', $script, 'post');

  ## form widgets
  my ($key) = $panel->interface->data->primary_columns;
  my $id = $object->param($key) || $object->param('id');
  if ($id) {
    #$panel->interface->data->populate($id);
  } else {
    $panel->interface->cgi_populate($object);
  }
  my @widgets = @{$panel->interface->edit_fields($object)};

  foreach my $element (@widgets) {
    $form->add_element(%$element);
  }
  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => 'prev_action', 'value' => 'Save Record');
  $form->add_element( 'type' => 'Hidden', 'name' => 'mode', 'value' => 'add');
  $form->add_element( 'type' => 'Hidden', 'name' => 'db_action', 'value' => 'save');
  $form->add_element( 'type' => 'Hidden', 'name' => 'dataview', 'value' => 'check_input');
  $form->add_element( 'type' => 'Submit', 'value' => 'Next');

  return $form ;
}

sub duplicate {
  my($panel, $object) = @_;
  my $html = '<p>Sorry, you appear to have registered already. If you have lost your password, we can send you a reactivation link to <a href="/Account/LostPassword">your registered email address</a>.</p>';    
  $panel->print($html);
  return 1;
}

1;
