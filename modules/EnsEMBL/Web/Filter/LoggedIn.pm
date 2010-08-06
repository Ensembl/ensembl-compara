package EnsEMBL::Web::Filter::LoggedIn;

use strict;

use base qw(EnsEMBL::Web::Filter);

sub init {
  my $self = shift;
  
  $self->redirect = '/Account/Login';
  $self->messages = {
    not_logged_in => 'You must be logged in to view this page.'
  };
}


sub catch {
  my $self = shift;
  my $user = $self->hub->user;
  
  $self->error_code = 'not_logged_in' unless $user;
}

1;
