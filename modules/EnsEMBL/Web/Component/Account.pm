package EnsEMBL::Web::Component::Account;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Form;

use CGI;

use strict;
use warnings;
no warnings "uninitialized";

our @ISA = qw( EnsEMBL::Web::Component);

sub edit_link {
  my ($self, $module, $id, $text) = @_;
  $text = 'Edit' if !$text;
  return sprintf(qq(<a href="/Account/%s?dataview=edit;id=%s">%s</a>), $module, $id, $text);
} 

sub delete_link {
  my ($self, $module, $id, $text) = @_;
  $text = 'Delete' if !$text;
  return sprintf(qq(<a href="/Account/%s?dataview=delete;id=%s">%s</a>), $module, $id, $text);
} 


sub share_link {
  my ($self, $call, $id) = @_;
  return sprintf(qq(<a href="/Account/SelectGroup?id=%s;type=%s">Share</a>), $id, $call);
} 


########################### OLD CODE! #################################

=pod

sub _render_invites_for_group {
  ### Additional rows for group tab, displaying invitations
  my ($group, $user) = @_;
  my $html = "";
  my $class = "";
  if ($group->type eq 'restricted') {
    my @invites = $group->invites;
    foreach my $invite (@invites) {
      if ($invite->email eq $user->email && $invite->status eq 'pending') {
        $class = "invite";
        $html .= "<tr>\n";
        $html .= "<td class='$class'>" . $group->name . "</td>";
        $html .= "<td class='$class'>" . $group->blurb . "</td>";
        $html .= "<td class='$class' style='text-align:right'><a href='/Account/_accept?record_id=" . $invite->id . "&invite=" . $invite->code . "'>Accept invite</a> or <a href='/Account/_remove_invite?id=" . $invite->id . "'>decline</a></td>";
        $html .= "</tr>\n";
        $class = "very_dark";
      }
    }
  }
  return $html;
}

sub _render_public_groups {
  ## Additional content for groups tab - NB Not currently in use
  my ($user, $included) = @_;
  my %included = ();
  my $html = "";
  if ($included) {
    %included = %{ $included }; 
  }
  my @all_groups = EnsEMBL::Web::Data::Group->search(type => 'open');
  if ($#all_groups > -1) {
    $html = "<h5>Publicly available groups</h5>";
    $html .= "<table width='100%' cellpadding='4' cellspacing='0'><tr>";

    my $class = "bg1";
    ## TODO: remove this sorting to mysql query
    foreach my $group (sort {$a->name cmp $b->name} @all_groups) {
      if (!$included{$group->id}) {
        $class = &toggle_class($class);
        $html .= "<tr>\n";
        $html .= "<td class='$class' width='25%'>" . $group->name . "</td>";
        $html .= "<td class='$class'>" . $group->description . "</td>";
        $html .= "<td class='$class' style='text-align: right;'><a href='/Account/_subscribe?id=" . $group->id . "'>Subscribe</a></td>";
        $html .= "</tr>\n";
      }
    }

    $html .= "</table>\n";
  }
  return $html;
}


##--------------------------------------------------------------------------------------------------
## GROUPVIEW COMPONENTS
##--------------------------------------------------------------------------------------------------

sub no_group {
  ### Error message if group id not found
  my ($panel, $user) = @_;

  my $html = qq(<p>No group was specified. Please go back to your <a href="/Account/Details">account home page</a> and click a "Manage group"
link for a group you created.</p>);

  $panel->print($html);
  return 1;
}

sub groupview {
  ### Selects appropriate components for groupview page, based on user's permissions
  my( $panel, $object) = @_;
  my $webgroup_id = $object->param('id');
  my $group = EnsEMBL::Web::Data::Group->new($webgroup_id);
  my $user  = $ENSEMBL_WEB_REGISTRY->get_user;

  my $html;
  if ($user->is_administrator_of($group)) {
    $html .= admin_intro();
    $html .= group_details($group, $user, 'Administrator');
    $html .= group_records($object, 1);
    $html .= delete_group($webgroup_id);
  }
  else {
    $html .= member_intro();
    $html .= group_details($group, $user, 'Member');
    $html .= group_records($object);
  }
  $panel->print($html);
  return 1;
}

sub admin_intro {
  ### Group administrator's blurb
  my( $panel, $user) = @_;
  my $html = "<div class='pale boxed'>";
  $html .= qq(<p>This page allows administrators to manage their $sitename group. From here you can invite new users to join your group, remove existing users, and decide which resources are shared between group members.</p>
                <p>For more information about $sitename groups, and how to use them,
                read the <a href='/info/about/groups.html'>introductory guide</a>.</p>);
  $html .= "</div>";
   
  return $html;
}

