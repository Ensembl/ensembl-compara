# $Id$

package EnsEMBL::Web::Component::Account::Login;

### Module to create user login form 

use strict;

use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $form     = $self->new_form({ id => 'login', action => $hub->url({ action => 'SetCookie' }) });
  my $fieldset = $form->add_fieldset;
  
  $fieldset->add_hidden([
    { name => 'url',   value => $hub->param('url')   },
    { name => 'popup', value => $hub->param('popup') },
    { name => 'next',  value => $hub->param('next')  },
  ]);

  $fieldset->add_field([
    { type => 'Email',    name => 'email',    label => 'Email',     required => 'yes'     },
    { type => 'Password', name => 'password', label => 'Password',  required => 'yes'     },
    { type => 'Submit',   name => 'submit',   value => 'Log in',    class => 'cp-refresh' }
  ]);
  
  $fieldset->add_notes(sprintf(
    '<p><a href="%s" class="modal_link">Register</a> | <a href="%s" class="modal_link">Lost password</a></p>',
    $hub->url({ action => 'User', function => 'Add' }),
    $hub->url({ action => 'LostPassword' }),
  ));

  return $form->render;
}

1;
