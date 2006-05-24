package EnsEMBL::Web::User;

use strict;
use warnings;
no warnings "uninitialized";

## STUB -  see sanger-plugins/ap5 for work in progress :)

sub new {
  my $class = shift;

  ## is the user logged in?
  my $user_id = $ENV{'ENSEMBL_USER'} || 0;

  my $self = {
    '_user_id'      => $user_id,
  };
  bless($self, $class);
  return $self;
}


sub id       { return $_[0]{'_user_id'}; }

1;


