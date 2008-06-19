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
  
  my @groups = $user->find_administratable_groups;
  my $has_groups = $#groups > -1 ? 1 : 0;

  if ($#configs > -1) {

    $html .= qq(<h3>Your configurations</h3>);
    ## Sort user configs by name if required

    ## Display user configs
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

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

      my $description = $config->description || '&nbsp;';
      $row->{'name'} = sprintf(qq(<a href="/Account/_use_config?id=%s" title="%s">%s</a>),
                        $config->id, $description, $config->name);

      $row->{'desc'} = $description;
      $row->{'rename'} = $self->edit_link('Configuration', $config->id, 'Rename');
      if ($has_groups) {
        $row->{'share'}   = $self->share_link('Bookmark', $bookmark->id);
      }
      $row->{'delete'} = $self->delete_link('Configuration', $config->id);
      $table->add_row($row);
      $has_configs = 1;
    }
    $html .= $table->render;
  }

  if (!$has_configs) {
    $html .= qq(<p class="center"><img src="/img/help/config_example.gif" /></p>);
    $html .= qq(<p class="center">You haven't saved any $sitename view configurations. <a href='/info/website/custom.html#configurations'>Learn more about configurating views &rarr;</a>);

  }

  return $html;
}

1;
