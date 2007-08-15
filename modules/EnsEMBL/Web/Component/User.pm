package EnsEMBL::Web::Component::User;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::DBSQL::NewsAdaptor;
use EnsEMBL::Web::Record::Group;
use Data::Dumper;
use EnsEMBL::Web::Interface::TabView;
use EnsEMBL::Web::Interface::Tab;
use EnsEMBL::Web::Interface::Table;
use EnsEMBL::Web::Interface::Table::Row;
use EnsEMBL::Web::Object::Data::User;
use EnsEMBL::Web::Object::Data::Group;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Form;

use CGI;

use strict;
use warnings;
no warnings "uninitialized";

our @ISA = qw( EnsEMBL::Web::Component);

our $sitename = $SiteDefs::ENSEMBL_SITETYPE eq 'EnsEMBL' ? 'Ensembl' : $SiteDefs::ENSEMBL_SITETYPE;

##--------------------------------------------------------------------------------------------------
## USER LOGIN/REGISTRATION COMPONENTS
##--------------------------------------------------------------------------------------------------

sub login_form {
  ### Main site login form
  my( $panel, $object ) = @_;

  my $form = EnsEMBL::Web::Form->new( 'login', "/common/user/set_cookie", 'post' );

  $form->add_element('type'  => 'String', 'name'  => 'email', 'label' => 'Email', 'required' => 'yes');
  $form->add_element('type'  => 'Password', 'name'  => 'password', 'label' => 'Password', 'required' => 'yes');
  $form->add_element('type'  => 'Hidden', 'name'  => 'url', 'value' => $object->param('url'));
  $form->add_element('type'  => 'Submit', 'name'  => 'submit', 'value' => 'Log in');
  $form->add_element('type'  => 'Information',
                     'value' => qq(<p><a href="/common/user/register">Register</a> 
                                  | <a href="/common/user/lost_password">Lost password</a></p>));
  return $form;
}


sub lost_password_form {
  ## Form to resend activation code to user who has lost password
  my( $panel, $object ) = @_;

  my $form = EnsEMBL::Web::Form->new( 'lost_password', "/common/user/send_activation", 'post' );

  $form->add_element('type'  => 'Information',
                    'value' => qq(<p>If you have lost your password or activation email, enter your email address and we will send you a new activation code.</p>));
  $form->add_element('type'  => 'String', 'name'  => 'email', 'label' => 'Email', 'required' => 'yes');
  $form->add_element('type'  => 'Hidden', 'name'  => 'lost', 'value' => 'yes');
  $form->add_element('type'  => 'Submit', 'name'  => 'submit', 'value' => 'Send');
  return $form;
}

sub login_check {
  ## Interstitial page - confirms login then uses JS redirect to page where logged in
  my( $panel, $object ) = @_;
  my $url = $object->param('url') || '/index.html';

  my $html;
  if ($ENV{'ENSEMBL_USER_ID'}) {
    if ($object->param('updated') eq 'yes') {
      $html .= qq(<p>Thank you. Your changes have been saved.</p>);
    }
    else {
      $html .= qq(<p>Thank you for logging into Ensembl</p>);
    }
    $html .= qq(
<script type="text/javascript">
<!--
window.setTimeout('backToEnsembl()', 5000);

function backToEnsembl(){
  window.location = "$url"
}
//-->
</script>
<p>Please <a href="$url">click here</a> if you are not returned to your starting page within five seconds.</p>
  );
  }
  else {
    $html .= qq(<p>Sorry, we were unable to log you in. Please check that your browser can accept cookies.</p>
<p><a href="$url">Click here</a> to return to your starting page.</p>
);
  }
  $panel->print($html);  
}

sub enter_password_form {
  ## Form to add/change password
  my( $panel, $object ) = @_;
  my $script = $object->script;

  my $form = EnsEMBL::Web::Form->new( 'enter_password', "/common/user/save_password", 'post' );
 
  $form->add_element('type' => 'Information',
    'value' => 'Passwords should be at least 6 characters long and include both letters and numbers.');
 
  if ($ENV{'ENSEMBL_USER_ID'}) {
    ## Logged-in user, changing own password
    my $user = EnsEMBL::Web::Object::Data::User->new({'id' => $ENV{'ENSEMBL_USER_ID'}});
    my $email = $user->email;
    $form->add_element('type'  => 'Hidden', 'name'  => 'email', 'value' => $email);
    $form->add_element('type'  => 'Password', 'name'  => 'password', 'label' => 'Old password', 
                      'required' => 'yes');
  }
  else {
    ## Setting new/forgotten password
    $form->add_element('type'  => 'Hidden', 'name'  => 'user_id', 'value' => $object->param('user_id'));
    $form->add_element('type'  => 'Hidden', 'name'  => 'email', 'value' => $object->param('email'));
    $form->add_element('type'  => 'Hidden', 'name'  => 'code', 'value' => $object->param('code'));
  }
  if ($object->param('record_id')) {
    $form->add_element('type'  => 'Hidden', 'name'  => 'record_id', 'value' => $object->param('record_id'));
  }
  $form->add_element('type'  => 'Password', 'name'  => 'new_password_1', 'label' => 'New password',
                      'required' => 'yes');
  $form->add_element('type'  => 'Password', 'name'  => 'new_password_2', 'label' => 'Confirm new password',
                      'required' => 'yes');
  $form->add_element('type'  => 'Submit', 'name'  => 'submit', 'value' => 'Save');
  return $form;
}

