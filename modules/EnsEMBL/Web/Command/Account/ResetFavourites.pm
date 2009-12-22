package EnsEMBL::Web::Command::Account::ResetFavourites;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $user   = $self->object->user;
  $user->specieslists->destroy;

  $self->ajax_redirect($ENV{'ENSEMBL_BASE_URL'});
}

1;