sub member_intro {
  ### Group member's blurb
  my( $panel, $user) = @_;
  my $html = "<div class='pale boxed'>";
  $html .= qq(<p>This page displays $sitename group information.<p>
                <p>For more information about $sitename groups, and how to use them,
                read the <a href='/info/about/groups.html'>introductory guide</a>.</p>);
  $html .= "</div>";
   
  return $html;
}

sub group_details {
  ### Details about this group and user's membership
  my( $group, $user, $level) = @_;

  my $group_id      = $group->id;
  my $group_name    = $group->name;
  my $group_blurb   = $group->blurb;
  my $creator       = $group->find_user_by_user_id($group->created_by);
  my $modifier      = $group->find_user_by_user_id($group->modified_by);
  my $creator_name  = $creator->name; 
  my $creator_org   = $creator->organisation; 
  my $created_at    = pretty_date($group->created_at);

  my $html = qq(<h3 class="plain">$group_name</h3>\n<p>$group_blurb</p>\n);
  if ($level eq 'Administrator') {
    $html .= qq(<p><a href="/Account/ManageGroup?dataview=edit;id=$group_id">Edit group description</a></p>);
  }
  if ($group->type ne 'open') {
    $html .= qq(<p><strong>Group created by</strong>: $creator_name ($creator_org));
  }
  if ($level eq 'Administrator') {
    ## extra info and options for admins
    $html .= qq( on $created_at);
    if ($modifier) {
      my $modifier_name = $modifier->name; 
      my $modifier_org  = $modifier->organisation; 
      my $modified_at   = $group->modified_at_pretty;
      $html .= qq(<br /><strong>Details modified by</strong>: $modifier_name ($modifier_org) on $modified_at);
    }
  }
  $html .= qq(</p>\n<p><strong>Your membership status</strong>: $level</p>\n);


  return $html;
}

sub group_records {
  my($object, $is_owner) = @_;
  my $user  = $ENSEMBL_WEB_REGISTRY->get_user;
  my $group = EnsEMBL::Web::Data::Group->new($object->param('id'));
  my $html;
  if ($is_owner) {
    $html = qq(<h3 class="plain">Membership and Shared Resources</h3>\n);
    $html .= group_management_tabs($object, $group, $user);
  }
  else {
    $html = qq(<h3 class="plain">Shared Resources</h3>\n);
    $html .= _render_group_settings($group, $user, 'group');
  }
  $html .= "<br />";
  $html .= "&larr; <a href='/Account/Details'>Back to your account</a>";
  $html .= "<br /><br />";
  return $html;
}

sub group_management_tabs {
  my( $object, $group, $user) = @_;
  
  my $manageTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'manage', 
                                     label => 'Group members', 
                                     content => _render_group_users($group, $user, $object->param('show_all')) 
                                                ));

  my $settingsTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'sharedsettings', 
                                     label => 'Shared settings', 
                                     content => _render_group_settings($group, $user, 'user') 
                                                ));

  my $inviteTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'invite', 
                                     label => 'Invite', 
                                     content => _render_group_invite($group)
                                                     ));

  my @invites = $group->invites;
  my @pending;
  foreach my $invitation (@invites) {
    push @pending, $invitation if $invitation->status eq 'pending';
  }
  my $pendingTab = undef;
  if ($#pending > -1) {
    my $label = "Invitations pending (" . ($#pending + 1) . ")";
    $pendingTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'pending', 
                                     label => $label, 
                                     content => _render_group_pending(( group => $group, user => $user, invites => \@pending)
                                                     )));
  }

  my $tabview = EnsEMBL::Web::Interface::TabView->new(( 
                                      name => "groups",
                                      tabs => [ $manageTab, $settingsTab, $pendingTab, $inviteTab ]
                                                     ));


  my @opentabs = $user->opentabs;
  if ($#opentabs > -1) {
    foreach my $opentab (@opentabs) {
      if ($opentab->name eq $tabview->name) { 
        $tabview->open($opentab->tab);
      } 
    }
  } 

  ## Override previous saved settings if necessary
  if ($object->param('tab')) {
     $tabview->open($object->param('tab'));
  }

  return $tabview->render;
}

