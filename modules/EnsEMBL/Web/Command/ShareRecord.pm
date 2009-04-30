package EnsEMBL::Web::Command::ShareRecord;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Group;
use Data::Dumper;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my $accessor = lc($object->param('type')).'s';

  my $url = '/'.$object->data_species.'/';
  my $param = {
    '_referer'  => $object->param('_referer'),
    'x_requested_with' => $object->param('x_requested_with'),
  };

  my $group = EnsEMBL::Web::Data::Group->new($object->param('webgroup_id'));
  my @ids = ($object->param('id'));

  if ($group && $user->is_administrator_of($group)) {
    foreach my $id (@ids) {
      next unless $id;
      my $user_record = EnsEMBL::Web::Data::Record->new('owner' => 'user', 'id' => $id);
      next unless $user_record && $user_record->user_id == $user->id;
      my $clone = $user_record->clone;
      $clone->owner($group);
      $clone->save;
    }
    $param->{'id'} = $group->id;
    $url .= 'Account/Group/List';
  } 
  else {
    $param->{'filter_module'} = 'Shareable';
    $param->{'filter_code'} = 'no_group';
    $url .= 'UserData/ManageData';
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
