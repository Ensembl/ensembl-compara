package EnsEMBL::Web::Document::HTML::SettingsList;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

{

sub new { return shift->SUPER::new( 'sp_bio' => '?? ??', 'sp_common' => '??', 'site_name' => '??',
                                    'logo_src' => '', 'logo_w' => 40, 'logo_h' => 40, 'sub_title' => undef ); }

sub render {
  my ($class, $request) = @_;
  my $html = "";
  if ($ENV{'ENSEMBL_USER_ID'}) {
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

  my $sitename = $SiteDefs::ENSEMBL_SITETYPE;

  my $group_id = undef;
  foreach my $this (@{ $user->drawers }) {
    $group_id = $this->group;
  }
  $html = "<div id='settings' style='display:none;'>\n";
  $html .= "<div id='settings_content'>\n";
  $html .= "<table width='100%' cellpadding='0' cellspacing='0'>\n";
  $html .= "<tr><td width='49%'>\n";
  $html .= "<b><a href='/common/user/account'>Your $sitename account</a> &gt; " . $user->name . "</b> &middot; <a href='javascript:void(0);' onclick='toggle_settings_drawer()'>Hide</a>\n";
  $html .= "</td>\n";
  $html .= "<td style='text-align: right;' width='49%'>";
  my @groups = @{ $user->groups };
  if (@groups) {
    $html .= "Show from: ";
    $html .= "<select name='group_select' id='group_select' onChange='settings_drawer_change()'>\n";
    $html .= "<option value='user'>Your account</option>\n";
    $html .= "<optgroup label='Groups'>\n";
  }
  foreach my $group (@{ $user->groups }) {
    next if $group->status ne 'active';
    my $selected = "";
    if ($group_id && $group_id eq $group->id) {
      $selected = "selected";
    }
    $html .= "<option $selected value='" . $group->id . "'>" . $group->name . "</option>\n";
  }
  if ($#groups > -1) {
    $html .= "</optgroup>\n";
    $html .= "</select>";
  }
  $html .= "</td>\n";
  $html .= "</tr>\n";
  $html .= "<tr>\n";
  $html .= "<td style='padding-top: 5px;'>\n";
  $html .= "Bookmarks";
  my @user_bookmarks = @{ $user->bookmarks };
  $html .= list_for_records({
    records  => \@user_bookmarks,
    tag      => 'user',
    selected => $group_id,
    type     => 'bookmark',
  });
  
  foreach my $group (@{ $user->groups }) {
    my @group_bookmarks = @{ $group->bookmarks };
    $html .= list_for_records({
      records  => \@group_bookmarks,
      tag      => $group->id,
      selected => $group_id,
      type     => 'bookmark',
    });
  }
  $html .= "</td>\n";
  $html .= "<td style='padding-top: 5px;'>\n";
  my @configurations = @{ $user->configurations };
  $html .= "Configurations";
  my @current_configs = @{ $user->currentconfigs };
  my $current_config = $current_configs[0];
  $html .= list_for_records({
    records        => \@configurations,
    tag            => 'user',
    selected       => $group_id,
    type           => 'configuration',
    current_config => $current_config,
  });
  foreach my $group (@{ $user->groups }) {
    my @group_configurations = @{ $group->configurations };
    $html .= list_for_records({
      records        => \@group_configurations,
      tag            => $group->id,
      selected       => $group_id,
      type           => 'configuration',
      current_config => $current_config,
    });
  }
  $html .= "</td>\n";
  $html .= "</tr>\n";
  $html .= "</table>";
  $html .= "</div></div>\n";
  }
  return $html;
}

sub list_for_records {
  my ($params) = @_;
  my @records = @{ $params->{records} };
  my $tag = $params->{tag};
  my $selected = $params->{selected};
  my $type = $params->{type};
  my $current_config = $params->{current_config};
  my $html = "";
  if ($#records > -1) {
    $html .= "<ul>";
    my $count = 0;
    foreach my $record (sort {$a->name cmp $b->name } @records) {
      $count++;
      my $style = "style='display: none;'";
      if (!$selected) {
        if ($tag eq 'user') {
          $style = "";
        }
      } else {
        if ($tag eq $selected) {
          $style = "";
        }
      }
      my $text;
      my $description = "Load bookmark";
      if ($record->url && $record->description) {
        $description = $record->description;
      }
      my $link = "<a href=/common/user/use_bookmark?id='" . $record->id . "' title='" . $description . "'>";
      if ($record->type eq 'configuration') {
        my $bold_start = '';
        my $bold_end = '';

        if (defined $current_config && $current_config->config eq $record->id) {
          $bold_start = "<strong>";
          $bold_end = "</strong>";
        }

        $text = $record->name . ':';
        if ($ENV{'ENSEMBL_SCRIPT'} && ($ENV{'ENSEMBL_SCRIPT'} eq 'contigview' || $ENV{'ENSEMBL_SCRIPT'} eq 'cytoview') ) {
          $text .=  ' <a href="javascript:void(0);" onclick="javascript:load_config(' . $record->id . ');">Load settings in this page</a> |';
        }
        $text .= ' <a  href="javascript:void(0);" onclick="javascript:go_to_config(' . $record->id . ');">Go to saved page and load tracks</a>';
      }
      else {
        $text = '<a href="' . $record->url . '" title="' . $description . '">' . $record->name . '</a>';
      }
      $html .= "<li class='all $tag' $style>" . $text . "</li>\n"; 
      if ($count > 10) {
        last;
      }
    }
    if ($count > 10) {
      $html .= "<li><i><a href='/common/user/account'>More settings &rarr;</a></i></li>"
    }
    $html .= "</ul>";
  } else {
    if ($type) {
      my $style = "style='display: none;'";
      if (!$selected) {
        if ($tag eq 'user') {
          $style = "";
        }
      } else {
        if ($tag eq $selected) {
          $style = "";
        }
      }
      $html .= "<ul class='all $tag' $style><li>No saved " . $type . "s</li>\n<li><a href='/info/help/custom.html'>Learn more about saving " . $type . "s &rarr;</a></li></ul>";
    }
  }
  return $html;
}

}

1;
