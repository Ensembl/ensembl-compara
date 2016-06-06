=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::UserData::ManageData;

use strict;

use Digest::MD5 qw(md5_hex);
use URI::Escape qw(uri_escape);
use HTML::Entities  qw(encode_entities);

use EnsEMBL::Web::Data::Session;
use EnsEMBL::Web::File::User;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub header {
  my $self = shift;
  my $info_icon = '<img class="_ht" src="/i/16/info.png" />';
  my $tip = encode_entities(qq{
          <p>You can rename your uploads and attached URLs by clicking on their current name in the Source column</p>
          <p><a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a></p>
            });

  return qq{
    <h2 class="legend">Your data <span class="ht _ht"><span class="_ht_tip hidden">$tip</span>$info_icon</span></h2>
  };
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $session      = $hub->session;
  my $session_id   = $session->session_id;
  my $user         = $hub->user;
  my $species_defs = $hub->species_defs;
  my $not_found    = 0;
  my (@data, @rows, $html);  

  my @temp_data = map $session->get_data('type' => $_), qw(upload url);
  
  push @data, map $user->get_records($_), qw(uploads urls) if $user;
  push @data, @temp_data;
  
  my $checkbox = '<input type="checkbox" class="choose_all" value="all" />';
  if (scalar @data) {

    #$html .= $self->_add_buttons;
    $html = sprintf '<div class="js_panel" id="ManageData"><form action="%s">', $hub->url({'action' => 'ModifyData', 'function' => 'mass_update'});

    my @columns = (
      #{ key => 'check',   title => '',             width => '5%', align => 'center'                                  },
      { key => 'type',    title => 'Type',         width => '10%', align => 'left'                                  },
      #{ key => 'status',  title => 'Status',       width => '10%', align => 'left'                                  },
      { key => 'name',    title => 'Source',       width => '30%', align => 'left', sort => 'html', class => 'wrap' },
      { key => 'species', title => 'Species',      width => '20%', align => 'left', sort => 'html'                  },
      { key => 'assembly', title => 'Assembly',    width => '15%', align => 'left', sort => 'html'                  },
      { key => 'date',    title => 'Last updated', width => '20%', align => 'left', sort => 'numeric_hidden'        },
    );
    
    push @columns, ({ key => 'actions', title => 'Actions', width => '120px', align => 'center', sort => 'none' });
   
    my $old_assemblies = 0; 
    foreach my $file (@data) {
      my @assemblies = split(', ', $file->{'assembly'});
      ## check if we have current assemblies
      $old_assemblies++ if (scalar(@assemblies) < 1); 
      foreach (@assemblies) {
        $old_assemblies++ if ($_ ne $hub->species_defs->get_config($file->{'species'}, 'ASSEMBLY_VERSION'));
      }
      my $user_record = ref($file) =~ /Record/;
      my $sharers     = $file->{'code'} =~ /_$session_id$/ ? EnsEMBL::Web::Data::Session->count(code => $file->{'code'}, type => $file->{'type'}) : 0;
         $sharers-- if $sharers && !$file->{'user_id'}; # Take one off for the original user
     
      if ($file->{'filename'}) {
        my %args = (
                    'hub'             => $hub, 
                    'file'            => $file->{'file'}, 
                    'extension'       => $file->{'extension'}
                    );
        if ($file->{'prefix'}) {
          $args{'prefix'} = $file->{'prefix'};
        }
        else {
          $args{'read_datestamp'} = $file->{'datestamp'};
        }
        my $user_file = EnsEMBL::Web::File::User->new(%args);
        if (!$user_file->exists) {
          $file->{'name'} .= ' (File could not be found)';
          $not_found++;
        }
      }

      my $row = $self->table_row($file, $sharers);
     
      my ($id, $type) = ($file->{'code'} =~ /^(\w+)_(\d+)$/);
      
      if (                                                              # This is a shared record (belonging to another user) if:
        !($user_record && $user && $file->created_by == $user->id) && ( # it's not a user record which was created by this user             AND  (stops $shared being true for the same user id with multiple session ids)
          ($type eq 'session' && $id != $session->session_id) ||        # it's a session record where the id doesn't match this session id  OR
          ($type eq 'user'    && $user && $id != $user->id)   ||        # it's a user record where the id doesn't match this user id        OR
          ($type eq 'user'    && !$user)                                # it's a user record where there is no logged in user
        )
      ) {
        delete $row->{$_} for qw(save share); # Remove controls if the data does not belong to the current user
      }
      
      push @rows, $row;
    }

    $html .= $self->new_table(\@columns, \@rows, { data_table => 'no_col_toggle', exportable => 0, class => 'fixed editable' })->render;
    if ($old_assemblies) {
      my $plural = $old_assemblies > 1 ? '' : 's';
      $html .= $self->warning_panel('Possible mapping issue', "$old_assemblies of your files contain$plural data on an old or unknown assembly. You may want to convert your data and re-upload, or try an archive site.");
    }
  
    $html .= '</form></div>';
  }
  
  $html  .= $self->group_shared_data;
  $html  .= $self->_warning('File not found', sprintf('<p>The file%s marked not found %s unavailable. Please try again later.</p>', $not_found == 1 ? ('', 'is') : ('s', 'are')), '100%') if $not_found;
  $html  .= '<div class="modal_reload"></div>' if $hub->param('reload');

  my $trackhub_search = sprintf '<a href="%s" class="modal_link" rel="modal_user_data"><img src="/i/16/globe.png" style="margin-right:8px; vertical-align:middle" />Search for public track hubs</a></p>', $hub->url({'action' => 'TrackHubSearch'});

  if (scalar @data) {
    my $more  = sprintf '<p><a href="%s" class="modal_link" rel="modal_user_data"><img src="/i/16/page-user.png" style="margin-right:8px;vertical-align:middle;" />Add more data</a> | %s', $hub->url({'action'=>'SelectFile'}), $trackhub_search; 
    ## Show 'add more' link at top as well, if table is long
    if (scalar(@rows) > 10) {
      $html = $more.$html;
    }

    $html .= $more if scalar(@rows);
  }
  else {
    $html .= $trackhub_search;
  }

  return $html;
}

