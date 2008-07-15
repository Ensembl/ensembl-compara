package EnsEMBL::Web::Configuration::Interface::Group;

### Sub-class to do user-specific interface functions

use strict;

use CGI;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Configuration::Interface;

our @ISA = qw( EnsEMBL::Web::Configuration::Interface );

sub save {
  ### Saves changes to the group details and redirects to a feedback page
  my ($self, $object, $interface) = @_;

  my $id = $object->param('id');
  $interface->cgi_populate($object);
  ## default group type is 'restricted'
  my $group = $interface->data;
  if (!$id && !$object->param('type')) {
    $group->type('restricted');
  }

  my $success = $group->save;

  ## If new group, add current user as administrator
  unless ($id) {
    $group->add_user(
      user  => $ENSEMBL_WEB_REGISTRY->get_user,
      level => 'administrator',
    );
  }

  my $script = $interface->script_name;
  my $url;
  if ($success) {
    $url = "/$script?dataview=success;_referer=".$object->param('_referer');
  }
  else {
    $url = "/$script?dataview=failure;_referer=".$object->param('_referer');
  }
  return $url;

}


1;
