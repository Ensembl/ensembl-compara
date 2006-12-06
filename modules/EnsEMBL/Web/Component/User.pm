package EnsEMBL::Web::Component::User;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::DBSQL::NewsAdaptor;
use EnsEMBL::Web::Group::Record;
use Data::Dumper;
use EnsEMBL::Web::Interface::TabView;
use EnsEMBL::Web::Interface::Tab;
use EnsEMBL::Web::Interface::Table;
use EnsEMBL::Web::Interface::Table::Row;

use CGI;

use strict;
use warnings;
no warnings "uninitialized";

our @ISA = qw( EnsEMBL::Web::Component);


sub _wrap_form {
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($node)->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

##---------- ACCOUNTVIEW ----------------------------------------

sub group_details {
  my( $panel, $user) = @_;
  my $cgi = new CGI;
  my $group = EnsEMBL::Web::Object::Group->new(( id => $cgi->param('id') ));
  my $html = "<div class='pale boxed'>";
  $html .= qq(This page allows administrators to manage their Ensembl group. From here you can invite new users to join your group, remove existing users, and decide which resources are shared between group members.<br />
                <br />For more information about Ensembl groups, and how to use them,
                read our <a href='/info/about/groups.html'>introductory guide</a>.);
  $html .= "</div>";
   
  $panel->print($html);
}

sub group_settings {
  my( $panel, $user) = @_;
  my $cgi = new CGI;
  my $group = EnsEMBL::Web::Object::Group->new(( id => $cgi->param('id') ));
  my $html = "";
  $html .= &info_box($user, "All members of this group can use these settings.", "group_setting_info");
  $html .= "<div class='group_setting'>\n";
  $html .= render_group_settings_table($group);
  $html .= "</div><br /><br />\n";
  $panel->print($html);
}

sub render_group_settings_table {
  my ($group) = @_;
  my $html = qq(
  <table width='100%' cellpadding='4' cellspacing='0'>
    <tr>
      <td class='settings_header' colspan='5'><b>Configurations and bookmarks</b></td>
    </tr>\n);

  my $class = "dark";
  my $found = 0;
  my @configs = $group->configuration_records;
  if ($#configs> -1) {
    $found = 1;
    foreach my $config (@configs) {
      if ($class) {
        $class = "";
      } else {
        $class = "dark";
      }
      $html .= "<tr>";
      $html .= "<td class='$class'><a href='" . $config->config_url . "' title='" . $config->blurb . "'>" . $config->name . "</a></td>";
      $html .= "<td class='$class' style='text-align:right;'><a href='/common/remove_group_record?group_id=" . $group->id . "&id=" . $config->id . "'>Delete</a></td>";
      $html .= "</tr>";
    }
  } 

  my @bookmarks = $group->bookmark_records;
  if ($#bookmarks > -1) {
    $found = 1;
    foreach my $bookmark (@bookmarks) {
      if ($class) {
        $class = "";
      } else {
        $class = "dark";
      }
      $html .= "<tr>";
      $html .= "<td class='$class'><a href='" . $bookmark->url . "' title='" . $bookmark->description. "'>" . $bookmark->name . "</a></td>";
      $html .= "<td class='$class' style='text-align:right;'><a href='/common/remove_group_record?group_id=" . $group->id . "&id=" . $bookmark->id . "'>Delete</a></td>";
      $html .= "</tr>";
    }
  } 

  if (!$found) { 
    $html .= "<tr><td class='dark' style='text-align:left;'>There are no shared settings for this group</td><td class='dark' style='text-align: right;'><a href='/info/about/sharing.html'>Learn more about sharing &rarr;</a></td></tr>\n";
  }
  $html .= "</table>\n";
  return $html;

}

sub group_users {
  my( $panel, $user) = @_;
  my $cgi = new CGI;
  my $group = EnsEMBL::Web::Object::Group->new(( id => $cgi->param('id') ));
  my $html = "";
  $html .= &info_box($user, "This panel lists all members of this group. You can invite new users to join your group by entering their email address in the 'Invite' tab.", "group_members_info");
  $html .= &group_users_tabview($user, $group);
  $html .= "<br /><br />";
  $panel->print($html);
}

sub info_box {
  my($user, $message, $name) = @_;
  my $found = 0;
  foreach my $record ($user->info_records) {
    if ($record->name eq $name) {
      $found = 1;
    }
  }
  my $html = "";
  if (!$found) {
    $html = "<div class='user_info boxed' id='$name'>";
    $html .= "<div>\n";
    $html .= "<img src='/img/infoicon.gif' width='11' height='11'> " . $message;
    $html .= "</div>\n";
    $html .= "<div style='text-align: right; font-size: 80%;'>\n";
    $html .= "<a href='javascript:void(0);' onclick='hide_info(\"$name\");'>Hide this message</a>";
    $html .= "</div>\n";
    $html .= "</div>\n";
  }
  return $html;
}

sub group_users_tabview {
  my ($user, $group) = @_;
  
  my $manageTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'manage', 
                                     label => 'Group members', 
                                     content => _render_group_users($group) 
                                                ));

  my $inviteTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'invite', 
                                     label => 'Invite', 
                                     content => _render_group_invite($group, $user)
                                                     ));

  my @invites = $group->invite_records;
  my $pendingTab = undef;
  if ($#invites > -1) {
    my $label = "Invited members (" . ($#invites + 1) . ")";
    $pendingTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'pending', 
                                     label => $label, 
                                     content => _render_group_pending(( group => $group, user => $user, invites => \@invites)
                                                     )));
  }

  my $tabview = EnsEMBL::Web::Interface::TabView->new(( 
                                      name => "users",
                                      tabs => [ $manageTab, $pendingTab, $inviteTab ]
                                                     ));

  return $tabview->render;
}

