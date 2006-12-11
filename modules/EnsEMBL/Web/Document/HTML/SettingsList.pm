package EnsEMBL::Web::Document::HTML::SettingsList;

use strict;
use warnings;

use EnsEMBL::Web::Object::User;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

{

sub new { return shift->SUPER::new( 'sp_bio' => '?? ??', 'sp_common' => '??', 'site_name' => '??',
                                    'logo_src' => '', 'logo_w' => 40, 'logo_h' => 40, 'sub_title' => undef ); }

sub render {
  my ($class, $request) = @_;
  my $html = "";
  if ($ENV{'ENSEMBL_USER_ID'}) {
  my $user = EnsEMBL::Web::Object::User->new({ id => $ENV{'ENSEMBL_USER_ID'} });
  my $group_id = undef;
  foreach my $this ($user->drawer_records) {
    $group_id = $this->group;
  }
  $html = "<div id='settings' style='display:none;'>\n";
  $html .= "<div id='settings_content'>\n";
  $html .= "<table width='100%' cellpadding='0' cellspacing='0'>\n";
  $html .= "<tr><td width='49%'>\n";
  $html .= "<b>Settings for " . $user->name . "</b>&middot; <a href='javascript:void(0);' onclick='toggle_settings_drawer()'>Hide</a>\n";
  $html .= "</td>\n";
  $html .= "<td style='text-align: right;' width='49%'>Show: ";
  $html .= "<select name='group_select' id='group_select' onChange='settings_drawer_change()'>\n";
  $html .= "<option value='user'>Your settings</option>\n";
  foreach my $group (@{ $user->groups }) {
    my $selected = "";
    if ($group_id eq $group->id) {
      $selected = "selected";
    }
    $html .= "<option $selected value='" . $group->id . "'>" . $group->name . "</option>\n";
  }
  $html .= "</select>";
  $html .= "</td>\n";
  $html .= "</tr>\n";
  $html .= "<tr>\n";
  $html .= "<td style='padding-top: 5px;'>\n";
  $html .= "Bookmarks";
  my @user_bookmarks = $user->bookmark_records;
  $html .= list_for_records({ records => \@user_bookmarks, tag => 'user', selected => $group_id });
  foreach my $group (@{ $user->groups }) {
    my @group_bookmarks = $group->bookmark_records;
    $html .= list_for_records({ records => \@group_bookmarks, tag => $group->id, selected => $group_id });
  }
  $html .= "</td>\n";
  $html .= "<td style='padding-top: 5px;'>\n";
  $html .= "Configurations";
  my @configurations = $user->configuration_records;
  $html .= list_for_records({ records => \@configurations, tag => 'user', selected => $group_id });
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
      my $link = "<a href='" . $record->url . "' title='" . $record->description . "'>";
      if ($record->type eq 'configuration') {
        $link = "<a href='javascript:void(0);' onclick='javascript:load_config_link(" . $record->id . ");'>";
      }
      $html .= "<li class='all $tag' $style>" . $link . $record->name . "</li>\n"; 
      if ($count > 10) {
        last;
      }
    }
    if ($count > 10) {
      $html .= "<li><i><a href='/common/accountview'>More settings &rarr;</a></i></li>"
    }
    $html .= "</ul>";
  }
  return $html;
}

}

1;
