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

sub toggle_class {   
  my $class = shift;
  if ($class eq 'bg1') {
    $class = "bg2";   
  } else {
    $class = "bg1";   
  }
  return $class;
}

##---------- ACCOUNTVIEW ----------------------------------------

sub user_details {
  my( $panel, $user) = @_;
  my $html = "<div>";
  $html .= qq(<p>This is your Ensembl account home page. From here you can manage
                your saved settings, update your details and join or create new 
                Ensembl groups.</p><p>To learn more about how to get the most
                from your Ensembl account, read our <a href='/info/about/accounts.html'>introductory guide</a>.</p>);
  $html .= "</div>";
   
  $panel->print($html);
}

sub settings_mixer {
  my( $panel, $user) = @_;
  my $html = "<div>";
  my @groups = @{ $user->groups };
  if ($#groups > -1) {
    $html .= "<p>[No groups]</p>";
  }
  else {
    $html .= "<p>[Show mixer]</p>";
  }
  $html .= "</div>";
   
  $panel->print($html);
}

sub user_tabs {
  my( $panel, $user) = @_;

  my $bookmarkTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'bookmarks', 
                                     label => 'Bookmarks', 
                                     content => _render_bookmarks($user), 
                                                ));

  my $configTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'configs', 
                                     label => 'Configurations', 
                                     content => _render_configs($user), 
                                                ));

  my $noteTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'notes', 
                                     label => 'Notes', 
                                     content => _render_notes($user), 
                                                ));

  my $newsTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'news', 
                                     label => 'News', 
                                     content => _render_news($user), 
                                                ));

  my $groupTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'groups', 
                                     label => 'Groups', 
                                     content => '', 
                                                ));

  my $tabview = EnsEMBL::Web::Interface::TabView->new(( 
                                      name => "settings",
                                      width => '770',
                                      tabs => [
                                                $bookmarkTab,
                                                $configTab,
                                                $noteTab,
                                                $newsTab,
                                                $groupTab,
                                              ]
                                                     ));

  $panel->print($tabview->render . '<br />');
}

sub settings_mixer {
  my( $panel, $user) = @_;
  my @groups = @{ $user->groups };
  my $html = "<div id='the_mixer' class='white boxed'>\n";
  my $hidden = 0;
  my $last = 0;
  my $first = 0;
  my $n = 0;
  my $total = 4; 
  for my $n ( 1 .. $total) {
    if ($n == 1) { $first = 1; }; 
    if ($n == $total - 1) { $last = 1; }; 
    $html .= &mixer($groups[($n - 1)], $n, $hidden, $first, $last, $user);
    $hidden = 1;
    $first = 0;
  }
  $html .= "</div>\n";
  $panel->print($html);
}

sub mixer {
  my ($group, $ident, $hidden, $first, $last, $user) = @_;
  my $style = "";
  if ($hidden) {
    $style = "style='display: none;'";
  }
  my $html .= "<div $style id='mixer_" . $ident . "'>";
  $html .= "<table width='100%' cellpadding='4' cellspacing='0'>";
  $html .= "<tr>\n";
  if ($first) {
    $html .= "<td width='20%' style='text-align: right;'>Show settings for </td>\n";
  } else {
    $html .= "<td width='20%' style='text-align: right;'>and </td>\n";
  }
  $html .= "<td width='60%' style='text-align: left;'><select id='mixer_" . $ident . "_select' onChange='javascript:mixer_change(\"" . $ident . "\")'>" . &options_for_user($user, $ident) . "</select>";
  $html .= "</td>\n";
  $html .= "<td width='10%' style='text-align: right'>";
  if (!$last) {
    $html .= "<a href='javascript:void(0);' onclick='javascript:add_mix(" . ($ident + 1) . ");'>Add</td>\n";
  }
  $html .= "</td>";
  $html .= "<td width='10%' style='text-align: right'>";
  if (!$first) {
    $html .= "<a href='javascript:void(0);' onclick='javascript:remove_mix(" . $ident . ");'>Remove</td>\n";
  }
  $html .= "</td>";
  $html .= "</tr>\n";
  $html .= "</table>";
  $html .= "</div>";
  return $html;
}

sub options_for_user {
  my ($user, $ident) = @_;
  my $your_settings = { description => "Your account", value => "user" };
  my @items = ();
  push @items, $your_settings;
  foreach my $group (@{ $user->groups }) {
    push @items, { description => $group->name, value => $group->id };
  }
  my $html = "";
  my $count = 0;
  my $selected = "";
  foreach my $item (@items) {
    $count++;
    $selected = "";
    if ($count == $ident) {
      $selected = "selected";
    }
    $html .= "<option value='" . $item->{value} . "' $selected>" . $item->{description} . "</option>\n";
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

sub user_prefs {
  my( $panel, $user) = @_;
  my @records = $user->info_records;
  my $html = "";

  if ($#records > -1) {
    $html = qq(<div class="white boxed" style="width:770px;">
<h3 class="plain">Ensembl preferences</h3>
<ul>
<li><a href="/common/reset_info_boxes">Show all infomation boxes</a></li>
</ul>
</div>);
  }

  $panel->print($html);
}


sub _render_settings_table {
  my ($user, $records) = @_;
  my @admin_groups = @{ $user->find_administratable_groups };
}

sub _render_bookmarks {
  my $user = shift;
  my @bookmarks = $user->bookmark_records;

  my $html;
  $html .= &info_box($user, qq(<p>Bookmarks allow you to save frequently used pages from Ensembl and elsewhere. When browsing Ensembl, you can add new bookmarks by clicking the 'Add bookmark' link in the sidebar.<br /><a href="/info/about/bookmarks.html">Learn more about saving frequently used pages &rarr;</a></p>) , 'user_bookmark_info');
  if ($#bookmarks > -1) {
    #$html .= render_settings_table($user, \@bookmarks);
  }
  else {
    $html .= qq(<p class="center"><img src="/img/bookmark_example.gif" /></p>);
  }  
  $html .= "</table>\n";
  return $html;
}

sub _render_configs {
  my $user = shift;
  my @configurations = $user->configuration_records;

  my $html;
  $html .= &info_box($user, qq(You can save custom configurations (DAS sources, decorations, additional drawing tracks, etc), and return to them later or share them with fellow group members. Look for the 'Save configuration link' in the sidebar when browsing Ensembl.<br /><a href="/info/about/configurations.html">Learn more about custom configurations &rarr;</a></p>), 'user_configuration_info');
  if ($#configurations > -1) {
    #$html .= render_settings_table($user, \@configurations);
  }
  else {
    $html .= qq(<p class="center"><img src="/img/config_example.gif" /></p>);
  }

  return $html;
}

sub _render_notes {
  my $user = shift;

  my $html;

  return $html;
}

sub _render_news {
  my $user = shift;

  my $html;

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