sub _render_group_pending {
  my (%params) = @_;
  my $group = $params{group};
  my $user = $params{user};
  my @invites = @{ $params{invites} };
  my $html = "";
  if ($#invites > -1) {
    my $table = EnsEMBL::Web::Interface::Table->new(( 
                                         class => "ss", 
                                         style => "border-collapse:collapse"
                                                    ));
    foreach my $invite (@invites) {
      my $row = EnsEMBL::Web::Interface::Table::Row->new();
      $row->add_column({ content => $invite->email });
      $row->add_column({ content => ucfirst($invite->status) });
      $row->add_column({ content => "<a href='/common/delete_invite?group_id=" . $group->id . "&invite_id=" . $invite->id . "&user_id=" . $user->id . "'>Delete</a>" });
      $table->add_row($row);
    }

    $html .= $table->render;
  } else {
    $html = "There are no pending memberships for this group.";
  }
  return $html;
}

sub _render_group_users {
  my ($group) = @_;
  my $html = "";
  my @users = @{ $group->users };
  my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss", 
                                       style => "border-collapse:collapse"
                                                  ));
  foreach my $user (@users) {
    my $row = EnsEMBL::Web::Interface::Table::Row->new();
    $row->add_column({ content => $user->name });
    warn "CREATED BY: " . $group->created_by;
    #if ($user->id == $group->created_by) {
    #  $row->add_column({ content => "Owner" });
    #  $row->add_column({ content => "" });
      #$row->add_column({ content => "" });
    #} else {

      if ($user->is_administrator_of($group)) {
        $row->add_column({ content => "Administrator" });
        #$row->add_column({ content => "Demote" });
        $row->add_column({ content => "" });
      } else {
        $row->add_column({ content => "Member" });
        #$row->add_column({ content => "Promote" });
        $row->add_column({ content => "<a href='/common/remove_user?user_id=" . $user->id . "&group_id=" . $group->id . "'>Unsubscribe</a>", align => "right" });
      }

    #}

    $table->add_row($row);
  }

  $html .= $table->render;

  return $html;
}

sub _render_group_invite {
  my ($group, $user) = @_;
  my $html = "<b>Invite a user to join this group</b><br /><br />\n";
  $html .= "<form action='/common/invite' action='post'>\n";
  $html .= "To invite a new member into this group, enter their email address. Users not already registered with Ensembl will be asked to do so before accepting your invite.<br /><br />\n";
  $html .= "<input type='hidden' value='" . $user->id . "' name='user_id' />"; 
  $html .= "<input type='hidden' value='" . $group->id . "' name='group_id' />"; 
  $html .= "<input type='text' value='' size='30' name='invite_email' />"; 
  $html .= "<input type='submit' value='Invite' />";
  $html .= "</form>";
  $html .= "<br />";
  return $html;
}

sub group_general {
  my( $panel, $object) = @_;
  
  my $cgi = new CGI;
  my $group = EnsEMBL::Web::Object::Group->new(( id => $cgi->param('id') ));

  my $html = "<h4>Settings</h4>";

  my $configTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'config', 
                                     label => 'Shared configurations', 
                                     content => _render_group_configs($group) 
                                                ));

  my $bookmarkTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'bookmark', 
                                     label => 'Shared bookmarks', 
                                     content => _render_group_bookmarks($group)
                                                     ));

  my $tabview = EnsEMBL::Web::Interface::TabView->new(( 
                                      name => "config",
                                      tabs => [ $configTab, $bookmarkTab ]
                                                     ));

  $panel->print($html . $tabview->render . "\n");
}

sub _render_group_configs {
  my ($group) = @_;
  my @configurations = $group->configuration_records;
  my $html = "";
  if ($#configurations > -1) {
    $html = render_config_collection({ collection => \@configurations, remove_link => "remove_group_config", group => $group });
  } else {
    $html = "You have not shared any configurations with the group.";
  }
  return $html;
}

sub _render_group_bookmarks {
  my ($group) = @_;
  my @bookmarks = $group->bookmark_records;
  my $html = "";
  if ($#bookmarks > -1) {
    my $table = EnsEMBL::Web::Interface::Table->new(( 
                                         class => "ss", 
                                         style => "border-collapse:collapse"
                                                    ));
    foreach my $bookmark (@bookmarks) {
      my $row = EnsEMBL::Web::Interface::Table::Row->new();
      $row->add_column({ content => "<a href='" . $bookmark->url . "'>" . $bookmark->name . "</a>" });
      $row->add_column({ content => "<a href='/common/remove_group_bookmark?id=" . $bookmark->id . "&group_id=" . $group->id . "'>Remove</a>" });
      $table->add_row($row);  
    }
    $html .= $table->render;
  } else {
    $html = "You have not shared any bookmarks with the group.";
  }
  return $html;
}

