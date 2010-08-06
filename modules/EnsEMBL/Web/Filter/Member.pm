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
  my $hub = $self->hub;
  my $user   = $hub->user;
  
  ## TODO: finally decide which param to use
  my $group_id = $hub->param('webgroup_id') || $hub->param('group_id') || $hub->param('id');
  
  $self->error_code = 'not_member' unless $user->is_member_of($group_id);
}

1;
