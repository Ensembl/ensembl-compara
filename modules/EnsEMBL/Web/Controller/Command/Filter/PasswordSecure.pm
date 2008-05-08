package EnsEMBL::Web::Controller::Command::Filter::PasswordSecure;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use CGI;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

### Checks if a password is strong enough to satisfy minimum security standards
### Also, expects two copies of the password and checks they are identical

{

sub allow {
  my ($self) = @_;
  my $cgi = new CGI;
  my $password_1 = $cgi->param('new_password_1');
  my $password_2 = $cgi->param('new_password_2');

  if ($password_1 eq $password_2) {
    if (length($password_1) > 5 && $password_1 =~ /[a-zA-Z]+/ && $password_1 =~ /[0-9]+/) {
      return 1;
    } else {
      return 0;
    }
  }
  else {
    return 0;
  }
}

sub message {
  my $self = shift;
  return 'Sorry, your passwords did not match or were insecure. Passwords should be at 
  least 6 characters long and include both letters and numbers.';
}

}

1;
