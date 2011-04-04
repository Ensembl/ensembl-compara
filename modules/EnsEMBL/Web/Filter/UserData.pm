package EnsEMBL::Web::Filter::UserData;

### Error messages for userdata database actions

use strict;

use base qw(EnsEMBL::Web::Filter);

sub init {
  my $self = shift;
  
  $self->messages = {
    no_file => 'Unable to save uploaded file contents to your account',
    no_das  => 'Unable to save DAS details to your account',
    no_url  => 'Unable to save remote URL to your account',
  };
}

1;
