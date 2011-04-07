# $Id$

package EnsEMBL::Web::Command::UserData::SaveImageconfig;

use strict;

use EnsEMBL::Web::Root;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self     = shift;
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $session  = $hub->session;
  my $redirect = $hub->species_path($hub->data_species) . '/UserData/RemoteFeedback';

  $self->ajax_redirect($redirect, $param);  
}

1;
