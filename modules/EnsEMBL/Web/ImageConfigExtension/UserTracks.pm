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

use EnsEMBL::Web::File::Utils::TrackHub;

sub load_user_tracks {
  my $self = shift;
  my $menu = $self->get_node('user_data');
  
  return unless $menu;
  
  my $hub      = $self->hub;
  my $session  = $hub->session;
  my $user     = $hub->user;
  my $trackhubs = $self->get_parameter('trackhubs') == 1;
  my (%url_sources, %upload_sources);
  
  $self->_load_url_feature($menu);
  
  ## Data attached via URL
  foreach my $entry ($session->get_data(type => 'url')) {
    next if $entry->{'no_attach'};
    next unless $entry->{'species'} eq $self->{'species'};
    
    $url_sources{"url_$entry->{'code'}"} = {
      source_type => 'session',
      source_name => $entry->{'name'} || $entry->{'url'},
      source_url  => $entry->{'url'},
      species     => $entry->{'species'},
      format      => $entry->{'format'},
      style       => $entry->{'style'},
      colour      => $entry->{'colour'},
      renderers   => $entry->{'renderers'},
      display     => $entry->{'display'},
      timestamp   => $entry->{'timestamp'} || time,
    };
  }
 
  ## Data uploaded but not saved
  foreach my $entry ($session->get_data(type => 'upload')) {
    next unless $entry->{'species'} eq $self->{'species'};
   
    my ($strand, $renderers, $default) = $self->_user_track_settings($entry->{'style'}, $entry->{'format'});
    $strand     = $entry->{'strand'} if $entry->{'strand'};
    $renderers  = $entry->{'renderers'} if $entry->{'renderers'};
    my $description = 'Data that has been temporarily uploaded to the web server.';
    $description   .= add_links($entry->{'description'}) if $entry->{'description'};
      
    $menu->append($self->create_track("upload_$entry->{'code'}", $entry->{'name'}, {
        external        => 'user',
        glyphset        => 'flat_file',
        colourset       => 'userdata',
        sub_type        => 'tmp',
        file            => $entry->{'file'},
        format          => $entry->{'format'},
        style           => $entry->{'style'},
        caption         => $entry->{'name'},
        renderers       => $renderers,
        description     => $description,
        display         => $entry->{'display'} || 'off',
        default_display => $entry->{'display'} || $default,
        strand          => $strand,
    }));
  }

  ## Data saved by the user  
  if ($user) {
    my @groups = $user->get_groups;

    ## URL attached data
    foreach my $entry (grep $_->species eq $self->{'species'}, $user->get_records('urls'), map $user->get_group_records($_, 'urls'), @groups) {
      $url_sources{'url_' . $entry->code} = {
        source_name => $entry->name || $entry->url,
        source_type => 'user', 
        source_url  => $entry->url,
        species     => $entry->species,
        format      => $entry->format,
        style       => $entry->style,
        colour      => $entry->colour,
        renderers   => $entry->renderers,
        display     => 'off',
        timestamp   => $entry->timestamp,
      };
    }
    
    ## Uploads that have been saved to the userdata database
    foreach my $entry (grep $_->species eq $self->{'species'}, $user->get_records('uploads'), map $user->get_group_records($_, 'uploads'), @groups) {
      my ($name, $assembly) = ($entry->name, $entry->assembly);
     
      if ($entry->analyses) {
        ## Data saved to userdata db
        ## TODO - remove in due course
        foreach my $analysis (split /, /, $entry->analyses) {
          $upload_sources{$analysis} = {
            source_name => $name,
            source_type => 'user',
            assembly    => $assembly,
            style       => $entry->style,
          };
        
          $self->_compare_assemblies($entry, $session);
        }
      }
      else {
        ## New saved-to-permanent-location
        my ($strand, $renderers, $default) = $self->_user_track_settings($entry->style, $entry->format);
        $strand     = $entry->strand if $entry->can('strand') && $entry->strand;
        $renderers  = $entry->renderers if $entry->can('renderers') && $entry->renderers;
        my $description = 'Data that has been saved to the web server. ';
        my $extra_desc  = $entry->description;
        $description   .= add_links($extra_desc) if $extra_desc;
        $menu->append($self->create_track("upload_".$entry->code, $entry->name, {
            external        => 'user',
            glyphset        => 'flat_file',
            colourset       => 'userdata',
            sub_type        => 'user',
            file            => $entry->file,
            format          => $entry->format,
            style           => $entry->style,
            caption         => $entry->name,
            strand          => $strand,
            renderers       => $renderers,
            description     => $description, 
            display         => $entry->display || 'off',
            default_display => $entry->display || $default,
        }));
      }
    }
  }
  
  ## Now we can add all remote (URL) data sources
  foreach my $code (sort { $url_sources{$a}{'source_name'} cmp $url_sources{$b}{'source_name'} } keys %url_sources) {
    my $add_method = lc "_add_$url_sources{$code}{'format'}_track";
    
    if ($self->can($add_method)) {
      $self->$add_method(
        key      => $code,
        menu     => $menu,
        source   => $url_sources{$code},
        external => 'user'
      );
    } elsif (lc $url_sources{$code}{'format'} eq 'trackhub') {
      $self->_add_trackhub($url_sources{$code}{'source_name'}, $url_sources{$code}{'source_url'}) if $trackhubs;
    } else {
      $self->_add_flat_file_track($menu, 'url', $code, $url_sources{$code}{'source_name'},
        sprintf('
          Data retrieved from an external webserver. This data is attached to the %s, and comes from URL: <a href="%s">%s</a>',
          encode_entities($url_sources{$code}{'source_type'}), 
          encode_entities($url_sources{$code}{'source_url'}),
          encode_entities($url_sources{$code}{'source_url'})
        ),
        url      => $url_sources{$code}{'source_url'},
        format   => $url_sources{$code}{'format'},
        style    => $url_sources{$code}{'style'},
        renderers => $url_sources{$code}{'renderers'},
        external => 'user',
      );
    }
  }
  
  ## And finally any saved uploads
  ## TODO - remove once we have removed the userdata databases
  if (keys %upload_sources) {
    my $dbs        = EnsEMBL::Web::DBSQL::DBConnection->new($self->{'species'});
    my $dba        = $dbs->get_DBAdaptor('userdata');
    my $an_adaptor = $dba->get_adaptor('Analysis');
    my @tracks;
    
    foreach my $logic_name (keys %upload_sources) {
      my $analysis = $an_adaptor->fetch_by_logic_name($logic_name);
      
      next unless $analysis;
   
      $analysis->web_data->{'style'} ||= $upload_sources{$logic_name}{'style'};
     
      my ($strand, $renderers, $default) = $self->_user_track_settings($analysis->web_data->{'style'}, $analysis->program_version);
      my $source_name = encode_entities($upload_sources{$logic_name}{'source_name'});
      my $description = encode_entities($analysis->description) || "User data from dataset $source_name";
      my $caption     = encode_entities($analysis->display_label);
         $caption     = "$source_name: $caption" unless $caption eq $upload_sources{$logic_name}{'source_name'};
         $strand      = $upload_sources{$logic_name}{'strand'} if $upload_sources{$logic_name}{'strand'};
      
      push @tracks, [ $logic_name, $caption, {
        external        => 'user',
        glyphset        => '_user_data',
        colourset       => 'userdata',
        sub_type        => $upload_sources{$logic_name}{'source_type'} eq 'user' ? 'user' : 'tmp',
        renderers       => $renderers,
        source_name     => $source_name,
        logic_name      => $logic_name,
        caption         => $caption,
        data_type       => $analysis->module,
        description     => $description,
        display         => 'off',
        default_display => $default,
        style           => $analysis->web_data,
        format          => $analysis->program_version,
        strand      => $strand,
      }];
    }
   
    $menu->append($self->create_track(@$_)) for sort { lc $a->[2]{'source_name'} cmp lc $b->[2]{'source_name'} || lc $a->[1] cmp lc $b->[1] } @tracks;
  }
 
  $ENV{'CACHE_TAGS'}{'user_data'} = sprintf 'USER_DATA[%s]', md5_hex(join '|', map $_->id, $menu->nodes) if $menu->has_child_nodes;
}