sub delete_group {
  my( $panel, $object) = @_;

  my $cgi = new CGI;
  my $group = EnsEMBL::Web::Object::Group->new(( id => $cgi->param('id') ));

  my $html = "<div class='white boxed' id='intro'>\n";
  $html .= "<form action='remove_group' name='remove' id='remove' method='post'>\n";
  $html .= "<input type='hidden' name='group_id' value='" . $group->id . "' />\n";
  $html .= "Delete this group? <input type='button' value='Delete' onClick='reallyDelete()' />";
  $html .= "</form>\n";
  $html .= "</div>\n";
  $html .= "&larr; <a href='accountview'>Back to your account</a>";

  $panel->print($html);
}

sub blurb {
  my( $panel, $object) = @_;

  my $html = qq(
<div class="pale boxed" id="intro">);

  if (my $feedback = $object->param('feedback')) {
    $html .= "<p><strong>$feedback</strong></p>";
  }
  else {
    $html .= qq(
<h4>Your account</h4>
<p>This is your account page. From here you can manage your bookmarks, configurations and groups.</p>
);
  }
  $html .= '</div>';

  $panel->print($html);
  return 1;
}

sub configs {
  my( $panel, $user) = @_;

  my $configTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'config', 
                                     label => 'Configurations', 
                                     content => _render_configs($user) 
                                                ));

  my $newsTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'news', 
                                     label => 'News Filters', 
                                     content => _render_filters($user) 
                                                ));

  my $bookmarkTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'bookmark', 
                                     label => 'Bookmarks', 
                                     content => _render_bookmarks($user)
                                                     ));

  my $tabview = EnsEMBL::Web::Interface::TabView->new(( 
                                      name => "config",
                                      tabs => [ $configTab, $bookmarkTab, $newsTab ]
                                                     ));

  $panel->add_content('left', $tabview->render . "<br />");
}

sub groups {
  my( $panel, $user) = @_;

  my $membershipTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'membership', 
                                     label => 'Membership', 
                                     content => _render_membership($user), 
                                                ));

  my $joinTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'join', 
                                     label => 'Join a group', 
                                     content => _render_join($user) 
                                                     ));

  my $administerTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'administer', 
                                     label => 'Administer groups', 
                                     content => _render_admin($user) 
                                                     ));

  my $tabview = EnsEMBL::Web::Interface::TabView->new(( 
                                      name => "group",
                                      tabs => [
                                                $membershipTab,
                                                $joinTab,
                                                $administerTab,
                                              ]
                                                     ));

  $panel->add_content('left', $tabview->render);

}

sub _render_join {
  my ($user) = @_;
  my $html = "";
  my @groups = @{ EnsEMBL::Web::Object::Group->all_groups_by_type('open') };
  $html .= "<b>Open groups</b><br />";
  if ($#groups > -1) {
    $html .= "The following groups are currently accepting members. Click a group name for more information.<br /><br />";
    my $table = EnsEMBL::Web::Interface::Table->new(( 
                                         class => "ss", 
                                         style => "border-collapse:collapse"
                                                    ));
    foreach my $group (@groups) {
      my $row = EnsEMBL::Web::Interface::Table::Row->new();
      $row->add_column({ content => "<a href='/common/group_info?id=" . $group->id . "'><b>" . $group->name. "</b></a>" });
      if ($user->is_member_of($group) == 1) {
        if ($user->is_administrator_of($group) == 1) {
          $row->add_column({ content => "Administrator (<a href='/common/groupview?id=" . $group->id . "'>View</a>)"});
        } else {
          $row->add_column({ content => "Member (<a href='/common/unsubscribe?id=" . $group->id . "'>Leave</a>)"});
        }
      } else {
        $row->add_column({ content => "<a href='/common/subscribe?id=" . $group->id . "'>Join group</a>"});
      }
      $table->add_row($row);
    }
 
    $html .= $table->render;

  } else {
    $html .= "There are currently no open groups available.";
  }
  #$html .= "<br /><br/ >";
  #$html .= "<b>On request</b><br />";
  #$html .= "Other Ensembl groups are available to join on request. Enter the name of a group to request membership.<br /><br />"; 
  #$html .= "<form action='/common/request_membership' method='post'>\n";
  #my $name_table = EnsEMBL::Web::Interface::Table->new(( 
  #                                       class => "ss", 
  #                                       style => "border-collapse:collapse"
  #                                                  ));
  #my $name_row = EnsEMBL::Web::Interface::Table::Row->new();
  #$name_row->add_column({ content => "Group name: " });
  #$name_row->add_column({ content => "<input type='text' name='group_name' />" });
  #$name_row->add_column({ content => "<input type='submit' value='Request' class='red_button' />" });
  #$name_table->add_row($name_row);
  #$html .= $name_table->render;
  #$html .= "</form>\n";
  return $html;
}

sub _render_admin {
  my ($user) = @_;
  my $html = "";
  my @groups = @{ $user->find_administratable_groups };
  if ($#groups > -1) {
    $html .= "<b>Your groups:</b><br /><br/ >";
    my $table = EnsEMBL::Web::Interface::Table->new(( 
                                         class => "ss", 
                                         style => "border-collapse:collapse"
                                                    ));
    foreach my $group (@groups) {
    my $row = EnsEMBL::Web::Interface::Table::Row->new();
      $row->add_column({ content => $group->name });
      $row->add_column({ content => ucfirst($group->type) });
      $row->add_column({ content => "<a href='/common/groupview?id=" . $group->id . "'>View</a>"});
      $table->add_row($row);
    }

    $html .= $table->render;

  } else {
    $html .= "You are not an administrator of any groups.<br /><br />";
  }
  $html .= "<br /><b><a href='/common/create_group'>Create a new group</a></b>, or <a href='/info/about/accounts.html'>learn more about Ensembl groups</a>.";
  return $html;
}

