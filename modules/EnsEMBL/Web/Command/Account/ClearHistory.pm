package EnsEMBL::Web::Command::Account::ClearHistory;

use strict;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $user = $self->object->user;
  $user->histories->delete_all;
}

1;
