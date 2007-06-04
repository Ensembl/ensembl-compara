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
use EnsEMBL::Web::Object::Data::Group;
use EnsEMBL::Web::RegObj;

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
  my $class = shift;
  if ($class eq 'bg1') {
    $class = "bg2";   
  } else {
    $class = "bg1";   
  }
  return $class;
}

##---------- ACCOUNTVIEW ----------------------------------------

sub settings_mixer {
  my ($panel) = @_;
  my $user = $panel->{user};
  warn "CHECKING FOR GROUPS: " . $user;
  my $html = "<div>";
  my @groups = @{ $user->groups };
  if ($#groups > -1) {
    $html .= &render_settings_mixer($user); 
  } else {
    $html .= "";
  }
  $html .= "</div>";
   
  $panel->print($html);
}

sub user_tabs {
  my ($panel) = @_;
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
  
  my $cgi = new CGI;
  my @opentabs = @{ $user->opentabs };
  if ($#opentabs > -1) {
    foreach my $opentab (@opentabs) {
      if ($opentab->name eq $tabview->name) { 
        $tabview->open($opentab->tab);
      } 
    }
  } 

  ## Override previous saved settings if necessary
  if ($cgi->param('tab')) {
     $tabview->open($cgi->param('tab'));
  }

  $panel->print($tabview->render . '<br />');
}

sub render_settings_mixer {
  my ($user) = @_;
  my @groups = @{ $user->groups };
  warn "RENDER SETTINGS MIXER";
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
  return $html;
}

sub mixer_presets_for_user {
  my ($user) = @_;
  warn "CHECKING FOR MIXERS: " . $user;
  my @mixers = @{ $user->mixers };
  my @presets = ();
  warn "MIXER OK";
  if ($#mixers > -1) {
    my $mixer = $mixers[0];
    @presets = split(/,/, $mixer->settings);
  } 
  return @presets;
}

