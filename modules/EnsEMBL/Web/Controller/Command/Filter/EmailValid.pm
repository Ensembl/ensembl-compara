package EnsEMBL::Web::Controller::Command::Filter::EmailValid;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use CGI;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

### Checks if an email address adheres to a valid format (no bogus characters!)

{

sub allow {
  my ($self) = @_;
  my $cgi = new CGI;
  my $email = $cgi->param('email');
  if ($email =~ /^(\w|\-|\.)+\@(\w|\-|\.)+[a-zA-Z]{2,}$/) {
    return 1;
  } else {
    return 0;
  }
}

sub message {
  my $self = shift;
  return 'Sorry, the email address you entered was not valid. Please try again.';
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
