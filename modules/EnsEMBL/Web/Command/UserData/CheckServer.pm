package EnsEMBL::Web::Command::UserData::CheckServer;

use strict;
use warnings;

use EnsEMBL::Web::Filter::DAS;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self   = shift;
  my $object = $self->object;
  my $url    = $object->species_path($object->data_species) . '/UserData/';
  my $param;

  ## Catch any errors at the server end
  my $server  = $object->param('other_das') || $object->param('preconf_das');
  my $filter  = new EnsEMBL::Web::Filter::DAS({ object => $object });
  my $sources = $filter->catch($server);

  if ($sources) {
    $param->{'das_server'} = $server;
    $url .= 'DasSources';
  } else {
    $url .= 'SelectServer';
  }
  
  $self->ajax_redirect($url, $param);
}

1;
