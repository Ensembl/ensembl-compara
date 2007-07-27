package EnsEMBL::Web::Configuration::Interface::User;

### Sub-class to do user-specific interface functions

use strict;
use EnsEMBL::Web::Configuration::Interface;
use EnsEMBL::Web::Tools::RandomString;

our @ISA = qw( EnsEMBL::Web::Configuration::Interface );

sub save {
  my ($self, $object, $interface) = @_;

  my $script = $interface->script_name || $object->script;
  my ($success, $url);
  my $id = $ENV{'ENSEMBL_USER_ID'};
  
  $interface->cgi_populate($object, $id);
  if (!$id) {
    $interface->data->salt(EnsEMBL::Web::Tools::RandomString::random_string(8));
  }
  $success = $interface->data->save;
  if ($success) {
    $url = "/common/$script?dataview=success;email=".$object->param('email');
    if ($object->param('record_id')) {
      $url .= ';record_id='.$object->param('record_id');
    }
  }
  else {
    $url = "/common/$script?dataview=failure";
  }
  return $url;
}

1;