sub update_failed {
  ## Generic message component for failed user_db update
  my( $panel, $object ) = @_;

## return the message
  my $html = qq(<p>Sorry - we were unable to update your account. If the problem persists, please contact <a href="mailto:webmaster\@ensembl.org">webmaster\@ensembl.org</a>. Thank you.</p>
<p><a href="/common/user/account">Return to your account home page</a>);

  $panel->print($html);
  return 1;
}

##--------------------------------------------------------------------------------------------------
## ACCOUNTVIEW
##--------------------------------------------------------------------------------------------------

sub account_intro {
  ## Accountview panel for intro blurb
  my ($panel) = @_;
  my $user = $panel->{user};

  my $html = "<div class='pale boxed'>";
  $html .= qq(This is your $sitename account home page. From here you can manage
                your saved settings, update your details and join or create new 
                $sitename groups. To learn more about how to get the most
                from your $sitename account, read our <a href='/info/about/accounts.html'>introductory guide</a>.<br />);
  $html .= "&larr; <a href='javascript:void(0);' onclick='account_return();'>Return to $sitename</a>";
  $html .= "</div>";
  $panel->print($html);
}

sub user_prefs {
  ## Preferences panel at foot of accountview
  my ($panel) = @_;
  my $user = $panel->{user};
  my @infoboxes = @{ $user->infoboxes };
  my @sortables = @{ $user->sortables };
  my $sortable = $sortables[0];
  my $html = "";
  $html = qq(<div class="white boxed">
<h3 class="plain">$sitename preferences</h3>
<ul>);

  if (defined $sortable && $sortable->kind eq 'alpha' ) {
    $html .= "<li><a href='/common/user/sortable?type=group'>Sort lists by group</a></li>";
  } else {
    $html .= "<li><a href='/common/user/sortable?type=alpha'>Sort lists alphabetically</a></li>";
  }

  if (scalar(@infoboxes) > 1) {
    $html .= "<li><a href='/common/user/reset_info_boxes'>Show all information boxes</a></li>";
  }

$html .= qq(</ul>
</div>);

  $panel->print($html);
}


##--------------------------------------------------------------------------------------------------
## ACCOUNTVIEW MIXER PANEL
##--------------------------------------------------------------------------------------------------

sub settings_mixer {
  ### Accountview panel allowing user to filter display by group (if group records exist)
  my ($panel) = @_;
  my $user = $panel->{user};
  my $html = "<div>";
  my @groups = @{ $user->groups };
  if ($#groups > -1) {
    my @presets = &mixer_presets_for_user($user);
    my $html = "<script type='text/javascript'>\n";
    my $count = 0;
    foreach my $setting (@presets) {
      $count++;
      if ($presets[$count]) {
        $html .= "displayed_settings[$count] = '" . $presets[$count] . "';\n";
      }
    }
    $html .= "</script>";
    $html .= "<div id='the_mixer' class='white boxed'>\n";
    my $hidden = 0;
    my $last = 0;
    my $first = 0;
    my $n = 0;
    my $total = $#groups + 3; 
    for my $n ( 1 .. $total) {
      if ($n == 1) { $first = 1; }; 
      if ($n == $total - 1) { $last = 1; }; 
      $html .= &mixer($groups[($n - 1)], $n, $hidden, $first, $last, $user, $presets[$n]);
      $hidden = 1;
      $first = 0;
    }
    $html .= "</div>\n";
  }
  $html .= "</div>";
   
  $panel->print($html);
}

sub mixer_presets_for_user {
  ## Retrieves mixer settings from user_record table
  my ($user) = @_;
  my @mixers = @{ $user->mixers };
  my @presets = ();
  if ($#mixers > -1) {
    my $mixer = $mixers[0];
    @presets = split(/,/, $mixer->settings);
  } 
  return @presets;
}

