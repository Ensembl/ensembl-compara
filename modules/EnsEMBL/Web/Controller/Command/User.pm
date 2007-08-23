package EnsEMBL::Web::Controller::Command::User;

use strict;
use warnings;

use base 'EnsEMBL::Web::Controller::Command';

sub user_or_admin {
  ### Chooses correct filter for shareable records, based on whether user or group record
  my ($self, $class, $id, $owner) = @_;
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) { ## inherited
    if ($owner eq 'group') {
      my $record = $class->new({'id'=>$id, 'record_type'=>'group'});
      $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $record->webgroup_id});
    }
    else {
      my $record = $class->new({'id'=>$id, 'record_type'=>'user'});
      $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $record->user->id});
    }
  }
}

sub add_member_from_invitation {
  my ($self, $user, $invitation) = @_;

  my $membership = EnsEMBL::Web::Object::Data::Membership->new;
  $membership->webgroup_id($invitation->webgroup_id);
  $membership->user_id($user->id);
  $membership->created_by($user->id);
  $membership->level('member');
  $membership->member_status('active');
  return $membership->save;
}


1;
