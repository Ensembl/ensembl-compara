package EnsEMBL::Web::Component::Interface::User;

### Module to create custom forms for the User modules

use EnsEMBL::Web::Component::Interface;
use EnsEMBL::Web::Form;

our @ISA = qw( EnsEMBL::Web::Component::Interface);
use strict;
use warnings;
no warnings "uninitialized";

sub confirm_form {
  ### Builds an HTML form populated with a database record
  my($panel, $object) = @_;

  my $primary_key = $panel->interface->data->get_primary_key;
  my $id = $object->param($primary_key);
  
  my $form = _data_form($panel, $object, 'confirm');
  $form->add_element(
          'type'  => 'Hidden',
          'name'  => $primary_key,
          'value' => $id,  
        );

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => 'db_action', 'value' => 'save');
  $form->add_element( 'type' => 'Hidden', 'name' => 'dataview', 'value' => 'activate');
  $form->add_element( 'type' => 'Submit', 'value' => 'Activate');
  return $form ;
}

sub confirm {
  ### Panel rendering for edit_form
  my($panel, $object) = @_;
  my $html;
  if ($object->param('code')) {
    $html .= qq(<p><strong>Thanks for confirming your email address.</strong></p><p>To start using your new Ensembl user account, just choose a password below. You'll need to use this password each time you log in to Ensembl.</p>);
  }
  else {
    $html .= qq(<p>Before you can start using your Ensembl user account, you need to validate your email address. We've just send you an email containing an activation code. Enter this code below, and choose a password. You'll need to use this password each time you log in to Ensembl.</p>);
  }
  $html .= _render_form($panel, 'confirm');
  $panel->print($html);
}

sub failed_registration {
  my( $panel, $user) = @_;
  my $error = $user->param('error');
  my $html;
  if ($error eq 'duplicate') {
    $html = qq(
<h3 class="plain">Account already exists</h3>
<p>There is already an account using that email address. Please choose a different address, and try again. Alternatively, if you have already registered and have forgotten your password, you can <a href='/forgotten.html'>reset it</a>.</p>
<p><a href="/common/register">&larr; Try again</a></p>
<p>If you continue to have problems, please <a href="/common/helpview?node=hv_contact">contact Helpdesk</a>.</p>

);
  }
  else {
    $html = qq(
<h3 class="plain">Database problem</h3>
<p>Sorry, we were unable to register your user account. Please <a href="/common/register">try again</a>
later, as it may simply be that our servers are very busy right now.</p>

<p>If you continue to have problems, please <a href="/common/helpview?node=hv_contact">contact Helpdesk</a>.</p>

);
  }
  $panel->print($html);
}

sub failed_activation {
  my( $panel, $user) = @_;
  my $html = qq();
  $panel->print($html);
}

1;
