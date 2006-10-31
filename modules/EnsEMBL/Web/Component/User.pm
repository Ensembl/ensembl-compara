package EnsEMBL::Web::Component::User;

use EnsEMBL::Web::Component;

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

##-----------------------------------------------------------------

sub accountview {
  my( $panel, $object ) = @_;

  my $id = $object->get_user_id;
  my %details = %{$object->get_user_by_id($id)};

## Get the user's full name
  my $name  = $details{'name'};
  my $email = $details{'email'};
  my $org   = $details{'org'};
  my $caption = "Account Details - $name";
  $panel->caption($caption);

  my $html;
 # $html .= _show_details($panel, $object, $id);
  $html .= _show_bookmarks($panel, $object, $id);
  $html .= _show_groups($panel, $object, $id);
  #$html .= _show_configs($panel, $object, $id);
  #$html .= _show_blast($panel, $object, $id);

  $panel->print($html);
  return 1;
}

sub _show_details {
  my( $panel, $object, $id ) = @_;

  my %details = %{$object->get_user_by_id($id)};

## Get the user's full name
  my $name  = $details{'name'};
  my $email = $details{'email'};
  my $org   = $details{'org'};

## return the message
  my $html = "<h3>Personal details</h3>";

  $html .= qq(<p><strong>Name</strong>: $name</p>
<p><strong>Email address</strong>: $email</p>
<p><strong>Organisation</strong>: $org</p>
<p><a href="/common/update_account">Update account details</a> | <a href="/common/set_password">Change password</a></p>);

  return $html;
}

sub _show_groups {
  my( $panel, $user, $id ) = @_;
  #my $groups = $user->get_membership({'user_id'=>$id});
  my @groups = @{ $user->groups };
  my $html .= "<h3>Groups</h3>";
  $html .= "Ensembl users can join together to share configuration settings and other information as groups. Your groups are listed below."; 
  $html .= "<ul>\n";

  foreach my $group (@groups) {
    my $group_id      = $group->id;
    my $group_name    = $group->name;
    my $member_level  = $group->level;
    my $member_status = $group->status;
    if ($member_status eq 'active' || $member_status eq 'pending') {
      $html .= qq(<li><a href="/common/group_details?webgroup_id=$group_id">$group_name</a>); 
      if ($member_level ne 'member') {
        $html .= " ($member_level)";
      }
      if ($member_status eq 'pending') {
         $html .= " - awaiting approval of application to join";
      }
      $html .= '</li>';
    }
  }

  $html .= "</ul>\n";
  $html .= qq(<p><a href="/common/join_a_group">Join another group &rarr;</a></p>
<p><a href="/common/group_details?node=edit_group">Start your own group &rarr;</a></p>);
  return $html;
}

#---------------------- BOOKMARKS ------------------------------------------------------

sub _show_bookmarks {
  my( $panel, $object, $id ) = @_;
  my $editable = $panel->ajax_is_available;

  ## Get the user's bookmark list
  my @bookmarks = $object->bookmark_records;

  ## return the message
  my $html = "<h3>Bookmarks</h3>\n";

  if (scalar(@bookmarks) > 0) {
    if ($editable) {
      $html .= _show_editable_bookmarks(@bookmarks);
    } else {
      $html .= _show_static_bookmarks(@bookmarks);
    }
  }
  else {
    $html .= "<p>You have no bookmarks set.</p>";
  }

  return $html;
}

sub _show_static_bookmarks {
    my @bookmarks = @_;
    my $html = "<ul>\n";
    foreach my $bookmark (@bookmarks) {
      my $name = $bookmark->name;
      my $url  = $bookmark->url;
      $html .= qq(<li><a href="$url">$name</a></li>);
    }
    $html .= qq(</ul>
<p><a href="/common/manage_bookmarks">Manage bookmarks</a></p>);
    return $html;
}

sub _show_editable_bookmarks {
    my @bookmarks = @_;
    my $html = "<div><p>Mouse over a bookmark name for edit and delete options.</p>";
    my $count = 0;
    foreach my $bookmark (@bookmarks) {
      my $name = $bookmark->name;
      my $url  = $bookmark->url;
      $html .= _inplace_editor_for_bookmarks($count, $bookmark) . qq(
<div class='bookmark_item' onmouseover="show_manage_links('bookmark_manage_$count')" onmouseout="hide_manage_links('bookmark_manage_$count')" id='bookmark_$count'><span class='bullet'><img src='/img/red_bullet.gif' width='4' height='8'></span><a href="$url" title='$url' id='bookmark_name_$count'>$name</a>) . _manage_links($count, $bookmark) . qq(</div>);
      $count++;
    }
    $html .= "</div>";
    return $html;
}

sub _manage_links {
  my ($id, $bookmark) = @_;
  my $bookmark_id   = $bookmark->id;
  my $user_id = $ENV{'ENSEMBL_USER_ID'}; 
  my $html = qq(<div class="bookmark_manage" style='display: none;' id='bookmark_manage_$id'><a href='#' onclick='javascript:show_inplace_editor($id);'>edit</a> &middot; <a href='#' onclick='javascript:delete_bookmark($id, $bookmark_id, $user_id)'>delete</a></div>);
  return $html;
}

