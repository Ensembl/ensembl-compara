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

package EnsEMBL::Web::ImageConfigExtension::UserTracks;

### An Extension to EnsEMBL::Web::ImageConfig
### Methods to load tracks from custom data/files/urls etc

package EnsEMBL::Web::ImageConfig;

use strict;
use warnings;
no warnings qw(uninitialized);

use EnsEMBL::Web::File::Utils::TrackHub;
use EnsEMBL::Web::Utils::FormatText qw(add_links);
use EnsEMBL::Web::Utils::Sanitize qw(clean_id strip_HTML);

sub load_user_tracks {
  ## Loads tracks attached by user
  my $self = shift;
  my $menu = $self->get_node('user_data');

  # Custom tracks menu not present - custom tracks not allowed
  return unless $menu;

  # Load single track added via url params
  $self->_load_url_feature_track($menu);

  # Load tracks attached via url
  $self->_load_remote_url_tracks($menu);

  # Load tracks from uploaded files
  $self->_load_uploaded_tracks($menu);
}

sub display_threshold_message {
  ## Displays a session message if number of loaded tracks is more than that can be accommodated
  my $self          = shift;
  my $threshold     = $self->{'userdata_threshold'};
  my $hidden_tracks = $self->{'user_track_count'} - $threshold;

  if ($hidden_tracks > 0) {
    $self->hub->session->set_record_data({
      'type'      => 'message',
      'function'  => '_warning',
      'code'      => 'threshold_warning',
      'message'   => "You have turned on too many tracks for the browser to load, so $hidden_tracks have been hidden. Please use Configure This Page to select a subset of $threshold tracks to display.",
    });
  }
}

sub check_threshold {
  ## Check if we've already loaded as many user tracks as we can cope with
  ## @param display String
  ## @return 1 if still OK, 0 if check fails i.e. threshold exceeded
  my ($self, $display) = @_;
  #warn ">>> CHECKING TRACK - CURRENTLY $display";

  $display ||= 'off';

  return $display if $display eq 'off';

  ## Track is supposed to be on, so compare with threshold
  if ($self->{'user_track_count'} >= $self->{'userdata_threshold'}) {
    #warn "@@@ THRESHOLD EXCEEDED!";
    $display = 'off';
  } else {
    $self->{'user_track_count'}++;
  }

  return $display;
}

sub _load_url_feature_track {
  ## @private
  ## Creates and adds to the config, a temporary track based on a single line of a row-based data file, such as VEP output, e.g. 21 9678256 9678256 T/G 1
  my ($self, $menu) = @_;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $data    = decode_entities($hub->param('custom_feature') || '');
  my $format  = decode_entities($hub->param('format') || '');

  my $session_record_data;

  # if params are present in the current url
  if ($data && $format) {

    $session_record_data = {
      'code'    => 'custom_feature',
      'type'    => 'custom',
      'format'  => $format,
      'data'    => $data
    };

    $session->set_record_data($session_record_data);

  # if not in the url, get a previous one from session record
  } else {
    $session_record_data = $session->get_record_data({'code' => 'custom_feature', 'type' => 'custom'});
    if (keys %$session_record_data) {
      $data   = $session_record_data->{'data'};
      $format = $session_record_data->{'format'};
    }
  }

  return unless $data && $format;

  my ($strand, $renderers, $default) = $self->_user_track_settings(undef, $format);

  my $track = $self->create_track_node('custom_feature', 'Single feature', {
    'linked_record'   => {'type' => $session_record_data->{'type'}, 'code' => $session_record_data->{'code'}, 'record_type' => 'session'},
    'external'        => 'user',
    'glyphset'        => 'flat_file',
    'colourset'       => 'classes',
    'sub_type'        => 'single_feature',
    'format'          => $format,
    'caption'         => sprintf('Single %s feature', {$hub->species_defs->multi_val('DATA_FORMAT_INFO') || {}}->{$format}{'label'} || ''),
    'renderers'       => $renderers,
    'description'     => 'A single feature that has been loaded via a URL',
    'display'         => 'off',
    'default_display' => $default,
    'strand'          => $strand,
    'data'            => $data,
  });

  $menu->append_child($track) if $track;
}

