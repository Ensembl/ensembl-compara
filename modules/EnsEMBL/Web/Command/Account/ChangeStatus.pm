package EnsEMBL::Web::Command::Account::ChangeStatus;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::Group;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $group = EnsEMBL::Web::Data::Group->new($object->param('id'));
  $group->assign_status_to_user($object->param('user_id'), $object->param('new_status'));

  $self->ajax_redirect('/Account/ManageGroup', {'id' => $object->param('id'), 'reload' => 1});
}

}

1;