sub _render_membership {
  my ($user) = @_;
  my @groups = @{ $user->groups };
  my $html = "";
  if ($#groups > -1) {
  $html = "You are a member of the following groups:<br /><br />";
  my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss", 
                                       style => "border-collapse:collapse"
                                                  ));
  foreach my $group (@groups) {
    my $row = EnsEMBL::Web::Interface::Table::Row->new();
    $row->add_column({ content => $group->name });
    if ($user->is_administrator_of($group)) {
      $row->add_column({ content => "Administrator (<a href='/common/groupview?id=" . $group->id . "'>View</a>)"});
    } else {
      $row->add_column({ content => "<a href='/common/unsubscribe?id=" . $group->id . "'>Leave group</a>"});
    }
    $table->add_row($row);
  }

  $html .= $table->render;
  } else {
    $html .= "You are not a member of any Ensembl groups.";
  }

  return $html;
}


sub user_details {
  my( $panel, $user) = @_;
  my $html = "<div class='pale boxed'>";
  $html .= qq(This is your Ensembl account home page. From here you can manage
                your saved settings, update your details and join or create new 
                Ensembl groups.<br /><br />To learn more about how to get the most
                from your Ensembl account, read our <a href='/info/about/accounts.html'>introductory guide</a>.);
  $html .= "</div>";
   
  $panel->print($html);
}

sub user_other_settings {
  my( $panel, $user) = @_;
  my @records = $user->info_records;
  my $html = "";

  if ($#records > -1) {
  $html = "<div class='white boxed'>";
  $html .= qq(<b>Ensembl preferences:</b>);
  $html .= qq(<ul><li><a href='/common/reset_info_boxes'>Show all infomation boxes</a></li></ul>);
  $html .= "</div>";
  }
   
  $panel->print($html);
}

sub user_groups {
  my( $panel, $user) = @_;
  my @groups = @{ $user->groups };
  my $html = "";
  $html .= "<div class='user_setting'>\n";
  $html .= &info_box($user, "You can share settings with other users via Ensembl groups. When subscribed to a group, you have access to that group's shared configurations and bookmarks.", "group_info");
  $html .= render_user_groups($user, @groups);
  $html .= "</div>\n";
  $panel->print($html);
}

sub render_user_groups {
  my ($user, @groups) = @_;
  
  my $html = "";
  $html .= qq(
  <table width='100%' cellpadding='4' cellspacing='0'>
    <tr>
      <td class='settings_header' colspan='4'><b>Groups</b> &middot <a href='/common/create_group'>New group &rarr;</a></td>
    </tr>\n);
  $html .= "</table>";

  my %included = ();
  my $class = "";
  my $found = 0;
  foreach my $group (@groups) {
    $found = 0;
    if (!$class) {
      $class = "dark"; 
    } else {
      $class = ""; 
    }
    $included{$group->id} = "yes"; 

    my @configurations = $group->configuration_records;
    my @bookmarks = $group->bookmark_records;
    my $display = "block";
    my $image = "minus";
    my $found = 0;
    if ( $#configurations > -1 ) {
      $found = 1;
    }
    if ( $#bookmarks > -1 ) {
      $found = 1;
    }

    if (!$found) {
      $display = "none"; 
      $image = "plus";
    }

    $html .= "<div class='" . $class . "' id='group_" . $group->id . "' style='padding: 4px;'>\n"; 
    $html .= "<div style='float: left; width: 50%;' class='group'><a href='javascript:void(0);' onclick='toggle_group_settings(\"" . $group->id . "\");'><img src='/img/" . $image . ".gif' id='group_" . $group->id . "_image' width='11' height='11' alt='Show group settings'></a> ";
    $html .= "<a href='javascript:void(0);' onclick='toggle_group_settings(\"" . $group->id . "\");'>" . $group->name . "</a></div>\n";
    if ($user->is_administrator_of($group)) {
      $html .= "<div style='float: left; text-align: right; width: 50%;'><a href='/common/groupview?id=" . $group->id . "'>Manage group</a></div>\n";
    } else {
      $html .= "<div style='float: left; text-align: right; width: 50%;'><a href='/common/unsubscribe?id=" . $group->id . "'>Unsubscribe</a></div>\n";
    }
    $html .= "<br clear='all' />";

    $html .= "<div id='group_" . $group->id . "_settings' style='display: $display;'>\n";
    foreach my $config (@configurations) {
      $html .= "<ul>\n";
      $html .= "<li><a href='" . $config->config_url . "'>" . $config->name . "</a></li>\n";
      $html .= "</ul>\n";
    }
    foreach my $bookmark (@bookmarks) {
      $html .= "<ul>\n";
      $html .= "<li><a href='" . $bookmark->url . "'>" . $bookmark->name . "</a></li>\n";
      $html .= "</ul>\n";
    }
    if (!$found) {
      $html .= "<div>\n";
      $html .= "<ul>\n";
      $html .= "<li>There are no shared settings for this group. <a href='javascript:void(0);' onclick='toggle_group_settings(\"" . $group->id . "\");'>&uarr;</a></li>\n";
      $html .= "</ul>\n";
      $html .= "</div>\n";
    }
    $html .= "</div>\n";
    $html .= "</div>\n";
  }
  $html .= "<br />";

  $html .= "<table width='100%' cellpadding='4' cellspacing='0'><tr>";

  if ($#groups < 0) {
    $html .= "<td class='dark'>You have not subscribed to any Ensembl groups.</td><td class='dark' style='text-align:right;' colspan='2'><a href='/info/about/groups.html'>Learn more about how to join and start a groups&rarr;</a></td></tr>\n";
  }

  my @all_groups = @{ EnsEMBL::Web::Object::Group->all_groups_by_type('restricted') };
  push @all_groups, @{ EnsEMBL::Web::Object::Group->all_groups_by_type('open') };
  my $first = 1;
  foreach my $group (@all_groups) {
    my $class = "very_dark";
    if (!$included{$group->id}) {
      if ($group->type eq 'restricted') {
        $group->load;
        my @invites = $group->invite_records;
        foreach my $invite (@invites) {
          if ($invite->email eq $user->email && $invite->status eq 'pending') {
            $class = "invite";
            $html .= "<tr>\n";
            $html .= "<td class='$class'>" . $group->name . "</td>";
            $html .= "<td class='$class'>" . $group->description. "</td>";
            $html .= "<td class='$class'><a href='/common/join_by_invite?record_id=" . $invite->id . "&invite=" . $invite->code . "'>Accept invite</a></td>";
            $html .= "</tr>\n";
            $class = "very_dark";
          }
        }
      } else {
        $html .= "<tr>\n";
        if ($first) {
          $class .= " top";
          $first = 0;
        }
        $html .= "<td class='$class'>" . $group->name . "</td>";
        $html .= "<td class='$class'>" . $group->description . "</td>";
        $html .= "<td class='$class' style='text-align: right;'><a href='/common/subscribe?id=" . $group->id . "'>Subscribe</a></td>";
        $html .= "</tr>\n";
      }
    }
  }

  $html .= "</table>\n";
  return $html;
}


