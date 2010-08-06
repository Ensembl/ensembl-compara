package EnsEMBL::Web::Filter::Admin;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Filter);

sub init {
  my $self = shift;
  
  $self->redirect = '/Account/Group/List';
  $self->messages = {
    not_admin => 'You are not an administrator of this group.',
    bogus_id  => 'No valid record selected.'
  };
}


sub catch {
  my $self   = shift;
  my $hub = $self->hub;
  my $id     = $hub->param('id');
  
  # First check we have a sensible value for 'id'
  if ($id && $id =~ /\D/) {
    $self->error_code = 'bogus_id';
    return;
  }
  
  my $user     = $hub->user;
  my $group_id = $hub->param('group_id');
  
  if ($group_id) {
    $self->error_code = 'not_admin' unless $user->is_administrator_of($group_id);
  } elsif ($id && !$user->is_administrator_of($id)) {
    $self->error_code = 'not_admin';
  }
}

1;
