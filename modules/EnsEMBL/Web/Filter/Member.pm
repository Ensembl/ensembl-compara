package EnsEMBL::Web::Filter::Member;

use strict;

use base qw(EnsEMBL::Web::Filter);

sub init {
  my $self = shift;
  
  $self->redirect = '/Account/Links';
  $self->messages{
    not_member => 'You are not a member of this group. If you think this is incorrect, please contact the group administrator.'
  };
}


sub catch {
  my $self   = shift;
  my $object = $self->object;
  my $user   = $object->user;
  
  ## TODO: finally decide which param to use
  my $group_id = $object->param('webgroup_id') || $object->param('group_id') || $object->param('id');
  
  $self->error_code = 'not_member' unless $user->is_member_of($group_id);
}

1;