sub mixer {
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

sub user_details {
  my ($panel) = @_;
  my $user = $panel->{user};

  my $html = "<div class='pale boxed'>";
  $html .= qq(This is your $SiteDefs::ENSEMBL_SITETYPE account home page. From here you can manage
                your saved settings, update your details and join or create new 
                $SiteDefs::ENSEMBL_SITETYPE groups. To learn more about how to get the most
                from your $SiteDefs::ENSEMBL_SITETYPE account, read our <a href='/info/about/accounts.html'>introductory guide</a>.<br />);
  $html .= "&larr; <a href='javascript:void(0);' onclick='account_return();'>Return to $SiteDefs::ENSEMBL_SITETYPE</a>";
  $html .= "</div>";
  $panel->print($html);
}

sub user_prefs {
  my ($panel) = @_;
  my $user = $panel->{user};
  my @invites = @{ $user->infoboxes };
  my @sortables = @{ $user->sortables };
  my $sortable = $sortables[0];
  my $html = "";
  $html = qq(<div class="white boxed">
<h3 class="plain">$SiteDefs::ENSEMBL_SITETYPE preferences</h3>
<ul>);

  if (defined $sortable && $sortable->kind eq 'alpha' ) {
    $html .= "<li><a href='/common/sortable?type=group'>Sort lists by group</a></li>";
  } else {
    $html .= "<li><a href='/common/sortable?type=alpha'>Sort lists alphabetically</a></li>";
  }

  if ($#invites > -1) {
    $html .= "<li><a href='/common/reset_info_boxes'>Show all infomation boxes</a></li>";
  }

$html .= qq(</ul>
</div>);

  $panel->print($html);
}


sub _render_settings_table {
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
    my $style = "style='display:none;'";
    my $found = 0;
    foreach my $preset (@presets) {
      if ($preset eq 'all') {
        $found = 1;
        last;
      }
      if ($preset eq $row->{ident}) {
        $found = 1;
      }
    }
    if ($found) {
      $style = "";
    }

    if ($#presets == -1 && $row->{ident} eq 'user') {
      $style = "";
    }

    $html .= qq(<tr class="$class all ) . $row->{ident} . qq(" $style>);
    my $id = $row->{'id'};
    my @data = @{$row->{'data'}};
    foreach my $column (@data) {
      if (ref($column) eq 'ARRAY') {
        $column = join(', ', @$column);
      }
      $html .= qq(<td>$column</td>);
    }
    if ($row->{ident} eq 'user') {
      if ($row->{'edit_url'}) {
        if ($row->{'absolute_url'}) {
          $html .= '<td style="text-align:right;"><a href="' . $row->{'edit_url'};
        } else {
          $html .= '<td style="text-align:right;"><a href="/common/' . $row->{'edit_url'} . '?id=' . $id;
        }
        if ($row->{'group_id'}) {
          $html .= '&class=group'; 
        }
        $html .= qq(">Edit</a></td>);
      }
      $html .= '<td style="text-align:right;">';
      if ($row->{'shareable'} && $is_admin) {
        $html .= qq(<a href="/common/share_record?id=$id">Share</a>);
      }
      else {
        $html .= '&nbsp;';
      }
      $html .= '</td><td style="text-align:right;"><a href="/common/' . $row->{'delete_url'} . qq(?id=$id);
      if ($row->{'group_id'}) {
        $html .= '&group_id=' . $row->{'group_id'};
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


sub _render_groups {
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
      if ($user->is_administrator_of($group)) {
        $html .= "<td style='text-align: right;'><a href='/common/groupview?id=" . $group->id . "'>Manage group</a></td>";
      } else {
        $html .= "<td style='text-align: right;'><a href='/common/unsubscribe?id=" . $group->id . "'>Unsubscribe</a></td>";
      }
      $html .= "</tr>\n";
    }
    if ($#all_groups > -1) {
      foreach my $group (@all_groups) {
        $html .= &_render_invites_for_group($group, $user);
      }
    }
    $html .= "</table><br />\n";
  }
  else {
    $html .= qq(<p class="center">You are not subscribed to any $SiteDefs::ENSEMBL_SITETYPE groups. &middot; <a href='/info/help/groups.html'>Learn more &rarr;</a> </p>);
  }  
  #$html .= "<br />";
  ## An unimplemented feature - we don't have any public groups yet.
  #$html .= &_render_all_groups($user, \%included);
  $html .= "<br />";
  $html .= qq(<p><a href="/common/create_group">Create a new group &rarr;</a></p>);
  return $html;
}

sub _render_invites_for_group {
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

sub _render_all_groups {
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

sub _render_das {
  my $user = shift;
  my $html .= &info_box($user, qq(DAS sources allow you to share annotation and other information.), 'user_das_info');
  my @dases= @{ $user->dases};
  my @records = ();
  warn "RENDERING DAS";
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
    warn "RENDERING DAS TABLE";
    $html .=  _render_settings_table(\@records, $user);
  } else {
    $html .= "You have not saved any DAS sources";
  }
  return $html;
}

sub _render_bookmarks {
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
      '<a href="' . $bookmark->url . '" title="' . $bookmark->description . '">' . $bookmark->name . '</a><br /><span style="font-size: 10px;">' . $bookmark->description . '</span>', '&nbsp;' 
    ]};
  }
  foreach my $group (@{ $user->groups }) {
    foreach my $bookmark (@{ $group->bookmarks }) {
      my $description = $bookmark->description || '&nbsp;';
      push @records, {'id' => $bookmark->id, 
                      'ident' => $group->id, 
                      'sortable' => $bookmark->name,
                      'data' => [
      '<a href="' . $bookmark->url . '" title="' . $bookmark->description . '">' . $bookmark->name . '</a><br /><span style="font-size: 10px;">' . $bookmark->description . '</span>', $group->name 
      ]};
    }
  }
  my $html;
  $html .= &info_box($user, qq(Bookmarks allow you to save frequently used pages from $SiteDefs::ENSEMBL_SITETYPE and elsewhere. When browsing $SiteDefs::ENSEMBL_SITETYPE, you can add new bookmarks by clicking the 'Add bookmark' link in the sidebar. <a href="http://www.ensembl.org/info/help/custom.html#bookmarks">Learn more about saving frequently used pages (Ensembl documentation) &rarr;</a>) , 'user_bookmark_info');
  if ($#records > -1) {
    $html .= _render_settings_table(\@records, $user);
  }
  else {
    $html .= qq(<p class="center"><img src="/img/help/bookmark_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= qq(<p class="center">You haven't saved any bookmarks. <a href='/info/help/custom.html#bookmarks'>Learn more about bookmarks &rarr;</a>);
  }  
  $html .= qq(<p><a href="/common/bookmark?forward=1"><b>Add a new bookmark </b>&rarr;</a></p>);
  return $html;
}

sub _render_configs {
  my $user = shift;
  my @configurations = @{ $user->configurations };
  my @records;

  foreach my $configuration (@configurations) {
    my $description = $configuration->description || '&nbsp;';
    my $link = "<a href='javascript:void(0);' onclick='javascript:load_config_link(" . $configuration->id . ");'>";
    push @records, {  'id' => $configuration->id, 
                      'ident' => 'user',
                      'sortable' => $configuration->name,
                      'shareable' => 1,
                      'edit_url' => 'edit_config', 
                      'delete_url' => 'remove_record',
                      'data' => [
                         $link . $configuration->name . '</a>', '&nbsp;' 
                      ]};
  }

  foreach my $group (@{ $user->groups }) {
    foreach my $configuration (@{ $group->configurations }) {
      my $description = $configuration->description || '&nbsp;';
      my $link = "<a href='javascript:void(0);' onclick='javascript:load_config_link(" . $configuration->id . ");'>";
      push @records, {'id' => $configuration->id, 
                      'ident' => $group->id, 
                      'sortable' => $configuration->name,
                      'data' => [
                        $link . $configuration->name . '</a>', $group->name
                      ]};
    }
  }

  my $html;
  $html .= &info_box($user, qq(You can save custom view configurations (DAS sources, decorations, additional drawing tracks, etc), and return to them later or share them with fellow group members. Look for the 'Save configuration link' in the sidebar when browsing $SiteDefs::ENSEMBL_SITETYPE. <a href="http://www.ensembl.org/info/help/custom.html#configurations">Learn more about view configurations (Ensembl documentation) &rarr;</a>), 'user_configuration_info');
  if ($#records > -1) {
    $html .= _render_settings_table(\@records, $user);
  }
  else {
    $html .= qq(<p class="center"><img src="/img/help/config_example.gif" /></p>);
    $html .= qq(<p class="center">You haven't saved any $SiteDefs::ENSEMBL_SITETYPE view configurations. <a href='/info/help/custom.html#configurations'>Learn more about configurating views &rarr;</a>);
  }

  return $html;
}

sub _render_notes {
  my $user = shift;
  my @notes = @{ $user->annotations };
  my @records;

  foreach my $note (@notes) {
    my $description = $note->annotation || '&nbsp;';
    warn "NOTE: " . $note;
    push @records, {  'id' => $note->id, 
                      'ident' => 'user',
                      'sortable' => $note->title,
                      'shareable' => 1,
                      'absolute_url' => 'yes',
                      'edit_url' => '/common/gene_annotation?url=/common/user/account&stable_id=' . $note->stable_id . "&id=" . $note->id, 
                      'delete_url' => 'remove_record',
                      'data' => [
      '<a href="/default/geneview?gene=' . $note->stable_id. '" title="' . $note->title . '">' . $note->stable_id . ': ' . $note->title . '</a>', '&nbsp;' 
    ]};
  }

  foreach my $group (@{ $user->groups }) {
    foreach my $note (@{ $group->annotations }) {
      my $description = $note->annotation || '&nbsp;';
      push @records, {'id' => $note->id, 
                      'ident' => $note->id, 
                      'sortable' => $note->title,
                      'data' => [
        '<a href="/default/geneview?gene=' . $note->stable_id . '" title="' . $note->title. '">' . $note->stable_id . ': ' . $note->title . '</a>', $group->name
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
    $html .= qq(<p class="center">You haven't saved any $SiteDefs::ENSEMBL_SITETYPE notes. <a href='/info/help/custom.html#notes'>Learn more about notes &rarr;</a>);
  }
  return $html;
}

sub _render_news {
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
<p><a href="/common/filter_news">Add a news filter &rarr;</a></p>
);
  }
  return $html;
}

sub denied {
  my( $panel, $object ) = @_;

## return the message
  my $html = qq(<p>Sorry - this page requires you to be logged into your $SiteDefs::ENSEMBL_SITETYPE user account and to have the appropriate permissions. If you cannot log in or need your access privileges changed, please contact <a href="mailto:webmaster\@ensembl.org">webmaster\@ensembl.org</a>. Thank you.</p>);

  $panel->print($html);
  return 1;
}

##-----------------------------------------------------------------
## USER REGISTRATION COMPONENTS    
##-----------------------------------------------------------------

sub add_group {
  my ($panel, $user) = @_;
  my $html = qq(<div class="formpanel" style="width:50%">);
  $html .= "You can create a new $SiteDefs::ENSEMBL_SITETYPE group from here. $SiteDefs::ENSEMBL_SITETYPE groups";
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
  $html .= qq(<p><a href="/common/user/register">Register</a> | <a href="/common/user/lost_password">Lost password</a></p>);
  #$html .= $panel->form('enter_details')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub enter_details   { 
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if (!$object->id) { ## new registration
    $html .= qq(<p><strong>Register with $SiteDefs::ENSEMBL_SITETYPE to bookmark your favourite pages, manage your BLAST tickets and more!</strong></p>);
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
    $html .= qq(<p>You have no bookmarks set at the moment. To set a bookmark, go to any $SiteDefs::ENSEMBL_SITETYPE content page whilst logged in (any 'view' page such as GeneView, or static content such as documentation), and click on the "Bookmark this page" link in the lefthand menu.</p>);
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
    $html .= qq(<p>You have no configurations saved in your account at the moment. To save a configuration, go to any configurable $SiteDefs::ENSEMBL_SITETYPE 'view' (such as ContigView) whilst logged in, and click on the "Save this configuration" link in the lefthand menu.</p>);
  }
  $html .= '</div>';
  
  $panel->print($html);
  return 1;
}

sub name_config     { _wrap_form($_[0], $_[1], 'name_config'); }

sub show_groups     { _wrap_form($_[0], $_[1], 'show_groups'); }

sub no_group {
  my( $panel, $user) = @_;

  my $html = qq(<p>No group was specified. Please go back to your <a href="/common/user/account">account home page</a> and click a "Manage group"
link for a group you created.</p>);

  $panel->print($html);
  return 1;
}

sub groupview {
  my( $panel, $user) = @_;
  warn "GROUPVIEW for: " . $user->id;
  my $webgroup_id = $user->param('webgroup_id');
  my $group = EnsEMBL::Web::Object::Data::Group->new({ id => $webgroup_id });

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

  $panel->print($html);
}

sub group_users {
  my( $panel, $reg_user) = @_;
  my $cgi = new CGI;
  my $user = EnsEMBL::Web::Object::Data::User->new({ id => $reg_user->id });
  warn "GROUP USERS: " . $user->id;
  my $group = EnsEMBL::Web::Object::Data::Group->new({ id => $cgi->param('id') });
  my $html = "";
  $html .= &group_users_tabview($user, $group);
  $html .= "<br />";
  $html .= "&larr; <a href='/common/user/account'>Back to your account</a>";
  $html .= "<br /><br />";
  $panel->print($html);
}

sub group_users_tabview {
  my ($user, $group) = @_;
  
  my $manageTab= EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'manage', 
                                     label => 'Group members', 
                                     content => _render_group_users($group, $user) 
                                                ));

  my $settingsTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'sharedsettings', 
                                     label => 'Shared settings', 
                                     content => _render_group_settings($group, $user) 
                                                ));

  my $inviteTab = EnsEMBL::Web::Interface::Tab->new(( 
                                     name => 'invite', 
                                     label => 'Invite', 
                                     content => _render_group_invite($group, $user)
                                                     ));

  my @invites = @{ $group->invites };
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
                                      name => "groups",
                                      tabs => [ $manageTab, $settingsTab, $pendingTab, $inviteTab ]
                                                     ));

  my $cgi = new CGI;
  my @opentabs = @{ $user->opentabs };
  if ($#opentabs > -1) {
    foreach my $opentab (@opentabs) {
      if ($opentab->name eq $tabview->name) { 
        $tabview->open($opentab->tab);
      } 
    }
  } 

  ## Override previous saved settings if necessary
  if ($cgi->param('tab')) {
     $tabview->open($cgi->param('tab'));
  }

  return $tabview->render;
}