sub _load_remote_url_tracks {
  ## @private
  ## Adds tracks attached via remote url
  my ($self, $menu)   = @_;
  my $hub             = $self->hub;
  my $session         = $hub->session;
  my $user            = $hub->user;
  my $session_records = $session->records({'type' => 'url', 'species' => $self->species});
  my $user_records    = $user ? $user->records({'type' => 'url', 'species' => $self->species}) : [];
  my $saved_config    = $self->get_user_settings->{'nodes'} || {};

  my %tracks_data;

  foreach my $record (@$session_records, @$user_records) {

    my $data = $record->data;

    next if $data->{'no_attach'};
    ## Don't turn off tracks that were added before disconnection code
    next if (defined $data->{'disconnected'} && $data->{'disconnected'} == 1);

    my $source_name = strip_HTML($data->{'name'}) || $data->{'url'};

    next unless $source_name;

    ## Do we have any saved config for this track?
    my $key     = sprintf '%s_%s', $record->type, $record->code;
    my $config  = $saved_config->{$key} || {};

    ## These can be zero, so check if defined
    my ($y_min, $y_max);
    if (defined($config->{'y_min'})) {
      $y_min = $config->{'y_min'};
    }
    elsif (defined($data->{'y_min'})) {
      $y_min = $data->{'y_min'};
    }
    if (defined($config->{'y_max'})) {
      $y_max = $config->{'y_max'};
    }
    elsif (defined($data->{'y_max'})) {
      $y_max = $data->{'y_max'};
    }

    $tracks_data{'url_'.$record->code} = {
      'linked_record' => {'type' => $record->type, 'code' => $record->code, 'record_type' => $record->record_type},
      'source_type'   => $record->record_type,
      'source_name'   => $source_name,
      'source_url'    => $data->{'url'}       || '',
      'species'       => $data->{'species'}   || '',
      'format'        => $data->{'format'}    || '',
      'style'         => $data->{'style'}     || '',
      'colour'        => $data->{'colour'}    || '',
      'y_min'         => $y_min, 
      'y_max'         => $y_max, 
      'renderers'     => $data->{'renderers'} || '',
      'timestamp'     => $data->{'timestamp'} || time,
      'display'       => $data->{'display'}, #$self->check_threshold($data->{'display'}),
    };
  }

  # Now add all remote URL data sources
  foreach my $code (sort { $tracks_data{$a}{'source_name'} cmp $tracks_data{$b}{'source_name'} } keys %tracks_data) {

    my $track_data = $tracks_data{$code};

    if (lc $track_data->{'format'} eq 'trackhub') {
      my ($trackhub_menu, $hub_info) = $self->get_parameter('can_trackhubs') ? $self->_add_trackhub(strip_HTML($track_data->{'source_name'}), $track_data->{'source_url'}) : ();

      if ($hub_info->{'error'}) {
        $self->hub->session->set_record_data({
          'type'      => 'message',
          'function'  => '_warning',
          'code'      => 'trackhub_barf',
          'message'   => "Problem parsing hub data: ".join('', @{$hub_info->{'error'}}),
        });
        next;
      }

      if ($trackhub_menu && ($trackhub_menu = $self->get_node($trackhub_menu))) {
        $trackhub_menu->set_data('linked_record', $track_data->{'linked_record'});
      }

    } else {

      my $add_method = sprintf('_add_%s_track', lc $track_data->{'format'});

      if ($self->can($add_method)) {
        $self->$add_method(
          'key'      => $code,
          'menu'     => $menu,
          'source'   => $track_data,
          'external' => 'user'
        );
      } else {

        my $desc = sprintf('Data retrieved from an external webserver. This data is attached %, and comes from URL: <a href="%s">%2$s</a>',
          $track_data->{'source_type'} eq 'session' ? 'temporarily' : 'and saved',
          encode_entities($track_data->{'source_url'})
        );

        $self->_add_flat_file_track($menu, 'url', $code, $track_data->{'source_name'}, $desc, {
          'url'       => $track_data->{'source_url'},
          'format'    => $track_data->{'format'},
          'style'     => $track_data->{'style'},
          'renderers' => $track_data->{'renderers'},
          'external'  => 'user',
        });
      }
    }
  }
}

