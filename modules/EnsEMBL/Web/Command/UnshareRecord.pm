package EnsEMBL::Web::Command::UnshareRecord;

use strict;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self  = shift;
  my $hub   = $self->hub;
  my $user  = $hub->user;
  my $group = $user->get_group($hub->param('webgroup_id'));
  my %url_params;

  if ($group && $user->is_admin_of($group)) {
    foreach (grep $_, $hub->param('id')) {
      my $group_record = $user->get_group_record($group, $_);

      next unless $group_record;

      $group_record->delete;
    }
  }
 
  $self->ajax_redirect($hub->url({'type' => 'UserData', 'action' => 'ManageData', 'function' => ''}));
}

1;
