# $Id$

package EnsEMBL::Web::Command::UserData::SaveTempData;

use strict;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub  = $self->hub;

  if ($hub->param('name')) {
    $hub->session->set_data('type' => $hub->param('type'), 'code' => $hub->param('code'), 'name' => $hub->param('name'));
  }
 
  $self->ajax_redirect($hub->species_path($hub->data_species). '/UserData/ManageData'); 
}

1;
