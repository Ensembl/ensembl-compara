package EnsEMBL::Web::Command::UserData::CheckServer;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Filter::DAS;
use base 'EnsEMBL::Web::Command';

{

sub BUILD {
}

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/'.$object->data_species.'/UserData/';
  my $param;
  ## Set these separately, or they cause an error if undef
  $param->{'_referer'} = $object->param('_referer');
  $param->{'x_requested_with'} = $object->param('x_requested_with');

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

  if ($object->param('x_requested_with')) {
    $self->ajax_redirect($url, $param);
  }
  else {
    $object->redirect($url, $param);
  }

}

}

1;
