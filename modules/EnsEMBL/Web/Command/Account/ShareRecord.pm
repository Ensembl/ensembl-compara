package EnsEMBL::Web::Command::Account::ShareRecord;

use strict;
use warnings;

use EnsEMBL::Web::Data::Group;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $user = $object->user;

  my ($records_accessor) = grep { $_ eq $accessor } keys %{ $user->relations };
  ## TODO: this should use abstraction limiting facility rather then grep

  my ($user_record) = $user->records($object->param('id'));
  my $group = EnsEMBL::Web::Data::Group->new($object->param('webgroup_id'));

  if ($user_record && $group) {
    my $clone = $user_record->clone;
    $clone->owner($group);
    $clone->save;
  }
  #else {
  #  ## TODO: error exception
  #}

  my $url;

  if ($user->is_administrator_of($group)) {
    $url = '/Account/Group/List';
  } else {
    $url = '/Account/MemberGroups';
  } 
 
  $self->ajax_redirect($url, { id => $group->id });
}

1;
