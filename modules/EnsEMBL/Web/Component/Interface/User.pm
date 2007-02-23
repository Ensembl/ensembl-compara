package EnsEMBL::Web::Component::Interface::User;

### Module to create custom forms for the User modules

use EnsEMBL::Web::Component::Interface;
use EnsEMBL::Web::Form;

our @ISA = qw( EnsEMBL::Web::Component::Interface);
use strict;
use warnings;
no warnings "uninitialized";

sub confirm_form {
  ### Builds an partially-populated HTML form
  my($panel, $object) = @_;

  my $primary_key = $panel->interface->data->get_primary_key;
  my $id = $object->param($primary_key);
  if ($id) {
    $panel->interface->data->populate($id);
  }

  my $script = EnsEMBL::Web::Component::Interface::script_name($panel, $object);

  my $form = EnsEMBL::Web::Form->new('confirm', "/common/$script", 'post');

  $form->add_element(
          'type'  => 'NoEdit',
          'name'  => 'name',
          'label' => 'Name',
          'value' => $panel->interface->data->name,
        );
  $form->add_element(
          'type'  => 'NoEdit',
          'name'  => 'email',
          'label' => 'Email',
          'value' => $panel->interface->data->email,
        );
  $form->add_element(
          'type'  => 'NoEdit',
          'name'  => 'organisation',
          'label' => 'Organisation',
          'value' => $panel->interface->data->organisation,
        );
  $form->add_element(
          'type'  => 'String',
          'name'  => 'salt',
          'label' => 'Activation Code',
          'value' => '',
        );
  $form->add_element(
          'type'  => 'Password',
          'name'  => 'password',
          'label' => 'Password',
        );
  $form->add_element(
          'type'  => 'Password',
          'name'  => 'confirm_password',
          'label' => 'Confirm Password',
        );
  $form->add_element(
          'type'  => 'Hidden',
          'name'  => $primary_key,
          'value' => $id,  
        );

  ## navigation elements
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
    $html .= qq(<p>Before you can start using your Ensembl user account, you need to validate your email address. We've just send you an email containing an activation code. Enter this code below, and choose a password. You'll need to use this password each time you log in to Ensembl.</p>
<p><strong>Important note:</strong> If you do not receive your activation email within the next few 
hours, please check your spam filter or <a href="/common/helpview?node=hv_contact">contact Helpdesk</a></p>
);
  }
  $html .= EnsEMBL::Web::Component::Interface::_render_form($panel, 'confirm');
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

sub password_error {
  my( $panel, $user) = @_;
  my $error = $user->param('error');
  my $html;

  if ($error eq 'mismatch') {
    $html = qq(<h3 class="plain">Password Mismatch</h3>
<p>Sorry - you entered two different passwords!</p>);
  }
  else {
    $html = qq(<h3 class="plain">Insecure Password</h3>
<p>The password you entered was too short or too simple. For security, please ensure that your
password is more than 6 characters long and contains both letters and numbers.</p>);
  }
  $html .= qq(<p>Please click on the Back button and try again.</p>);

  $panel->print($html);
}

sub failed_activation {
  my( $panel, $user) = @_;
  my $error = $user->param('error');
  my $id = $user->id;
  my $html;
  if ($error eq 'cookie_not_set') {
    $html = qq(
<h3 class="plain">Could not set cookie</h3>
<p>Sorry, we could not set a cookie to log you in. Please check your browser settings, then
click on the Back button to try again.</p>
);
  }
  else {
    $html = qq(
<h3 class="plain">Database problem</h3>
<p>Sorry, we were unable to activate your user account. Please try again
later, as it may simply be that our servers are very busy right now.</p>

<p>If you continue to have problems, please <a href="/common/helpview?node=hv_contact">contact Helpdesk</a>.</p>

);
  }
  $panel->print($html);
}


1;
