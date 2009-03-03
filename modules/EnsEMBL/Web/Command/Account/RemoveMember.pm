package EnsEMBL::Web::Command::Account::RemoveMember;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::Group;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $membership = EnsEMBL::Web::Data::Membership->find('webgroup_id' => $object->param('id'), 'user_id' => $object->param('user_id'));
  $membership->destroy;
  $self->ajax_redirect('/Account/ManageGroup', {'id'   => $object->param('id')});
}

}

1;