sub mixer {
  ### HTML table to hold mixer widget
  my ($group, $ident, $hidden, $first, $last, $user, $preset) = @_;
  my $style = "";
  if ($hidden) {
    $style = "style='display: none;'";
  }
  if ($preset) {
    $style = "";
  }
  my $html .= "<div $style id='mixer_" . $ident . "'>";
  $html .= "<table width='100%' cellpadding='4' cellspacing='0'>";
  $html .= "<tr>\n";
  if ($first) {
    $html .= "<td width='20%' style='text-align: right;'>Show for </td>\n";
  } else {
    $html .= "<td width='20%' style='text-align: right;'>and </td>\n";
  }
  $html .= "<td width='60%' style='text-align: left;'><select id='mixer_" . $ident . "_select' onChange='javascript:mixer_change(\"" . $ident . "\")'>" . &options_for_user($user, $ident, $preset) . "</select>";
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
  ### Creates contents of dropdown list
  my ($user, $ident, $preset) = @_;
  my @items = ();
  my $your_settings = { description => "Your account", value => "user" };
  push @items, $your_settings;
  my $everything = { description => "Everything", value => "all" };
  push @items, $everything;
  foreach my $group (@{ $user->groups }) {
    push @items, { description => $group->name, value => $group->id };
  }
  my $html = "";
  my $count = 0;
  my $selected = "";
  my $optgroup = 0;
  foreach my $item (@items) {
    $count++;
    $selected = "";
    if ($preset) {
      if ($preset eq $item->{value}) {
        $selected = "selected";
      } 
    } else {
      if ($count == $ident) {
        $selected = "selected";
      }
    }
    if ($item->{value} ne 'user' && $item->{value} ne 'all' && !$optgroup) {
      $optgroup = 1;
      $html .= "<optgroup label='Groups'>\n";
    }
    $html .= "<option value='" . $item->{value} . "' $selected>" . $item->{description} . "</option>\n";
  }
  if ($optgroup) {
    $html .= "</optgroup>\n";
  }
  return $html;
}

##--------------------------------------------------------------------------------------------------
## ACCOUNTVIEW TABBED PANEL
##--------------------------------------------------------------------------------------------------

sub user_tabs {
  ### Tabbed panel for various user records
  my ($panel, $object) = @_;
  my $user = $panel->{user};

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
                                     label => 'News filters', 
                                     content => _render_news($user), 
                                                ));

  my $groupTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'groups', 
                                     label => 'Groups', 
                                     content => _render_groups($user), 
                                                ));

  my $dasTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'das', 
                                     label => 'DAS sources', 
                                     content => _render_das($user), 
                                                ));

  my $tabview = EnsEMBL::Web::Interface::TabView->new(( 
                                      name => "settings",
                                      tabs => [
                                                $bookmarkTab,
                                                $configTab,
                                                $dasTab,
                                                $noteTab,
                                                $newsTab,
                                                $groupTab,
                                              ]
                                                     ));
  
  my @opentabs = @{ $user->opentabs };
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

  $panel->print($tabview->render . '<br />');
}

