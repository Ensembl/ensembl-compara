package EnsEMBL::Web::User;

use strict;
use warnings;
no warnings "uninitialized";


sub new {
  my $class = shift;

  ## is the user logged in?
  my $user_id = $ENV{'ENSEMBL_USER_ID'} || 0;

  my $self = {
    '_user_id'      => $user_id,
  };
  bless($self, $class);
  return $self;
}

sub id       {
  my $self = shift;
  return $self->{'_user_id'};
}

1;


