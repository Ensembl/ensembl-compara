package EnsEMBL::Web::Filter::Activation;

### Checks if a given activation code matches the value stored in the database

use strict;

use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Filter);

sub init {
  my $self = shift;
  
  $self->messages = {
    invalid => 'Sorry, your activation details could not be validated. Please check your activation link, or <a href="/Help/Contact" class="popup">contact our Helpdesk</a> for assistance.'
  };
}


sub catch {
  my $self   = shift;
  my $hub = $self->hub;
  my $user   = EnsEMBL::Web::Data::User->find(email => $hub->param('email'));
  my $code;

  if ($user) {
    $code = $hub->param('code');
    $code =~ s/[^\w]//g; # Strip all the non \w chars
  }
  
  $self->error_code = 'invalid' if !$user || $user->salt ne $code;
}

1;