sub _load_uploaded_tracks {
  ## @private
  ## Loads all the tracks uploaded via data files
  my ($self, $menu)   = @_;
  my $hub             = $self->hub;
  my $session         = $hub->session;
  my $user            = $hub->user;
  my $session_records = $session->records({'type' => 'upload', 'species' => $self->species});
  my $user_records    = $user ? $user->records({'type' => 'upload', 'species' => $self->species}) : [];
  my $saved_config    = $self->get_user_settings->{'nodes'} || {};

  foreach my $record (@$session_records, @$user_records) {

    my $data    = $record->data;
    next if (defined $data->{'disconnected'} && $data->{'disconnected'} == 1);

    my $is_user = $record->record_type ne 'session'; # both user and group

    ## Do we have any saved config for this track?
    my $key     = sprintf '%s_%s', $record->type, $record->code;
    my $config  = $saved_config->{$key} || {};

    my ($strand, $renderers, $default) = $self->_user_track_settings($data->{'style'} // '', $data->{'format'} // '');

    $strand         = $data->{'strand'}     // $strand;
    $renderers      = $data->{'renderers'}  // $renderers;
    my $description = sprintf 'Data that has been %s to the web server. %s', $is_user ? 'saved': 'temporarily uploaded', $data->{'description'} ? add_links($data->{'description'}) : '';
    my $display     = $data->{'display'}; #$self->check_threshold($data->{'display'});

    ## These can be zero, so check if defined
    my ($y_min, $y_max);
    if (defined($config->{'y_min'})) {
      $y_min = $config->{'y_min'};
    }
    elsif (defined($data->{'y_min'})) {
      $y_min = $data->{'y_min'};
    } 
    if (defined($config->{'y_max'})) {
      $y_max = $config->{'y_max'};
    }
    elsif (defined($data->{'y_max'})) {
      $y_max = $data->{'y_max'};
    } 

    $menu->append_child($self->create_track_node('upload_'.$record->code, $data->{'name'}, {
      'linked_record'   => {'type' => $record->type, 'code' => $record->code, 'record_type' => $record->record_type},
      'external'        => 'user',
      'sub_type'        => $is_user ? 'user' : 'tmp',
      'glyphset'        => 'flat_file',
      'colourset'       => 'userdata',
      'colour'          => $data->{'colour'}  || '',
      'y_min'           => $y_min, 
      'y_max'           => $y_max, 
      'file'            => $data->{'file'}    || '',
      'format'          => $data->{'format'}  || '',
      'style'           => $data->{'style'}   || '',
      'caption'         => $data->{'name'}    || '',
      'renderers'       => $renderers,
      'description'     => $description,
      'display'         => $display,
      'default_display' => $data->{'display'} || $default,
      'strand'          => $strand,
    }));
  }
}

sub _add_trackhub {
  my ($self, $menu_name, $url, $existing_menu, $force_hide) = @_;

  ## Check if this trackhub is already attached - now that we can attach hubs via
  ## URL, they may not be saved in the imageconfig
  my $already_attached = $self->get_node($menu_name);
  return ($menu_name, {}) if ($already_attached || $self->{'_attached_trackhubs'}{$url});

  ## Note: no need to validate assembly at this point, as this will have been done
  ## by the attachment interface - otherwise we run into issues with synonyms
  my $trackhub  = EnsEMBL::Web::File::Utils::TrackHub->new('hub' => $self->hub, 'url' => $url);
  my $hub_info = $trackhub->get_hub({'parse_tracks' => 1}); ## Do we have data for this species?

  if ($hub_info->{'error'}) {
    ## Probably couldn't contact the hub
    push @{$hub_info->{'error'}||[]}, '<br /><br />Please check the source URL in a web browser.';
  } else {
    my $description = $hub_info->{'details'}{'longLabel'};
    if ($hub_info->{'details'}{'descriptionUrl'}) {
      $description .= sprintf ' <a href="%s">More information</a>', $hub_info->{'details'}{'descriptionUrl'};
    }

    my $menu     = $existing_menu || $self->tree->root->append_child($self->create_menu_node($menu_name, $menu_name, { external => 1, trackhub_menu => 1, description =>  $description}));

    my $node;
    my $assemblies = $self->hub->species_defs->get_config($self->species,'TRACKHUB_ASSEMBLY_ALIASES');
    $assemblies ||= [];
    $assemblies = [ $assemblies ] unless ref($assemblies) eq 'ARRAY';
    foreach my $assembly_var (qw(UCSC_GOLDEN_PATH ASSEMBLY_VERSION)) {
      my $assembly = $self->hub->species_defs->get_config($self->species,$assembly_var);
      next unless $assembly;
      push @$assemblies,$assembly;
    }
    foreach my $assembly (@$assemblies) {
      $node = $hub_info->{'genomes'}{$assembly}{'tree'};
      $node = $node->root if $node;
      last if $node;
    }
    if ($node) {
      $self->_add_trackhub_node($node, $menu, $menu_name, $force_hide);

      $self->{'_attached_trackhubs'}{$url} = 1;
    } else {
      my $assembly = $self->hub->species_defs->get_config($self->species, 'ASSEMBLY_VERSION');
      $hub_info->{'error'} = ["No sources could be found for assembly $assembly. Please check the hub's genomes.txt file for supported assemblies."];
    }
  }
  return ($menu_name, $hub_info);
}

sub _add_trackhub_node {
  my ($self, $node, $menu, $name, $force_hide) = @_;

  my (@next_level, @childless);
  if ($node->has_child_nodes) {
    foreach my $child (@{$node->child_nodes}) {
      if ($child->has_child_nodes) {
        push @next_level, $child;
      }
      else {
        push @childless, $child;
      }
    }
  }

  if (scalar(@next_level)) {
    $self->_add_trackhub_node($_, $menu, $name, $force_hide) for @next_level;
  }

  if (scalar(@childless)) {
    ## Get additional/overridden settings from parent nodes. Note that we will
    ## combine visibility and on_off later to produce Ensembl-friendly settings
    my $n       = $node;
    my $data    = $n->data;
    my $config  = {};
    my @ok_keys = qw(visibility dimensions priority);
    if ($data->{'superTrack'} && $data->{'superTrack'} eq 'on') {
      my @inherited = qw(on_off visibility viewLimits maxHeightPixels);
      foreach (@inherited) {
        $config->{$_} = $data->{$_};
      }
    }
    else {
      for (keys %$data) {
        if ($_ =~ /subGroup/ || grep $_, @ok_keys) {
          $config->{$_} = $data->{$_} if $data->{$_};
        }
      }
    }

    ## Add any setting inherited from parents
    while ($n = $n->parent_node) {
      $data = $n->data;
      if ($data->{'superTrack'} && $data->{'superTrack'} eq 'on') {
        $config->{'visibility'} = $data->{'visibility'};
      }
      else {
        for (keys %$data) {
          if ($_ =~ /subGroup/ || grep $_, @ok_keys) {
            $config->{$_} = $data->{$_} if $data->{$_};
          }
        }
      }
    }
    $config->{'on_off'} = 'off' if $force_hide;

    $self->_add_trackhub_tracks($node, \@childless, $config, $menu, $name);
  }
}

sub _add_trackhub_tracks {
  my ($self, $parent, $children, $config, $menu, $name) = @_;
  my $hub    = $self->hub;
  my $data   = $parent->data;
  my $matrix = $config->{'dimensions'}{'x'} && $config->{'dimensions'}{'y'};
  my %tracks;

  my %options = (
    menu_key      => $name,
    menu_name     => $name,
    submenu_key   => clean_id("${name}_$data->{'track'}", '\W'),
    submenu_name  => strip_HTML($data->{'shortLabel'}),
    submenu_desc  => $data->{'longLabel'},
    trackhub      => 1,
  );

  if ($matrix) {
    $options{'matrix_url'} = $hub->url('Config', { 'matrix' => 1, 'menu' => $options{'submenu_key'} });

    foreach my $subgroup (keys %$config) {
      next unless $subgroup =~ /subGroup\d/;

      foreach (qw(x y)) {
        if ($config->{$subgroup}{'name'} eq $config->{'dimensions'}{$_}) {
          $options{'axis_labels'}{$_} = { %{$config->{$subgroup}} }; # Make a deep copy so that the regex below doesn't affect the subgroup config
          s/_/ /g for values %{$options{'axis_labels'}{$_}};
        }
      }

      last if scalar keys %{$options{'axis_labels'}} == 2;
    }

    $options{'axes'} = { map { $_ => $options{'axis_labels'}{$_}{'label'} } qw(x y) };
  }

  my $submenu = $self->create_menu_node($options{'submenu_key'}, $options{'submenu_name'}, {
    external    => 1,
    description => $options{'submenu_desc'},
    ($matrix ? (
      menu   => 'matrix',
      url    => $options{'matrix_url'},
      matrix => {
        section     => $menu->data->{'caption'},
        header      => $options{'submenu_name'},
        desc_url    => $config->{'description_url'},
        description => $config->{'longLabel'},
        axes        => $options{'axes'},
      }
    ) : ())
  });

  $self->alphabetise_tracks($submenu, $menu);

  my $count_visible = 0;

  my $style_mappings = {
                        'bam'     => {
                                      'default' => 'coverage_with_reads',
                                      },
                        'cram'    => {
                                      'default' => 'coverage_with_reads',
                                      },
                        'bigbed'  => {
                                      'full'    => 'as_transcript_nolabel',
                                      'pack'    => 'as_transcript_label',
                                      'squish'  => 'half_height',
                                      'dense'   => 'as_alignment_nolabel',
                                      'default' => 'as_transcript_label',
                                      },
                        'biggenepred' => {
                                      'full'    => 'as_transcript_nolabel',
                                      'pack'    => 'as_transcript_label',
                                      'squish'  => 'half_height',
                                      'dense'   => 'as_collapsed_label',
                                      'default' => 'as_collapsed_label',
                                      },
                        'bigwig'  => {
                                      'full'    => 'signal',
                                      'dense'   => 'compact',
                                      'default' => 'compact',
                                      },
                        'vcf'     =>  {
                                      'full'    => 'histogram',
                                      'dense'   => 'compact',
                                      'default' => 'compact',
                                      },
                      };

  foreach (@{$children||[]}) {
    my $track        = $_->data;
    my $type         = ref $track->{'type'} eq 'HASH' ? uc $track->{'type'}{'format'} : uc $track->{'type'};

    my $on_off = $config->{'on_off'} || $track->{'on_off'};
    ## Turn track on if there's no higher setting turning it off
    if ($track->{'visibility'}  eq 'hide') {
      $on_off = 'off';
    } elsif (!$config->{'on_off'} && !$track->{'on_off'}) {
      $on_off = 'on';
    }
    #} elsif ($self->check_threshold($on_off) eq 'off') {
    #  $on_off = 'off';
    #}

    my $ucsc_display  = $config->{'visibility'} || $track->{'visibility'};

    ## FIXME - According to UCSC's documentation, 'squish' is more like half_height than compact
    my $squish       = $ucsc_display eq 'squish';
    (my $source_name = strip_HTML($track->{'shortLabel'})) =~ s/_/ /g;

    ## Translate between UCSC terms and Ensembl ones
    my $default_display = $style_mappings->{lc($type)}{$ucsc_display}
                              || $style_mappings->{lc($type)}{'default'}
                              || 'normal';
    $options{'default_display'} = $default_display;

    ## Set track style if appropriate
    if ($on_off && $on_off eq 'on') {
      $options{'display'} = $default_display;
    }
    else {
      $options{'display'} = 'off';
    }

    ## Note that we use a duplicate value in description and longLabel, because non-hub files
    ## often have much longer descriptions so we need to distinguish the two
    my $source       = {
      name            => $track->{'track'},
      source_name     => $source_name,
      desc_url        => $track->{'description_url'},
      description     => $name.': '.$track->{'longLabel'},,
      longLabel       => $track->{'longLabel'},
      source_url      => $track->{'bigDataUrl'},
      colour          => exists $track->{'color'} ? $track->{'color'} : undef,
      colorByStrand   => exists $track->{'colorByStrand'} ? $track->{'colorByStrand'} : undef,
      spectrum        => exists $track->{'spectrum'} ? $track->{'spectrum'} : undef,
      no_titles       => $type eq 'BIGWIG', # To improve browser speed don't display a zmenu for bigwigs
      squish          => $squish,
      signal_range    => $track->{'signal_range'},
      viewLimits      => $track->{'viewLimits'} || $config->{'viewLimits'},
      maxHeightPixels => $track->{'maxHeightPixels'} || $config->{'maxHeightPixels'},
      %options
    };

    # Graph range - Track Hub default is 0-127

    if (exists $track->{'viewLimits'}) {
      $source->{'viewLimits'} = $track->{'viewLimits'};
    } elsif ($track->{'autoScale'} eq 'off') {
      $source->{'viewLimits'} = '0:127';
    }

    if (exists $track->{'maxHeightPixels'}) {
      $source->{'maxHeightPixels'} = $track->{'maxHeightPixels'};
    } elsif ($type eq 'BIGWIG' || $type eq 'BIGBED' || $type eq 'BIGGENEPRED') {
      $source->{'maxHeightPixels'} = '64:32:16';
    }

    if ($matrix) {
      my $caption = strip_HTML($track->{'shortLabel'});
      $source->{'section'} = strip_HTML($parent->data->{'shortLabel'});
      ($source->{'source_name'} = $track->{'longLabel'}) =~ s/_/ /g;
      $source->{'labelcaption'} = $caption;

      $source->{'matrix'} = {
        menu   => $options{'submenu_key'},
        column => $options{'axis_labels'}{'x'}{$track->{'subGroups'}{$config->{'dimensions'}{'x'}}},
        row    => $options{'axis_labels'}{'y'}{$track->{'subGroups'}{$config->{'dimensions'}{'y'}}},
      };
      $source->{'column_data'} = { desc_url => $config->{'description_url'}, description => $config->{'longLabel'}, no_subtrack_description => 1 };
    }

    $tracks{$type}{$source->{'name'}} = $source;
  }

  $self->load_file_format(lc, $tracks{$_}) for keys %tracks;
}

sub _add_trackhub_extras_options {
  my ($self, %args) = @_;

  if (exists $args{'menu'}{'maxHeightPixels'} || exists $args{'source'}{'maxHeightPixels'}) {
    $args{'options'}{'maxHeightPixels'} = $args{'menu'}{'maxHeightPixels'} || $args{'source'}{'maxHeightPixels'};
  }

  # Alternative renderings for genome segmentation and similar
  if ($args{'source'}{'squish'}) {
    $args{'renderers'} = [
      'off',          'Off',
      'half_height',  'Half height',
      'compact',      'Continuous',
      'stack',        'Stacked',
      'unlimited',    'Stacked unlimited',
      'normal',       'Separate',
      'labels',       'Separate with labels',
    ];
  }

  $args{'options'}{'viewLimits'} = $args{'menu'}{'viewLimits'} || $args{'source'}{'viewLimits'} if exists $args{'menu'}{'viewLimits'} || exists $args{'source'}{'viewLimits'};
  $args{'options'}{'signal_range'} = $args{'source'}{'signal_range'} if exists $args{'source'}{'signal_range'};
  $args{'options'}{'no_titles'}  = $args{'menu'}{'no_titles'}  || $args{'source'}{'no_titles'}  if exists $args{'menu'}{'no_titles'}  || exists $args{'source'}{'no_titles'};
  $args{'options'}{'set'}        = $args{'source'}{'submenu_key'};
  $args{'options'}{'subset'}     = clean_id($args{'source'}{'submenu_key'}, '\W') unless $args{'source'}{'matrix'};
  $args{'options'}{$_}           = $args{'source'}{$_} for qw(trackhub matrix column_data colour description desc_url);

  return %args;
}

sub load_configured_bam    { shift->load_file_format('bam');    }
sub load_configured_bigbed {
  my $self = shift;
  $self->load_file_format('bigbed');
  my $sources  = $self->species_defs->get_config($self->species, 'ENSEMBL_INTERNAL_BIGBED_SOURCES') || {};
  if ($sources->{'age_of_base'}) {
    $self->add_track('information', 'age_of_base_legend', 'Age of Base Legend', 'age_of_base_legend', { strand => 'r' });
  }
}

sub load_configured_bigwig    { shift->load_file_format('bigwig'); }
sub load_configured_vcf       { shift->load_file_format('vcf');    }
sub load_configured_trackhubs { shift->load_file_format('trackhub'); }

sub load_file_format {
  my ($self, $format, $sources) = @_;
  my $function = "_add_${format}_track";

  return unless ($format eq 'trackhub' || $self->can($function));

  my $internal = !defined $sources;
  $sources  = $self->species_defs->get_config($self->species, sprintf('ENSEMBL_INTERNAL_%s_SOURCES', uc $format)) || {} unless defined $sources; # get the internal sources from config

  foreach my $source_name (sort keys %$sources) {
    # get the target menu
    my $menu = $self->get_node($sources->{$source_name});
    my ($source, $view);

    if ($menu) {
      $source = $self->species_defs->get_config($self->species, $source_name);
      $view   = $source->{'view'};
    } else {
      ## Probably an external trackhub source
         $source       = $sources->{$source_name};
         $view         = $source->{'view'};
      my $menu_key     = $source->{'menu_key'};
      my $menu_name    = $source->{'menu_name'};
      my $submenu_key  = $source->{'submenu_key'};
      my $submenu_name = $source->{'submenu_name'};
      my $main_menu    = $self->get_node($menu_key) || $self->tree->root->append_child($self->create_menu_node($menu_key, $menu_name, { external => 1, trackhub_menu => !!$source->{'trackhub'} }));
         $menu         = $self->get_node($submenu_key);

      if (!$menu) {
        $menu = $self->create_menu_node($submenu_key, $submenu_name, { external => 1, ($source->{'matrix_url'} ? (menu => 'matrix', url => $source->{'matrix_url'}) : ()) });
        $main_menu->insert_alphabetically($menu);
      }
    }

    if ($source) {
      if ($format eq 'trackhub') {
        ## Force hiding of internally configured trackhubs, because they should be
        ## off by default regardless of the settings in the hub
        my $force_hide = $internal ? 1 : 0;
        $self->_add_trackhub(strip_HTML($source->{'source_name'}), $source->{'url'}, $menu, $force_hide);
      }
      else {
        my $is_internal = $source->{'source_url'} ? 0 : $internal;
        $self->$function(key => $source_name, menu => $menu, source => $source, description => $source->{'description'}, internal => $is_internal, view => $view);
      }
    }
  }
}

sub _add_bam_track  { shift->_add_htslib_track('bam', @_);  } ## @private
sub _add_cram_track { shift->_add_htslib_track('cram', @_); } ## @private

sub _add_htslib_track {
  ## @private
  my ($self, $hts_format, %args) = @_;
  my $desc = '
    The read end bars indicate the direction of the read and the colour indicates the type of read pair:
    Green = both mates are part of a proper pair; Blue = either this read is not paired, or its mate was not mapped; Red = this read is not properly paired.
  ';

  ## Override default renderer (mainly used by trackhubs)
  my %options;
  $options{'display'} = $args{'source'}{'display'} if $args{'source'}{'display'};
  $options{'strand'}  = 'b';

  $self->_add_file_format_track(
    format      => 'BAM',
    description => $desc,
    renderers   => [
                    'off',                  'Off',
                    'coverage_with_reads',  'Normal',
                    'unlimited',            'Unlimited',
                    'histogram',            'Coverage only'
                    ],
    colourset   => 'BAM',
    options => {
      external => 'external',
      sub_type => $hts_format,
      %options,
    },
    %args,
  );
}

sub _add_bigbed_track {
  my ($self, %args) = @_;

  ## Get default settings for this format
  my ($strand, $renderers, $default) = $self->_user_track_settings($args{'source'}{'style'}, 'BIGBED');

  my $options = {
    external        => 'external',
    sub_type        => 'url',
    colourset       => 'feature',
    colorByStrand   => $args{'source'}{'colorByStrand'},
    spectrum        => $args{'source'}{'spectrum'},
    strand          => $args{'source'}{'strand'} || $strand,
    style           => $args{'source'}{'style'},
    longLabel       => $args{'source'}{'longLabel'},
    addhiddenbgd    => 1,
    max_label_rows  => 2,
    default_display => $args{'source'}{'default'} || $default,
  };
  ## Override default renderer (mainly used by trackhubs)
  $options->{'display'} = $args{'source'}{'display'} if $args{'source'}{'display'};

  if ($args{'view'} && $args{'view'} =~ /peaks/i) {
    $options->{'join'} = 'off';
  } else {
    push @$renderers, ('signal', 'Wiggle plot');
  }

  $self->_add_file_format_track(
    format      => 'BigBed',
    description => 'Bigbed file',
    renderers   => $args{'source'}{'renderers'} || $renderers,
    options     => $options,
    %args,
  );
}

sub _add_biggenepred_track {
  my ($self, %args) = @_;

  ## Get default settings for this format
  my ($strand, $renderers, $default) = $self->_user_track_settings($args{'source'}{'style'}, 'BIGGENEPRED');

  my $options = {
    external        => 'external',
    sub_type        => 'url',
    colourset       => 'feature',
    colorByStrand   => $args{'source'}{'colorByStrand'},
    spectrum        => $args{'source'}{'spectrum'},
    strand          => $args{'source'}{'strand'} || $strand,
    style           => $args{'source'}{'style'},
    longLabel       => $args{'source'}{'longLabel'},
    addhiddenbgd    => 1,
    max_label_rows  => 2,
    default_display => $args{'source'}{'default'} || $default,
  };
  ## Override default renderer (mainly used by trackhubs)
  $options->{'display'} = $args{'source'}{'display'} if $args{'source'}{'display'};

  if ($args{'view'} && $args{'view'} =~ /peaks/i) {
    $options->{'join'} = 'off';
  } else {
    push @$renderers, ('signal', 'Wiggle plot');
  }

  $self->_add_file_format_track(
    format      => 'BigGenePred',
    description => 'BigGenePred file',
    renderers   => $args{'source'}{'renderers'} || $renderers,
    options     => $options,
    %args,
  );
}

sub _add_bigwig_track {
  my ($self, %args) = @_;

  my $renderers = $args{'source'}{'renderers'} || [
    'off',     'Off',
    'signal',  'Wiggle plot',
    'compact', 'Compact',
    'scatter', 'Manhattan plot',
  ];

  my $options = {
    external        => 'external',
    sub_type        => 'bigwig',
    style           => 'wiggle',
    colour          => $args{'menu'}{'colour'} || $args{'source'}{'colour'} || 'red',
    longLabel       => $args{'source'}{'longLabel'},
    y_min           => $args{'source'}{'y_min'},
    y_max           => $args{'source'}{'y_max'},
    addhiddenbgd    => 1,
    max_label_rows  => 2,
  };

  ## Override default renderer (mainly used by trackhubs)
  $options->{'display'} = $args{'source'}{'display'} if $args{'source'}{'display'};

  $self->_add_file_format_track(
    format    => 'BigWig',
    renderers =>  $renderers,
    options   => $options,
    %args
  );
}

sub _add_vcf_track {
  my ($self, %args) = @_;

  ## Override default renderer (mainly used by trackhubs)
  my %options;
  $options{'display'} = $args{'source'}{'display'} if %args && $args{'source'}{'display'};

  $self->_add_file_format_track(
    format    => 'VCF',
    renderers => [
      'off',       'Off',
      'histogram', 'Histogram',
      'simple',    'Compact'
    ],
    options => {
      external   => 'external',
      sources    => undef,
      depth      => 0.5,
      bump_width => 0,
      colourset  => 'variation',
      %options,
    },
    %args
  );
}

sub _add_pairwise_track {
  shift->_add_file_format_track(
    format    => 'PAIRWISE',
    renderers => [
      'off',                'Off',
      'interaction',        'Pairwise interaction',
    ],
    options => {
      external   => 'external',
      subtype    => 'pairwise',
    },
    @_
  );

}

sub _add_flat_file_track {
  ## @private
  my ($self, $menu, $sub_type, $key, $name, $description, $options) = @_;

  my ($strand, $renderers, $default) = $self->_user_track_settings($options->{'style'}, $options->{'format'});

  #$options->{'display'} = $self->check_threshold($options->{'display'});

  my $track = $self->create_track_node($key, $name, {
    display         => 'off',
    strand          => $strand,
    external        => 'external',
    glyphset        => 'flat_file',
    colourset       => 'userdata',
    caption         => $name,
    sub_type        => $sub_type,
    renderers       => $renderers,
    default_display => $default,
    description     => $description,
    %$options
  });

  $menu->append_child($track) if $track;
}

sub _add_file_format_track {
  my ($self, %args) = @_;
  my $menu = $args{'menu'} || $self->get_node('user_data');

  return unless $menu;

  %args = $self->_add_trackhub_extras_options(%args) if $args{'source'}{'trackhub'};

  my $type    = lc $args{'format'};
  my $article = $args{'format'} =~ /^[aeiou]/ ? 'an' : 'a';
  my ($desc, $url);

  if ($args{'internal'}) {
    $desc = $args{'description'};
    $url = join '/', $self->hub->species_defs->DATAFILE_BASE_PATH, lc $self->hub->species, $self->hub->species_defs->ASSEMBLY_VERSION, $args{'source'}{'dir'}, $args{'source'}{'file'};
    $args{'options'}{'external'} = undef;
  } else {
    if ($args{'source'}{'source_type'} =~ /^session|user$/i) {
      my $format = $args{'format'} eq 'BAM' ? uc $args{'options'}{'sub_type'} : $args{'format'};
      $desc = sprintf(
        'Data retrieved from %s %s file on an external webserver. %s <p>This data is attached to the %s, and comes from URL: <a href="%s">%s</a></p>',
        $article,
        $format,
        $args{'description'},
        encode_entities($args{'source'}{'source_type'}),
        encode_entities($args{'source'}{'source_url'}),
        encode_entities($args{'source'}{'source_url'})
      );
    } else {
      $desc = $args{'description'};
    }
  }

  #$args{'options'}{'display'} = $self->check_threshold($args{'options'}{'display'});

  $self->_add_track($menu, undef, $args{'key'}, {}, {
    strand      => 'f',
    format      => $args{'format'},
    glyphset    => $type,
    colourset   => $type,
    renderers   => $args{'renderers'},
    name        => $args{'source'}{'source_name'},
    caption     => exists($args{'source'}{'caption'}) ? $args{'source'}{'caption'} : $args{'source'}{'source_name'},
    labelcaption => $args{'source'}{'labelcaption'},
    section     => $args{'source'}{'section'},
    url         => $url || $args{'source'}{'source_url'},
    description => $desc,
    %{$args{'options'}}
  });
}

sub _user_track_settings {
  my ($self, $style, $format) = @_;
  my (@user_renderers, $default);
  my $strand = 'b';

  if (lc($format) eq 'pairwise') {
    @user_renderers = ('off', 'Off', 'interaction', 'Pairwise interaction');
    $strand = 'f';
  }
  elsif (lc($format) eq 'bedgraph' || lc($format) eq 'wig' || $style =~ /^(wiggle|WIG)$/) {
    @user_renderers = ('off', 'Off', 'signal', 'Wiggle plot');
    $strand = 'f';
  }
  elsif (uc($format) =~ /BED|GFF|GTF/) {
    @user_renderers = @{$self->_transcript_renderers};
    $default = 'as_transcript_label';
  }
  elsif (uc($format) eq 'BIGGENEPRED') {
    @user_renderers = @{$self->_gene_renderers};
    $default = 'as_collapsed_label';
  }
  else {
    @user_renderers = (@{$self->_alignment_renderers}, 'difference', 'Differences');
  }
  $strand = 'f' if $format =~ /vcf/;
  $default = $user_renderers[2] unless $default;

  return ($strand, \@user_renderers, $default);
}

1;
