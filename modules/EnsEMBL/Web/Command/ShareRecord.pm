# $Id$

package EnsEMBL::Web::Command::ShareRecord;

use strict;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::Record;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self  = shift;
  my $hub   = $self->hub;
  my $user  = $hub->user;
  my $group = new EnsEMBL::Web::Data::Group($hub->param('webgroup_id'));
  my %url_params;

  if ($group && $user->is_administrator_of($group)) {
    foreach (grep $_, $hub->param('id')) {
      my $user_record = new EnsEMBL::Web::Data::Record(owner => 'user', id => $_);
      
      next unless $user_record && $user_record->user_id == $user->id;
      
      my $clone = $user_record->clone;
      
      $clone->owner($group);
      $clone->save;
    }
    
    %url_params = (
      type     => 'Account',
      action   => 'Group',
      function => 'List',
      id       => $group->id,
    );
  } else {
    %url_params = (
      type          => 'UserData',
      action        => 'ManageData',
      filter_module => 'Shareable',
      filter_code   => 'no_group',
    );
  }
 
  $self->ajax_redirect($hub->url(\%url_params));
}

1;
