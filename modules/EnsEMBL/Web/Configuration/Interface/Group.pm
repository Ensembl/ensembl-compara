package EnsEMBL::Web::Configuration::Interface::Group;

### Sub-class to do user-specific interface functions

use strict;

use CGI;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Configuration::Interface;
use EnsEMBL::Web::Object::Data::Membership;


our @ISA = qw( EnsEMBL::Web::Configuration::Interface );

sub save {
  ### Saves changes to the group details and redirects to a feedback page
  my ($self, $object, $interface) = @_;
  my $primary_key = EnsEMBL::Web::Tools::DBSQL::TableName::parse_primary_key($interface->data->get_primary_key);
  my $id = $object->param($primary_key) || $object->param('id');
  $interface->cgi_populate($object, $id);
  ## default group type is 'restricted'
  if (!$id && !$object->param('type')) {
    $interface->data->type('restricted');
  }

  my $success = $interface->data->save;

  ## If new group, add current user as administrator
  if (!$id) {
    my $member = EnsEMBL::Web::Object::Data::Membership->new();
    $member->user_id($ENV{'ENSEMBL_USER_ID'});
    $member->webgroup_id($interface->data->id);
    $member->level('administrator');
    $member->status('active');
    $member->save;
  }

  my $script = $interface->script_name || $object->script;
  my $url;
  if ($success) {
    $url = "/common/$script?dataview=success";
  }
  else {
    $url = "/common/$script?dataview=failure";
  }
  return $url;

}


1;