sub _inplace_editor_for_bookmarks {
  my ($id, $bookmark) = @_;
  my $bookmark_id   = $bookmark->id;
  my $bookmark_name   = $bookmark->name;
  my $bookmark_url   = $bookmark->url;
  my $user_id = $ENV{'ENSEMBL_USER_ID'}; 
  my $html = "<div id='bookmark_editor_$id' class='bookmark_editor' style='display: none'><form action='javascript:save_bookmark($id, $bookmark_id, $user_id);'><input type='text' id='bookmark_text_field_$id' value='" . $bookmark_name . "'> <div id='bookmark_editor_spinner_$id' style='display: none'><img src='/img/ajax-loader.gif' width='16' height='16' />'</div><div style='display: inline' id='bookmark_editor_links_$id'><a href='#' onclick='javascript:save_bookmark($id, $bookmark_id, $user_id);'>save</a> &middot; <a href='#' onclick='javascript:hide_inplace_editor($id);'>cancel</a></div></form></div>";
  return $html;
}

#----------------------- USER CONFIGS ---------------------------------------------

sub _show_configs {
  my( $panel, $object, $id ) = @_;
  my $editable = $panel->ajax_is_available;
  ## Get the user's config list
  my @configs = @{$object->get_configs($id)};

  ## return the message
  my $html = "<h3>Saved configurations</h3>\n";

  if (scalar(@configs) > 0) {
    if ($editable) {
      $html .= _show_editable_configs(@configs);
    } else {
      $html .= _show_static_configs(@configs);
    }
  }
  else {
    $html .= "<p>You have no saved configurations.</p>";
  }

  return $html;
}

sub _show_static_configs {
    my @configs = @_;
    my $html = "<ul>\n";
    foreach my $config (@configs) {
      my $name = $$config{'config_name'};
      my $type = $$config{'config_type'};
    
      $html .= qq(<li>$name ($type)</li>);
    }
    $html .= qq(</ul>
<p><a href="/common/manage_configs">Manage configurations</a></p>);
    return $html;
}

#--------------------------- BLAST -------------------------------------------

sub _show_blast {
  my( $panel, $object, $id ) = @_;

## Get the user's BLAST ticket list
  my $blast = {};

## return the message
  my $html = "<h3>BLAST tickets</h3>\n";

  if (keys %$blast) {
    $html .= "<ul>\n";
    while( my ($text, $url) = each %$blast) {
      $html .= qq(<li><a href="$url">$text</a></li>);
    }
    $html .= "</ul>\n";
  }
  else {
    $html .= "<p>You do not have any saved BLAST tickets.</p>";
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
  $html .= $panel->form('enter_details')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub enter_details   { 
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if (!$object->param('email')) { ## new registration
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
  my( $panel, $object ) = @_;

  my $webgroup_id = $object->param('webgroup_id');
  my $membership = $object->get_membership({'user_id'=>$object->user_id, 'webgroup_id'=>$webgroup_id});
  my $group = $membership->[0];

  my $group_name    = $group->{'group_name'};
  my $group_blurb   = $group->{'group_blurb'};
  my $member_level  = $group->{'member_level'};
  my $creator_name  = $group->{'creator_name'};
  my $creator_org   = $group->{'creator_org'};
  my $created_at    = $group->{'created_at'};
  my $modifier_name = $group->{'modifier_name'};
  my $modifier_org  = $group->{'modifier_org'};
  my $modified_at   = $group->{'modified_at'};

  my $html = qq(
<h4>Group name - $group_name</h4>
<p>$group_blurb</p>);

  if ($member_level eq 'administrator' || $member_level eq 'superuser') {
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
  my( $panel, $object ) = @_;

  my $html = qq(
<form action="/common/manage_members">
<h4>Membership Requests Pending Approval</h4>
<table class="spreadsheet">
<tr><th>Name and organisation</th><th>Date Submitted</th><th></th></tr>
<tr class="tint"><td>Q (Q Continuum)</td><td>1 Jan 2406</td><td><input type="submit" name="member_id" value="Approve"></td></tr>
<tr><td>William Riker (USS Enterprise)</td><td>1 Apr 2406</td><td><input type="submit" name="member_id" value="Approve"></td></tr>
<tr class="tint"><td>Miles O'Brien (USS Defiant)</td><td>4 Jul 2406</td><td><input type="submit" name="member_id" value="Approve"></td></tr>
</table>
<h4>Current Members</h4>
<table class="spreadsheet">
<tr><th>Name and organisation</th><th>Position</th></th><th></tr>
<tr class="tint"><td>Jean-Luc Picard (USS Enterprise)</td><td>administrator</td><td></td></tr>
<tr><td>Catherine Janeway (USS Voyager)</td><td>member</td><td><input type="submit" name="member_id" value="Remove from group"> <input type="submit" name="member_id" value="Ban from group"></td></tr>
<tr class="tint"><td>Benjamin Sisko (Deep Space Nine)</td><td>member</td><td><input type="submit" name="member_id" value="Remove from group"> <input type="submit" name="member_id" value="Ban from group"></td></tr>
</table>
</form>
  );

  $panel->print($html);
  return 1;
}

1;