sub _icon_inner {
  my ($self, $params) = @_;
  return qq(<span class="sprite _ht $params->{'class'}" title="$params->{'title'}">&nbsp;</span>);
}

sub _icon {
  my ($self, $params) = @_;
  $params->{'link'} ||= '%s';
  $params->{$_} ||= '' for qw(link_class link_extra class);
  
  my $title = ucfirst $params->{'class'};
     $title =~ s/_icon$//;
  
  $params->{'title'} ||= $title;
  
  my $inner = $self->_icon_inner($params);
  
  return $inner if $params->{'no_link'};
  return qq(<a href="$params->{'link'}" class="$params->{'link_class'} icon_link" rel="modal_user_data" $params->{'link_extra'}>$inner</a>);
}

sub _no_icon {
  return '';
}

sub _add_buttons {
### Buttons for applying methods to all selected files
### Note they are disabled until some files are selected
  my $self    = shift;
  my $hub     = $self->hub;

  my $html = '<div class="ff-inline tool_buttons"><b>Update selected</b>: ';

  my @buttons = qw(enable disable delete);

  foreach (@buttons) {
    $html .= sprintf '<input type="submit" name="%s_button" value="%s" class="%s fbutton disabled modal_link">', 
                        $_, ucfirst($_), $_;
  }
  $html .= '</div>';

  return $html;
}

