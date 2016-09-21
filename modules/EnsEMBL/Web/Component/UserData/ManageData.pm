=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

use EnsEMBL::Web::File::User;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub header {
  my $self = shift;

  return sprintf '<h2 class="legend">Your data <span class="_ht"><span class="_ht_tip hidden">%s</span><img src="%s16/info.png" /></span></h2>',
    encode_entities(qq{
      <p>You can rename your uploads and attached URLs by clicking on their current name in the Source column</p>
      <p><a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a></p>
    }),
    $self->img_url;
}

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $session         = $hub->session;
  my $user            = $hub->user;
  my $species_defs    = $hub->species_defs;
  my $img_url         = $self->img_url;
  my $not_found       = 0;
  my $records_data    = $self->object->get_userdata_records;

  my (@data, @rows);
  my $html = '';

  ## Show table if any user or session record is present
  if (@$records_data) {

    my $old_assemblies  = 0;
    my $here            = $hub->species_defs->ENSEMBL_SERVERNAME;
    my $data_elsewhere  = 0;
    my %other_servers;

    $html .= sprintf '<div class="js_panel" id="ManageData"><form action="%s">', $hub->url({'action' => 'ModifyData', 'function' => 'mass_update'});

    my @columns = (
      { key => 'type',      title => 'Type',          width => '10%',   align => 'left'                                     },
      { key => 'name',      title => 'Source',        width => '30%',   align => 'left',    sort => 'html', class => 'wrap' },
      { key => 'species',   title => 'Species',       width => '20%',   align => 'left',    sort => 'html'                  },
      { key => 'assembly',  title => 'Assembly',      width => '15%',   align => 'left',    sort => 'html'                  },
      { key => 'date',      title => 'Last updated',  width => '20%',   align => 'left',    sort => 'numeric_hidden'        },
      { key => 'actions',   title => 'Actions',       width => '120px', align => 'center',  sort => 'none'                  },
    );

    foreach my $record_data (@$records_data) {
      my @assemblies = split(', ', $record_data->{'assembly'});
      ## check if we have current assemblies
      $old_assemblies++ if (scalar(@assemblies) < 1);
      foreach (@assemblies) {
        $old_assemblies++ if ($_ ne $hub->species_defs->get_config($record_data->{'species'}, 'ASSEMBLY_VERSION'));
      }

      ## Hide saved records that were not uploaded on the current server
      if ($record_data->{'site'} && $record_data->{'site'} ne $here) {
        $data_elsewhere = 1;
        $other_servers{$record_data->{'site'}} = 1;
        next;
      }

      ## Data was uploaded on release 84, before we added the site to records
      if (!$record_data->{'site'}) {
        my $path_to_file = $hub->species_defs->ENSEMBL_TMP_DIR.'/'.$record_data->{'file'};
        unless (-e $path_to_file) {
          $data_elsewhere = 1;
          next;
        }
      }

      if ($record_data->{'filename'}) {
        my %args = (
                    'hub'             => $hub,
                    'file'            => $record_data->{'file'},
                    'extension'       => $record_data->{'extension'}
                    );
        if ($record_data->{'prefix'}) {
          $args{'prefix'} = $record_data->{'prefix'};
        }
        else {
          $args{'read_datestamp'} = $record_data->{'datestamp'};
        }
        my $user_file = EnsEMBL::Web::File::User->new(%args);
        if (!$user_file->exists) {
          $record_data->{'name'} .= ' (File could not be found)';
          $not_found++;
        }
      }

      my $row = $self->table_row($record_data);

      push @rows, $row;
    }

    $html .= $self->new_table(\@columns, \@rows, { data_table => 'no_col_toggle', exportable => 0, class => 'fixed editable' })->render;
    if ($old_assemblies) {
      my $plural = $old_assemblies > 1 ? '' : 's';
      $html .= $self->warning_panel('Possible mapping issue', "$old_assemblies of your files contain$plural data on an old or unknown assembly. You may want to convert your data and re-upload, or try an archive site.");
    }

    $html .= '</form></div>';

    if ($data_elsewhere) {
      my $message;
      if (scalar keys %other_servers) {
        $message = 'You also have uploaded data saved on the following sites:<br /><ul>';
        foreach (keys %other_servers) {
          $message .= sprintf('<li><a href="http://%s">%s</a></li>', $_, $_);
        }
        $message .= '</ul>';
      }
      else {
        $message = sprintf 'You also have uploaded data saved on other %s sites (e.g. a mirror or archive) that we cannot show here.', $hub->species_defs->ENSEMBL_SITETYPE;
      }
      $html .= $self->info_panel('Saved data on other servers', $message);
    }
  }

  $html  .= $self->group_shared_data;
  $html  .= $self->_warning('File not found', sprintf('<p>The file%s marked not found %s unavailable. Please try again later.</p>', $not_found == 1 ? ('', 'is') : ('s', 'are')), '100%') if $not_found;
  $html  .= '<div class="modal_reload"></div>' if $hub->param('reload');

  my $trackhub_search = $self->trackhub_search;

  if (scalar @$records_data) {
    my $more  = sprintf '<p><a href="%s" class="modal_link" rel="modal_user_data"><img src="/i/16/page-user.png" style="margin-right:8px;vertical-align:middle;" />Add more data</a> | %s', $hub->url({'action'=>'SelectFile'}), $trackhub_search;
    ## Show 'add more' link at top as well, if table is long
    if (scalar(@rows) > 10) {
      $html = $more.$html;
    }

    $html .= $more if scalar(@rows);
  }
  else {
    $html .= $trackhub_search;
    $html .= $self->userdata_form;
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

sub table_row {
  my ($self, $record_data, $sharers) = @_;
  my $hub          = $self->hub;
  my $img_url      = $self->img_url.'16/';
  my $delete_class = $sharers ? 'modal_confirm' : 'modal_link';
  my $title        = $sharers ? ' title="This data is shared with other users"' : '';
  my $delete       = $self->_icon({ link_class => $delete_class, class => 'delete_icon', link_extra => $title });
  my $group_sharing_info = $hub->user && $hub->user->find_admin_groups ? 'You cannot share temporary data with a group until you save it to your account.' : '';
  my $user_record  = $record_data->{'record_type'} eq 'user';
  my $share        = $self->_icon({ link_class => 'modal_link',  class => 'share_icon' });
  my $download     = $self->_no_icon;
  my $reload       = $self->_no_icon;
  my $name         = qq(<div><strong class="val" title="Click here to rename your data">$record_data->{'name'}</strong>);
  my %url_params   = ( __clear => 1, source => $record_data->{'url'} ? 'url' : 'upload' );
  my ($save, $assembly);

  if ($record_data->{'prefix'} && $record_data->{'prefix'} eq 'download') {
    my $format   = $record_data->{'format'} eq 'report' ? 'txt' : $record_data->{'format'};
       $download = $self->_icon({ link => sprintf('/%s/download?file=%s;prefix=download;format=%s', $hub->species, $record_data->{'filename'}, $format), class => 'download_icon', title => 'Download' });
  }

  if ($user_record) {
    $assembly = $record_data->{'assembly'} || 'Unknown';
    $url_params{'id'} = join '-', $record_data->{'id'}, md5_hex($record_data->{'code'});
    $save = $self->_icon({ no_link => 1, class => 'sprite_disabled save_icon', title => 'Saved data' });
  } else {
    $assembly = $record_data->{'assembly'} || 'Unknown';

    $url_params{'code'} = $record_data->{'code'};

    if ($hub->users_available) {
      my $save_html = $self->_icon({ link_class => 'modal_link', class => 'save_icon', title => '%s' });
      my $save_url  = $hub->url({ action => 'ModifyData', function => $record_data->{'url'} ? 'save_remote' : 'save_upload', code => $record_data->{'code'}, __clear => 1 });

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

  if ($record_data->{'nearest'}) {
    $name .= sprintf(
      '<a href="%s;contigviewbottom=%s">View sample location</a><br />',
      $hub->url({
        species  => $record_data->{'species'},
        type     => 'Location',
        action   => 'View',
        function => undef,
        r        => $record_data->{'nearest'},
        __clear  => 1
      }),
      join ',', map $_ ? "$_=on" : (), join '_', $user_record ? 'user' : $record_data->{'type'}, $record_data->{'code'}
    );
  }

  if ($record_data->{'format'} eq 'TRACKHUB') {
    $name .= $record_data->{'description'};
  }
  else {
    $name .= $record_data->{'url'} || sprintf '%s file', $record_data->{'filetype'} || $record_data->{'format'};
  }

  ## Link for valid datahub
  my ($config_link, $conf_template);
  if ($record_data->{'format'} eq 'TRACKHUB' && $hub->species_defs->get_config($record_data->{'species'}, 'ASSEMBLY_VERSION') eq $record_data->{'assembly'}) {
    $conf_template  = $self->_icon({ class => 'config_icon', 'title' => 'Configure hub tracks for '.$hub->species_defs->get_config($record_data->{'species'}, 'SPECIES_COMMON_NAME') });
    my $sample_data = $hub->species_defs->get_config($record_data->{'species'}, 'SAMPLE_DATA') || {};
    my $default_loc = $sample_data->{'LOCATION_PARAM'};
    (my $menu_name = $record_data->{'name'}) =~ s/ /_/g;
    $config_link = $hub->url({
        species  => $record_data->{'species'},
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
  my $delete_html = sprintf $delete, $hub->url({ action => 'ModifyData', function => lc($record_data->{'type'}) eq 'url' ? 'delete_remote' : 'delete_upload', %url_params });
  if ($record_data->{'format'} eq 'TRACKHUB' || $record_data->{'type'} eq 'upload' && $record_data->{'url'}) {
    my ($reload_action, $reload_text);
    if ($record_data->{'format'} eq 'TRACKHUB') {
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

  my $checkbox = sprintf '<input type="checkbox" class="mass_update" value="%s_%s" />', $record_data->{'type'}, $record_data->{'code'};

  return {
    check   => $checkbox,
    type    => $record_data->{'type'} =~ /url/i ? 'URL' : ucfirst($record_data->{'type'}),
    status  => ucfirst($record_data->{'status'} || 'Enabled'),
    name    => { value => $name, class => 'wrap editable' },
    species => sprintf('<em>%s</em>', $hub->species_defs->get_config($record_data->{'species'}, 'SPECIES_SCIENTIFIC_NAME')),
    assembly => $assembly,
    date    => sprintf('<span class="hidden">%s</span>%s', $record_data->{'timestamp'} || '-', $self->pretty_date($record_data->{'timestamp'}, 'simple_datetime')),
    actions => join '', grep $_, $config_html, $download, $reload, $save, $share_html, $delete_html,
  };
}

sub group_shared_data {
  my $self    = shift;
  my $hub     = $self->hub;
  my $user    = $hub->user        or return '';
  my @groups  = @{$user->groups}  or return '';

  my @columns = (
    { key => 'type',    title => 'Type',         width => '10%', align => 'left'                  },
    { key => 'name',    title => 'Source',       width => '39%', align => 'left', class => 'wrap' },
    { key => 'species', title => 'Species',      width => '15%', align => 'left'                  },
    { key => 'date',    title => 'Last updated', width => '16%', align => 'left'                  },
    { key => 'share',   title => '',             width => '20%', align => 'right'                 }
  );

  my $html = '';

  foreach my $group (@groups) {
    my @rows;

    foreach (grep $_, $group->records('uploads'), $group->records('urls')) {
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