sub _render_group_settings {
  ### Renders shared settings tab content
  my ($group, $user, $ident) = @_;
  my @bookmarks      = $group->bookmarks;
  my @configurations = $group->configurations;
  my @notes          = $group->annotations;
  my $html = "";
  if ($#bookmarks > -1) {
    $html .= "<h5>Bookmarks</h5>\n";
    my @records = ();
    foreach my $bookmark (@bookmarks) {
      my $description = $bookmark->description || '&nbsp;';
      my $data =  ['<a href="' . $bookmark->url . '" title="' . $bookmark->description . '">' . $bookmark->name . '</a>'];
      if ($ident eq 'group') {
        push @$data, $description;
      } else {
        push @$data, '';
      }

      push @records, {
        'id'       => $bookmark->id, 
        'group_id' => $group->id,
        'sortable' => $bookmark->name,
        'ident'    => $ident,
        'edit_url' => 'bookmark', 
        'data'     => $data,
      };

    }
    $html .= _render_settings_table(\@records);
  }

  if ($#configurations > -1) {
    $html .= "<h5>Configurations</h5>\n";
    my @records = ();
    foreach my $configuration (@configurations) {
      my $description = $configuration->description || '&nbsp;';
      my $link = "<a href='#' onclick='javascript:load_config_link(" . $configuration->id . ");'>";
      push @records, {  'id' => $configuration->id, 
                        'group_id' => $group->id,
                        'sortable' => $configuration->name,
                        'ident'    => $ident,
                        'edit_url' => 'configuration', 
                        'data' => [
                          $link . $configuration->name . '</a>', '&nbsp;' 
                        ]};
    }
    $html .= _render_settings_table(\@records);
  }

  return $html;
}


sub _render_group_users {
  my ($group, $admin, $show_all) = @_;
  my $html;
  $html .= &info_box($admin, "This panel lists all members of this group. You can invite new users to join your group by entering their email address in the 'Invite' tab.", "group_members_info");
  my @users = $group->members;
  my $table = EnsEMBL::Web::Interface::Table->new( 
    class => 'ss', 
    style => 'border-collapse:collapse',
  );
  
  foreach my $user (@users) {
    next if ($show_all ne 'yes' && $user->member_status ne 'active');
    my $row = EnsEMBL::Web::Interface::Table::Row->new();
    $row->add_column({ content => $user->name });
    my $member_details = ucfirst($user->level);
    if ($user->level ne 'active') {
      $member_details .= ' ('.$user->member_status.')';
    }
    $row->add_column({ content => $member_details });
    if ($user->id eq $ENV{'ENSEMBL_USER_ID'}) {
      $row->add_column({ content => qq(<a href="/common/user/change_status?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_status=inactive">Unsubscribe</a> (N.B. You will no longer have any access to this group!)), align => 'right' });
      ## Needed for table neatness!
      $row->add_column({ content => '&nbsp;'});
      $row->add_column({ content => '&nbsp;'});
    }
    else {
      if ($user->member_status eq 'active') { 
        if ($user->level eq 'member') {
          $row->add_column({ content => qq(<a href="/Account/_change_level?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_level=administrator">Promote to Admin</a>), align => 'right' });
        } 
        else {
          $row->add_column({ content => qq(<a href="/Account/_change_level?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_level=member">Demote to Member</a>), align => 'right' });
        }
        $row->add_column({ content => qq(<a href="/Account/_change_status?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_status=none">Remove</a>), align => 'right' });
      }
      if ($user->member_status eq 'barred') {
        $row->add_column({ content => qq(<a href="/Account/_change_status?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_status=active">Re-admit</a>), align => 'right' });
      }
      elsif ($user->member_status eq 'inactive') {
        $row->add_column({ content => qq(<a href="/Account/Invite?invite_email=) . $user->email . qq(;id=) . $group->id . qq(">Re-invite</a>), align => 'right' });
      }
      else {
        $row->add_column({ content => qq(<a href="/Account/_change_status?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_status=barred">Ban</a>), align => 'right' });
      }
    }
    $table->add_row($row);
  }

  $html .= $table->render;
  if ($show_all && $show_all eq 'yes') {
    $html .= qq(<p><a href="/Account/Group?id=).$group->id.qq(;show_all=no">Hide non-active members</a></p>);
  }
  else {
    $html .= qq(<p><a href="/Account/Group?id=).$group->id.qq(;show_all=yes">Show non-active members</a> (if any)</p>);
  }

  return $html;
}

