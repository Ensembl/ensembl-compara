# $Id$

package EnsEMBL::Web::Component::Account::MemberDetails;

### Module to show details of a particular group that a user belongs to

use strict;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;

use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  return unless $object->param('id');

  my $html;
  my $user = $object->user;
  my $group = EnsEMBL::Web::Data::Group->new($object->param('id')); 

  if ($group) {

    ## Control panel fixes
    my $dir = $object->species_path;
    $dir = '' if $dir !~ /_/;

    my $creator = EnsEMBL::Web::Data::User->new($group->created_by);

    $html .= '<p>Group created by '.$creator->name;
    $html .= ' on '.$self->pretty_date($group->created_at).'</p>';

    $html .= '<h3>Bookmarks</h3>';
    if ($group->bookmarks) {

      my $table = $self->new_table([], [], { margin => '0px' });

      $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '30%', 'align' => 'left' },
        { 'key' => 'desc',      'title' => 'Description',   'width' => '70%', 'align' => 'left' },
      );

      foreach my $bookmark ($group->bookmarks) {
        my $row = {};

        $row->{'name'} = sprintf(qq(<a href="%s/Account/UseBookmark?id=%s" title="%s" class="modal_link">%s</a>),
                        $dir, $bookmark->id, $bookmark->url, $bookmark->name);

        $row->{'desc'} = $bookmark->description || '&nbsp;';

        $table->add_row($row);
      }
      $html .= $table->render;
    }
    else {
      $html .= '<p>No shared bookmarks</p>';
    }
  }

  return $html;
}

1;
