package EnsEMBL::Web::Document::HTML::AccountView;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

{

sub render {
  my ($class, $request) = @_;
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

  my $html = "";
  $html .= "<div>\n";
  $html .= "<div style='float: left; width: 70%;'>\n";

  $html .= "<div class='box_tabs'>";
  $html .= "<div class='tab selected' id='bookmarks_tab'><a href='javascript:void(0);' onClick='switch_tab(\"bookmarks\");'>Bookmarks</a></div>";
  $html .= "<div class='tab' id='groups_tab'><a href='javascript:void(0);' onClick='switch_tab(\"groups\");'>Groups</a></div>";
  $html .= "<br clear='all' />\n";
  $html .= "<div class='tab_content'>\n";
  $html .= "<div class='tab_content_panel' id='bookmarks'>\n";
  $html .= render_bookmarks($user);
  $html .= "</div>\n";
  $html .= "<div class='tab_content_panel' style='display:none;' id='groups'>\n";
  $html .= render_groups($user);
  $html .= "</div>\n";
  $html .= "</div>\n";
  $html .= "</div>\n";

  $html .= "</div>\n";
  $html .= "<div class='boxed' style='float: left; margin-left: 20px; width: 24%;'>\n";
  $html .= "<b>" . $user->name . "</b>\n";
  $html .= "<ul style='margin: 0px; padding: 5px 15px;'>\n";
  $html .= "<li>" . $user->email . "</li>\n";
  $html .= "<li>" . $user->organisation . "</li>\n";
  $html .= "</ul>\n";
  $html .= "<a href='/common/update'>Update details</a>";
  $html .= "</div>\n";
  $html .= "<br clear='all' />\n";
  $html .= "</div>\n";
  return $html;
}

sub render_groups {
  my $user = shift;
  return "groups";
}

sub render_bookmarks {
  my $user = shift;
  my $html = "";
  $html .= "<table width='100%' cellpadding='5' cellspacing='0'>\n";
  my $count = 0;
  my $colour = 'fff';
  foreach my $record ($user->bookmark_records({ order_by => 'click' })) {
    $count++;
    $colour = 'fff';
    if ($count % 2) {
      $colour = 'efefef';
    }
    $html .= "<tr style='background: #" . $colour . ";'>";
    $html .= "<td width='16px'><img src='/img/bullet_star.png' width='16' height='16' /></td>";
    $html .= "<td><a href='" . $record->url . "'>" . $record->name . "</a></td>\n";
    $html .= "<td><a href='/common/bookmark?id=" . $record->id . "'>Edit</a></td>";
    $html .= "<td><a href='/common/delete_bookmark?id=" . $record->id . "'>Delete</a></td>";
    $html .= "</tr>\n";
  }
  $html .= "</table>\n";
  return $html;
}

}

1;