sub _render_group_invite {
  my $group = shift;
  my $html = qq(<h4>Invite a user to join this group</h4>
<form action="/Account/Invite" action="post">
<p>To invite a new member into this group, enter their email address. Accounts not already registered with $sitename will be asked to do so before accepting your invite.</p>
<input type="hidden" value=") . $group->id . qq(" name="id" /> 
<p><textarea name="invite_email" cols="35" rows="6"></textarea><br />Multiple email addresses can be separated by commas.</p>
<p><input type="submit" value="Invite" /></p>
</form>);
  return $html;
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
      $row->add_column({ content => '<a href="/Account/_remove_invitation?id=' . $invite->id . ';group_id=' . $group->id . '">Delete</a>' });
      $table->add_row($row);
    }

    $html .= $table->render;
  } else {
    $html = "There are no pending memberships for this group.";
  }
  return $html;
}

sub delete_group {
  ### Bottom panel on groupview, to delete the group!
  my $group_id = shift;

  my $html = "<div class='white boxed' id='intro'>\n";
  $html .= "<form action='/Account/_remove_group' name='remove' id='remove' method='post'>\n";
  $html .= "<input type='hidden' name='id' value='" . $group_id . "' />\n";
  $html .= "Delete this group? <input type='button' value='Delete' onClick='reallyDelete()' />";
  $html .= "</form>\n";
  $html .= "</div>\n";

  return $html;
}

sub invitation_nonpending {
  my ($panel, $object) = @_;
  my $status = $object->param('status');
  my $html;
  if ($status eq 'accepted') {
    $html = qq(<p>This invitation seems to have been accepted already. Please <a href="/Account/Details">go to your account</a> or <a href="/Account/Login">log in</a> to check your group membership details.</p>);
  }
  else {
    $html = qq(<p>Sorry, there was a problem with the invitation record in our database. Please contact the person who invited you to get a new invitation.</p>);
  }

  $panel->print($html);
}

sub invitations {
  my ($panel, $object) = @_;

  my $group_id = $object->param('id');

  my $html = qq(<p>The following addresses have been checked and invitations sent where appropriate:</p>
<table class="ss">
<tr class="ss-header"><th>Email address</th><th>Invitation sent?</th><th>Notes</th></tr>);

  my $group = EnsEMBL::Web::Data::Group->new($group_id);
  my $bg = 'bg1';
  my $count = 1;

  foreach my $invitation ($group->invites) {

    if ($count % 2 == 0) {
      $bg = 'bg2';
    }
    else {
      $bg = 'bg1';
    }
    $html .= '<tr class="$bg"><td>'. $invitation->email .'</td><td>';
    if ($invitation->status eq 'invited') {
      $html .= 'No</td><td>Already invited';
    }
    elsif ($invitation->status eq 'active') {
      $html .= 'No</td><td>Already a member of this group';
    }
    elsif ($invitation->status eq 'barred') {
      $html .= 'No</td><td>This user has been barred from this group';
    }
    elsif ($invitation->status eq 'inactive') {
      $html .= 'Yes</td><td>This user is a former member of this group';
    }
    elsif ($invitation->status eq 'exists') {
      $html .= 'Yes</td><td>Registered user';
    }
    else {
      $html .= 'Yes</td><td>Not yet registered';
    }
    $html .= "</td></tr>\n";
    $count++;

  }
  $html .= qq(</table>
<p>&larr; <a href="/Account/Group?id=$group_id">Back to group details</a></p>);

  $panel->print($html);
}
=cut

##--------------------------------------------------------------------------------------------------
## MISCELLANEOUS COMPONENTS
##--------------------------------------------------------------------------------------------------

sub message {
  ### Displays a message (e.g. error) from the Controller::Command::Account module
  my ($panel, $object) = @_;
  my $command = $panel->{command};

  my $html;
  if ($command->get_message) {
    $html = $command->get_message;
  }
  else {
    $html = '<p>'.$command->filters->message.'</p>';
  }
  $panel->print($html);
}

sub info_box {
  ### Wrapper for infobox content
  my($self, $user, $message, $name) = @_;
  my $found = 0;
=pod
  foreach my $info ($user->infoboxes) {
    if ($info->name eq $name) {
      $found = 1;
    }
  }
=cut
  my $html = "";
  if (!$found) {
    $html = qq(<div id="$name" class="tinted-box info-box">
  <p><img src="/img/infoicon.gif" style="width:11px;height:11px;float:left;margin:4px;" />$message</p>
  <div class="right small">
  <a href="#" onclick="hide_info('$name');">Hide this message</a>
  </div>
</div>);
  }
  return $html;
}


1;

