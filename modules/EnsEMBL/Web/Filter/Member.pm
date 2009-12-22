package EnsEMBL::Web::Filter::Member;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Filter);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_redirect('/Account/Links');
  ## Set the messages hash here
  $self->set_messages({
    'not_member' => 'You are not a member of this group. If you think this is incorrect, please contact the group administrator.',
  });
}


sub catch {
  my $self = shift;
  my $object = $self->object;
  my $user  = $object->user;
  
  ## TODO: finally decide which param to use
  my $group_id = $object->param('webgroup_id') || $object->param('group_id') || $object->param('id');
  
  $self->set_error_code('not_member') unless $user->is_member_of($group_id);
}

}

1;
