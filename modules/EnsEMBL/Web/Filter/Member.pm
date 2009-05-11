package EnsEMBL::Web::Filter::Member;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Registry;

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
  my $user  = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  
  ## TODO: finally decide which param to use
  my $group_id = $self->object->param('webgroup_id') || $self->object->param('group_id') || $self->object->param('id');
  unless ($user->is_member_of($group_id)) {
    $self->set_error_code('not_member');
  }
}

}

1;
