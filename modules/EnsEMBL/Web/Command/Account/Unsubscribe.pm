package EnsEMBL::Web::Command::Account::Unsubscribe;

use strict;

use EnsEMBL::Web::Data::Group;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub  = $self->hub;

  my $group = EnsEMBL::Web::Data::Group->new($hub->param('id'));
  $group->assign_status_to_user($hub->user, 'inactive');

  $self->ajax_redirect('/Account/MemberGroups', { reload => 1 });
}

1;