sub table_row {
  my ($self, $file, $sharers) = @_;
  my $hub          = $self->hub;
  my $img_url      = $self->img_url.'16/';
  my $delete_class = $sharers ? 'modal_confirm' : 'modal_link';
  my $title        = $sharers ? ' title="This data is shared with other users"' : '';
  my $delete       = $self->_icon({ link_class => $delete_class, class => 'delete_icon', link_extra => $title });
  my $group_sharing_info = $hub->user && $hub->user->find_admin_groups ? 'You cannot share temporary data with a group until you save it to your account.' : '';

  my $share        = $self->_icon({ link_class => 'modal_link',  class => 'share_icon' });
  my $download     = $self->_no_icon;
  my $reload       = $self->_no_icon;
  my $conf_template = $self->_no_icon;
  my $user_record  = ref($file) =~ /Record/;
  my $name         = qq{<div><strong class="val" title="Click here to rename your data">$file->{'name'}</strong>};
  my %url_params   = ( __clear => 1, source => $file->{'url'} ? 'url' : 'upload' );
  my ($save, $assembly);
  
  if ($file->{'prefix'} && $file->{'prefix'} eq 'download') {
    my $format   = $file->{'format'} eq 'report' ? 'txt' : $file->{'format'};
       $download = $self->_icon({ link => sprintf('/%s/download?file=%s;prefix=download;format=%s', $hub->species, $file->{'filename'}, $format), class => 'download_icon', title => 'Download' });
  }
  
  if ($user_record) {
    $assembly = $file->assembly || 'Unknown';
    $url_params{'id'} = join '-', $file->id, md5_hex($file->code);
    $save = $self->_icon({ no_link => 1, class => 'sprite_disabled save_icon', title => 'Saved data' });
  } else {
    $assembly = $file->{'assembly'} || 'Unknown';    

    $url_params{'code'} = $file->{'code'};

    if ($hub->users_available) {
      my $save_html = $self->_icon({ link_class => 'modal_link', class => 'save_icon', title => '%s' });
      my $save_url  = $hub->url({ action => 'ModifyData', function => $file->{'url'} ? 'save_remote' : 'save_upload', code => $file->{'code'}, __clear => 1 });
   
      $save = sprintf $save_html, $hub->user ? ($save_url, 'Save to account') : ($hub->url({ type => 'Account', action => 'Login', __clear => 1, then => uri_escape($save_url), modal_tab => 'modal_user_data' }), 'Log in to save');
    }
  }
  
  $name .= sprintf(
    '<input type="text" maxlength="255" name="record_name" /><a href="%s" class="save"></a></div>',
    $hub->url({
      action   => 'ModifyData',
      function => $user_record ? 'rename_user_record' : 'rename_session_record',
      %url_params
    })
  );
  
  if ($file->{'nearest'}) {
    $name .= sprintf(
      '<a href="%s;contigviewbottom=%s">View sample location</a><br />',
      $hub->url({
        species  => $file->{'species'},
        type     => 'Location',
        action   => 'View',
        function => undef,
        r        => $file->{'nearest'},
        __clear  => 1
      }),
      join ',', map $_ ? "$_=on" : (), join '_', $user_record ? 'user' : $file->{'type'}, $file->{'code'}
    );
  }
 
  if ($file->{'format'} eq 'TRACKHUB') {
    $name .= $file->{'description'};
  }
  else { 
    $name .= $file->{'url'} || sprintf '%s file', $file->{'filetype'} || $file->{'format'};
  }

  ## Link for valid datahub  
  my ($config_link, $conf_template);
  if ($file->{'format'} eq 'TRACKHUB' && $hub->species_defs->get_config($file->{'species'}, 'ASSEMBLY_VERSION') eq $file->{'assembly'}) {
    $conf_template  = $self->_icon({ class => 'config_icon', 'title' => 'Configure hub tracks for '.$hub->species_defs->get_config($file->{'species'}, 'SPECIES_COMMON_NAME') });
    my $sample_data = $hub->species_defs->get_config($file->{'species'}, 'SAMPLE_DATA') || {};
    my $default_loc = $sample_data->{'LOCATION_PARAM'};
    (my $menu_name = $file->{'name'}) =~ s/ /_/g;
    $config_link = $hub->url({
        species  => $file->{'species'},
        type     => 'Location',
        action   => 'View',
        function => undef,
        r        => $hub->param('r') || $default_loc,
    });
    ## Add menu name here, as we need it in icon link, below this block
    $config_link .= '#modal_config_viewbottom-'.$menu_name;
    $name .= sprintf('<br /><a href="%s">Configure hub</a>',
      $config_link,
    );
  }

  my $config_html = $config_link ? sprintf $conf_template, $config_link : '';
  my $share_html  = sprintf $share,  $hub->url({ action => 'SelectShare', %url_params });
  my $delete_html = sprintf $delete, $hub->url({ action => 'ModifyData', function => lc($file->{'type'}) eq 'url' ? 'delete_remote' : 'delete_upload', %url_params });
  if ($file->{'format'} eq 'TRACKHUB' || $file->{'type'} eq 'upload' && $file->{'url'}) {
    my ($reload_action, $reload_text);
    if ($file->{'format'} eq 'TRACKHUB') {
      $reload_action = 'RefreshTrackHub';
      $reload_text   = 'Reload this track hub';
    }
    else {
      $reload_action = 'RefreshUpload';
      $reload_text   = 'Reload this file from URL';
    }
    my $reload_url = $hub->url({'action' => $reload_action, %url_params});
    $reload = $self->_icon({'link' => $reload_url, 'title' => $reload_text, 'link_class' => 'modal_link', 'class' => 'reload_icon'});
  }

  my $checkbox = sprintf '<input type="checkbox" class="mass_update" value="%s_%s" />', $file->{'type'}, $file->{'code'};

  return {
    check   => $checkbox,
    type    => $file->{'type'} =~ /url/i ? 'URL' : ucfirst($file->{'type'}),
    status  => ucfirst($file->{'status'}) || 'Enabled', 
    name    => { value => $name, class => 'wrap editable' },
    species => sprintf('<em>%s</em>', $hub->species_defs->get_config($file->{'species'}, 'SPECIES_SCIENTIFIC_NAME')),
    assembly => $assembly,
    date    => sprintf('<span class="hidden">%s</span>%s', $file->{'timestamp'} || '-', $self->pretty_date($file->{'timestamp'}, 'simple_datetime')),
    actions => "$config_html$download$reload$save$share_html$delete_html",
  };
}