sub user_settings {
  my( $panel, $user) = @_;
  my @configurations = $user->configuration_records;
  my @bookmarks = $user->bookmark_records;
  my @admin_groups = @{ $user->find_administratable_groups };
  my $html = "";
  $html .= "<div class='user_setting'>\n";
  $html .= &info_box($user, "You can save custom configurations (DAS sources, decorations, additional drawing tracks, etc), and return to them later or share them with fellow group members. Look for the 'Save configuration link' in the sidebar when browsing Ensembl.", "user_configuration_info");
  $html .= render_user_configuration_table(( user => $user, configurations => \@configurations, admin_groups => \@admin_groups));
  $html .= "</div>\n";

  $html .= "<div class='user_setting'>\n";
  $html .= &info_box($user, "Bookmarks allow you to save frequently used pages from Ensembl and elsewhere. When browsing Ensembl, you can add new bookmarks by clicking the 'Add bookmark' link in the sidebar." , "user_bookmark_info");
  $html .= render_user_bookmark_table(( user => $user, bookmarks => \@bookmarks, admin_groups => \@admin_groups));
  $html .= "</div>\n";
  $panel->print($html);
}

sub toggle_class {
  my $class = shift;
  if ($class) {
    $class = "";
  } else {
    $class = "dark";
  }
}

sub render_user_bookmark_table {
  my (%params) = @_;
  my $user = $params{user};
  my @bookmarks = @{ $params{bookmarks} };
  my @admin_groups = @{ $params{admin_groups } };
  my $is_admin = 0;
  if ($#admin_groups > -1) {
    $is_admin = 1;
  } 
  my $html = qq(
  <table width='100%' cellpadding='4' cellspacing='0'>
    <tr>
      <td class='settings_header' colspan='5'><b>Bookmarks</b> &middot <a href='/common/bookmark?forward=1'>New bookmark &rarr;</a></td>
    </tr>\n);
  my $class = "dark";
  if ($#bookmarks > -1) {
    foreach my $bookmark (@bookmarks) {
      $class = &toggle_class($class);
      $html .= "<tr>";
      $html .= "<td class='$class'><a href='" . $bookmark->url . "' title='" . $bookmark->description . "'>" . $bookmark->name . "</a></td>"; 
      $html .= "<td class='$class' style='text-align:right;'><a href='/common/bookmark?id=" . $bookmark->id . "'>Edit</a></td>"; 
      if ($is_admin) {
      $html .= "<td class='$class' style='text-align:right;'><a href='/common/share_record?id=" . $bookmark->id . "'>Share</a></td>"; 
      }
      $html .= "<td class='$class' style='text-align:right;'><a href='/common/remove_bookmark?id=" . $bookmark->id . "'>Delete</a></td>"; 
      $html .= "</tr>";
    }
  } else {
    $html .= "<tr><td class='dark' style='text-align:left;'>You have not saved any bookmarks.</td><td class='dark' style='text-align: right;'><a href='/info/about/bookmarks.html'>Learn more about saving frequently used pages &rarr;</a></td></tr>\n";
  }
  $html .= "</table>\n";
  return $html;
}

