package EnsEMBL::Web::Filter::Admin;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Filter);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_redirect('/Account/Group/List');
  $self->set_messages({
    'not_admin' => 'You are not an administrator of this group.',
    'bogus_id'  => 'No valid record selected.',
  });
}


sub catch {
  my $self = shift;
  my $object = $self->object;
  
  ## First check we have a sensible value for 'id'
  if ($object->param('id') && $object->param('id') =~ /\D/) {
    $self->set_error_code('bogus_id');
    return;
  }
  
  my $user  = $object->user;
  
  if ($object->param('group_id')) {
    $self->set_error_code('not_admin') unless $user->is_administrator_of($object->param('group_id'));
  } elsif ($object->param('id') && !$user->is_administrator_of($object->param('id'))) {
    $self->set_error_code('not_admin');
  }
}

}

1;
