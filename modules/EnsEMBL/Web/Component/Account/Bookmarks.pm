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

=pod
  ## info box - move to help database!
  $html .= $self->info_box($user, qq(Bookmarks allow you to save frequently used pages from $sitename and elsewhere. When browsing $sitename, you can add new bookmarks by clicking the 'Add bookmark' link in the sidebar. <a href="http://www.ensembl.org/info/about/custom.html#bookmarks">Learn more about saving frequently used pages (Ensembl documentation) &rarr;</a>) , 'user_bookmark_info');
=cut  

  ## Get all bookmark records for this user
  my @bookmarks = $user->bookmarks;
  my $has_bookmarks = 0;

  my @groups = $user->find_administratable_groups;
  my $has_groups = $#groups > -1 ? 1 : 0;

  if ($#bookmarks > -1) {
  
    $html .= qq(<h3>Your bookmarks</h3>);
    ## Sort user bookmarks by name if required 

    ## Display user bookmarks
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

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
      $row->{'name'} = sprintf(qq(<a href="/Account/_use_bookmark?id=%s" title="%s">%s</a>),
                        $bookmark->id, $description, $bookmark->name);

      $row->{'desc'}    = $description;
      $row->{'edit'}    = $self->edit_link('Bookmark', $bookmark->id);
      if ($has_groups) {
        $row->{'share'}   = $self->share_link('Bookmark', $bookmark->id);
      }
      $row->{'delete'}  = $self->delete_link('Bookmark', $bookmark->id);
      $table->add_row($row);
      $has_bookmarks = 1;
    }
    $html .= $table->render;
  }


  ## Get all bookmark records for this user's groups
  my %group_bookmarks = ();
  foreach my $group ($user->groups) {
    foreach my $bookmark ($group->bookmarks) {
      unless ($group_bookmarks{$bookmark->id}) {
        $group_bookmarks{$bookmark->id} = $bookmark;
        $has_bookmarks = 1;
      }
    }
  }

  if (scalar values %group_bookmarks > 0) {
    $html .= qq(<h3>Group bookmarks</h3>);
    ## Sort group bookmarks by name if required 

    ## Display group bookmarks
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

    $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '20%', 'align' => 'left' },
        { 'key' => 'desc',      'title' => 'Description',   'width' => '40%', 'align' => 'left' },
        { 'key' => 'group',     'title' => 'Group',         'width' => '40%', 'align' => 'left' },
    );

    foreach my $bookmark (values %group_bookmarks) {
      my $row = {};
      my $description = $bookmark->description || '&nbsp;';
      $row->{'name'} = sprintf(qq(<a href="/Account/_use_bookmark?id=%s" title="%s">%s</a>),
                        $bookmark->id, $description, $bookmark->name);

      $row->{'desc'} = $description;
      $row->{'rename'} = $self->rename_link('Bookmark', $bookmark->id);
      $row->{'share'} = $self->share_link('Bookmark', $bookmark->id);
      $row->{'delete'} = $self->delete_link('Bookmark', $bookmark->id);
      $has_bookmarks = 1;
    }
    $html .= $table->render;
  }

  if (!$has_bookmarks) {
    $html .= qq(<p class="center"><img src="/i/help/bookmark_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= qq(<p class="center">You haven't saved any bookmarks. <a href="/info/website/account/settings.html#bookmarks">Learn more about bookmarks &rarr;</a>);
  }
  $html .= qq(<p><a href="/Account/Bookmark?dataview=add"><b>Add a new bookmark </b>&rarr;</a></p>);

  return $html;
}

1;