sub render_user_configuration_table {
  my (%params) = @_;
  my $user = $params{user};
  my @configurations = @{ $params{configurations} };
  my @admin_groups = @{ $params{admin_groups } };
  my $html = qq(
  <table width='100%' cellpadding='4' cellspacing='0'>
    <tr>
      <td class='settings_header' colspan='4'><b>Configurations</b></td>
    </tr>);
  my $class = "dark";
  if ($#configurations > -1) {
    foreach my $config (@configurations) {
      $class = &toggle_class($class);
      $html .= "<tr>";
      $html .= "<td class='$class'><a href='" . $config->config_url . "?load_config=" . $config->id . "'>" . $config->name . "</a></td>";
      $html .= "<td class='$class'>" . $config->blurb . "</td>\n";
      $html .= "<td class='$class' style='text-align: right;'><a href='/common/remove_record?id=" . $config->id . "'>Delete</a></td>";
      $html .= "</tr>\n";
    }
  } else {
    $html .= "<tr><td class='dark' style='text-align:left;'>You have not saved any configurations.</td><td class='dark' style='text-align: right;'><a href='/info/about/configurations.html'>Learn more about custom configurations &rarr;</a></td></tr>\n";
  }

  $html .= "</table>\n";

  return $html;
}

sub details {
  ### x
  my( $panel, $user) = @_;

  my $html = sprintf(qq(<div class="boxed" style="max-width: 150px">
<strong>%s</strong>
<ul style="margin: 0px; padding: 5px 15px;">
<li>%s</li>
<li>%s</li>
</ul>
<a href="/common/update?id=%s">Update details</a>
</div>), $user->name, $user->email, $user->organisation, $user->id);

  $panel->add_content('right', $html);
}


sub _render_configs {
  my $user = shift;
  my $html;
  my @configs = $user->configuration_records();
  if ($#configs > -1) {
    $html = render_config_collection({ collection => \@configs, share => 'yes', remove_link => "remove_config" });
    my $found = 0;
    my %group_configs = ();
    my %group_lookups = ();

    foreach my $group (@{ $user->groups }) {
      if (!$group_configs{$group}) {
        $group_configs{$group} = [];
        $group_lookups{$group} = $group;
      }
      my @records = $group->configuration_records;
      if ($#records > -1) {
        $found = 1;
        push @{ $group_configs{$group} }, @records; 
      }
    }
    if ($found) { 
      $html .= "<br /><br /><b>Shared configurations</b><br />";
      my $table = EnsEMBL::Web::Interface::Table->new((
                                         class => "ss tint",
                                         style => "border-collapse:collapse"
                                                    ));

      foreach my $key (sort keys %group_configs) {
        my $row = EnsEMBL::Web::Interface::Table::Row->new();
        my $group = $group_lookups{$key};
        foreach my $config (@{ $group_configs{$key} }) {
          $row->add_column({ content => $config->name });
          $row->add_column({ content => $group->name });
          if ($user->is_administrator_of($group)) {
            $row->add_column({ content => "<a href='/common/remove_group_config?id=" . $config->id . "&group_id=" . $group->id . "'>Remove</a>" });
          } else {
            $row->add_column({ content => "" });
          }
        }
        $table->add_row($row);
      }

      $html .= $table->render;

    }
  } else {
    $html = "You do not have any saved configurations.";
  } 
  return $html;
}

sub render_config_collection {
  my ($params) = @_;
  my @configs = @{ $params->{collection} };
  my $share = $params->{share};
  my $link = $params->{remove_link};
  my $group = $params->{group};
  my $html = "";
  my $view_mapping = { "contigviewbottom" => "contigview" };
  my $table = EnsEMBL::Web::Interface::Table->new(( 
                                     class => "ss tint", 
                                     style => "border-collapse:collapse"
                                                ));
  foreach my $record (@configs) {
    my $config_string = $record->config;
    $config_string  =~ s/&quote;/'/g;
    my $config = eval($config_string);
    my $views = "";
    foreach my $view (keys %{ $config }) {
      $views .= ucfirst($view_mapping->{$view}) . ", ";
    }
    $views =~ s/, //;
    my $row = EnsEMBL::Web::Interface::Table::Row->new();
    $row->add_column({ width => "16px", content => "<img src='/img/bullet_star.png' width='16' height='16' />" });
    $row->add_column({ content => "" . $record->name . "" });
    $row->add_column({ content => "$views" });
    if ($share) {
      $row->add_column({ content => "<a href='/common/share_record?id=" . $record->id . "'>Share</a>" });
    }
    my $extra = "";
    if ($group) {
      $extra = "&group_id=" . $group->id; 
    }
    $row->add_column({ content => "<a href='/common/" . $link . "?id=" . $record->id . "$extra'>Delete</a>" });
    $table->add_row($row);
  }

  $html = $table->render;
  return $html;
}