sub group_shared_data {
  my $self    = shift;
  my $hub     = $self->hub;
  my $user    = $hub->user        or return;
  my @groups  = $user->get_groups or return;

  my @columns = (
    { key => 'type',    title => 'Type',         width => '10%', align => 'left'                  },
    { key => 'name',    title => 'Source',       width => '39%', align => 'left', class => 'wrap' },
    { key => 'species', title => 'Species',      width => '15%', align => 'left'                  },
    { key => 'date',    title => 'Last updated', width => '16%', align => 'left'                  },
    { key => 'share',   title => '',             width => '20%', align => 'right'                 }
  );
  
  my $html;
  
  foreach my $group (@groups) {
    my @rows;
    
    foreach (grep $_, $user->get_group_records($group, 'uploads'), $user->get_group_records($group, 'urls')) {
      push @rows, {
        %{$self->table_row($_)},
        share => sprintf('<a href="%s" class="modal_link">Unshare</a>', $hub->url({ action => 'Unshare', id => $_->id, webgroup_id => $group->group_id, __clear => 1 }))
      };
    }
    
    next unless scalar @rows;
    
    $html .= sprintf '<h4>Data shared from the <i>%s</i> group</h4>', $group->name;
    $html .= $self->new_table(\@columns, \@rows, { class => 'fixed editable' })->render;
  }
  
  return $html;
}

1;