sub _render_group_settings {
  my ($group) = @_;
  my @bookmarks = @{ $group->bookmarks };
  my @configurations = @{ $group->configurations };
  my @notes = @{ $group->annotations };
  my $html = "";
  if ($#bookmarks > -1) {
    $html .= "<h5>Bookmarks</h5>\n";
    my @records = ();
    foreach my $bookmark (@bookmarks) {
      my $description = $bookmark->description || '&nbsp;';
      push @records, {  'id' => $bookmark->id, 
                        'group_id' => $group->id,
                        'ident' => 'user',
                        'sortable' => $bookmark->name,
                        'edit_url' => 'bookmark', 
                        'delete_url' => 'remove_group_record', 
                        'data' => [
        '<a href="' . $bookmark->url . '" title="' . $bookmark->description . '">' . $bookmark->name . '</a>', '&nbsp;' 
      ]};
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
                        'ident' => 'user',
                        'sortable' => $configuration->name,
                        'edit_url' => 'edit_config', 
                        'delete_url' => 'remove_group_record', 
                        'data' => [
                          $link . $configuration->name . '</a>', '&nbsp;' 
                        ]};
    }
    $html .= _render_settings_table(\@records);
  }

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
  my ($group, $user) = @_;
  my $html = "";
  $html .= &info_box($user, "This panel lists all members of this group. You can invite new users to join your group by entering their email address in the 'Invite' tab.", "group_members_info");
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
  $html .= "To invite a new member into this group, enter their email address. Users not already registered with $SiteDefs::ENSEMBL_SITETYPE will be asked to do so before accepting your invite.<br /><br />\n";
  $html .= "<input type='hidden' value='" . $user->id . "' name='user_id' />"; 
  $html .= "<input type='hidden' value='" . $group->id . "' name='group_id' />"; 
  $html .= "<textarea name='invite_email' cols='35' rows='6'></textarea><br />Multiple email addresses can be separated by commas.<br /><br />";
  $html .= "<input type='submit' value='Invite' />";
  $html .= "</form>";
  $html .= "<br />";
  return $html;
}

sub group_details {
  my( $panel, $user) = @_;
  my $cgi = new CGI;
  my $group = EnsEMBL::Web::Object::Group->new(( id => $cgi->param('id') ));
  my $html = "<div class='pale boxed'>";
  $html .= qq(This page allows administrators to manage their $SiteDefs::ENSEMBL_SITETYPE group. From here you can invite new users to join your group, remove existing users, and decide which resources are shared between group members.<br />
                <br />For more information about $SiteDefs::ENSEMBL_SITETYPE groups, and how to use them,
                read the Ensembl <a href='http://www.ensembl.org/info/help/groups.html'>introductory guide</a>.);
  $html .= "</div>";
   
  $panel->print($html);
}

1;