sub _add_trackhub {
  my ($self, $menu_name, $url, $is_poor_name, $existing_menu, $force_hide) = @_;

  ## Check if this trackhub is already attached - now that we can attach hubs via
  ## URL, they may not be saved in the imageconfig
  my $already_attached = $self->get_node($menu_name); 
  return ($menu_name, {}) if ($already_attached || $self->{'_attached_trackhubs'}{$url});

  my $trackhub  = EnsEMBL::Web::File::Utils::TrackHub->new('hub' => $self->hub, 'url' => $url);
  my $hub_info = $trackhub->get_hub({'assembly_lookup' => $self->species_defs->assembly_lookup, 
                                      'parse_tracks' => 1}); ## Do we have data for this species?
 
  if ($hub_info->{'error'}) {
    ## Probably couldn't contact the hub
    push @{$hub_info->{'error'}||[]}, '<br /><br />Please check the source URL in a web browser.';
  } else {
    my $shortLabel = $hub_info->{'details'}{'shortLabel'};
    $menu_name = $shortLabel if $shortLabel and $is_poor_name;

    my $menu     = $existing_menu || $self->tree->append_child($self->create_submenu($menu_name, $menu_name, { external => 1, trackhub_menu => 1, description =>  $hub_info->{'details'}{'longLabel'}}));

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
    ## The only parameter we override from superTrack nodes is visibility
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
    submenu_key   => $self->tree->clean_id("${name}_$data->{'track'}", '\W'),
    submenu_name  => $data->{'shortLabel'},
    submenu_desc  => $data->{'longLabel'},
    trackhub      => 1,
  );

  if ($matrix) {
    $options{'matrix_url'} = $hub->url('Config', { action => 'Matrix', function => $hub->action, partial => 1, menu => $options{'submenu_key'} });
    
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
  
  my $submenu = $self->create_submenu($options{'submenu_key'}, $options{'submenu_name'}, {
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
                                      'full'    => 'as_transcript_label',
                                      'pack'    => 'as_transcript_label',
                                      'squish'  => 'half_height',
                                      'dense'   => 'as_alignment_nolabel',
                                      'default' => 'as_transcript_label',
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
    }
    elsif (!$config->{'on_off'} && !$track->{'on_off'}) {
      $on_off = 'on';
    }

    my $ucsc_display  = $config->{'visibility'} || $track->{'visibility'};

    ## FIXME - According to UCSC's documentation, 'squish' is more like half_height than compact
    my $squish       = $ucsc_display eq 'squish';
    (my $source_name = $track->{'shortLabel'}) =~ s/_/ /g;

    ## Translate between UCSC terms and Ensembl ones
    my $default_display = $style_mappings->{lc($type)}{$ucsc_display}
                              || $style_mappings->{lc($type)}{'default'}
                              || 'normal';
    $options{'default_display'} = $default_display;

    ## Set track style if appropriate 
    if ($on_off && $on_off eq 'on') {
      $options{'display'} = $default_display;
      $count_visible++;
    }
    else {
      $options{'display'} = 'off';
    }

    ## Note that we use a duplicate value in description and longLabel, because non-hub files 
    ## often have much longer descriptions so we need to distinguish the two
    my $source       = {
      name        => $track->{'track'},
      source_name => $source_name,
      desc_url    => $track->{'description_url'},
      description => $track->{'longLabel'},
      longLabel   => $track->{'longLabel'},
      source_url  => $track->{'bigDataUrl'},
      colour      => exists $track->{'color'} ? $track->{'color'} : undef,
      colorByStrand => exists $track->{'colorByStrand'} ? $track->{'colorByStrand'} : undef,
      spectrum    => exists $track->{'spectrum'} ? $track->{'spectrum'} : undef,
      no_titles   => $type eq 'BIGWIG', # To improve browser speed don't display a zmenu for bigwigs
      squish      => $squish,
      signal_range => $track->{'signal_range'},
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
    } elsif ($type eq 'BIGWIG' || $type eq 'BIGBED') {
      $source->{'maxHeightPixels'} = '64:32:16';
    }
    
    if ($matrix) {
      my $caption = $track->{'shortLabel'};
      $source->{'section'} = $parent->data->{'shortLabel'};
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
  #warn ">>> HUB $name HAS $count_visible TRACKS TURNED ON BY DEFAULT!";
  
  $self->load_file_format(lc, $tracks{$_}) for keys %tracks;
}

sub _add_trackhub_extras_options {
  my ($self, %args) = @_;
  
  if (exists $args{'menu'}{'maxHeightPixels'} || exists $args{'source'}{'maxHeightPixels'}) {
    $args{'options'}{'maxHeightPixels'} = $args{'menu'}{'maxHeightPixels'} || $args{'source'}{'maxHeightPixels'};
  }
  
  # Alternative rendering order for genome segmentation and similar
  if ($args{'source'}{'squish'}) {
    $args{'renderers'} = [
      'off',     'Off',
      'compact', 'Continuous',
      'normal',  'Separate',
      'labels',  'Separate with labels',
    ];
  }
  
  $args{'options'}{'viewLimits'} = $args{'menu'}{'viewLimits'} || $args{'source'}{'viewLimits'} if exists $args{'menu'}{'viewLimits'} || exists $args{'source'}{'viewLimits'};
  $args{'options'}{'signal_range'} = $args{'source'}{'signal_range'} if exists $args{'source'}{'signal_range'};
  $args{'options'}{'no_titles'}  = $args{'menu'}{'no_titles'}  || $args{'source'}{'no_titles'}  if exists $args{'menu'}{'no_titles'}  || exists $args{'source'}{'no_titles'};
  $args{'options'}{'set'}        = $args{'source'}{'submenu_key'};
  $args{'options'}{'subset'}     = $self->tree->clean_id($args{'source'}{'submenu_key'}, '\W') unless $args{'source'}{'matrix'};
  $args{'options'}{$_}           = $args{'source'}{$_} for qw(trackhub matrix column_data colour description desc_url);
  
  return %args;
}

sub _load_url_feature {
## Creates a temporary track based on a single line of a row-based data file,
## such as VEP output, e.g. 21 9678256 9678256 T/G 1 
  my ($self, $menu) = @_;
  return unless $menu;

  my $session_data = $self->hub->session->get_data('code' => 'custom_feature', type => 'custom');
  my ($format, $data);

  if ($self->hub->param('custom_feature')) {
    $format  = $self->hub->param('format');
    $data    = decode_entities($self->hub->param('custom_feature'));
    $session_data = {'code' => 'custom_feature', 'type' => 'custom', 
                      'format' => $format, 'data' => $data}; 
    $self->hub->session->set_data(%$session_data);
  }
  elsif ($session_data && ref($session_data) eq 'HASH' && $session_data->{'data'}) {
    $format = $session_data->{'format'};
    $data = $session_data->{'data'};
  }
  return unless ($data && $format);

  my ($strand, $renderers, $default) = $self->_user_track_settings(undef, $format);
  my $file_info = $self->hub->species_defs->multi_val('DATA_FORMAT_INFO');

  my $track = $self->create_track('custom_feature', 'Single feature', {
        external        => 'user',
        glyphset        => 'flat_file',
        colourset       => 'classes',
        sub_type        => 'single_feature',
        format          => $format,
        caption         => 'Single '.$file_info->{$format}{'label'}.' feature',
        renderers       => $renderers,
        description     => 'A single feature that has been loaded via a hyperlink',
        display         => 'off',
        default_display => $default,
        strand          => $strand,
        data            => $data,
  });
  $menu->append($track) if $track;
}

sub load_configured_bam    { shift->load_file_format('bam');    }
sub load_configured_bigbed { 
  my $self = shift;
  $self->load_file_format('bigbed'); 
  my $sources  = $self->sd_call('ENSEMBL_INTERNAL_BIGBED_SOURCES') || {};
  if ($sources->{'age_of_base'}) {
    $self->add_track('information', 'age_of_base_legend', 'Age of Base Legend', 'age_of_base_legend', { strand => 'r' });        
  }
}
sub load_configured_bigwig { shift->load_file_format('bigwig'); }
sub load_configured_vcf    { shift->load_file_format('vcf');    }
sub load_configured_trackhubs { shift->load_file_format('trackhub'); }

sub load_file_format {
  my ($self, $format, $sources) = @_;
  my $function = "_add_${format}_track";
  
  return unless ($format eq 'trackhub' || $self->can($function));
  
  my $internal = !defined $sources;
  $sources  = $self->sd_call(sprintf 'ENSEMBL_INTERNAL_%s_SOURCES', uc $format) || {} unless defined $sources; # get the internal sources from config
  
  foreach my $source_name (sort keys %$sources) {
    # get the target menu 
    my $menu = $self->get_node($sources->{$source_name});
    my ($source, $view);
    
    if ($menu) {
      $source = $self->sd_call($source_name);
      $view   = $source->{'view'};
    } else {
      ## Probably an external trackhub source
         $source       = $sources->{$source_name};
         $view         = $source->{'view'};
      my $menu_key     = $source->{'menu_key'};
      my $menu_name    = $source->{'menu_name'};
      my $submenu_key  = $source->{'submenu_key'};
      my $submenu_name = $source->{'submenu_name'};
      my $main_menu    = $self->get_node($menu_key) || $self->tree->append_child($self->create_submenu($menu_key, $menu_name, { external => 1, trackhub_menu => !!$source->{'trackhub'} }));
         $menu         = $self->get_node($submenu_key);
      
      if (!$menu) {
        $menu = $self->create_submenu($submenu_key, $submenu_name, { external => 1, ($source->{'matrix_url'} ? (menu => 'matrix', url => $source->{'matrix_url'}) : ()) });
        $self->alphabetise_tracks($menu, $main_menu);
      }
    }
    if ($source) {
      if ($format eq 'trackhub') {
        ## Force hiding of internally configured trackhubs, because they should be 
        ## off by default regardless of the settings in the hub
        my $force_hide = $internal ? 1 : 0;  
        $self->_add_trackhub($source->{'source_name'}, $source->{'url'}, undef, $menu, $force_hide);
      }
      else { 
        my $is_internal = $source->{'source_url'} ? 0 : $internal;
        $self->$function(key => $source_name, menu => $menu, source => $source, description => $source->{'description'}, internal => $is_internal, view => $view);
      }
    }
  }
}

sub _add_bam_track {
  my ($self, %args) = @_;
  $self->_add_htslib_track('bam', %args);
}

sub _add_cram_track {
  my ($self, %args) = @_;
  $self->_add_htslib_track('cram', %args);
}


sub _add_htslib_track {
  my ($self, $hts_format, %args) = @_;
  my $desc = '
    The read end bars indicate the direction of the read and the colour indicates the type of read pair:
    Green = both mates are part of a proper pair; Blue = either this read is not paired, or its mate was not mapped; Red = this read is not properly paired.
  ';
 

  ## Override default renderer (mainly used by trackhubs)
  my %options;
  $options{'display'} = $args{'source'}{'display'} if $args{'source'}{'display'};
 
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

sub _add_bigwig_track {
  my ($self, %args) = @_;

  my $renderers = $args{'source'}{'renderers'} || [
    'off',     'Off',
    'signal',  'Wiggle plot',
    'compact', 'Compact',
  ];

  my $options = {
    external        => 'external',
    sub_type        => 'bigwig',
    style           => 'wiggle',
    colour          => $args{'menu'}{'colour'} || $args{'source'}{'colour'} || 'red',
    longLabel       => $args{'source'}{'longLabel'},
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
  my ($self, $menu, $sub_type, $key, $name, $description, %options) = @_;

  $menu ||= $self->get_node('user_data');

  return unless $menu;

  my ($strand, $renderers, $default) = $self->_user_track_settings($options{'style'}, $options{'format'});

  my $track = $self->create_track($key, $name, {
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
    %options
  });

  $menu->append($track) if $track;
  return $renderers;
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
      $desc = sprintf(
        'Data retrieved from %s %s file on an external webserver. %s <p>This data is attached to the %s, and comes from URL: <a href="%s">%s</a></p>',
        $article,
        $args{'format'},
        $args{'description'},
        encode_entities($args{'source'}{'source_type'}),
        encode_entities($args{'source'}{'source_url'}),
        encode_entities($args{'source'}{'source_url'})
      );
    } else {
      $desc = $args{'description'};
    }
  }
 
  $self->generic_add($menu, undef, $args{'key'}, {}, {
    display     => 'off',
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
    @user_renderers = @{$self->{'alignment_renderers'}};
    splice @user_renderers, 6, 0, 'as_transcript_nolabel', 'Structure', 'as_transcript_label', 'Structure with labels';
    $default = 'as_transcript_label';
  }
  else {
    @user_renderers = (@{$self->{'alignment_renderers'}}, 'difference', 'Differences');
  }

  return ($strand, \@user_renderers, $default);
}

sub _compare_assemblies {
  my ($self, $entry, $session) = @_;

  if ($entry->{'assembly'} && $entry->{'assembly'} ne $self->sd_call('ASSEMBLY_VERSION')) {
    $session->add_data(
      type     => 'message',
      code     => 'userdata_assembly_mismatch',
      message  => "Sorry, track $entry->{'name'} is on an old assembly ($entry->{'assembly'}) and cannot be shown",
      function => '_error'
    );
  }
}

1;
