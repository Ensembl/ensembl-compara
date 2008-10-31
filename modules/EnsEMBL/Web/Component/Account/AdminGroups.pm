package EnsEMBL::Web::Component::Account::AdminGroups;

### Module to create list of groups that a user is an admin of

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

  ## Control panel fixes
  my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
  $dir = '' if $dir !~ /_/;
  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');
  
  my @groups = $user->find_administratable_groups;

  if (@groups) {

    $html .= qq(<h3>Your groups</h3>);
    $html .= '<p>Sorry, group administration has been temporarily suspended whilst we test that user accounts are working correctly.</p>';

    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

    $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '20%', 'align' => 'left' },
        { 'key' => 'desc',      'title' => 'Description',   'width' => '50%', 'align' => 'left' },
        { 'key' => 'details',   'title' => '',              'width' => '10%', 'align' => 'left' },
        { 'key' => 'manage',    'title' => '',              'width' => '20%', 'align' => 'left' },
    );

    foreach my $group (@groups) {
      my $row = {};

      $row->{'name'} = $group->name;
      $row->{'desc'} = $group->blurb || '&nbsp;';
      if ($self->object->param('id') && $self->object->param('id') == $group->id) {
        $row->{'details'} = qq(<a href="$dir/Account/AdminGroups?$referer" class="modal_link">Hide Details</a>);
      }
      else {
        $row->{'details'} = qq(<a href="$dir/Account/AdminGroups?id=).$group->id.qq(;$referer" class="modal_link">Show Details</a>);
      }

#      $row->{'manage'} = '<a href="/Account/Group?id='.$group->id.';dataview=edit;_referer='.CGI::escape($self->object->param('_referer')).'" class="modal_link">Manage Group</a>';
      $table->add_row($row);
    }
    $html .= $table->render;
  }
  else {
    $html .= qq(<p class="center">You are not an administrator of any $sitename groups.</p>);
  }
 # $html .= '<p><a href="/Account/Group?dataview=add;_referer='.CGI::escape($self->object->param('_referer')).'" class="modal_link">Create a new group &rarr;</a></p>';

  return $html;
}

1;
