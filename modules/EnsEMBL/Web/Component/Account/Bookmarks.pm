package EnsEMBL::Web::Component::Account::Bookmarks;

### Module to create user bookmark list

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

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
  my $html;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $sitename = $self->site_name;

  ## Get all bookmark records for this user
  my @bookmarks = $user->bookmarks;
  my $has_bookmarks = 0;

  my @admin_groups = $user->find_administratable_groups;
  my $has_groups = $#admin_groups > -1 ? 1 : 0;

  if ($#bookmarks > -1) {
  
    $html .= qq(<h3>Your bookmarks</h3>);
    ## Sort user bookmarks by name if required 

    ## Display user bookmarks
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

    $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '20%', 'align' => 'left' },
        { 'key' => 'desc',      'title' => 'Description',   'width' => '50%', 'align' => 'left' },
        { 'key' => 'edit',      'title' => '',              'width' => '10%', 'align' => 'left' },
    );
    if ($has_groups) {
      $table->add_columns(
        { 'key' => 'share',     'title' => '',              'width' => '10%', 'align' => 'left' },
      );
    }
    $table->add_columns(
        { 'key' => 'delete',    'title' => '',              'width' => '10%', 'align' => 'left' },
    );

    foreach my $bookmark (@bookmarks) {
      my $row = {};

      my $description = $bookmark->description || '&nbsp;';
      $row->{'name'} = sprintf(qq(<a href="/Account/UseBookmark?id=%s" title="%s" class="cp-external">%s</a>),
                        $bookmark->id, $description, $bookmark->name);

      $row->{'desc'}    = $description;
      $row->{'edit'}    = $self->edit_link('Bookmark', $bookmark->id);
      if ($has_groups) {
        $row->{'share'}   = $self->share_link('bookmarks', $bookmark->id);
      }
      $row->{'delete'}  = $self->delete_link('Bookmark', $bookmark->id);
      $table->add_row($row);
      $has_bookmarks = 1;
    }
    $html .= $table->render;
    $html .= $self->_add_bookmark;
  }


  ## Get all bookmark records for this user's groups
  my %group_bookmarks = ();
  foreach my $group ($user->groups) {
    foreach my $bookmark ($group->bookmarks) {
      next if $bookmark->created_by == $user->id;
      if ($group_bookmarks{$bookmark->id}) {
        push @{$group_bookmarks{$bookmark->id}{'groups'}}, $group;
      }
      else {
        $group_bookmarks{$bookmark->id}{'bookmark'} = $bookmark;
        $group_bookmarks{$bookmark->id}{'groups'} = [$group];
        $has_bookmarks = 1;
      }
    }
  }

  if (scalar values %group_bookmarks > 0) {
    $html .= qq(<h3>Group bookmarks</h3>);
    ## Sort group bookmarks by name if required 

    ## Display group bookmarks
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

    $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '20%', 'align' => 'left' },
        { 'key' => 'desc',      'title' => 'Description',   'width' => '40%', 'align' => 'left' },
        { 'key' => 'group',     'title' => 'Group(s)',      'width' => '40%', 'align' => 'left' },
    );

    foreach my $bookmark_id (keys %group_bookmarks) {
      my $row = {};
      my $bookmark = $group_bookmarks{$bookmark_id}{'bookmark'};

      $row->{'name'} = sprintf(qq(<a href="/Account/UseBookmark?id=%s" class="cp-external">%s</a>),
                        $bookmark->id, $bookmark->name);

      $row->{'desc'} = $bookmark->description || '&nbsp;';

      my @group_links;
      foreach my $group (@{$group_bookmarks{$bookmark_id}{'groups'}}) {
        push @group_links, sprintf(qq(<a href="/Account/MemberGroups?id=%s" class="cp-internal">%s</a>), $group->id, $group->name);
      }
      $row->{'group'} = join(', ', @group_links);
      $table->add_row($row);
    }
    $html .= $table->render;
  }

  if (!$has_bookmarks) {
    $html .= qq(<p class="center"><img src="/i/help/bookmark_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= $self->_add_bookmark;
  }

  return $html;
}

sub _add_bookmark {
  my $self = shift;
  return qq(<p><a href="/Account/Bookmark?dataview=add" class="cp-internal"><strong>Add a new bookmark </strong>&rarr;</a></p>);
}

1;