sub _render_bookmarks {
  my $user = shift;
  my $html;

  my @bookmarks = $user->bookmark_records({ order_by => 'click' });
  my @admin_groups = @{ $user->find_administratable_groups };

  if (@bookmarks) {
    my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss tint", 
                                       style => "border-collapse:collapse"
                                                  ));
    foreach my $record (@bookmarks) {
      my $row = EnsEMBL::Web::Interface::Table::Row->new();
      $row->add_column({ width => '16px', content => '<img src="/img/bullet_star.png" width="16" height="16" />' });
      $row->add_column({ content => '<a href="' . $record->url. '" title="' . $record->description . '">' .$record->name . '</a>' });
      $row->add_column({ content => '<a href="/common/bookmark?id=' . $record->id . '">Edit</a>' });
      if ($#admin_groups > -1) {
        $row->add_column({ content => '<a href="/common/share_record?id=' . $record->id . '">Share</a>' });
      }
      $row->add_column({ content => '<a href="/common/remove_bookmark?id=' . $record->id . '">Delete</a>' });
      $table->add_row($row);
    }
 
    $html = $table->render; 
  } else {
    $html = "You do not have any bookmarks saved. <a href='/common/bookmark?forward=1'>Add a new bookmark &rarr;</a>";
  } 

  my @groups = @{ $user->groups };
  if (@groups) {
    my $found = 0;
    my %group_bookmarks = ();
    my %group_lookup = ();
    foreach my $group (@groups) {
      if (!$group_bookmarks{$group} ) {
        $group_bookmarks{$group} = [];
        $group_lookup{$group} = $group;
      }
      my @records = $group->bookmark_records;
      if ($#records > -1) {
        $found = 1;
        push @{ $group_bookmarks{$group} }, @records; 
      }
    }

    if ($found) {
      $html .= "<br /><br /><b>Shared bookmarks</b><br />";
      my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss tint", 
                                       style => "border-collapse:collapse"
                                                  ));
      foreach my $key (keys %group_bookmarks) {
        my $group = $group_lookup{$key};
        foreach my $record (@{ $group_bookmarks{$key} }) { 
          my $row = EnsEMBL::Web::Interface::Table::Row->new();
          $row->add_column({ content => "<a href='" . $record->url . "' title='" . $record->description . "'>" . $record->name . "</a>" });
          $row->add_column({ content => $group->name });
          if ($user->is_administrator_of($group)) {
            $row->add_column({ content => "<a href='/common/bookmark?id=" . $record->id . "&class=group'>Edit</a>" }); 
            $row->add_column({ content => "<a href='/common/remove_group_bookmark?id=" . $record->id . "&group_id=" . $group->id . "'>Remove</a>" }); 
          } else {
            $row->add_column({ content => "" });
            $row->add_column({ content => "" });
          }
          $table->add_row($row);
        }
      }
      $html .= $table->render;
    }
    
  }

  return $html;
}

sub _render_filters {
  my $user = shift;
  my $html;

  my @filters = $user->news_records;
  if (@filters) {
    my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss tint", 
                                       style => "border-collapse:collapse"
                                                  ));
    foreach my $record (@filters) {
      my $row = EnsEMBL::Web::Interface::Table::Row->new();
      $row->add_column({ width => "16px", content => "<img src='/img/bullet_star.png' width='16' height='16' />" });
      if ($record->species) {
        $row->add_column({ content => $record->species });
      }
      elsif ($record->topic) {
        $row->add_column({ content => $record->topic });
      }
      $row->add_column({ content => "<a href='/common/filter_news?id=" . $record->id . "'>Edit</a>" });
      $table->add_row($row);
    }
 
    $html = $table->render; 
  }
  else {
    $html = qq(You do not have any news filters set up. <a href="/common/filter_news">Add a filter</a>);
  } 
  return $html;
}

sub denied {
  my( $panel, $object ) = @_;

## return the message
  my $html = qq(<p>Sorry - this page requires you to be logged into your Ensembl user account and to have the appropriate permissions. If you cannot log in or need your access privileges changed, please contact <a href="mailto:webmaster\@ensembl.org">webmaster\@ensembl.org</a>. Thank you.</p>);

  $panel->print($html);
  return 1;
}
=cut

##-----------------------------------------------------------------
## USER REGISTRATION COMPONENTS    
##-----------------------------------------------------------------

sub add_group {
  my ($panel, $user) = @_;
  my $html = qq(<div class="formpanel" style="width:50%">);
  $html .= "You can create a new Ensembl group from here. Ensembl groups";
  $html .= "allow you to share customisations and settings between collections";
  $html .= " of users.<br /><br />";
  $html .= "Setting up a new group takes about 2 minutes.";
  $html .= "<br />";
  $html .= $panel->form('add_group')->render();
  $html .= qq(</div>);
  $panel->print($html);
  return 1;
}

sub group_settings {
  my ($panel, $user) = @_;
  my $html = qq(<div class="formpanel" style="width:50%">);
  $html .= "Group settings.";
  $html .= "<br />";
  $html .= $panel->form('group_settings')->render();
  $html .= qq(</div>);
  $panel->print($html);
  return 1;
}

