package EnsEMBL::Web::Filter::EmailAddress;

use strict;

use base qw(EnsEMBL::Web::Filter);

### Checks if an email address adheres to a valid format (no bogus characters!)

sub init {
  my $self = shift;
  
  $self->messages = {
    empty         => 'Please supply an email address',
    invalid_email => 'Sorry, the email address you entered was not valid. Please try again.'
  };
}

sub catch {
  my $self  = shift;
  my $email = $self->hub->param('email');
  
  if (!$email) {
    $self->error_code = 'empty';
  } elsif ($email !~ /^[^@]+@[^@.:]+[:.][^@]+$/) { 
    $self->error_code = 'invalid_email';
  }
}

1;
