package EnsEMBL::Web::Component::User;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::DBSQL::NewsAdaptor;

use EnsEMBL::Web::Interface::TabView;
use EnsEMBL::Web::Interface::Tab;
use EnsEMBL::Web::Interface::Table;
use EnsEMBL::Web::Interface::Table::Row;

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

sub blurb {
  my( $panel, $object) = @_;

  my $html = qq(
<div class="pale boxed" id="intro">);

  if (my $feedback = $object->param('feedback')) {
    $html .= "<p><strong>Thank you - your changes have been saved.</strong></p>";
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
                                     content => "join" 
                                                     ));

  my $administerTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'administer', 
                                     label => 'Administer groups', 
                                     content => "admin" 
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

sub _render_membership {
  my ($user) = @_;
  my @groups = @{ $user->groups };
  my $html = "";
  if ($#groups > 0) {
  $html = "You are a member of the following groups:<br /><br />";
  my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss", 
                                       style => "border-collapse:collapse"
                                                  ));
  foreach my $group (@groups) {
    my $row = EnsEMBL::Web::Interface::Table::Row->new();
    $row->add_column({ content => $group->name });
    $row->add_column({ content => "<a href='/common/unsubscribe'>Leave group</a>"});
    $table->add_row($row);
  }

  $html .= $table->render;
  } else {
    $html .= "You are not a member of any Ensembl groups.";
  }

  return $html;
}

sub details {
  my( $panel, $user) = @_;

  my $html = sprintf(qq(<div class="boxed">
<strong>%s</strong>
<ul style="margin: 0px; padding: 5px 15px;">
<li>%s</li>
<li>%s</li>
</ul>
<a href="/common/update">Update details</a>
</div>), $user->name, $user->email, $user->organisation);

  $panel->add_content('right', $html);
}


sub _render_configs {
  my $user = shift;
  my $html;

  my @configs = $user->config_records({ order_by => 'click' });
  if (@configs) {
    my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss", 
                                       style => "border-collapse:collapse"
                                                  ));
    foreach my $record (@configs) {
      my $row = EnsEMBL::Web::Interface::Table::Row->new();
      $row->add_column({ width => "16px", content => "<img src='/img/bullet_star.png' width='16' height='16' />" });
      $row->add_column({ content => "<a href=''>" . $record->name . "</a>" });
      $row->add_column({ content => "<a href='/common/config?id=" . $record->id . "'>Edit</a>" });
      $row->add_column({ content => "<a href='/common/remove_config?id=" . $record->id . "'>Delete</a>" });
      $table->add_row($row);
    }
 
    $html = $table->render;
  }
  else {
    $html = "You do not have any saved configurations.";
  } 
  return $html;
}



sub _render_bookmarks {
  my $user = shift;
  my $html;

  my @bookmarks = $user->bookmark_records({ order_by => 'click' });

  if (@bookmarks) {
    my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss", 
                                       style => "border-collapse:collapse"
                                                  ));
    foreach my $record (@bookmarks) {
      my $row = EnsEMBL::Web::Interface::Table::Row->new();
      $row->add_column({ width => '16px', content => '<img src="/img/bullet_star.png" width="16" height="16" />' });
      $row->add_column({ content => '<a href="' . $record->url. '">' .$record->name . '</a>' });
      $row->add_column({ content => '<a href="/common/bookmark?id=' . $record->id . '">Edit</a>' });
      $row->add_column({ content => '<a href="/common/remove_bookmark?id=' . $record->id . '">Delete</a>' });
      $table->add_row($row);
    }
 
    $html = $table->render; 
  }
  else {
    $html = "You do not have any bookmarks saved.";
  } 
  return $html;
}

sub _render_filters {
  my $user = shift;
  my $html;

  my @filters = $user->news_records;
  if (@filters) {
    my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss", 
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
    $html = "You do not have any news filters set up.";
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
  my $member_level  = $user->is_administrator($group) ? "Administrator" : "Member";  
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

