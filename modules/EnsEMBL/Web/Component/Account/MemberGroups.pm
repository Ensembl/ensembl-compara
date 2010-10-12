# $Id$

package EnsEMBL::Web::Component::Account::MemberGroups;

### Module to create list of groups that a user belongs to

use strict;

use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;

  my $user = $object->user;
  my $sitename = $self->site_name;

  ## Control panel fixes
  my $dir = $object->species_path;
  $dir = '' if $dir !~ /_/;
  my @groups = $user->find_nonadmin_groups;

  if (@groups) {

    $html .= qq(<h3>Your subscribed groups</h3>);

    my $table = $self->new_table([], [], { margin => '1em 0px' });

    $table->add_columns(
        { 'key' => 'name',    'title' => 'Name',          'width' => '20%', 'align' => 'left' },
        { 'key' => 'desc',    'title' => 'Description',   'width' => '40%', 'align' => 'left' },
        { 'key' => 'admin',   'title' => 'Administrator', 'width' => '20%', 'align' => 'left' },
        { 'key' => 'details', 'title' => '',              'width' => '10%', 'align' => 'left' },
        { 'key' => 'leave',   'title' => '',              'width' => '10%', 'align' => 'left' },
    );

    foreach my $group (@groups) {
      my $row = {};

      $row->{'name'} = $group->name;
      $row->{'desc'} = $group->blurb || '&nbsp;';
      my @admins;
      foreach my $member ($group->members) {
        push @admins, $member->name if $member->level eq 'administrator';
      }
      $row->{'admin'} = join(',', @admins);
      if ($object->param('id') && $object->param('id') == $group->id) {
        $row->{'details'} = qq(<a href="$dir/Account/MemberGroups" class="modal_link">Hide Details</a>);
      }
      else {
        $row->{'details'} = qq(<a href="$dir/Account/MemberGroups?id=).$group->id.qq(" class="modal_link">Show Details</a>);
      }
      $row->{'leave'} = qq(<a href="$dir/Account/Unsubscribe?id=).$group->id.qq(" class="modal_link">Unsubscribe</a>);;
      $table->add_row($row);
    }
    $html .= $table->render;
  }
  else {
    $html .= qq(<p class="center">You are not subscribed to any $sitename groups.</p>);
  }

  return $html;
}

1;
