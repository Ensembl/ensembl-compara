# $Id$

package EnsEMBL::Web::Command::Account::LogOut;

use strict;

use EnsEMBL::Web::Cookie;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;

  $hub->clear_cookie($species_defs->ENSEMBL_USER_COOKIE);

  $hub->redirect($hub->referer->{'absolute_url'});
}

1;
