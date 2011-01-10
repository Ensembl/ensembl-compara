# $Id$

package EnsEMBL::Web::ImageConfig;

use strict;

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use URI::Escape qw(uri_unescape);

use Sanger::Graphics::TextHelper;

use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::NewTree;

#########
# 'user' settings are restored from cookie if available
#  default settings are overridden by 'user' settings
#

# Takes two parameters
# (1) - the hub (i.e. an EnsEMBL::Web::Hub object)
# (2) - the species to use (defaults to the current species)

sub new {
  my $class   = shift;
  my $hub     = shift;
  my $species = shift || $hub->species;
  my $type    = $class =~ /([^:]+)$/ ? $1 : $class;
  my $style   = $hub->species_defs->ENSEMBL_STYLE || {};
  my $session = $hub->session;
  my $cache   = $hub->cache;
  
  my $self = {
    hub                 => $hub,
    _font_face          => $style->{'GRAPHIC_FONT'} || 'Arial',
    _font_size          => ($style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'}) || 20,
    _texthelper         => new Sanger::Graphics::TextHelper,
    type                => $type,
    species             => $species,
    user                => {},
    _useradded          => {}, # contains list of added features
    _r                  => undef,
    no_load             => undef,
    storable            => 1,
    altered             => 0,
    _core               => undef,
    _tree               => new EnsEMBL::Web::NewTree,
    _parameters         => {},
    transcript_types    => [qw(transcript alignslice_transcript tsv_transcript gsv_transcript TSE_transcript gene)],
    alignment_renderers => [
      'off',         'Off',
      'normal',      'Normal',
      'labels',      'Labels',
      'half_height', 'Half height',
      'stack',       'Stacked',
      'unlimited',   'Stacked unlimited',
      'ungrouped',   'Ungrouped',
    ],
  };

  bless $self, $class;

  # Special code here to set species back to default if cannot merge
  $self->{'species'} = $hub->species if $species eq 'merged' && !$self->mergeable_config;
  $species = $self->{'species'};
     
  # Check to see if we have a user/session saved copy of tree.... 
  #   Load tree from cache...
  #   If not check to see if we have a "common" saved copy of tree
  #     If not generate and cache it!
  #   If we have a (user/session) modify the common tree
  #     Cache the user/session version.
  #
  # Check memcached for defaults
  if (my $defaults = $cache ? $cache->get("::${class}::$species") : undef) {
    $self->{$_} = $defaults->{$_} for keys %$defaults;
  } else {
    # No cached defaults found, so initialize them and cache
    $self->init if $self->can('init');
    
    if ($cache) {
      my $defaults = {
        _tree       => $self->{'_tree'},
        _parameters => $self->{'_parameters'},
      };
      
      $cache->set("::${class}::$species", $defaults, undef, 'IMAGE_CONFIG', $species);
    }
  }
  
  $self->{'no_image_frame'} = 1;
  
  # Add user defined data sources
  $self->load_user_tracks($session);
  
  return $self;
}

sub storable :lvalue { $_[0]->{'storable'}; } # Set whether this ViewConfig is changeable by the User, and hence needs to access the database to set storable do $view_config->storable = 1; in SC code
sub altered  :lvalue { $_[0]->{'altered'};  } # Set to one if the configuration has been updated

sub hub               { return $_[0]->{'hub'};                                                 }
sub core_objects      { return $_[0]->hub->core_objects;                                       }
sub colourmap         { return $_[0]->hub->colourmap;                                          }
sub species_defs      { return $_[0]->hub->species_defs;                                       }
sub sd_call           { return $_[0]->species_defs->get_config($_[0]->{'species'}, $_[1]);     }
sub databases         { return $_[0]->sd_call('databases');                                    }
sub texthelper        { return $_[0]->{'_texthelper'};                                         }
sub transform         { return $_[0]->{'transform'};                                           }
sub tree              { return $_[0]->{'_tree'};                                               }
sub mergeable_config  { return 0;                                                              }
sub bgcolor           { return $_[0]->get_parameter('bgcolor') || 'background1';               }
sub bgcolour          { return $_[0]->bgcolor;                                                 }
sub get_node          { return shift->tree->get_node(@_);                                      }
sub get_user_settings { return $_[0]->tree->user_data;                                         }
sub subsections       { return grep { /^managed_/ } keys %{$_[0]->{'user'}};                   }
sub get_parameters    { return $_[0]->{'_parameters'};                                         }
sub get_parameter     { return $_[0]->{'_parameters'}{$_[1]};                                  }
sub set_width         { $_[0]->set_parameter('width', $_[1]);                                  } # TODO: find out why we have width and image_width. delete?
sub image_height      { return shift->parameter('image_height',    @_);                        }
sub image_width       { return shift->parameter('image_width',     @_);                        }
sub container_width   { return shift->parameter('container_width', @_);                        }
sub title             { return shift->parameter('title',           @_);                        }
sub slice_number      { return shift->parameter('slice_number',    @_);                        } # TODO: delete?
sub glyphset_configs  { return grep { $_->data->{'node_type'} eq 'track' } $_[0]->tree->nodes; } # return a list of glyphsets

sub set_user_settings {
  my ($self, $data) = @_;
  
  foreach my $key (keys %$data) {
    my $node = $self->get_node($key);
    
    if ($node) {
      $node->set_user($_, $data->{$key}->{$_}) for keys %{$data->{$key}};
    }
  }
}

sub set_parameters {
  my ($self, $params) = @_;
  $self->{'_parameters'}{$_} = $params->{$_} for keys %$params; 
}

sub set_parameter {
  my ($self, $key, $value) = @_;
  $self->{'_parameters'}{$key} = $value;
}

sub parameter {
  my ($self, $key, $value) = @_;
  $self->set_parameter($key, $value) if $value;
  return $self->get_parameter($key);
}

sub reset {
  my $self = shift;
  $self->{'user'}->{$self->{'type'}} = {}; 
  $self->altered = 1;
}

sub reset_subsection {
  my ($self, $subsection) = @_;
  return unless defined $subsection;
  $self->{'user'}->{$self->{'type'}}->{$subsection} = {}; 
  $self->altered = 1;
}

sub scalex {
  my ($self, $scalex) = @_;
  
  if ($scalex) {
    $self->{'_scalex'} = $scalex;
    $self->texthelper->scalex($scalex);
  }
  
  return $self->{'_scalex'};
}

sub cache {
  my $self = shift;
  my $key  = shift;
  $self->{'_cache'}{$key} = shift if @_;
  return $self->{'_cache'}{$key}
}

# Delete all tracks where menu = no, and parent nodes if they are now empty
sub remove_disabled_menus {
  my ($self, $node) = @_;
  
  if (!$node) {
    $_->remove for grep $_->get('menu') eq 'no', $self->tree->leaves;
    $self->remove_disabled_menus($_) for $self->tree->nodes;
    return;
  }
  
  if ($node->get('node_type') !~ /^(track|option)$/ && !$node->has_child_nodes) {
    my $parent = $node->parent_node;
    $self->remove_disabled_menus($parent) if $parent && scalar @{$parent->child_nodes} == 1;
    $node->remove;
  }
}

# create_menus - takes an "associate array" i.e. ordered key value pairs
# to configure the menus to be seen on the display..
# key and value pairs are the code and the text of the menu...
sub create_menus {
  my ($self, @list) = @_;
  while (my ($key, $caption) = splice @list, 0, 2) {
    $self->tree->append_child($self->create_submenu($key, $caption));
  }
}

sub create_submenu {
  my ($self, $code, $caption, $options) = @_;
  
  my $details = {
    caption   => $caption, 
    node_type => 'menu',
    %{$options || {}}
  };
  
  return $self->tree->create_node($code, $details);
}

sub create_track {
  my ($self, $code, $caption, $options) = @_;
  
  my $details = { 
    name      => $caption,
    node_type => 'track',
    %{$options || {}}
  };
  
  $details->{'strand'}    ||= 'b';      # Make sure we have a strand setting
  $details->{'display'}   ||= 'normal'; # Show unless we explicitly say no
  $details->{'renderers'} ||= [qw(off Off normal Normal)];
  $details->{'colours'}   ||= $self->species_defs->colour($options->{'colourset'}) if exists $options->{'colourset'};
  $details->{'glyphset'}  ||= $code;
  $details->{'caption'}   ||= $caption;
  
  return $self->tree->create_node($code, $details);
}

sub add_track { shift->add_tracks(shift, \@_); }

sub add_tracks {
  my $self     = shift;
  my $menu_key = shift;
  my $menu     = $self->get_node($menu_key);
  
  return unless $menu;
  
  foreach my $row (@_) {
    my ($key, $caption, $glyphset, $params) = @$row; 
    
    next if $self->get_node($key); # Don't add duplicates
    
    $params->{'glyphset'} = $glyphset;
    $menu->append( $self->create_track($key, $caption, $params));
  }
}

sub create_option {
  my ($self, $code, $caption, $values, $renderers, $display) = @_;
  
  $values    ||= { off => 0, normal => 1 };
  $renderers ||= [ 'off', 'Off', 'normal', 'On' ];
  
  return $self->tree->create_node($code, {
    node_type => 'option',
    caption   => $caption,
    name      => $caption,
    values    => $values,
    renderers => $renderers,
    display   => $display || 'normal'
  });
}

sub add_option {
  my $self = shift;
  my $menu = $self->get_node('options');
  
  return unless $menu;
  
  $menu->append($self->create_option(@_));
}

sub add_options {
  my $self = shift;
  my $menu = $self->get_node(ref $_[0] ? 'options' : shift);
  
  return unless $menu;
  
  $menu->append($self->create_option(@$_)) for @_;
}

sub get_option {
  my ($self, $code, $key) = @_;
  my $node = $self->get_node($code);
  return $node ? $node->get($key || 'values')->{$node->get('display')} : 0;
}

sub _check_menus {
  my $self = shift;
  return !!grep $self->get_node($_), @_;
}

sub load_user_tracks {
  my ($self, $session) = @_;
  my $menu = $self->get_node('user_data');
  
  return unless $menu;
  
  my $hub  = $self->hub;
  my $user = $hub->user;
  my $das  = $hub->get_all_das;
  my (%url_sources, %user_sources, %bam_sources);

  foreach my $source (sort { ($a->caption || $a->label) cmp ($b->caption || $b->label) } values %$das) {
    next if $self->get_node('das_' . $source->logic_name);
    
    $source->is_on($self->{'type'}) || next;
    $self->add_das_tracks('user_data', $source);
  }

  # Get the tracks that are temporarily stored - as "files" not in the DB....
  # Firstly "upload data" not yet committed to the database...
  # Then those attached as URLs to either the session or the User
  # Now we deal with the url sources... again flat file
  foreach my $entry ($session->get_data(type => 'url')) {
    next unless $entry->{'species'} eq $self->{'species'};
    
    $url_sources{$entry->{'url'}} = {
      source_name => $entry->{'name'} || $entry->{'url'},
      source_type => 'session',
      format      => $entry->{'format'},
      style       => $entry->{'style'},
    };
  }
  
  foreach my $entry ($session->get_data( type => 'upload' )) {
    next unless $entry->{'species'} eq $self->{'species'};
    
    if ($entry->{'analyses'}) {
      foreach my $analysis (split /, /, $entry->{'analyses'}) {
        $user_sources{$analysis} = {
          source_name => $entry->{'name'},
          source_type => 'session',
          assembly    => $entry->{'assembly'}
        };
        
        $self->_compare_assemblies($entry, $session);
      }
    } elsif ($entry->{'species'} eq $self->{'species'}) {
      my ($display, $strand, $renderers) = $self->_user_track_settings($entry->{'style'});
      
      $menu->append($self->create_track("tmp_$entry->{'code'}", $entry->{'name'}, {
        _class      => 'tmp',
        glyphset    => '_flat_file',
        colourset   => 'classes',
        sub_type    => 'tmp',
        file        => $entry->{'filename'},
        format      => $entry->{'format'},
        caption     => $entry->{'name'},
        renderers   => $renderers,
        description => 'Data that has been temporarily uploaded to the web server.',
        display     => $display,
        strand      => $strand,
      }));
    }
  }
  
  if ($user) {
    foreach my $entry (grep $_->species eq $self->{'species'}, $user->urls) {
      $url_sources{$entry->url} = {
        source_name => $entry->name || $entry->url,
        source_type => 'user' 
      };
    }
    
    foreach my $entry (grep $_->species eq $self->{'species'}, $user->uploads) {
      my ($name, $assembly) = ($entry->name, $entry->assembly);
      
      foreach my $analysis (split /, /, $entry->analyses) {
        $user_sources{$analysis} = {
          source_name => $name,
          source_type => 'user',
          assembly    => $assembly,
        };
        
        $self->_compare_assemblies($entry, $session);
      }
    }
  }

  foreach (sort { $url_sources{$a}{'source_name'} cmp $url_sources{$b}{'source_name'} } keys %url_sources) {
    my $k = 'url_' . md5_hex("$self->{'species'}:$_");
    
    $self->_add_flat_file_track($menu, 'url', $k, $url_sources{$_}{'source_name'}, sprintf('
        Data retrieved from an external webserver. This data is attached to the %s, and comes from URL: %s', 
        encode_entities($url_sources{$_}{'source_type'}), encode_entities($_)
      ),
      'url'    => $_,
      'format' => $url_sources{$_}{'format'},
      'style'  => $url_sources{$_}{'style'},
    );
  }
  
  # We now need to get a userdata adaptor to get the analysis info
  if (keys %user_sources) {
    my $dbs        = new EnsEMBL::Web::DBSQL::DBConnection($self->{'species'});
    my $dba        = $dbs->get_DBAdaptor('userdata');
    my $an_adaptor = $dba->get_adaptor('Analysis');
    my @tracks;
    
    foreach my $logic_name (keys %user_sources) {
      my $analysis = $an_adaptor->fetch_by_logic_name($logic_name);
      
      next unless $analysis;
      
      my ($display, $strand, $renderers) = $self->_user_track_settings($analysis->program_version);
      my $description = encode_entities($analysis->description) || 'User data from dataset ' . encode_entities($user_sources{$logic_name}{'source_name'});
      
      push @tracks, [ "user_$logic_name", $analysis->display_label, {
        _class      => 'user',
        glyphset    => '_user_data',
        colourset   => 'classes',
        sub_type    => 'user',
        renderers   => $renderers,
        source_name => $user_sources{$logic_name}{'source_name'},
        logic_name  => $logic_name,
        caption     => $analysis->display_label,
        data_type   => $analysis->module,
        description => $description,
        display     => $display,
        style       => $analysis->web_data,
        strand      => $strand,
      }];
    }
    
    $menu->append($self->create_track(@$_)) for sort { lc($a->[2]{'source_name'}) cmp lc($b->[2]{'source_name'}) || lc($a->[1]) cmp lc($b->[1]) } @tracks;
  }
  
  # session bam sources
  foreach my $entry (grep $_->{'species'} eq $self->{'species'}, $session->get_data(type => 'bam')) {
    $bam_sources{"$entry->{'name'}_$entry->{'url'}"} = {
      source_name => $entry->{'name'},
      source_url  => $entry->{'url'},
      source_type => 'session'
    };
  }
  
  # user bam sources
  if ($user) {
    foreach my $entry (grep $_->species eq $self->{'species'}, $user->bams) {
      $bam_sources{$entry->name . '_' . $entry->url} = {
        source_name => $entry->name,
        source_url  => $entry->url,
        source_type => 'user'
      };
    }
  }
 
  # create bam tracks
  foreach (sort { $bam_sources{$a}{'source_name'} cmp $bam_sources{$b}{'source_name'} } keys %bam_sources) {
    my $source = $bam_sources{$_};
    my $key    = "bam_$source->{'source_name'}_" . md5_hex("$self->{'species'}:$source->{'source_url'}");
    
    $self->_add_bam_track($menu, $key, $source->{'source_name'},
      caption     => $source->{'source_name'},
      url         => $source->{'source_url'},
      description => sprintf('
        Data retrieved from a BAM file on an external webserver. This data is attached to the %s, and comes from URL: %s',
        encode_entities($source->{'source_type'}), encode_entities($source->{'source_url'})
      ),
    );
  }
}

sub load_configured_bam {
  my $self = shift;
  
  # get the internal sources from config
  my $internal_bam_sources = $self->sd_call('ENSEMBL_INTERNAL_BAM_SOURCES') || {};
  
  foreach my $source_name (sort keys %$internal_bam_sources) {
    # get the target menu 
    my $menu   = $self->get_node($internal_bam_sources->{$source_name});
    my $source = $menu ? $self->sd_call($source_name) : undef;
    
    $self->_add_bam_track($menu, "bam_${source_name}_" . md5_hex("$self->{'species'}:$source->{'url'}"), $source_name, %$source) if $source;
  }
}
 
sub _add_bam_track {
  my ($self, $menu, $key, $name, %options) = @_;
  
  $menu ||= $self->get_node('user_data');
  
  return unless $menu;
 
  my $track = $self->create_track($key, $name, {
    display   => 'off',
    strand    => 'f',
    _class    => 'bam',
    glyphset  => 'bam',
    colourset => 'bam',
    sub_type  => 'bam',
    renderers => [
      'off',       'Off', 
      'normal',    'Normal', 
      'unlimited', 'Unlimited', 
      'histogram', 'Coverage only'
    ],
    %options
  });
 
  $menu->append($track) if $track;
}

sub _user_track_settings {
  my ($self, $style) = @_;
  my $renderers      = $self->{'alignment_renderers'};
  my $strand         = 'b'; 
  my $display        = 'normal';
      
  if ($style eq 'wiggle' || $style eq 'WIG') {
    $display   = 'tiling';
    $strand    = 'r';
    $renderers = [ 'off', 'Off', 'tiling', 'Wiggle plot' ];
  }
  
  return ($display, $strand, $renderers);
}

sub _compare_assemblies {
  my ($self, $entry, $session) = @_;

  if ($entry->{'assembly'} && $entry->{'assembly'} ne $self->sd_call('ASSEMBLY_NAME')) {
    $session->add_data(
      type     => 'message',
      code     => 'userdata_assembly_mismatch',
      message  => "Sorry, track $entry->{'name'} is on an old assembly ($entry->{'assembly'}) and cannot be shown",
      function => '_error'
    );
  }
}

sub _add_flat_file_track {
  my ($self, $menu, $sub_type, $key, $name, $description, %options) = @_;
  
  $menu ||= $self->get_node('user_data');
  
  return unless $menu;
  
  my ($display, $strand, $renderers) = $self->_user_track_settings($options{'style'});

  my $track = $self->create_track($key, $name, {
    display     => $display,
    strand      => $strand,
    _class      => 'url',
    glyphset    => '_flat_file',
    colourset   => 'classes',
    caption     => $name,
    sub_type    => $sub_type,
    renderers   => $renderers,
    description => $description,
    %options
  });
  
  $menu->append($track) if $track;
}

sub update_from_input {
  my $self  = shift;
  my $input = $self->hub->input;
  
  return $self->altered = $self->tree->flush_user if $input->param('reset');
  
  foreach my $param ($input->param) {
    my $renderer = $input->param($param);
    $self->update_track_renderer($param, $renderer);
  }
}

sub update_from_url {
  my ($self, @values) = @_;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $species = $hub->species;
  
  foreach my $v (@values) {
    my ($key, $renderer) = split /=/, $v, 2;
    
    if ($key =~ /^(\w+)[\.:](.*)$/) {
      my ($type, $p) = ($1, $2);
      
      if ($type eq 'url') {
        $p = uri_unescape($p);
        my @path = split(/\./, $p);
        my $ext = $path[-1] eq 'gz' ? $path[-2] : $path[-1];
        my $format = uc($ext);
        
        # We have to create a URL upload entry in the session
        my $code = md5_hex("$species:$p");
        my $n    =  $p =~ /\/([^\/]+)\/*$/ ? $1 : 'un-named';
        
        $session->set_data(
          type    => 'url',
          url     => $p,
          species => $species,
          code    => $code, 
          name    => $n,
          format  => $format,
          style   => $format,
        );
        
        $session->add_data(
          type     => 'message',
          function => '_info',
          code     => 'url_data:' . md5_hex($p),
          message  => sprintf('Data has been attached to your display from the following URL: %s', encode_entities($p))
        );
        
        # We then have to create a node in the user_config
        $self->_add_flat_file_track(undef, 'url', "url_$code", $n, 
          sprintf('Data retrieved from an external webserver. This data is attached to the %s, and comes from URL: %s', encode_entities($n), encode_entities($p)),
          'url' => $p
        );
        
        $self->update_track_renderer("url_$code", $renderer);
      } elsif ($type eq 'das') {
        $p = uri_unescape($p);
        
        if (my $error = $session->add_das_from_string($p, $self->{'type'}, { display => $renderer })) {
          $session->add_data(
            type     => 'message',
            function => '_warning',
            code     => 'das:' . md5_hex($p),
            message  => sprintf('You attempted to attach a DAS source with DSN: %s, unfortunately we were unable to attach this source (%s)', encode_entities($p), encode_entities($error))
          );
        } else {
          $session->add_data(
            type     => 'message',
            function => '_info',
            code     => 'das:' . md5_hex($p),
            message  => sprintf('You have attached a DAS source with DSN: %s %s', encode_entities($p), $self->get_node('user_data') ? ' to this display' : ' but it cannot be displayed on the specified image')
          );
        }
      }
    } else {
      $self->update_track_renderer($key, $renderer, 1);
    }
  }
  
  if ($self->altered) {
    $session->add_data(
      type     => 'message',
      function => '_info',
      code     => 'image_config',
      message  => 'The link you followed has made changes to the tracks displayed on this page',
    );
  }
}

sub update_track_renderer {
  my ($self, $key, $renderer, $on_off) = @_;
  my $node = $self->get_node($key);
  
  return unless $node;
  
  my %valid_renderers = @{$node->data->{'renderers'}};
  my $flag            = 0;

  # if $on_off == 1, only allow track enabling/disabling. Don't allow enabled tracks' renderer to be changed.
  $flag += $node->set_user('display', $renderer) if $valid_renderers{$renderer} && (!$on_off || $renderer eq 'off' || $node->get('display') eq 'off');
  
  $self->altered = 1 if $flag;
  
  return $flag;
}

sub get_track_key {
  my ($self, $prefix, $obj) = @_;
  my $logic_name = $obj->gene ? $obj->gene->analysis->logic_name : $obj->analysis->logic_name;
  my $db         = $obj->get_db;
  my $db_key     = 'DATABASE_' . uc $db;
  my $key        = $self->databases->{$db_key}{'tables'}{'gene'}{'analyses'}{lc $logic_name}{'web'}{'key'} || lc $logic_name;
  return join '_', $prefix, $db, $key;
}

sub modify_configs {
  my ($self, $nodes, $config) = @_;
  
  foreach my $node (map { $self->get_node($_) || () } @$nodes) {
    foreach my $n (grep $_->get('node_type') eq 'track', $node, $node->nodes) {
      $n->set($_, $config->{$_}) for keys %$config;
    }
  }
}

sub _update_missing {
  my ($self, $object) = @_;
  my $species_defs    = $self->species_defs;
  my $count_missing   = grep { $_->get('display') eq 'off' || !$_->get('display') } $self->glyphset_configs; 
  my $missing         = $self->get_node('missing');
  $missing->set('text', $count_missing > 0 ? "There are currently $count_missing tracks turned off." : 'All tracks are turned on') if $missing;
  
  my $info = sprintf(
    '%s %s version %s.%s (%s) %s: %s - %s',
    $species_defs->ENSEMBL_SITETYPE,
    $species_defs->SPECIES_BIO_NAME,
    $species_defs->ENSEMBL_VERSION,
    $species_defs->SPECIES_RELEASE_VERSION,
    $species_defs->ASSEMBLY_NAME,
    $object->seq_region_type_and_name,
    $object->thousandify($object->seq_region_start),
    $object->thousandify($object->seq_region_end)
  );

  my $information = $self->get_node('info');
  $information->set('text', $info) if $information;
  
  return { count => $count_missing, information => $info };
}

# load_tracks - loads in various database derived tracks; 
# loop through core like dbs, compara like dbs, funcgen like dbs, variation like dbs
sub load_tracks { 
  my $self         = shift;
  my $species      = $self->{'species'};
  my $species_defs = $self->species_defs;
  my $dbs_hash     = $self->databases;
  
  my %data_types = (
    core => [
      'add_dna_align_features',     # Add to cDNA/mRNA, est, RNA, other_alignment trees
#     'add_ditag_features',         # Add to ditag_feature tree
      'add_genes',                  # Add to gene, transcript, align_slice_transcript, tsv_transcript trees
      'add_trans_associated',       # Add to features associated with transcripts
      'add_marker_features',        # Add to marker tree
      'add_qtl_features',           # Add to marker tree
      'add_misc_features',          # Add to misc_feature tree
      'add_prediction_transcripts', # Add to prediction_transcript tree
      'add_protein_align_features', # Add to protein_align_feature_tree
      'add_protein_features',       # Add to protein_feature_tree
      'add_repeat_features',        # Add to repeat_feature tree
      'add_simple_features',        # Add to simple_feature tree
      'add_decorations'
    ],
    compara => [
      'add_synteny',                # Add to synteny tree
      'add_alignments'              # Add to compara_align tree
    ],
    funcgen => [
      'add_regulation_features',    # Add to regulation_feature tree
      'add_regulation_builds',      # Add to regulation_feature tree
      'add_oligo_probes'            # Add to oligo tree
    ],
    variation => [
      'add_sequence_variations',    # Add to variation_feature tree
      'add_structural_variations',  # Add to variation_feature tree
      'add_somatic_mutations'       # Add to somatic tree
    ],
  );
  
  foreach my $type (keys %data_types) {
    my ($check, $databases) = $type eq 'compara' ? ($species_defs->multi_hash, $species_defs->compara_like_databases) : ($dbs_hash, $self->sd_call("${type}_like_databases"));
    
    foreach my $db (grep exists $check->{$_}, @{$databases || []}) {
      my $key = lc substr $db, 9;
      $self->$_($key, $check->{$db}{'tables'} || $check->{$db}, $species) for @{$data_types{$type}}; # Look through tables in databases and add data from each one
    }
  }
  
  $self->add_options('information', [ 'opt_empty_tracks', 'Display empty tracks', undef, undef, 'off' ]);
}
 
sub load_configured_das {
  my $self = shift;
  my @extra = @_;
  
  # Now we do the das stuff - to append to menus (if the menu exists)
  my $internal_das_sources = $self->species_defs->get_all_das;
  
  foreach my $source (sort { $a->caption cmp $b->caption } values %$internal_das_sources) {
    next unless $source->is_on($self->{'type'});
    
    my $key  = $source->category . '_external';
    my $node = $self->get_node($source->category);
    my $menu = $self->get_node($key);
    
    if (!$menu && $node) {
      $menu = $self->create_submenu($key, 'External data sources');
      $node->append($menu);
    }
    
    $self->add_das_tracks($key, $source, @extra);
  }
}

sub _merge {
  my ($self, $_sub_tree, $sub_type) = @_;
  my $tree        = $_sub_tree->{'analyses'};
  my $config_name = $self->{'type'};
  my $data        = {};

  foreach my $analysis (keys %$tree) {
    my $sub_tree = $tree->{$analysis}; 
    
    next unless $sub_tree->{'disp'}; # Don't include non-displayable tracks
    next if exists $sub_tree->{'web'}{$sub_type}{'do_not_display'};
    
    my $key = $sub_tree->{'web'}{'key'} || $analysis;
    
    foreach (grep $_ ne 'desc', keys %{$sub_tree->{'web'} || {}}) {
      if ($_ eq 'default') {
        $data->{$key}{'display'} ||= ref $sub_tree->{'web'}{$_} eq 'HASH' ? $sub_tree->{'web'}{$_}{$config_name} : $sub_tree->{'web'}{$_};
      } else {
        $data->{$key}{$_} ||= $sub_tree->{'web'}{$_}; # Longer form for help and configuration
      }
    }
    
    if ($sub_tree->{'web'}{'key'}) {
      if ($sub_tree->{'desc'}) {
        $data->{$key}{'description'} ||= '';
        $data->{$key}{'description'}  .= ($data->{$key}{'description'} ? '; ' : '') . $sub_tree->{'desc'};
      }
    } else {
      $data->{$key}{'description'} = $sub_tree->{'desc'};
    }
    
    push @{$data->{$key}{'logic_names'}}, $analysis;
  }
  
  foreach my $key (keys %$data) {
    $data->{$key}{'name'}    ||= $tree->{$key}{'name'};
    $data->{$key}{'caption'} ||= $data->{$key}{'name'} || $tree->{$key}{'name'};
    $data->{$key}{'display'} ||= 'off';
    $data->{$key}{'strand'}  ||= 'r';
  }
  
  return ([ sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data ], $data);
}

sub generic_add {
  my ($self, $menu, $key, $name, $data, $options) = @_;
  
  $menu->append($self->create_track($name, $data->{'name'}, {
    %$data,
    db        => $key,
    renderers => [ 'off', 'Off', 'normal', 'Normal' ],
    %$options
  }));
}

sub add_das_tracks {
  my ($self, $menu, $source, @extra) = @_;
  my $node = $self->get_node($menu); 
  
  if (!$node && grep { $menu eq "${_}_external" } @{$self->{'transcript_types'}}) {
    for (@{$self->{'transcript_types'}}) {
      $node = $self->get_node("${_}_external");
      last if $node;
    }
  }
  
  $node ||= $self->get_node('external_data'); 
  
  return unless $node;
  
  my $caption  = $source->caption || $source->label;
  my $desc     = $source->description;
  my $homepage = $source->homepage;
  
  $desc .= sprintf ' [<a href="%s" rel="external">Homepage</a>]', $homepage if $homepage;
  
  my $track = $self->create_track('das_' . $source->logic_name, $source->label, {
    @extra,
    _class      => 'DAS',
    glyphset    => '_das',
    display     => 'off',
    logic_names => [ $source->logic_name ],
    caption     => $caption,
    description => $desc,
    renderers   => [
      'off',      'Off', 
      'nolabels', 'No labels', 
      'normal',   'Normal', 
      'labels',   '(force) Labels'
    ],
  });
  
  $node->append($track) if $track;
}

#----------------------------------------------------------------------#
# Functions to add tracks from core like databases                     #
#----------------------------------------------------------------------#

# add_dna_align_features
# loop through all core databases - and attach the dna align
# features from the dna_align_feature tables...
# these are added to one of four menus: cdna/mrna, est, rna, other
# depending whats in the web_data column in the database
sub add_dna_align_features {
  my ($self, $key, $hashref) = @_;
  
  return unless $self->_check_menus('dna_align_cdna');
  
  my ($keys, $data) = $self->_merge($hashref->{'dna_align_feature'}, 'dna_align_feature');
  
  foreach my $key_2 (@$keys) {
    my $k    = $data->{$key_2}{'type'} || 'other';
    my $menu = $self->tree->get_node("dna_align_$k");
    
    if ($menu) {
      my $alignment_renderers = [ @{$self->{'alignment_renderers'}} ];
      
      if (my @other_renderers = @{$data->{$key_2}{'additional_renderers'} || [] }) {
        my $i = 0;
        
        while ($i < scalar(@other_renderers)) {
          splice @$alignment_renderers, $i+2, 0, $other_renderers[$i];
          splice @$alignment_renderers, $i+3, 0, $other_renderers[$i+1];
          $i += 2;
        }
      }
      
      my $display = (grep { $data->{$key_2}{'display'} eq $_ } @{$self->{'alignment_renderers'}}) ? $data->{$key_2}{'display'} : 'off'; # needed because the same logic_name can be a gene and an alignment
      
      $self->generic_add($menu, $key, "dna_align_${key}_$key_2", $data->{$key_2}, {
        glyphset  => '_alignment',
        sub_type  => lc $k,
        colourset => 'feature',
        display   => $display,
        renderers => $alignment_renderers,
        strand    => 'b',
      });
    }
  }
}

sub add_ditag_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->tree->get_node('ditag');
  
  return unless $menu;
  
  my ($keys, $data) = $self->_merge($hashref->{'ditag_feature'});
  $self->generic_add($menu, $key, "ditag_${key}_$_", $data->{$_}, { glyphset => '_ditag', strand => 'b' }) for @$keys;
}

# add_genes
# loop through all core databases - and attach the gene
# features from the gene tables...
# there are a number of menus sub-types these are added to:
# * gene                    # genes
# * transcript              # ordinary transcripts
# * alignslice_transcript   # transcripts in align slice co-ordinates
# * tse_transcript          # transcripts in collapsed intro co-ords
# * tsv_transcript          # transcripts in collapsed intro co-ords
# * gsv_transcript          # transcripts in collapsed gene co-ords
# depending on which menus are configured
sub add_genes {
  my ($self, $key, $hashref) = @_;
  
  # Gene features end up in each of these menus
  return unless $self->_check_menus(@{$self->{'transcript_types'}});

  my ($keys, $data) = $self->_merge($hashref->{'gene'}, 'gene');
  my $colours = $self->species_defs->colour('gene');
  my $flag = 0;
  
  foreach my $type (@{$self->{'transcript_types'}}) {
    my $menu = $self->get_node($type);

    next unless $menu;
    
    foreach (@$keys) {
      $self->generic_add($menu, $key, "${type}_${key}_$_", $data->{$_}, {
        glyphset    => ($type =~ /_/ ? '' : '_') . $type, # QUICK HACK
        colours     => $colours,
        strand      => $type eq 'gene' ? 'r' : 'b',
        renderers   => $type eq 'transcript' ? [
          'off',                'Off',
          'gene_nolabel',       'No exon structure without labels',
          'gene_label',         'No exon structure with labels',
          'transcript_nolabel', 'Expanded without labels',
          'transcript_label',   'Expanded with labels',
          'collapsed_nolabel',  'Collapsed without labels',
          'collapsed_label',    'Collapsed with labels',
        ] : [ 
          'off',          'Off', 
          'gene_nolabel', 'No labels', 
          'gene_label',   'With labels'
        ]
      });
      
      $flag = 1;
    }
  }
  
  # Need to add the gene menu track here
  $self->add_track('information', 'gene_legend', 'Gene Legend', 'gene_legend', { strand => 'r' }) if $flag;
}

sub add_trans_associated {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('trans_associated');
  
  return unless $menu;
  
  my ($keys, $data) = $self->_merge($hashref->{'simple_feature'});
  $self->generic_add($menu, $key, "simple_${key}_$_", $data->{$_}, { glyphset => '_simple', colourset => 'simple' }) for grep $data->{$_}{'transcript_associated'}, @$keys;  
}

sub add_marker_features {
  my($self, $key, $hashref) = @_;
  my $menu = $self->get_node('marker');
  
  return unless $menu;
  
  my ($keys, $data) = $self->_merge($hashref->{'marker_feature'});
  my $colours = $self->species_defs->colour('marker');
  
  foreach (@$keys) {
    $self->generic_add($menu, $key, "marker_${key}_$_", $data->{$_}, {
      glyphset => '_marker',
      labels   => 'on',
      colours  => $colours,
      strand   => 'r',
    });
  }
}

sub add_qtl_features {
  my ($self, $key, $hashref) = @_;
  
  my $menu = $self->get_node('marker');
  
  return unless $menu && $hashref->{'qtl'} && $hashref->{'qtl'}{'rows'} > 0;
  
  $menu->append($self->create_track("qtl_$key", 'QTLs', {
    db          => $key,
    glyphset    => '_qtl',
    caption     => 'QTLs',
    colourset   => 'qtl',
    description => 'Quantative trait loci',
    display     => 'normal',
    renderers   => [ 'off', 'Off', 'normal', 'Normal' ],
    strand      => 'r'
  }));
}

sub add_misc_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('misc_feature');
  
  return unless $menu;
  
  # set some defaults and available tracks
  my $default_tracks = {
    cytoview   => {
      tilepath => { default   => 'normal' },
      encode   => { threshold => 'no'     }
    },
    contigviewbottom => {
      ntctgs => { available => 'no' },
      encode => { threshold => 'no' }
    }
  };
  
  my $config_name = $self->{'type'};
  my $data        = $hashref->{'misc_feature'}{'sets'}; # Different loop - no analyses - just misc_sets
  
  foreach (sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data) {
    next if $_ eq 'NoAnnotation' || $default_tracks->{$config_name}{$_}{'available'} eq 'no';
    
    $self->generic_add($menu, $key, "misc_feature_${key}_$_", $data->{$_}, {
      glyphset          => '_clone',
      set               => $_,
      colourset         => 'clone',
      caption           => $data->{$_}{'name'},
      description       => $data->{$_}{'desc'},
      strand            => 'r',
      display           => $default_tracks->{$config_name}{$_}{'default'} || $data->{$_}{'display'} || 'off',
      outline_threshold => $default_tracks->{$config_name}{$_}{'threshold'} eq 'no' ? undef : 350000
    });
  }
}

sub add_prediction_transcripts {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('prediction');
  
  return unless $menu;
  
  my ($keys, $data) = $self->_merge($hashref->{'prediction_transcript'});
  
  foreach (@$keys) {
    $self->generic_add($menu, $key, "transcript_${key}_$_", $data->{$_}, {
      glyphset    => '_prediction_transcript',
      colourset   => 'prediction',
      colour_key  => lc $_,
      renderers   => [ 'off', 'Off', 'transcript_nolabel', 'No labels', 'transcript_label', 'With labels' ],
      strand      => 'b',
    });
  }
}

# add_protein_align_features
# loop through all core databases - and attach the protein align
# features from the protein_align_feature tables...
sub add_protein_align_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->tree->get_node('protein_align');
  
  return unless $menu;
  
  my ($keys, $data) = $self->_merge($hashref->{'protein_align_feature'}, 'protein_align_feature');
  
  foreach my $key_2 (@$keys) {
    # needed because the same logic_name can be a gene and an alignment, need to fix default rederer  the web_data
    my $display = (grep { $data->{$key_2}{'display'} eq $_ } @{$self->{'alignment_renderers'}}) ? $data->{$key_2}{'display'} : 'off';
    
    $self->generic_add($menu, $key, "protein_${key}_$key_2", $data->{$key_2}, {
      glyphset    => '_alignment',
      sub_type    => 'protein',
      colourset   => 'feature',
      object_type => 'ProteinAlignFeature',
      display     => $display,
      renderers   => $self->{'alignment_renderers'},
      strand      => 'b',
    });
  }
}

sub add_protein_features {
  my ($self, $key, $hashref) = @_;

  # We have two separate glyphsets in this in this case
  # P_feature and P_domain - plus domains get copied onto gsv_domain as well
  my %menus = (
    domain     => [ 'domain',    'P_domain',   'normal' ],
    feature    => [ 'feature',   'P_feature',  'normal' ],
    alignment  => [ 'alignment', 'P_domain',   'off'    ],
    gsv_domain => [ 'domain',    'gsv_domain', 'normal' ]
  );

  return unless $self->_check_menus(keys %menus);

  my ($keys, $data) = $self->_merge($hashref->{'protein_feature'});

  foreach my $menu_code (keys %menus) {
    my $menu = $self->get_node($menu_code);
    
    next unless $menu;
    
    my $type     = $menus{$menu_code}[0];
    my $gset     = $menus{$menu_code}[1];
    my $renderer = $menus{$menu_code}[2];
    
    foreach (@$keys) {
      next if $self->tree->get_node("${type}_$_");
      next if $type ne ($data->{$_}{'type'} || 'feature'); # Don't separate by db in this case
      
      $self->generic_add($menu, $key, "${type}_$_", $data->{$_}, {
        glyphset  => $gset,
        colourset => 'protein_feature',
        display   => $renderer,
        depth     => 1e6,
        strand    => $gset =~ /P_/ ? 'f' : 'b',
      });
    }
  }
}

sub add_repeat_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('repeat');
  
  return unless $menu && $hashref->{'repeat_feature'}{'rows'} > 0;
  
  my $data = $hashref->{'repeat_feature'}{'analyses'};
  
  my %options = (
    glyphset    => '_repeat',
    optimizable => 1,
    depth       => 0.5,
    bump_width  => 0,
    strand      => 'r',
  );
  
  $menu->append($self->create_track("repeat_$key", 'All repeats', {
    db          => $key,
    logic_names => [ undef ], # All logic names
    types       => [ undef ], # All repeat types
    name        => 'All repeats',
    description => 'All repeats',
    colourset   => 'repeat',
    display     => 'off',
    renderers   => [qw(off Off normal Normal)],
    %options
  }));
  
  my $flag    = keys %$data > 1;
  my $colours = $self->species_defs->colour('repeat');
  
  foreach my $key_2 (sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data) {
    if ($flag) {
      # Add track for each analysis
      $self->generic_add($menu, $key, "repeat_${key}_$key_2", $data->{$key_2}, {
        logic_names => [ $key_2 ], # Restrict to a single supset of logic names
        types       => [ undef  ],
        colours     => $colours,
        description => $data->{$key_2}{'desc'},
        display     => 'off',
        %options
      });
    }
    
    my $d2 = $data->{$key_2}{'types'};
    
    if (keys %$d2 > 1) {
      foreach my $key_3 (sort keys %$d2) {
        (my $key_3a = $key_3) =~ s/\W/_/g;
        my $n = $key_3;
        $n   .= " ($data->{$key_2}{'name'})" unless $data->{$key_2}{'name'} eq 'Repeats';
         
        # Add track for each repeat_type;        
        $menu->append($self->create_track('repeat_' . $key . '_' . $key_2 . '_' . $key_3a, $n, {
          db          => $key,
          logic_names => [ $key_2 ],
          types       => [ $key_3 ],
          name        => $n,
          colours     => $colours,
          description => "$data->{$key_2}{'desc'} ($key_3)",
          display     => 'off',
          renderers   => [qw(off Off normal Normal)],
          %options
        }));
      }
    }
  }
}

sub add_simple_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('simple');
  
  return unless $menu;
  
  my ($keys, $data) = $self->_merge($hashref->{'simple_feature'});
  $self->generic_add($menu, $key, "simple_${key}_$_", $data->{$_}, { glyphset => '_simple', colourset => 'simple', strand => 'r' }) for grep !$data->{$_}{'transcript_associated'}, @$keys;
}

sub add_decorations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('decorations');
  
  return unless $menu;
  
  if ($key eq 'core' && $hashref->{'assembly_exception'}{'rows'} > 0) {
    $menu->append($self->create_track("assembly_exception_$key", 'Assembly exceptions', {
      db            => $key,
      glyphset      => 'assemblyexception',
      height        => 2,
      display       => 'normal',
      strand        => 'x',
      label_strand  => 'r',
      short_labels  => 0,
      description   => 'GRC assembly patches, haplotype (HAPs) and pseudo autosomal regions (PARs)',
      colourset     => 'assembly_exception'
    }));
  }
  
  if ($key eq 'core' && $hashref->{'karyotype'}{'rows'} > 0 && !$self->get_node('ideogram')) {
    $menu->append($self->create_track("chr_band_$key", 'Chromosome bands', {
      db          => $key,
      glyphset    => 'chr_band',
      display     => 'normal',
      strand      => 'f',
      description => 'Cytogenetic bands',
      colourset   => 'ideogram'
    }));
  }
  
  if ($key eq 'core' && $hashref->{'misc_feature'}{'sets'}{'NoAnnotation'}) {
    $menu->append($self->create_track('annotation_status', 'Annotation status', {
      db            => $key,
      glyphset      => 'annotation_status',
      height        => 2,
      display       => 'normal',
      strand        => 'x',
      label_strand  => 'r',
      short_labels  => 0,
      depth         => 0,
      description   => 'Unannotated regions',
      colourset     => 'annotation_status',
    }));
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from compara like databases                  #
#----------------------------------------------------------------------#

sub add_synteny {
  my ($self, $key, $hashref, $species) = @_;
  my $menu = $self->get_node('synteny');
  
  return unless $menu;
  
  my @synteny_species = sort keys %{$hashref->{'SYNTENY'}{$species} || {}};

  return unless @synteny_species;
  
  my $species_defs = $self->species_defs;
  my $colours      = $species_defs->colour('synteny');
  my $self_label   = $species_defs->species_label($species, 'no_formatting');

  foreach my $species_2 (@synteny_species) {
    (my $species_readable = $species_2) =~ s/_/ /g;
    my ($a, $b) = split / /, $species_readable;
    my $caption = substr($a, 0, 1) . ".$b synteny";
    my $label   = $species_defs->species_label($species_2, 'no_formatting');
    (my $name   = "Synteny with $label") =~ s/<.*?>//g;
    
    $menu->append($self->create_track("synteny_$species_2", $name, {
      db          => $key,
      glyphset    => '_synteny',
      species     => $species_2,
      species_hr  => $species_readable,
      caption     => $caption,
      description => qq{<a href="/info/docs/compara/analyses.html#synteny" class="cp-external">Synteny regions</a> between $self_label and $label},
      colours     => $colours,
      display     => 'off',
      renderers   => [qw(off Off normal Normal)],
      height      => 4,
      strand      => 'r'
    }));
  }
}

sub add_alignments {
  my ($self, $key, $hashref, $species) = @_;
  
  return unless $self->_check_menus(qw(multiple_align pairwise_tblat pairwise_blastz pairwise_other));
  
  my $species_defs = $self->species_defs;
  
  return if $species_defs->ENSEMBL_SITETYPE eq 'Pre';
  
  my $alignments = {};
  my $vega       = $species_defs->ENSEMBL_SITETYPE eq 'Vega';
  my $self_label = $species_defs->species_label($species, 'no_formatting');
  my $regexp     = $species =~ /^([A-Z])[a-z]*_([a-z]{3})/ ? "-?$1.$2-?" : 'xxxxxx';
  
  foreach my $row (values %{$hashref->{'ALIGNMENTS'}}) {
    next unless $row->{'species'}{$species};
    
    if ($row->{'class'} =~ /pairwise_alignment/) {
      my ($other_species) = grep { !/^$species|merged|ancestral_sequences$/ } keys %{$row->{'species'}};
      $other_species ||= $species if $vega && $row->{'species'}->{$species} && scalar keys %{$row->{'species'}} == 2;
      
      my $other_label = $species_defs->species_label($other_species, 'no_formatting');
      my $menu_key;
      my $description;
      
      if ($row->{'type'} =~ /(B?)LASTZ/) {
        $menu_key    = 'pairwise_blastz';
        $description = qq{<a href="/info/docs/compara/analyses.html" class="cp-external">$1LASTz net pairwise alignments</a> between $self_label and $other_label};
      } elsif ($row->{'type'} =~ /TRANSLATED_BLAT/) {
        $menu_key    = 'pairwise_tblat';
        $description = qq{<a href="/info/docs/compara/analyses.html" class="cp-external">Trans. BLAT net pairwise alignments</a> between $self_label and $other_label};
      } else {
        $menu_key    = 'pairwise_align';
        $description = qq{<a href="/info/docs/compara/analyses.html" class="cp-external">Pairwise alignments</a> between $self_label and $other_label};
      }
      
      $description .= " $1" if $row->{'name'} =~ /\((on.+)\)/;
      
      $alignments->{$menu_key}{$row->{'id'}} = {
        db                         => $key,
        glyphset                   => '_alignment_pairwise',
        name                       => $row->{'name'},
        caption                    => $row->{'name'},
        type                       => $row->{'type'},
        species                    => $other_species,
        method_link_species_set_id => $row->{'id'},
        description                => $description,
        order                      => $other_label,
        colourset                  => 'pairwise',
        strand                     => 'r',
        display                    => 'off',
        renderers                  => [ 'off', 'Off', 'compact', 'Compact', 'normal', 'Normal' ],
      };
    } else {
      my $n_species = grep { !/^ancestral_sequences|merged$/ } keys %{$row->{'species'}};
      
      my %options = (
        db                         => $key,
        glyphset                   => '_alignment_multiple',
        short_name                 => $row->{'name'},
        type                       => $row->{'type'},
        species_set_id             => $row->{'species_set_id'},
        method_link_species_set_id => $row->{'id'},
        class                      => $row->{'class'},
        colourset                  => 'multiple',
        strand                     => 'f',
      );
      
      if ($row->{'conservation_score'}) {
        my ($program) = $hashref->{'CONSERVATION_SCORES'}{$row->{'conservation_score'}}{'type'} =~ /(.+)_CONSERVATION_SCORE/;
        
        $options{'caption'}     = "$n_species way $program scores";
        $options{'description'} = qq{<a href="/info/docs/compara/analyses.html#conservation">$program conservation scores</a> based on the $row->{'name'}};
        
        $alignments->{'multiple_align'}{"$row->{'id'}_scores"} = {
          %options,
          conservation_score => $row->{'conservation_score'},
          name               => "Conservation score for $row->{'name'}",
          order              => sprintf('%12d::%s::%s', 1e12-$n_species*10, $row->{'type'}, $row->{'name'}),
          display            => $row->{'id'} == 352 ? 'tiling' : 'off',
          renderers          => [ 'off', 'Off', 'tiling', 'Tiling array' ],
        };
        
        $alignments->{'multiple_align'}{"$row->{'id'}_constrained"} = {
          %options,
          constrained_element => $row->{'constrained_element'},
          name                => "Constrained elements for $row->{'name'}",
          order               => sprintf('%12d::%s::%s', 1e12-$n_species*10+1, $row->{'type'}, $row->{'name'}),
          display             => $row->{'id'} == 352 ? 'compact' : 'off',
          renderers           => [ 'off', 'Off', 'compact', 'Normal' ],
        };
      }
      
      $alignments->{'multiple_align'}{$row->{'id'}} = {
        %options,
        name        => $row->{'name'},
        caption     => $row->{'name'},
        order       => sprintf('%12d::%s::%s', 1e12-$n_species*10-1, $row->{'type'}, $row->{'name'}),
        display     => 'off', ## Default to on at the moment - change to off by default!
        renderers   => [ 'off', 'Off', 'compact', 'Normal' ],
        description => qq{<a href="/info/docs/compara/analyses.html#conservation">$n_species way whole-genome multiple alignments</a>.; } . 
                       join('; ', sort map { $species_defs->species_label($_, 'no_formatting') } grep { $_ ne 'ancestral_sequences' } keys %{$row->{'species'}}),
      };
    } 
  }
  
  foreach my $menu_key (keys %$alignments) {
    my $menu = $self->get_node($menu_key);
    next unless $menu;
    
    foreach my $key_2 (sort { $alignments->{$menu_key}{$a}{'order'} cmp  $alignments->{$menu_key}{$b}{'order'} } keys %{$alignments->{$menu_key}}) {
      my $row = $alignments->{$menu_key}{$key_2};
      $menu->append($self->create_track("alignment_${key}_$key_2", $row->{'caption'}, $row));
    }
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from functional genomics like database       #
#----------------------------------------------------------------------#

# needs configuring so tracks only display if data in species fg_database
sub add_regulation_features {
  my ($self, $key, $hashref) = @_;  
  my $menu = $self->get_node('functional');
  
  return unless $menu;
  
  my ($keys_1, $data_1) = $self->_merge($hashref->{'feature_set'});
  my ($keys_2, $data_2) = $self->_merge($hashref->{'result_set'});
  my %fg_data           = (%$data_1, %$data_2);
  
  foreach my $key_2 (sort grep { !/reg_feats/ } @$keys_1, @$keys_2) {
    my $type = $fg_data{$key_2}{'type'};
    
    next if !$type || $type eq 'ctcf';
    
    my @renderers;
    
    if ($fg_data{$key_2}{'renderers'}) {
      push @renderers, $_, $fg_data{$key_2}{'renderers'}{$_} for sort keys %{$fg_data{$key_2}{'renderers'}}; 
    } else {
      @renderers = qw(off Off normal Normal);
    }
    
    $menu->append($self->create_track("${type}_${key}_$key_2", $fg_data{$key_2}{'name'} || $fg_data{$key_2}{'logic_names'}, { 
      db          => $key,
      glyphset    => $type,
      sources     => 'undef',
      strand      => 'r',
      labels      => 'on',
      depth       => $fg_data{$key_2}{'depth'}     || 0.5,
      colourset   => $fg_data{$key_2}{'colourset'} || $type,
      display     => $fg_data{$key_2}{'display'}   || 'off', 
      description => $fg_data{$key_2}{'description'},
      logic_name  => $fg_data{$key_2}{'logic_names'}[0],
      renderers   => \@renderers, 
    }));
    
    if ($fg_data{$key_2}{'description'} =~ /cisRED/) {
      $menu->append($self->create_track("${type}_${key}_search", 'cisRED Search Regions', {
        db          => $key,
        glyphset    => 'regulatory_search_regions',
        sources     => 'undef',
        strand      => 'r',
        labels      => 'on',
        depth       => 0.5,
        colourset   => 'regulatory_search_regions',
        description => 'cisRED Search Regions',
        display     => 'off',
      }));
    }
  }
}

sub add_regulation_builds {
  my ($self, $key, $hashref) = @_;  
  my $menu = $self->get_node('functional');
  
  return unless $menu;
  
  my ($keys_1, $data_1) = $self->_merge($hashref->{'feature_set'});
  my ($keys_2, $data_2) = $self->_merge($hashref->{'result_set'});
  my %fg_data           = (%$data_1, %$data_2);
  my $db_tables         = $self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'};
  
  foreach my $key_2 (sort grep { /reg_feats/ } @$keys_1, @$keys_2) {
    my $type = $fg_data{$key_2}{'type'};
    
    next unless $type;
    
    my @cell_lines = sort keys %{$db_tables->{'cell_type'}{'ids'}};
    my (@renderers, $multi_flag);

    if ($fg_data{$key_2}{'renderers'}) {
      push @renderers, $_, $fg_data{$key_2}{'renderers'}{$_} for sort keys %{$fg_data{$key_2}{'renderers'}}; 
    } else {
      @renderers = qw(off Off normal Normal);
    }
    
    # Add MultiCell first
    unshift @cell_lines, 'AAAMultiCell';   

    foreach my $cell_line (sort  @cell_lines) { 
      $cell_line =~ s/AAA|\:\w*//g;
      
      next if $cell_line eq 'MultiCell' && $multi_flag;

      my $track_key = "${key_2}_$cell_line";
      my $display   = 'off';
      my $name      = "$fg_data{$key_2}{'name'} $cell_line";
      
      if ($cell_line =~ /MultiCell/) {  
        $display    = $fg_data{$key_2}{'display'} || 'off';
        $name       = $fg_data{$key_2}{'name'}; 
        $multi_flag = 1;
      }
      
      my $cell_line_menu = $self->create_submenu("regulatory_features $cell_line", "$cell_line tracks");
      
      $cell_line_menu->append($self->create_track($track_key, $name || $fg_data{$key_2}{'logic_names'}, {
        db          => $key,
        glyphset    => $type,
        sources     => 'undef',
        strand      => 'r',
        depth       => $fg_data{$key_2}{'depth'}     || 0.5,
        colourset   => $fg_data{$key_2}{'colourset'} || $type,
        description => $fg_data{$key_2}{'description'},
        display     => $display,
        renderers   => \@renderers,
        cell_line   => $cell_line
      }));
      
      ### Add tracks for cell_line peaks and wiggles only if we have data to display
      my @ftypes     = keys %{$db_tables->{'meta'}{'feature_type_ids'}{$cell_line}      || {}};  
      my @focus_sets = keys %{$db_tables->{'meta'}{'focus_feature_set_ids'}{$cell_line} || {}};  
      
      my %options = (
        db          => $key,
        glyphset    => 'fg_multi_wiggle',
        strand      => 'r',
        depth       => $fg_data{$key_2}{'depth'} || 0.5,
        description => $fg_data{$key_2}{'description'},
        colourset   => 'feature_set',
        display     => 'off',
        menu        => 'no',
        cell_line   => $cell_line,
        renderers   => [
          'off',            'Off', 
          'compact',        'Peaks', 
          'tiling',         'Wiggle plot', 
          'tiling_feature', 'Both' 
        ],         
      );
      
      if (scalar @focus_sets && scalar @focus_sets <= scalar @ftypes) { 
        # Add Core evidence tracks
        $cell_line_menu->append($self->create_track("${key_2}_core_$cell_line", "Core evidence $cell_line", { %options, type => 'core' }));
      } 

      if (scalar @ftypes != scalar @focus_sets  && $cell_line ne 'MultiCell') {
        # Add 'Other' evidence tracks
        $cell_line_menu->append($self->create_track("${key_2}_other_$cell_line", "Other evidence $cell_line", { %options, type => 'other' })); 
      }
      
      $menu->append($cell_line_menu);
    } 
  }
  
  $self->add_track('information', 'fg_regulatory_features_legend', 'Reg. Features Legend', 'fg_regulatory_features_legend', { colourset => 'fg_regulatory_features', strand => 'r' }) if $db_tables->{'cell_type'}{'ids'};
}

sub add_oligo_probes {
  my ($self, $key, $hashref) = @_; 
  my $menu = $self->get_node('oligo');
  
  return unless $menu;
  
  my $data        = $hashref->{'oligo_feature'}{'arrays'};
  my $description = $hashref->{'oligo_feature'}{'analyses'}{'AlignAffy'}{'desc'};  # Different loop - no analyses - base on probeset query results
  
  foreach my $key_2 (sort keys %$data) {
    my $key_3 = $key_2;
    $key_2    =~ s/:/__/;
    
    $menu->append($self->create_track("oligo_${key}_" . uc $key_2, uc $key_3, {
      glyphset    => '_oligo',
      db          => $key,
      sub_type    => 'oligo',
      array       => $key_2,
      object_type => 'ProbeFeature',
      colourset   => 'feature',
      description => $description,
      caption     => $key_3,
      strand      => 'b',
      display     => 'off',
      renderers   => $self->{'alignment_renderers'}
    }));
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from variation like databases                #
#----------------------------------------------------------------------#

sub add_sequence_variations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('variation');
    
  return unless $menu && $hashref->{'variation_feature'}{'rows'} > 0;
  
  my %options = (
    db         => $key,
    glyphset   => '_variation',
    strand     => 'r',
    depth      => 0.5,
    bump_width => 0,
    colourset  => 'variation',
    display    => 'off'
  );
  
  my $sequence_variation = $self->create_submenu('sequence_variations', 'Sequence variants');
  
  $sequence_variation->append($self->create_track("variation_feature_$key", 'Sequence variants (all sources)', {
    %options,
    sources     => undef,
    description => 'Sequence variants from all sources',
  }));
  
  foreach my $key_2 (sort keys %{$hashref->{'source'}{'counts'} || {}}) {
    next unless $hashref->{'source'}{'counts'}{$key_2} > 0;
    next if     $hashref->{'source'}{'somatic'}{$key_2} == 1;
    
    (my $k = $key_2) =~ s/\W/_/g;

    $sequence_variation->append($self->create_track("variation_feature_${key}_$k", "$key_2 variations", {
      %options,
      caption     => $key_2,
      sources     => [ $key_2 ],
      description => $hashref->{'source'}{'descriptions'}{$key_2},
    }));
  }
  
  $menu->append($sequence_variation);

  $self->add_track('information', 'variation_legend', 'Variation Legend', 'variation_legend', { strand => 'r' });
  
  # add in variation sets
  if ($hashref->{'variation_set'}{'rows'} > 0) {
    my $variation_sets = $self->create_submenu('variation_sets', 'Variation sets');
    
    $menu->append($variation_sets);
  
    foreach my $toplevel_set (sort { $a->{'name'} cmp $b->{'name'} && (scalar @{$a->{'subsets'}} ? 1 : 0) <=> (scalar @{$b->{'subsets'}} ? 1 : 0) } values %{$hashref->{'variation_set'}{'supersets'}}) {
      my $name          = $toplevel_set->{'name'};
      my $caption       = $name . (scalar @{$toplevel_set->{'subsets'}} ? ' (all data)' : '');
      my $set_variation = scalar @{$toplevel_set->{'subsets'}} ? $self->create_submenu("set_variation_$name", $name) : $variation_sets;
      
      $set_variation->append($self->create_track("variation_set_$name", $caption, {
        %options,
        caption     => $caption,
        sources     => undef,
        sets        => [ $name ],
        description => $toplevel_set->{'description'},
      }));
  
      # add in sub sets
      if (scalar @{$toplevel_set->{'subsets'}}) {
        foreach my $subset_id (sort @{$toplevel_set->{'subsets'}}) {
          my $sub_set_name        = $hashref->{'variation_set'}{'subsets'}{$subset_id}{'name'}; 
          my $sub_set_description = $hashref->{'variation_set'}{'subsets'}{$subset_id}{'description'};
          
          $set_variation->append($self->create_track("variation_set_${name}_$sub_set_name", $sub_set_name, {
            %options,
            caption     => $sub_set_name,
            sources     => undef,
            sets        => [ $sub_set_name ],
            description => $sub_set_description
          }));
        }
       
        $variation_sets->append($set_variation);
      }
    }
  }
}

sub add_structural_variations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('variation');
  
  return unless $menu && $hashref->{'structural_variation'}{'rows'} > 0;
  
  my $structural_variation = $self->create_submenu('structural_variation', 'Structural variants');
  
  my %options = (
    db         => $key,
    glyphset   => 'structural_variation',
    strand     => 'r', 
    bump_width => 0,
    colourset  => 'structural_variant',
    display    => 'off'
  );
  
  $structural_variation->append($self->create_track('variation_feature_structural', 'Structural variants and CNVs (all sources)', {   
    %options,
    caption     => 'All Structural variants',
    sources     => undef,
    depth       => 5,
    description => 'Structural variants from all sources'
  }));
  
  foreach my $key_2 (sort keys %{$hashref->{'structural_variation'}{'counts'} || {}}) {
    my $description = $hashref->{'source'}{'descriptions'}{$key_2};
    
    $structural_variation->append($self->create_track("variation_feature_structural_$key_2", "$key_2 structural variations", {
      %options,
      caption     => $key_2,
      sources     => [ $key_2 ],
      depth       => 0.5,
      description => $description
      
    }));  
  }
  
  $menu->append($structural_variation);
}
  
sub add_somatic_mutations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('somatic');
  
  return unless $menu;
  
  my %options = (
    db         => $key,
    glyphset   => '_variation',
    strand     => 'r',
    depth      => 0.5,
    bump_width => 0,
    colourset  => 'variation',
    display    => 'off'
  );
  
  foreach my $key_2 (sort grep { $hashref->{'source'}{'somatic'}{$_} == 1 } keys %{$hashref->{'source'}{'somatic'}}) {
    next unless $hashref->{'source'}{'counts'}{$key_2} > 0;
    
    my $description  = $hashref->{'source'}{'descriptions'}{$key_2};
    (my $k = $key_2) =~ s/\W/_/g;

    $menu->append($self->create_track("somatic_mutation_$k", "$key_2 somatic mutations (all)", {
      %options,
      caption     => $key_2,
      description => $description
    }));

    ## Add tracks for each tumour site
    my %tumour_sites = %{$self->species_defs->databases->{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'}{$key_2} || {}};
    
    foreach my $description (sort  keys %tumour_sites) {
      my $phenotype_id           = $tumour_sites{$description};
      my ($source, $type, $site) = split /\:/, $description;
      my $formatted_site         = $site;
      $formatted_site            =~ s/\_/ /g;

      $menu->append($self->create_track("somatic_mutation_${k}_$site", "$key_2 somatic mutations in $formatted_site", {
        %options,
        caption     => "$key_2 $site tumours",
        filter      => $phenotype_id,
        description => $description
      }));    
    }
  }
}

1;
