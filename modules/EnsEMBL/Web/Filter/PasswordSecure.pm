package EnsEMBL::Web::Filter::PasswordSecure;

use strict;

use base qw(EnsEMBL::Web::Filter);

### Checks if a password is strong enough to satisfy minimum security standards
### Also, expects two copies of the password and checks they are identical

sub init {
  my $self = shift;
  
  $self->messages = {
    insecure => 'Passwords must be at least 6 characters long and include both letters and numbers.',
    mismatch => 'Sorry, your passwords did not match. Please try again.'
  };
}

sub catch {
  my $self = shift;
  
  $self->redirect = '/Account/Password';
  
  my $hub     = $self->hub;
  my $password_1 = $hub->param('new_password_1');
  my $password_2 = $hub->param('new_password_2');

  if ($password_1 eq $password_2) {
    $self->error_code = 'insecure' unless length $password_1 > 5 && $password_1 =~ /[a-zA-Z]+/ && $password_1 =~ /[0-9]+/;
  } else {
    $self->error_code = 'mismatch';
  }
}

1;
