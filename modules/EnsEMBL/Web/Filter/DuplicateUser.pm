package EnsEMBL::Web::Filter::DuplicateUser;

use strict;

use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Filter);

### Checks if an email address is already registered

sub init {
  my $self = shift;
  
  $self->messages = {
    duplicate => 'Sorry, that email address is already registered.'
  };
}

sub catch {
  my $self = shift;
  
  $self->error_code = 'duplicate' if EnsEMBL::Web::Data::User->find(email => $self->hub->param('email'));
}

1;
