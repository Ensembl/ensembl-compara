package EnsEMBL::Web::Command::Account::RemoveInvitation;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($object->param('id'));
  $invitation->destroy;
  $self->ajax_redirect('/Account/ManageGroup', {'id'   => $object->param('group_id')});
}

}

1;
