package EnsEMBL::Web::Configuration::Interface::User;

### Sub-class to do user-specific interface functions

use strict;
use EnsEMBL::Web::Configuration::Interface;
use EnsEMBL::Web::Tools::RandomString;

use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::Record::Group;
use EnsEMBL::Web::Object::Data::Invite;
use EnsEMBL::Web::RegObj;

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


sub join_by_invite {
  my ($self, $object, $interface) = @_;
  my $url;

  my $record_id = $object->param('record_id');
  #warn "RECORD ID: " . $record_id;
  if ($record_id && $record_id =~ /^\d+$/) {
    my @records = EnsEMBL::Web::Record::Group->find_invite_by_group_record_id($record_id, { adaptor => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor });
    my $record = $records[0];
    $record->adaptor($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor);
    my $email = $record->email;

    my $user = EnsEMBL::Web::Object::User->new({ adaptor => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor,  email => $email });

    if ($user->id) {
      my $invite = EnsEMBL::Web::Object::Data::Invite->new({id => $object->param('record_id')});
      my $group_id = $invite->group->id;

      my $group = EnsEMBL::Web::Object::Group->new(( adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, id => $group_id ));
      # warn "WORKING WITH USER: " . $user->id . ": " . $user->email;
      $user->add_group($group);
      # warn "SAVING USER";
      $user->save;
      $invite->status('accepted');
      # warn "SAVING RECORD";
      $invite->save;
    
      if ($ENV{'ENSEMBL_USER_ID'}) {
        $url = "/common/user/account";
      }
      else {
        $url = '/common/user/login';
      }
    }
    else {
      $url = "/common/user/register?email=$email;status=active;record_id=$record_id";
    }
  }
  else {
      $url = "/common/register?dataview=failure;error=no_record";
  }
  return $url;
}


1;
