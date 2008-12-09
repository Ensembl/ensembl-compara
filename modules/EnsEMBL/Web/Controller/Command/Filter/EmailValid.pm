package EnsEMBL::Web::Controller::Command::Filter::EmailValid;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

### Checks if an email address adheres to a valid format (no bogus characters!)

{

sub allow {
  my $self = shift;
  my $cgi = $self->action->cgi;
  my $email = $cgi->param('email');
  if ($email =~ /^[^@]+@[^@.:]+[:.][^@]+$/) { 
    return 1;
  } else {
    return 0;
  }
}

sub message {
  my $self = shift;
  my $ref = $ENV{'HTTP_REFERER'};
  return qq(Sorry, the email address you entered was not valid. Please try again.<br /><br /><a href="$ref" class="red-button">Back</a>);
}

}

1;