sub login {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:50%">);
  $html .= $panel->form('login')->render();
  $html .= qq(<p><a href="/common/register">Register</a> | <a href="/common/lost_password">Lost password</a></p>);
  #$html .= $panel->form('enter_details')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub enter_details   { 
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if (!$object->id) { ## new registration
    $html .= qq(<p><strong>Register with Ensembl to bookmark your favourite pages, manage your BLAST tickets and more!</strong></p>);
  }

  $html .= $panel->form('enter_details')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub preview           { _wrap_form($_[0], $_[1], 'preview'); }

sub enter_password      { 
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if ($object->param('code')) { ## resetting lost password
    $html .= qq(<p><strong>Please enter a new password to reactivate your account.</strong></p>);
  }

  $html .= $panel->form('enter_password')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub enter_email {
  my ( $panel, $object ) = @_;
  
  my $help_email  = $object->species_defs->ENSEMBL_HELPDESK_EMAIL;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= qq(<p>Please note that information on resetting your password will be emailed to your <strong>current registered email address</strong>. If you have changed your email address as well as losing your password, please contact <a href="mailto:$help_email">$help_email</a> for assistance. Thank you.</p>);
  $html .= $panel->form('enter_email')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub thanks_lost {
  my ( $panel, $object ) = @_;
  my $exp_text = $panel->{wizard}->data('exp_text');

  my $html = qq(<p>An activation code has been sent to your registered email address; follow the enclosed instructions to log back in and reset your password.</p>
<p>Please note that the code expires after $exp_text.</p>
);
    
  $panel->print($html);
  return 1;
}


sub thanks_reg {
  my ( $panel, $object ) = @_;
  my $exp_text = $panel->{wizard}->data('exp_text');

  my $website   = $ENV{'SERVER_SITETYPE'};
  my $html =  qq(<p>Thank you for registering with $website. An email has been sent to your address with an activation code; follow the instructions to return to this website and activate your new account.</p>
<p>Please note that the code expires after $exp_text.</p>
);

  $panel->print($html);
  return 1;
}


##-----------------------------------------------------------------
## USER CUSTOMISATION COMPONENTS    
##-----------------------------------------------------------------

sub select_bookmarks {
  my ( $panel, $object) = @_;

  ## Get the user's bookmark list
  my $id = $object->get_user_id;
  my @bookmarks = @{$object->get_bookmarks($id)};

  my $html = qq(<div class="formpanel" style="width:80%">);
  if (scalar(@bookmarks)) {
    $html .= $panel->form('select_bookmarks')->render();
  }
  else {
    $html .= qq(<p>You have no bookmarks set at the moment. To set a bookmark, go to any Ensembl content page whilst logged in (any 'view' page such as GeneView, or static content such as documentation), and click on the "Bookmark this page" link in the lefthand menu.</p>);
  }
  $html .= '</div>';
  
  $panel->print($html);
  return 1;
}

sub name_bookmark     { _wrap_form($_[0], $_[1], 'name_bookmark'); }

sub select_configs {
  my ( $panel, $object) = @_;

  ## Get the user's bookmark list
  my $id = $object->get_user_id;
  my @configs = @{$object->get_configs($id)};

  my $html = qq(<div class="formpanel" style="width:80%">);
  if (scalar(@configs)) {
    $html .= $panel->form('select_configs')->render();
  }
  else {
    $html .= qq(<p>You have no configurations saved in your account at the moment. To save a configuration, go to any configurable Ensembl 'view' (such as ContigView) whilst logged in, and click on the "Save this configuration" link in the lefthand menu.</p>);
  }
  $html .= '</div>';
  
  $panel->print($html);
  return 1;
}

sub name_config     { _wrap_form($_[0], $_[1], 'name_config'); }

sub show_groups     { _wrap_form($_[0], $_[1], 'show_groups'); }

sub groupview {
  my( $panel, $user) = @_;
  my $webgroup_id = $user->param('webgroup_id');
  my $group = $user->find_group_by_group_id($webgroup_id);

  my $group_name    = $group->name;
  my $group_blurb   = $group->blurb;
  my $member_level  = $user->is_administrator_of($group) ? "Administrator" : "Member";  
  my $creator_name  = $group->find_user_by_user_id($group->created_by)->name; 
  my $creator_org   = $group->find_user_by_user_id($group->created_by)->organisation; 
  my $created_at    = localtime($group->created_at);
  my $modifier_name = $group->find_user_by_user_id($group->modified_by)->name; 
  my $modifier_org  = $group->find_user_by_user_id($group->modified_by)->organisation; 
  my $modified_at   = localtime($group->modified_at);

  my $html = qq(
<h4>Group name - $group_name</h4>
<p>$group_blurb</p>);

  if ($member_level eq 'Administrator' || $member_level eq 'superuser') {
    ## extra info and options for admins
    $html .= qq(<p><strong>Group created by</strong>: $creator_name ($creator_org) at $created_at);
    if ($modifier_name) {
      $html .= qq(<br /><strong>Details modified by</strong>: $modifier_name ($modifier_org) at $modified_at);
    }
    $html .= qq(</p>
<a href="/common/group_details?node=edit_group;webgroup_id=$webgroup_id">Edit group details</a> | <a href="/common/manage_members?webgroup_id=$webgroup_id">Manage member list</a></p>);
  }

  $html .= qq(<h4>Your membership status</h4>
<p>$member_level</p>
<h4>Stored configurations for this group</h4>
<p>[List for members, form for admins]</p>
<h4>Private pages for this group</h4>
<p>[List for members, form for admins]</p>
);

  $panel->print($html);
  return 1;
}

sub edit_group  { _wrap_form($_[0], $_[1], 'edit_group'); }

sub admin_groups {
}

sub show_members {
  my( $panel, $user) = @_;
  my $group = $user->find_group_by_group_id($user->param('webgroup_id'));
  my @users = @{ $group->find_users_by_status('active') };
  my @pending_users = @{ $group->find_users_by_status('pending') };
  my $html = "'" . $group->name . "' has " . ($#users + 1) . "active user" . ("s" ? $#users > 0 : ""); 
  if (@pending_users) {
    my $html .= "(" + ($#pending_users + 1) + " pending requests)";
  } 

  $panel->print($html);
  return 1;
}

1;

