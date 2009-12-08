package EnsEMBL::Web::Command::UserData::CheckServer;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Filter::DAS;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = $object->species_path($object->data_species).'/UserData/';
  my $param;
  ## Set these separately, or they cause an error if undef
  $param->{'_referer'} = $object->param('_referer');

  ## Catch any errors at the server end
  my $server = $object->param('other_das') || $object->param('preconf_das');
  my $filter = EnsEMBL::Web::Filter::DAS->new({'object' => $object});
  my $sources = $filter->catch($server);

  if ($sources) {
    $param->{'das_server'} = $server;
    $url .= 'DasSources';
  }
  else {
    $url .= 'SelectServer';
  }

  $self->ajax_redirect($url, $param);
}

1;
