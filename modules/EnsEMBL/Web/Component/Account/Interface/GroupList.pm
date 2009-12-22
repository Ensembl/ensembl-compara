package EnsEMBL::Web::Component::Account::Interface::GroupList;

### Module to display a list of groups that a user is an admin of

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Document::SpreadSheet;

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
  my $user = $object->user;
  my $sitename = $self->site_name;
  my @groups = $user->find_administratable_groups;
  my $html;

  if (@groups) {
    $html .= qq(<h3>Your groups</h3>);

    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

    $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',  'width' => '25%', 'align' => 'left' },
        { 'key' => 'edit',      'title' => '',      'width' => '20%', 'align' => 'left' },
        { 'key' => 'details',   'title' => '',      'width' => '20%', 'align' => 'left' },
        { 'key' => 'members',   'title' => '',      'width' => '20%', 'align' => 'left' },
        { 'key' => 'delete',    'title' => '',      'width' => '15%', 'align' => 'left' },
    );

    foreach my $group (@groups) {
      my $row = {};

      my $info = '<strong>'.$group->name.'</strong>';
      $info .= '<br />'.$group->blurb if $group->blurb;
      $row->{'name'} = $info;
      $row->{'edit'} = qq(<a href="/Account/Group/Edit?id=).$group->id.qq(" class="modal_link">Edit Name/Description</a>);

      $row->{'members'} = qq(<a href="/Account/ManageGroup?id=).$group->id.qq(" class="modal_link">Manage Member List</a>);
  
      if ($object->param('id') && $object->param('id') == $group->id) {
        $row->{'details'} = qq(<a href="/Account/Group/List" class="modal_link">Hide Shared Settings</a>);
      }
      else {
        $row->{'details'} = qq(<a href="/Account/Group/List?id=).$group->id.qq(" class="modal_link">Show Shared Settings</a>);
      }

      $row->{'delete'} = qq(<a href="/Account/Group/ConfirmDelete?id=).$group->id.qq(" class="modal_link">Delete Group</a>);
      $table->add_row($row);
    }
    $html .= $table->render;
  }
  else {
    $html .= qq(<p class="center">You are not an administrator of any $sitename groups.</p>);
  }

  if ($object->param('id')) {
    my $group = EnsEMBL::Web::Data::Group->new($object->param('id'));   
    my $user  = $object->get_user;
    if ($user->is_administrator_of($group)) {
      $html .= $self->_show_group_details($group);
    }
  }

  return $html;
}

sub _show_group_details {
  my ($self, $group) = @_;
  my $html;
  my $creator = EnsEMBL::Web::Data::User->new($group->created_by);

  $html .= '<h2>'.$group->name.'</h2>';
  $html .= '<p><strong>Group created by</strong>: '.$creator->name;
  $html .= ' <strong>on</strong> '.$self->pretty_date($group->created_at).'</p>';

  $html .= '<h3>Bookmarks</h3>';
  if ($group->bookmarks) {

    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

    $table->add_columns(
      { 'key' => 'name',      'title' => 'Name',          'width' => '30%', 'align' => 'left' },
      { 'key' => 'desc',      'title' => 'Description',   'width' => '70%', 'align' => 'left' },
    );

    foreach my $bookmark ($group->bookmarks) {
      my $row = {};

      $row->{'name'} = sprintf(qq(<a href="/Account/UseBookmark?owner_type=group;id=%s" title="%s">%s</a>),
                      $bookmark->id, $bookmark->url, $bookmark->name);

      $row->{'desc'} = $bookmark->description || '&nbsp;';

      $table->add_row($row);
    }
    $html .= $table->render;
  }
  else {
    $html .= '<p>No shared bookmarks</p>';
  }

  $html .= '<h3>Annotations</h3>';
  if ($group->annotations) {

    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

    $table->add_columns(
      { 'key' => 'type',    'title' => 'Type',          'width' => '20%', 'align' => 'left' },
      { 'key' => 'id',      'title' => 'Stable ID',     'width' => '30%', 'align' => 'left' },
      { 'key' => 'title',   'title' => 'Title',         'width' => '50%', 'align' => 'left' },
    );

    foreach my $note ($group->annotations) {
      my $row = {};
      $row->{'type'} = $note->ftype || 'Gene';
      if ($note->species) {
        $row->{'id'} = sprintf(qq(<a href="/%s/Gene/UserAnnotation?g=%s">%s</a>),
                      $note->species, $note->stable_id, $note->stable_id);
      }
      else {
        $row->{'id'} = $note->stable_id; 
      }
      $row->{'title'} = $note->title || '&nbsp;';

      $table->add_row($row);
    }
    $html .= $table->render;
  }
  else {
    $html .= '<p>No shared annotations</p>';
  }

  $html .= '<h3>Custom data</h3>';
  if ($group->uploads || $group->urls) {

    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

    $table->add_columns(
      { 'key' => 'type',    'title' => 'Type',    'width' => '20%', 'align' => 'left' },
      { 'key' => 'name',   'title' => 'Name',     'width' => '50%', 'align' => 'left' },
    );

    my @records = ($group->uploads, $group->urls);
    foreach my $record (@records) {
      my $row = {};
      $row->{'type'} = $record->type;
      $row->{'name'} = $record->name;

      $table->add_row($row);
    }
    $html .= $table->render;
  }
  else {
    $html .= '<p>No shared data</p>';
  }

  return $html;  
}


1;
