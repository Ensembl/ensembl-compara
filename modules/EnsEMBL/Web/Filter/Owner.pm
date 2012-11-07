package EnsEMBL::Web::Filter::Owner;

use strict;

use EnsEMBL::Web::Data::Group;

use base qw(EnsEMBL::Web::Filter);

sub init {
  my $self = shift;
  
  $self->redirect = '/Account/Links';
  $self->messages = {
    not_owner  => 'You are not the owner of this record.',
    not_member => 'You are not a member of the group that owns this record.',
    bogus_id   => 'No valid record selected.'
  };
}

sub catch {
  my $self   = shift;
  my $hub = $self->hub;
  my $id     = $hub->param('id');
  
  # Don't fail if no ID - implies new record
  if ($id) {
    # First check we have a sensible value for 'id'
    if ($id =~ /\D/) {
      $self->error_code = 'bogus_id';
      return;
    } else {
      my $user  = $hub->user;
      my $group = $hub->param('group');
      
      if ($group) {
        ## First check we have a sensible value for 'id'
        if ($group =~ /\D/) {
          $self->error_code = 'bogus_id';
          return;
        } else {
          my $data_group = EnsEMBL::Web::Data::Group->new($group);
          
          if ($data_group && $user->is_member_of($data_group)) {            
            if (!$data_group->records($id)) {
              $self->error_code = 'not_owner';
              return;
            }
          } else {
            $self->error_code = 'not_member';
            return;
          }
        }
      } else {        
        $self->error_code = 'not_owner' unless $user->records($id);
      }
    }
  }
}

1;
