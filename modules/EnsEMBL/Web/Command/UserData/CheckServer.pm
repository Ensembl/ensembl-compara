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

  # Hack for cache reloading for now - special text in filter box
  if ($object->param('das_name_filter') eq 'reloadCache') {
    $object->param('das_clear_cache','1');
    $object->param('das_name_filter','');
  }

  my $filter  = EnsEMBL::Web::Filter::DAS->new({ object => $object });
  my $sources = $filter->catch($server);

  if ($sources) {
    $param->{'das_server'} = $server;
    $param->{'das_name_filter'} = $object->param('das_name_filter');
    $url .= 'DasSources';
  } else {
    $param->{'filter_module'} = 'DAS';
    $param->{'filter_code'} = $filter->error_code;
    $url .= 'SelectServer';
  }
  
  $self->ajax_redirect($url, $param);
}

1;