sub _render_bookmarks {
  ### Content for bookmarks tab
  my $user = shift;
  my @bookmarks = @{ $user->bookmarks };
  my @records;
  foreach my $bookmark (@bookmarks) {
    my $description = $bookmark->description || '&nbsp;';
    push @records, {  'id' => $bookmark->id, 
                      'ident' => 'user',
                      'sortable' => $bookmark->name,
                      'shareable' => 1,
                      'edit_url' => 'bookmark', 
                      'delete_url' => 'remove_record',
                      'data' => [
      '<a href="/common/user/use_bookmark?id=' . $bookmark->id . '" title="' . $bookmark->description . '">' . $bookmark->name . '</a><br /><span style="font-size: 10px;">' . $bookmark->description . '</span>', '&nbsp;' 
    ]};
  }
  foreach my $group (@{ $user->groups }) {
    foreach my $bookmark (@{ $group->bookmarks }) {
      my $description = $bookmark->description || '&nbsp;';
      push @records, {'id' => $bookmark->id, 
                      'ident' => $group->id, 
                      'sortable' => $bookmark->name,
                      'data' => [
      '<a href="/common/user/use_bookmark?id=' . $bookmark->id . '" title="' . $bookmark->description . '">' . $bookmark->name . '</a><br /><span style="font-size: 10px;">' . $bookmark->description . '</span>', $group->name 
      ]};
    }
  }
  my $html;
  $html .= &info_box($user, qq(Bookmarks allow you to save frequently used pages from $sitename and elsewhere. When browsing $sitename, you can add new bookmarks by clicking the 'Add bookmark' link in the sidebar. <a href="http://www.ensembl.org/info/help/custom.html#bookmarks">Learn more about saving frequently used pages (Ensembl documentation) &rarr;</a>) , 'user_bookmark_info');
  if ($#records > -1) {
    $html .= _render_settings_table(\@records, $user);
  }
  else {
    $html .= qq(<p class="center"><img src="/img/help/bookmark_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= qq(<p class="center">You haven't saved any bookmarks. <a href='/info/help/custom.html#bookmarks'>Learn more about bookmarks &rarr;</a>);
  }  
  $html .= qq(<p><a href="/common/user/bookmark?dataview=add"><b>Add a new bookmark </b>&rarr;</a></p>);
  return $html;
}

sub _render_configs {
  ### Content for Configurations tab
  my $user = shift;
  my @configurations = @{ $user->configurations };
  my @records;

  foreach my $configuration (@configurations) {
    my $description = $configuration->description || '&nbsp;';
    my $link = "<a href='javascript:void(0);' onclick='javascript:go_to_config(" . $configuration->id . ");'>";
    $description = substr($configuration->description, 0, 30);
    push @records, {  'id' => $configuration->id, 
                      'ident' => 'user',
                      'sortable' => $configuration->name,
                      'shareable' => 1,
                      'edit_url' => 'configuration', 
                      'data' => [
                         $link . $configuration->name . '</a>', '&nbsp;' , "($description)" 
                      ]};
  }

  foreach my $group (@{ $user->groups }) {
    foreach my $configuration (@{ $group->configurations }) {
      my $description = $configuration->description || '&nbsp;';
      my $link = "<a href='javascript:void(0);' onclick='javascript:got_to_config(" . $configuration->id . ");'>";
      push @records, {'id' => $configuration->id, 
                      'ident' => $group->id, 
                      'sortable' => $configuration->name,
                      'data' => [
                        $link . $configuration->name . '</a>', $group->name
                      ]};
    }
  }

  my $html;
  $html .= &info_box($user, qq(You can save custom view configurations (DAS sources, decorations, additional drawing tracks, etc), and return to them later or share them with fellow group members. Look for the 'Save configuration link' in the sidebar when browsing $sitename. <a href="http://www.ensembl.org/info/help/custom.html#configurations">Learn more about view configurations (Ensembl documentation) &rarr;</a>), 'user_configuration_info');
  if ($#records > -1) {
    $html .= _render_settings_table(\@records, $user);
  }
  else {
    $html .= qq(<p class="center"><img src="/img/help/config_example.gif" /></p>);
    $html .= qq(<p class="center">You haven't saved any $sitename view configurations. <a href='/info/help/custom.html#configurations'>Learn more about configurating views &rarr;</a>);
  }

  return $html;
}

sub _render_das {
  ### Content for DAS tab
  my $user = shift;
  my $html .= &info_box($user, qq(DAS sources allow you to share annotation and other information.), 'user_das_info');
  my @dases= @{ $user->dases};
  my @records = ();
  #warn "RENDERING DAS";
  foreach my $das (@dases) {
    my $description = $das->name || '&nbsp;';
    push @records, {  'id' => $das->id, 
                      'ident' => 'user',
                      'sortable' => $das->name,
                      'shareable' => 1,
                      'edit_url' => 'das', 
                      'delete_url' => 'remove_record',
                      'data' => [
      $das->name . '<br /><span style="font-size: 10px;">' . $das->url . '</span>', '&nbsp;' 
    ]};
  }
  if ($#records > -1) {
    #warn "RENDERING DAS TABLE";
    $html .=  _render_settings_table(\@records, $user);
  } else {
    $html .= "You have not saved any DAS sources";
  }
  return $html;
}

sub _render_notes {
  ### Content for Notes tab
  my $user = shift;
  my @notes = @{ $user->annotations };
  my @records;

  foreach my $note (@notes) {
    my $description = $note->annotation || '&nbsp;';
    #warn "NOTE: " . $note;
    push @records, {  'id' => $note->id, 
                      'ident' => 'user',
                      'sortable' => $note->title,
                      'shareable' => 1,
                      'edit_url' => 'annotation', 
                      'data' => [
      '<a href="' . $note->url. '" title="' . $note->title . '">' . $note->stable_id . ': ' . $note->title . '</a>', '&nbsp;' 
    ]};
  }

  foreach my $group (@{ $user->groups }) {
    foreach my $note (@{ $group->annotations }) {
      my $description = $note->annotation || '&nbsp;';
      push @records, {'id' => $note->id, 
                      'ident' => $note->id, 
                      'sortable' => $note->title,
                      'data' => [
        '<a href="' . $note->url . '" title="' . $note->title. '">' . $note->stable_id . ': ' . $note->title . '</a>', $group->name
      ]};
    }
  }

  my $html = "";
  $html .= &info_box($user, qq(Annotation notes from genes are listed here. <a href='http://www.ensembl.org/info/help/custom.html#notes'>Learn more about notes (Ensembl documentation) &rarr;</a>), 'user_note_info');
  if ($#records > -1) {
    $html .= _render_settings_table(\@records, $user);
  }
  else {
    $html .= qq(<p class="center"><img src="/img/help/note_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= qq(<p class="center">You haven't saved any $sitename notes. <a href='/info/help/custom.html#notes'>Learn more about notes &rarr;</a>);
  }
  return $html;
}

sub _render_news {
  ### Content for News Filters tab
  my $user = shift;
  my @filters = @{ $user->news };
  my @records;
  my $both = 0;
  foreach my $filter (@filters) {
    my $data;
    if ($filter->topic) {
      my $topic = $filter->topic;
      if (ref($topic) eq 'ARRAY') {
        $topic = join(', ', @$topic);
      }
      $data .= "Topic: $topic";
      $both = 1;
    }
    if ($filter->species) {
      my $species = $filter->species;
      if (ref($species) eq 'ARRAY') {
        $species = join(', ', @$species);
      }
      $species =~ s/_/ /g;
      $data .= '; ' if $both;
      $data .= "Species: $species";
    }
    push @records, {'id' => $filter->id, 
               'edit_url' => 'filter_news', 'delete_url' => 'remove_record', 
               'ident' => 'user',
               'data' => [$data] };
  }

  my $html;
  $html .= &info_box($user, qq(You can filter the news headlines on the home page and share these settings with fellow group members.<br /><a href="http://www.ensembl.org/info/help/custom.html#news">Learn more about news filters (Ensembl documentation) &rarr;</a>), 'news_filter_info');
  if ($#records > -1) {
    $html .= _render_settings_table(\@records, $user);
  }
  else {
    $html .= qq(<p class="center"><img src="/img/help/filter_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= qq(<p class="center">You do not have any filters set, so you will see general headlines.</p>
<p><a href="/common/user/filter_news">Add a news filter &rarr;</a></p>
);
  }
  return $html;
}

sub _render_groups {
  ### Content for group tab
  my $user = shift;
  my $html;
  my @groups = @{ $user->groups };
  my @group_rows = ();
  my %included = ();
  my @all_groups = @{ EnsEMBL::Web::Object::Data::Group->find_all };
  $html .= &info_box($user, qq(Groups enable you to organise your saved bookmarks, notes and view configurations, and also let you share them with other users. The groups you're subscribed to are listed below. <a href="http://www.ensembl.org/info/help/groups.html">Learn more about creating and managing groups (Ensembl documentation) &rarr;</a>) , 'user_group_info');
  if ($#groups > -1) {
    $html .= "<h5>Your subscribed groups</h5>\n";
    $html .= "<table width='100%' cellspacing='0' cellpadding='4'>\n";
    my $class = "bg1";
    foreach my $group (sort {$a->name cmp $b->name} @groups) {
      $class = &toggle_class($class);
      $included{$group->id} = 'yes';
      $html .= "<tr class='$class'>\n";
      $html .= "<td width='25%'>" . $group->name . "</td>";
      $html .= "<td>" . $group->blurb. "</td>";
      if ($group->id && $user->is_administrator_of($group)) {
        $html .= '<td style="text-align: right;"><a href="/common/user/view_group?id=' . $group->id . '">Manage group</a></td>';
      } else {
        $html .= '<td style="text-align: right;"><a href="/common/user/view_group?id=' . $group->id . '">View membership details</a></td>';
        $html .= '<td style="text-align: right;"><a href="/common/unsubscribe?id=' . $group->id . '">Unsubscribe</a></td>';
      }
      $html .= "</tr>\n";
    }
    #if ($#all_groups > -1) {
    #  foreach my $group (@all_groups) {
    #    $html .= &_render_invites_for_group($group, $user);
    #  }
    #}
    $html .= "</table><br />\n";
  }
  else {
    $html .= qq(<p class="center">You are not subscribed to any $sitename groups. &middot; <a href='/info/help/groups.html'>Learn more &rarr;</a> </p>);
  }  
  #$html .= "<br />";
  ## An unimplemented feature - we don't have any public groups yet.
  #$html .= &_render_public_groups($user, \%included);
  $html .= "<br />";
  $html .= qq(<p><a href="/common/user/group">Create a new group &rarr;</a></p>);
  return $html;
}

sub _render_invites_for_group {
  ### Additional rows for group tab, displaying invitations
  my ($group, $user) = @_;
  my $html = "";
  my $class = "";
  if ($group->type eq 'restricted') {
    my @invites = @{ $group->invites };
    foreach my $invite (@invites) {
      if ($invite->email eq $user->email && $invite->status eq 'pending') {
        $class = "invite";
        $html .= "<tr>\n";
        $html .= "<td class='$class'>" . $group->name . "</td>";
        $html .= "<td class='$class'>" . $group->blurb . "</td>";
        $html .= "<td class='$class' style='text-align:right'><a href='/common/join_by_invite?record_id=" . $invite->id . "&invite=" . $invite->code . "'>Accept invite</a> or <a href='/common/user/remove_invite?id=" . $invite->id . "'>decline</a></td>";
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
  my @all_groups = @{ EnsEMBL::Web::Object::Group->all_groups_by_type('open') };
  if ($#all_groups > -1) {
    $html = "<h5>Publicly available groups</h5>";
    $html .= "<table width='100%' cellpadding='4' cellspacing='0'><tr>";

    my $class = "bg1";
    foreach my $group (sort {$a->name cmp $b->name} @all_groups) {
      if (!$included{$group->id}) {
        $class = &toggle_class($class);
        $html .= "<tr>\n";
        $html .= "<td class='$class' width='25%'>" . $group->name . "</td>";
        $html .= "<td class='$class'>" . $group->description . "</td>";
        $html .= "<td class='$class' style='text-align: right;'><a href='/common/subscribe?id=" . $group->id . "'>Subscribe</a></td>";
        $html .= "</tr>\n";
      }
    }

    $html .= "</table>\n";
  }
  return $html;
}

sub _render_settings_table {
  ### Generic table-rendering code for tab content
  ### (Individual content methods below)
  my ($records, $user) = @_;
  my @row_records = @{ $records };
  my $sort = 0;
  my $sortable = undef;
  my @sortables = undef;
  my @presets = ();
  if ($user) {
    @sortables = @{ $user->sortables };
    $sortable = $sortables[0];
    @presets = &mixer_presets_for_user($user);
  }
  if (defined $sortable && $sortable->kind eq 'alpha') {
    $sort = 1;
  }
  if ($sort) {
    @row_records = sort { $a->{sortable} cmp $b->{sortable} } @{ $records };
  } 

  my @admin_groups = ();
  if ($user) {
    @admin_groups = @{ $user->find_administratable_groups };
  }
  my $is_admin = 0;
  if ($#admin_groups > -1) {
    $is_admin = 1;
  }

  my $html = qq(<table class="ss" cellpadding='4' cellspacing='0'>);
  my $class = 'bg1';
 
  foreach my $row (@row_records) {
    $class = &toggle_class($class);
    my $style = '';
  
    #my $style = "style='display:none;'";
    #my $found = 0;
    #foreach my $preset (@presets) {
    #  if ($preset eq 'all') {
    #    $found = 1;
    #    last;
    #  }
    #  if ($preset eq $row->{ident}) {
    #    $found = 1;
    #  }
    #}
    #if ($found) {
    #  $style = "";
    #}

    #if ($#presets == -1 && $row->{ident} eq 'user') {
    #  $style = "";
    #}

    $html .= qq(<tr class="$class all ) . $row->{ident} . qq(" $style>);
    my $id = $row->{'id'};
    my @data = @{$row->{'data'}};
    foreach my $column (@data) {
      if (ref($column) eq 'ARRAY') {
        $column = join(', ', @$column);
      }
      $html .= qq(<td>$column</td>);
    }
    if ($row->{ident} eq 'user' ) {
      if ($row->{'edit_url'}) {
        if ($row->{'absolute_url'}) {
          $html .= '<td style="text-align:right;"><a href="' . $row->{'edit_url'};
        } else {
          $html .= '<td style="text-align:right;"><a href="/common/user/' . $row->{'edit_url'} . '?dataview=edit;id=' . $id;
        }
        if ($row->{'group_id'}) {
          $html .= ';record_type=group'; 
        }
        my $edit_link = 'Edit';
        if ($row->{'edit_url'} =~ /configuration/) {
          $edit_link = 'Rename';
          $html .= ';rename=yes'; 
        }
        $html .= qq(">$edit_link</a></td>);
      }
      $html .= '<td style="text-align:right;">';
      if ($row->{'shareable'} && $is_admin) {
        $html .= qq(<a href="/common/user/select_group?id=$id">Share</a>);
      }
      else {
        $html .= '&nbsp;';
      }
      $html .= '</td><td style="text-align:right;"><a href="/common/user/' . $row->{'edit_url'} . qq(?dataview=delete;id=$id);
      if ($row->{'group_id'}) {
        $html .= ';record_type=group';
      }
      $html .= qq(">Delete</a></td>);
    }
    else {
      $html .= '<td colspan="3" class="center">&nbsp;</td>';
    }
    $html .= "</tr>";
  }

  $html .= '</table>';
  return $html;
}

sub select_group_form {
  ## Form to add/change password
  my( $panel, $object ) = @_;
  my $script = $object->script;

  my $form = EnsEMBL::Web::Form->new( 'select_group', "/common/user/share_record", 'post' );
  
  my $user = EnsEMBL::Web::Object::Data::User->new({'id' => $ENV{'ENSEMBL_USER_ID'}});
  my (@admin_groups, $group);
  foreach $group (@{ $user->find_administratable_groups }) {
    push @admin_groups, $group;
  }
  my $count = $#admin_groups;
  if ($count > 1) {
    foreach $group (@admin_groups) {
      $form->add_element('type'  => 'RadioButton', 'name'  => 'webgroup_id', 
                      'label' => $group->name, 'value' => $group->id);
    }
  }
  else {
    $group = $admin_groups[0];
    $form->add_element('type'  => 'RadioButton', 'name'  => 'webgroup_id', 
                      'label' => $group->name, 'value' => $group->id, 'checked' => 'checked');
  }
  $form->add_element('type'  => 'Hidden', 'name'  => 'id', 'value' => $object->param('id'));
  $form->add_element('type'  => 'Submit', 'name'  => 'submit', 'value' => 'Share');
  return $form;
}

##--------------------------------------------------------------------------------------------------
## GROUPVIEW COMPONENTS
##--------------------------------------------------------------------------------------------------

sub no_group {
  ### Error message if group id not found
  my( $panel, $user) = @_;

  my $html = qq(<p>No group was specified. Please go back to your <a href="/common/user/account">account home page</a> and click a "Manage group"
link for a group you created.</p>);

  $panel->print($html);
  return 1;
}

sub groupview {
  ### Selects appropriate components for groupview page, based on user's permissions
  my( $panel, $object) = @_;
  my $webgroup_id = $object->param('id');
  my $group = EnsEMBL::Web::Object::Data::Group->new({ id => $webgroup_id });
  my $user = EnsEMBL::Web::Object::Data::User->new({ id => $object->id });

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
                read the <a href='/info/help/groups.html'>introductory guide</a>.</p>);
  $html .= "</div>";
   
  return $html;
}

sub member_intro {
  ### Group member's blurb
  my( $panel, $user) = @_;
  my $html = "<div class='pale boxed'>";
  $html .= qq(<p>This page displays $sitename group information.<p>
                <p>For more information about $sitename groups, and how to use them,
                read the <a href='/info/help/groups.html'>introductory guide</a>.</p>);
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
  my $created_at    = $group->pretty_date($group->created_at);

  my $html = qq(<h3 class="plain">$group_name</h3>\n<p>$group_blurb</p>\n);
  if ($level eq 'Administrator') {
    $html .= qq(<p><a href="/common/user/group/dataview=edit;id=$group_id">Edit group description</a></p>);
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
      my $modified_at   = $group->pretty_date($group->modified_at);
      $html .= qq(<br /><strong>Details modified by</strong>: $modifier_name ($modifier_org) on $modified_at);
    }
  }
  $html .= qq(</p>\n<p><strong>Your membership status</strong>: $level</p>\n);


  return $html;
}

sub group_records {
  my($object, $is_owner) = @_;
  my $user = EnsEMBL::Web::Object::Data::User->new({ id => $object->id });
  my $group = EnsEMBL::Web::Object::Data::Group->new({ id => $object->param('id') });
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
  $html .= "&larr; <a href='/common/user/account'>Back to your account</a>";
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

  my @invites = @{ $group->invites };
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


  my @opentabs = @{ $user->opentabs };
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
  my @bookmarks = @{ $group->bookmarks };
  my @configurations = @{ $group->configurations };
  my @notes = @{ $group->annotations };
  my $html = "";
  if ($#bookmarks > -1) {
    $html .= "<h5>Bookmarks</h5>\n";
    my @records = ();
    foreach my $bookmark (@bookmarks) {
      my $description = $bookmark->description || '&nbsp;';
      my $data =  ['<a href="' . $bookmark->url . '" title="' . $bookmark->description . '">' . $bookmark->name . '</a>'];
      if ($ident eq 'group') {
        push @$data, $description;
      }
      else {
        push @$data, '';
      }
      push @records, {  'id' => $bookmark->id, 
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
      my $link = "<a href='javascript:void(0);' onclick='javascript:load_config_link(" . $configuration->id . ");'>";
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
  my $html = "";
  $html .= &info_box($admin, "This panel lists all members of this group. You can invite new users to join your group by entering their email address in the 'Invite' tab.", "group_members_info");
  my @users = @{ $group->users };
  my $table = EnsEMBL::Web::Interface::Table->new(( 
                                       class => "ss", 
                                       style => "border-collapse:collapse"
                                                  ));
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
          $row->add_column({ content => qq(<a href="/common/user/change_level?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_level=administrator">Promote to Admin</a>), align => 'right' });
        } 
        else {
          $row->add_column({ content => qq(<a href="/common/user/change_level?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_level=member">Demote to Member</a>), align => 'right' });
        }
        $row->add_column({ content => qq(<a href="/common/user/change_status?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_status=none">Remove</a>), align => 'right' });
      }
      if ($user->member_status eq 'barred') {
        $row->add_column({ content => qq(<a href="/common/user/change_status?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_status=active">Re-admit</a>), align => 'right' });
      }
      elsif ($user->member_status eq 'inactive') {
        $row->add_column({ content => qq(<a href="/common/user/invite?invite_email=) . $user->email . qq(;id=) . $group->id . qq(">Re-invite</a>), align => 'right' });
      }
      else {
        $row->add_column({ content => qq(<a href="/common/user/change_status?user_id=) . $user->id . qq(;group_id=) . $group->id . qq(;new_status=barred">Ban</a>), align => 'right' });
      }
    }
    $table->add_row($row);
  }

  $html .= $table->render;
  if ($show_all && $show_all eq 'yes') {
    $html .= qq(<p><a href="/common/user/view_group?id=).$group->id.qq(;show_all=no">Hide non-active members</a></p>);
  }
  else {
    $html .= qq(<p><a href="/common/user/view_group?id=).$group->id.qq(;show_all=yes">Show non-active members</a> (if any)</p>);
  }

  return $html;
}

sub _render_group_invite {
  my $group = shift;
  my $html = qq(<h4>Invite a user to join this group</h4>
<form action="/common/user/invite" action="post">
<p>To invite a new member into this group, enter their email address. Users not already registered with $sitename will be asked to do so before accepting your invite.</p>
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
      $row->add_column({ content => '<a href="/common/user/remove_invitation?id=' . $invite->id . ';group_id=' . $group->id . '">Delete</a>' });
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
  $html .= "<form action='remove_group' name='remove' id='remove' method='post'>\n";
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
    $html = qq(<p>This invitation seems to have been accepted already. Please <a href="/common/user/account">go to your account</a> or <a href="/common/user/login">log in</a> to check your group membership details.</p>);
  }
  else {
    $html = qq(<p>Sorry, there was a problem with the invitation record in our database. Please contact the person who invited you to get a new invitation.</p>);
  }

  $panel->print($html);
}

sub invitations {
  my ($panel, $object) = @_;
  my $html = qq(<p>The following addresses have been checked and invitations sent where appropriate:</p>
<table class="ss">
<tr class="ss-header"><th>Email address</th><th>Invitation sent?</th><th>Notes</th></tr>);

  my %invitation = %{$object->invitees};
  my $bg = 'bg1';
  my $count = 1;
  while (my ($email, $status) = each (%invitation)) {
    if ($count % 2 == 0) {
      $bg = 'bg2';
    }
    else {
      $bg = 'bg1';
    }
    $html .= qq(<tr class="$bg"><td>$email</td><td>);
    if ($status eq 'invited') {
      $html .= 'No</td><td>Already invited';
    }
    elsif ($status eq 'active') {
      $html .= 'No</td><td>Already a member of this group';
    }
    elsif ($status eq 'barred') {
      $html .= 'No</td><td>This user has been barred from this group';
    }
    elsif ($status eq 'inactive') {
      $html .= 'Yes</td><td>This user is a former member of this group';
    }
    elsif ($status eq 'exists') {
      $html .= 'Yes</td><td>Registered user';
    }
    else {
      $html .= 'Yes</td><td>Not yet registered';
    }
    $html .= "</td></tr>\n";
    $count++;
  }
  my $group_id = $object->param('id');
  $html .= qq(</table>
<p>&larr; <a href="/common/user/view_group?id=$group_id">Back to group details</a></p>);

  $panel->print($html);
}

##--------------------------------------------------------------------------------------------------
## MISCELLANEOUS COMPONENTS
##--------------------------------------------------------------------------------------------------

sub message {
  ### Displays a message (e.g. error) from the Controller::Command::User module
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

sub _wrap_form {
  ### Wrapper for form content
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($node)->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub info_box {
  ### Wrapper for infobox content
  my($user, $message, $name) = @_;
  my $found = 0;
  foreach my $info (@{ $user->infoboxes }) {
    if ($info->name eq $name) {
      $found = 1;
    }
  }
  my $html = "";
  if (!$found) {
    $html = "<div class='alt boxed' id='$name'>";
    $html .= "<p><img src='/img/infoicon.gif' class='float-left' > " . $message . '</p>';
    $html .= "<div style='text-align: right; font-size: 80%;'>\n";
    $html .= "<a href='javascript:void(0);' onclick='hide_info(\"$name\");'>Hide this message</a>";
    $html .= "</div>\n";
    $html .= "</div>\n";
  }
  return $html;
}

sub toggle_class {   
  ### Stripes for tables
  my $class = shift;
  if ($class eq 'bg1') {
    $class = "bg2";   
  } else {
    $class = "bg1";   
  }
  return $class;
}

##-----------------------------------------------------------------


#------------------------------------------------------------------------------

sub denied {
  my( $panel, $object ) = @_;

## return the message
  my $html = qq(<p>Sorry - this page requires you to be logged into your $sitename user account and to have the appropriate permissions. If you cannot log in or need your access privileges changed, please contact <a href="mailto:webmaster\@ensembl.org">webmaster\@ensembl.org</a>. Thank you.</p>);

  $panel->print($html);
  return 1;
}



1;

