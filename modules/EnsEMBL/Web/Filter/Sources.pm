package EnsEMBL::Web::Filter::Sources;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Filter);

### Checks if the user has actually selected one or more DAS sources

sub init {
  my $self = shift;
  
  $self->messages = {
    none => 'No sources selected.'
  };
}

sub catch {
  my $self = shift;
  
  $self->redirect = '/UserData/SelectDAS';
  
  # Process any errors
  if (!$self->hub->param('dsn')) {
    $self->error_code = 'none'; # Store the server's message in the session
  }
}

1;
