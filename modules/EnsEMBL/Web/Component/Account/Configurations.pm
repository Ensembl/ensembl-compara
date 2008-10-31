package EnsEMBL::Web::Component::Account::Configurations;

### Module to create user saved config list

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
  
  my @configs = $user->configurations;
  my $has_configs = 0;
  
  my @admin_groups = $user->find_administratable_groups;
  my $has_groups = $#admin_groups > -1 ? 1 : 0;

  if ($#configs > -1) {

    $html .= qq(<h3>Your configurations</h3>);
    ## Sort user configs by name if required

    ## Display user configs
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

    $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '20%', 'align' => 'left' },
        { 'key' => 'desc',      'title' => 'Description',   'width' => '50%', 'align' => 'left' },
        { 'key' => 'rename',    'title' => '',              'width' => '10%', 'align' => 'left' },
    );
    if ($has_groups) {
      $table->add_columns(
        { 'key' => 'share',     'title' => '',              'width' => '10%', 'align' => 'left' },
      );
    }
    $table->add_columns(
        { 'key' => 'delete',    'title' => '',              'width' => '10%', 'align' => 'left' },
    );

    foreach my $config (@configs) {
      my $row = {};

      $row->{'name'} = sprintf(qq(<a href="/Account/UseConfig?id=%s" class="cp-refresh">%s</a>),
                        $config->id, $config->name);

      $row->{'desc'} = $config->description || '&nbsp;';
      $row->{'rename'} = $self->edit_link('Configuration', $config->id, 'Rename');
      if ($has_groups) {
        $row->{'share'}   = $self->share_link('Bookmark', $config->id);
      }
      $row->{'delete'} = $self->delete_link('Configuration', $config->id);
      $table->add_row($row);
      $has_configs = 1;
    }
    $html .= $table->render;
  }

 ## Get all config records for this user's subscribed groups
  my %group_configs = ();
  foreach my $group ($user->groups) {
    foreach my $config ($group->configurations) {
      next if $config->created_by == $user->id;
      if ($group_configs{$config->id}) {
        push @{$group_configs{$config->id}{'groups'}}, $group;
      }
      else {
        $group_configs{$config->id}{'config'} = $config;
        $group_configs{$config->id}{'groups'} = [$group];
        $has_configs = 1;
      }
    }
  }

  if (scalar values %group_configs > 0) {
    $html .= qq(<h3>Group configurations</h3>);
    ## Sort group configs by name if required

    ## Display group configs
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

    $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '20%', 'align' => 'left' },
        { 'key' => 'desc',      'title' => 'Description',   'width' => '40%', 'align' => 'left' },
        { 'key' => 'group',     'title' => 'Group(s)',      'width' => '40%', 'align' => 'left' },
    );

    foreach my $config_id (keys %group_configs) {
      my $row = {};
      my $config = $group_configs{$config_id}{'config'};

      $row->{'name'} = sprintf(qq(<a href="/Account/UseConfig?id=%s" class="cp-refresh">%s</a>),
                        $config_id, $config->name);

      $row->{'desc'} = $config->description || '&nbsp;';

      my @group_links;
      foreach my $group (@{$group_configs{$config_id}{'groups'}}) {
        push @group_links, 
          sprintf(qq(<a href="/Account/MemberGroups?id=%s;_referer=%s" class="modal_link">%s</a>), 
              $group->id, CGI::escape($self->object->param('_referer')), $group->name);
      }
      $row->{'group'} = join(', ', @group_links);
      $table->add_row($row);
    }
    $html .= $table->render;
  }


  if (!$has_configs) {
    $html .= qq(<p class="center"><img src="/img/help/config_example.gif" /></p>);
  }

  return $html;
}

1;
