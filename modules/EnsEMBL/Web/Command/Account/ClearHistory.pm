package EnsEMBL::Web::Command::Account::ClearHistory;

use strict;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $user = $self->object->user;
  my $object = $self->hub->param('object');
  
  if ($object) {
    $_->delete for grep $_->{'object'} eq $object, $user->histories;
  } else {
    $user->histories->delete_all;
  }
}

1;
