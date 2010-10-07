package EnsEMBL::Web::ImageConfig;

use warnings;
no warnings 'uninitialized';
use strict;

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);

use Sanger::Graphics::TextHelper;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::OrderedTree;

# use EnsEMBL::Web::Tools::Misc qw(style_by_filesize); # DO NOT UNCOMMENT OR DELETE THIS LINE - It can cause circular references.

our $MEMD = new EnsEMBL::Web::Cache;

#########
# 'general' settings contain defaults.
# 'user' settings are restored from cookie if available
# 'general' settings are overridden by 'user' settings
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
  
  my $self = {
    hub                 => $hub,
    _font_face          => $style->{'GRAPHIC_FONT'} || 'Arial',
    _font_size          => ($style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'}) || 20,
    _texthelper         => new Sanger::Graphics::TextHelper,
    type                => $type,
    species             => $species,
    general             => {},
    user                => {},
    _useradded          => {}, # contains list of added features
    _r                  => undef,
    no_load             => undef,
    storable            => 1,
    altered             => 0,
    _core               => undef,
    _tree               => new EnsEMBL::Web::OrderedTree,
    _parameters         => {},
    transcript_types    => [qw(transcript alignslice_transcript tsv_transcript gsv_transcript TSE_transcript gene)],
    alignment_renderers => [
      off         => 'Off',
      normal      => 'Normal',
      labels      => 'Labels',
      half_height => 'Half height',
      stack       => 'Stacked',
      unlimited   => 'Stacked unlimited',
      ungrouped   => 'Ungrouped',
    ]
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
  # init sets up defaults in $self->{'general'}
  # Check memcached for defaults
  if (my $defaults = $MEMD ? $MEMD->get("::${class}::$species") : undef) {
    $self->{$_} = $defaults->{$_} for keys %$defaults;
  } else {
    # No cached defaults found, so initialize them and cache
    $self->init if $self->can('init');
    
    if ($MEMD) {
      my $defaults = {
        _tree       => $self->{'_tree'},
        _parameters => $self->{'_parameters'},
        general     => $self->{'general'},
      };
      $MEMD->set(
        "::${class}::$species",
        $defaults,
        undef,
        'IMAGE_CONFIG',
        $species,
      );
    }
  }
  
  $self->{'no_image_frame'} = 1;
  
  # Add user defined data sources
  if ($class =~ /ImageConfig::V/) {
    $self->load_user_vert_tracks($session);
  } else {
    $self->load_user_tracks($session);
  }
  
  return $self;
}

sub storable :lvalue { $_[0]->{'storable'}; } # Set whether this ViewConfig is changeable by the User, and hence needs to access the database to set storable do $view_config->storable = 1; in SC code
sub altered  :lvalue { $_[0]->{'altered'};  } # Set to one if the configuration has been updated

sub hub              { return $_[0]->{'hub'};           }
sub core_objects     { return $_[0]->hub->core_objects; }
sub colourmap        { return $_[0]->hub->colourmap;    }
sub species_defs     { return $_[0]->hub->species_defs; }
sub texthelper       { return $_[0]->{'_texthelper'};   }
sub transform        { return $_[0]->{'transform'};     }
sub mergeable_config { return 0; }

sub bgcolor  { return $_[0]->get_parameter('bgcolor') || 'background1'; }
sub bgcolour { return $_[0]->bgcolor; }

# We load less data on vertical drawing code, as it shows regions 
# at a much smaller scale. We also need to distinguish between
# density features, rendered as separate tracks, and pointers,
# which are part of the karyotype track
sub load_user_vert_tracks {
  my ($self, $session) = @_;
  my $menu = $self->get_node('user_data');
  return unless $menu;

  # First, get all the data
  my (@user_tracks, $track_keys);

  # Add in temporary data
  my %types = ( upload => 'filename', url => 'url' );
  
  foreach my $type (keys %types) {
    my @tracks = $session->get_data( type => $type );
    my $field = $types{$type};
    
    foreach my $track (@tracks) {
      my $track_info = {
        id      => 'temp-' . $type . '-' . $track->{'code'}, 
        species => $track->{'species'},
        source  => $track->{$field},
        format  => $track->{'format'},
      };
      
      $track_info->{'render'} = EnsEMBL::Web::Tools::Misc::style_by_filesize($track->{'filesize'});
      
      if ($track->{'name'}) {
        $track_info->{'name'} = $track->{'name'};
      } else {
        my $other = $types{$type};
        $track_info->{'name'} = $track->{$other};
      }
      
      push @user_tracks, $track_info;
    }
  }

  # Add saved tracks, if any
  my $user_sources = {};
  
  if (my $user = $self->hub->user) {    
    foreach my $entry ($user->uploads) {
      next unless  $entry->species eq $self->{'species'};
      
      foreach my $analysis (split /, /, $entry->analyses) {
        $user_sources->{$analysis} = {
          id          => $analysis,
          source_name => $entry->name,
          source_type => 'user',
          filesize    => $entry->filesize,
          species     => $entry->species,
          assembly    => $entry->assembly,
        };
        
        $self->_compare_assemblies($entry, $session);
      }
    }
    
    if (keys %$user_sources) {
      my $dbs = new EnsEMBL::Web::DBSQL::DBConnection($self->{'species'});
      my $dba = $dbs->get_DBAdaptor('userdata');
      my $ana = $dba->get_adaptor('Analysis');

      while (my ($logic_name, $source) = each (%$user_sources)) {
        my $analysis = $ana->fetch_by_logic_name($logic_name);
        next unless $analysis;

        my $track_info = {
          id          => $source->{'id'}, 
          species     => $source->{'species'},
          name        => $analysis->display_label,
          logic_name  => $logic_name,
          description => $analysis->description,
          style       => $analysis->web_data,
        };
        
        $track_info->{'render'} = EnsEMBL::Web::Tools::Misc::style_by_filesize($source->{'filesize'});
        push @user_tracks, $track_info;
      }
    }
  }

  my @density_renderers = (
    'off'             => 'Off',
    'density_line'    => 'Density plot - line graph',
    'density_bar'     => 'Density plot - filled bar chart',
    'density_outline' => 'Density plot - outline bar chart',
  );
  
  my @all_renderers = @density_renderers;
  
  push @all_renderers, (
    'highlight_lharrow'   => 'Arrow on lefthand side',
    'highlight_rharrow'   => 'Arrow on righthand side',
    'highlight_bowtie'    => 'Arrows on both sides',
    'highlight_wideline'  => 'Line',
    'highlight_widebox'   => 'Box',
  );

  # Now, add these tracks to the menu as checkboxes 
  my $width = $self->get_parameter('all_chromosomes') eq 'yes' ? 10 : 60;
  
  foreach my $entry (@user_tracks) {
    push @$track_keys, $entry->{'id'};
    
    if ($entry->{'species'} eq $self->{'species'}) {
      my $settings = {
        id          => $entry->{'id'},
        source      => $entry->{'source'},
        format      => $entry->{'format'},
        glyphset    => 'Vuserdata',
        colourset   => 'densities',
        maxmin      =>  1,
        logic_name  => $entry->{'logic_name'},
        caption     => $entry->{'name'},
        description => $entry->{'description'},
        display     => 'off',
        style       => $entry->{'style'},
        width       => $width,
        strand      => 'b'
      };
      
      if ($entry->{'render'} eq 'density' || ref($self) =~ /mapview/) {
        $settings->{'renderers'} = \@density_renderers;
      } else {
        $settings->{'renderers'} = \@all_renderers;
      }
      
      $menu->append($self->create_track($entry->{'id'}, $entry->{'name'}, $settings));
    }
  }
}

sub load_user_tracks {
  my ($self, $session) = @_;
  my $menu = $self->get_node('user_data');
  
  return unless $menu;
  
  my $hub  = $self->hub;
  my $user = $hub->user;
  my $das  = $hub->get_all_das;
  my %url_sources;
  my %user_sources;

  foreach my $source (sort { ($a->caption || $a->label) cmp ($b->caption || $b->label) } values %$das) {
    next if $self->get_node('das_'.$source->logic_name);
    
    $source->is_on($self->{'type'}) || next;
    $self->add_das_track('user_data', $source);
  }

  # Get the tracks that are temporarily stored - as "files" not in the DB....
  # Firstly "upload data" not yet committed to the database...
  # Then those attached as URLs to either the session or the User
  # Now we deal with the url sources... again flat file
  
  foreach my $entry ($session->get_data(type => 'url')) {
    next unless $entry->{'species'} eq $self->{'species'};
    
    $url_sources{$entry->{'url'}} = {
      source_name => $entry->{'name'} || $entry->{'url'},
      source_type => 'session'
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
    } else {
      my $display   = 'normal';
      my $renderers = $self->{'alignment_renderers'};
      my $strand   = 'b'; 
      
      if ($entry->{'style'} eq 'wiggle') {
        $display   = 'tiling';
        $strand    = 'r';
        $renderers = [ 'off' => 'Off', 'tiling' => 'Wiggle plot' ];
      }
      
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
      })) if $entry->{'species'} eq $self->{'species'};
    }
  }
  
  if ($user) {
    foreach my $entry ($user->urls) {
      next unless  $entry->species eq $self->{'species'};
      
      $url_sources{$entry->url} = {
        source_name => $entry->name || $entry->url,
        source_type => 'user' 
      };
    }
    
    foreach my $entry ($user->uploads) {
      next unless $entry->species eq $self->{'species'};
      
      foreach my $analysis (split /, /, $entry->analyses) {
        $user_sources{$analysis} = {
          source_name => $entry->name,
          source_type => 'user',
          assembly    => $entry->assembly,
        };
        
        $self->_compare_assemblies($entry, $session);
      }
    }
  }

  foreach (sort { $url_sources{$a}{'source_name'} cmp $url_sources{$b}{'source_name'} } keys %url_sources) {
    my $k = 'url_' . md5_hex($self->{'species'} . ':' . $_);
    
    $self->_add_flat_file_track($menu, 'url', $k, $url_sources{$_}{'source_name'}, sprintf('
        Data retrieved from an external webserver. This data is attached to the %s, and comes from URL: %s', 
        encode_entities($url_sources{$_}{'source_type'}), encode_entities($_)
      ),
      'url' => $_
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
      
      my $display   = 'normal';
      my $renderers = $self->{'alignment_renderers'};
      my $strand    = 'b'; 
      
      if ($analysis->program_version eq 'WIG') {
        $display   = 'tiling';
        $strand    = 'r';
        $renderers = [ 'off' => 'Off', 'tiling' => 'Wiggle plot' ];
      }
      
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
    
    foreach(sort { lc($a->[2]{'source_name'}) cmp lc($b->[2]{'source_name'}) || lc($a->[1]) cmp lc($b->[1]) } @tracks) {
      $menu->append($self->create_track(@$_));
    }
  }
  
  return;
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
  
  my $track = $self->create_track($key, $name, {
    display     => 'normal',
    strand      => 'b',
    _class      => 'url',
    glyphset    => '_flat_file',
    colourset   => 'classes',
    caption     => $name,
    sub_type    => $sub_type,
    renderers   => $self->{'alignment_renderers'},
    description => $description,
    %options
  });
  
  $menu->append($track) if $track;
}

sub update_from_input {
  my $self  = shift;
  my $input = $self->hub->input;
  
  return $self->tree->flush_user if $input->param('reset');
  
  my $flag = 0;
  
  foreach my $param ($input->param) {
    my $renderer = $input->param($param);
    $flag += $self->update_track_renderer($param, $renderer);
  }
  
  $self->altered = 1 if $flag;
  
  return $flag;
}

sub update_track_renderer {
  my ($self, $key, $renderer, $on_off) = @_;
  
  my $node = $self->get_node($key);
  
  return unless $node;
  
  my $flag = 0;

  my %valid_renderers = @{$node->data->{'renderers'}};

  # if $on_off == 1, only allow track enabling/disabling. Don't allow enabled tracks' renderer to be changed.
  $flag += $node->set_user('display', $renderer) if $valid_renderers{$renderer} && (!$on_off || $renderer eq 'off' || $node->get('display') eq 'off');
  
  return $flag;
}

#=============================================================================
# General setting/getting cache values...
#=============================================================================

sub cache {
  my $self = shift;
  my $key  = shift;
  $self->{'_cache'}{$key} = shift if @_;
  return $self->{'_cache'}{$key}
}

#=============================================================================
# General setting/getting parameters...
#=============================================================================

sub set_parameters {
  my ($self, $params) = @_;
  $self->{'_parameters'}{$_} = $params->{$_} for keys %$params; 
}

sub get_parameters {
  my $self = shift;
  return $self->{'_parameters'};
}

sub get_parameter {
  my ($self, $key) = @_;
  return $self->{'_parameters'}{$key};
}

sub set_parameter {
  my ($self, $key, $value) = @_;
  $self->{'_parameters'}{$key} = $value;
}

#-----------------------------------------------------------------------------
# Specific parameter setting - image width/container width
#-----------------------------------------------------------------------------
sub title {
  my $self = shift;
  $self->set_parameter('title', shift) if @_;
  return $self->get_parameter('title');
}

sub container_width {
  my $self = shift;
  $self->set_parameter('container_width', shift) if @_;
  return $self->get_parameter('container_width');
}

sub image_width {
  my $self = shift;
  $self->set_parameter('image_width', shift) if @_;
  return $self->get_parameter('image_width');
}

sub slice_number {
  my $self = shift;
  $self->set_parameter('slice_number', shift) if @_;
  return $self->get_parameter('slice_number');
}

sub sd_call { 
  my ($self, $key) = @_;
  return $self->species_defs->get_config($self->{'species'}, $key);
}
sub databases {
  my ($self) = @_;
  return $self->sd_call('databases');
}

sub get_track_key {
  my ($self, $prefix, $obj) = @_;

  my $logic_name = $obj->gene ? $obj->gene->analysis->logic_name : $obj->analysis->logic_name;
  my $db         = $obj->get_db;
  my $db_key     = 'DATABASE_' . uc $db;
  my $key        = $self->databases->{$db_key}{'tables'}{'gene'}{'analyses'}{lc($logic_name)}{'web'}{'key'} || lc($logic_name);
  return join '_', $prefix, $db, $key;
}

sub modify_configs {
  my ($self, $nodes, $config) = @_;
  
  foreach my $conf_key (@$nodes) {
    my $n = $self->get_node($conf_key);
    next unless $n;
    
    foreach my $t ($n->nodes) {
      next unless $t->get('node_type') eq 'track';
      $t->set($_, $config->{$_}) for keys %$config;
    }
  }
}

sub _update_missing {
  my ($self, $object) = @_;
  
  my $count_missing = grep { $_->get('display') eq 'off' || !$_->get('display') } $self->glyphset_configs; 
  my $missing = $self->get_node('missing');
  $missing->set('text' => $count_missing > 0 ? "There are currently $count_missing tracks turned off." : 'All tracks are turned on') if $missing;
  
  my $info = sprintf(
    '%s %s version %s.%s (%s) %s: %s - %s',
    $self->species_defs->ENSEMBL_SITETYPE,
    $self->species_defs->SPECIES_BIO_NAME,
    $self->species_defs->ENSEMBL_VERSION,
    $self->species_defs->SPECIES_RELEASE_VERSION,
    $self->species_defs->ASSEMBLY_NAME,
    $object->seq_region_type_and_name,
    $object->thousandify($object->seq_region_start),
    $object->thousandify($object->seq_region_end)
  );

  my $information = $self->get_node('info');
  $information->set('text' => $info) if $information;
  
  return { count => $count_missing, information => $info };
}
#=============================================================================
# General setting tree stuff...
#=============================================================================

sub tree {  return $_[0]{'_tree'}; }

# create_menus - takes an "associate array" i.e. ordered key value pairs
# to configure the menus to be seen on the display..
# key and value pairs are the code and the text of the menu...

sub create_menus {
  my ($self, @list) = @_;
  while(my ($key, $caption) = splice @list, 0, 2) {
    $self->create_submenu($key, $caption);
  }
}

# load_tracks - loads in various database derived tracks; 
# loop through core like dbs, compara like dbs, funcgen like dbs, variation like dbs
sub load_tracks { 
  my $self       = shift;
  my $species    = $self->{'species'};
  my $dbs_hash   = $self->databases;
  my $multi_hash = $self->species_defs->multi_hash;
  
  my %data_types = (
    core => [
      'add_dna_align_feature',     # Add to cDNA/mRNA, est, RNA, other_alignment trees
#     'add_ditag_feature',         # Add to ditag_feature tree
      'add_gene',                  # Add to gene, transcript, align_slice_transcript, tsv_transcript trees
      'add_trans_associated',      # Add to features associated with transcripts
      'add_marker_feature',        # Add to marker tree
      'add_qtl_feature',           # Add to marker tree
      'add_misc_feature',          # Add to misc_feature tree
      'add_prediction_transcript', # Add to prediction_transcript tree
      'add_protein_align_feature', # Add to protein_align_feature_tree
      'add_protein_feature',       # Add to protein_feature_tree
      'add_repeat_feature',        # Add to repeat_feature tree
      'add_simple_feature',        # Add to simple_feature tree
      'add_assemblies',            # Add to sequence tree
      'add_decorations'
    ],
    compara => [
      'add_synteny',               # Add to synteny tree
      'add_alignments'             # Add to compara_align tree
    ],
    funcgen => [
      'add_regulation_feature',    # Add to regulation_feature tree
      'add_oligo_probe'            # Add to oligo tree
    ]
  );
  
  foreach my $db (@{$self->sd_call('core_like_databases')||[]}) {
    next unless exists $dbs_hash->{$db};
    my $key = lc substr $db, 9;
    
    # Look through tables in databases and add data from each one
    $self->$_($key, $dbs_hash->{$db}{'tables'}) for @{$data_types{'core'}};
  }

  foreach my $db (@{$self->species_defs->compara_like_databases||[]}) {
    next unless exists $multi_hash->{$db};
    my $key = lc substr $db, 9;
    
    # Configure dna_dna_align features and synteny tracks
    $self->$_($key, $multi_hash->{$db}, $species) for @{$data_types{'compara'}};
  }
  
  foreach my $db (@{$self->sd_call('funcgen_like_databases')||[]}) {
    next unless exists $dbs_hash->{$db};
    my $key = lc substr $db, 9;
    
    # Configure regulatory features
    $self->$_($key, $dbs_hash->{$db}{'tables'}, $species) for @{$data_types{'funcgen'}};
  }
  
  foreach my $db (@{$self->sd_call('variation_like_databases')||[]}) {
    next unless exists $dbs_hash->{$db};
    my $key = lc substr $db, 9;
    
    # Configure variation features
    $self->add_variation_feature($key, $dbs_hash->{$db}{'tables'}); # To variation_feature tree
  }
  
  $self->add_options('information',
    [ 'opt_empty_tracks', 'Display empty tracks', undef, undef, 'off' ]
  );
}
 
sub load_configured_das {
  my $self = shift;
  my @extra = @_;
  
  # Now we do the das stuff - to append to menus (if the menu exists)
  my $internal_das_sources = $self->species_defs->get_all_das;
  
  foreach my $source (sort { $a->caption cmp $b->caption } values %$internal_das_sources) {
    $source->is_on($self->{'type'}) || next;
    $self->add_das_track( $source->category, $source, @extra);
  }
}

sub add_das_track {
  my ($self, $menu, $source, @extra) = @_;
  my $node = $self->get_node($menu); 
  
  if (!$node && grep { $menu eq $_ } @{$self->{'transcript_types'}}) {
    for (@{$self->{'transcript_types'}}) {
      $node = $self->get_node($_);
      last if $node;
    }
  }
  
  $node ||= $self->get_node('external_data'); 
  
  return unless $node;

  my $caption  = $source->caption || $source->label;
  my $desc     = $source->description;
  my $homepage = $source->homepage;
  
  $desc .= sprintf ' [<a href="%s" rel="external">Homepage</a>]', $homepage if $homepage;
  
  my $t = $self->create_track('das_' . $source->logic_name, $source->label, {
    @extra,
    _class      => 'DAS',
    glyphset    => '_das',
    display     => 'off',
    renderers   => ['off' => 'Off', 'nolabels' => 'No labels', 'normal' => 'Normal', 'labels' => '(force) Labels'],
    logicnames  => [ $source->logic_name ],
    caption     => $caption,
    description => $desc,
  });
  
  $node->append($t) if $t;
}

#-----------------------------------------------------------------------------
# Functions to add tracks from core like databases....
#-----------------------------------------------------------------------------

sub _check_menus {
  my $self = shift;
  return !!grep $self->tree->get_node($_), @_;
}

sub _merge {
  my ($self, $_sub_tree, $sub_type) = @_;
  my $data = {};
  my $tree = $_sub_tree->{'analyses'};
  my $config_name = $self->{'type'};

  foreach my $analysis (keys %$tree) {
    my $sub_tree = $tree->{$analysis}; 
    
    next unless $sub_tree->{'disp'}; # Don't include non-displayable tracks
    next if exists $sub_tree->{'web'}{ $sub_type }{'do_not_display'};
    
    my $key = $sub_tree->{'web'}{'key'} || $analysis;
    
    foreach ( keys %{$sub_tree->{'web'}||{}} ) {
      next if $_ eq 'desc';
      
      if ($_ eq 'default') {
        if (ref $sub_tree->{'web'}{$_} eq 'HASH') {
          $data->{$key}{'display'} ||= $sub_tree->{'web'}{$_}{$config_name};
        } else {
          $data->{$key}{'display'} ||= $sub_tree->{'web'}{$_};
        }
      } else {
        $data->{$key}{$_} ||= $sub_tree->{'web'}{$_}; # Longer form for help and configuration
      }
    }
    
    if ($sub_tree->{'web'}{'key'}) {
      if ($sub_tree->{'desc'}) {
        $data->{$key}{'html_desc'}   ||= "<dl>\n";
        $data->{$key}{'description'} ||= '';
        $data->{$key}{'html_desc'} .= sprintf(
          "  <dt>%s</dt>\n  <dd>%s</dd>\n",
          encode_entities($sub_tree->{'web'}{'name'}),  # Description for pop-help - merger of all descriptions
          encode_entities($sub_tree->{'desc'})
        );
        $data->{$key}{'description'} .= ($data->{$key}{'description'} ? '; ' : '') . $sub_tree->{'desc'};
      }
    } else {
      $data->{$key}{'description'} = $sub_tree->{'desc'};
      $data->{$key}{'html_desc'}  .= sprintf '<p>%s</p>', encode_entities($sub_tree->{'desc'});
    }
    
    push @{$data->{$key}{'logic_names'}}, $analysis;
  }
  
  foreach my $key (keys %$data) {
    $data->{$key}{'name'}       ||= $tree->{$key}{'name'};
    $data->{$key}{'caption'}    ||= $data->{$key}{'name'} || $tree->{$key}{'name'};
    $data->{$key}{'description'} .= '</dl>' if $data->{$key}{'description'} =~ '<dl>';
  }
  
  return ([ sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data ], $data);
}

sub add_assemblies {
  my ($self, $key, $hashref) = @_;
  return unless $self->_check_menus('sequence');
}

# add_dna_align_feature
# loop through all core databases - and attach the dna align
# features from the dna_align_feature tables...
# these are added to one of four menus: cdna/mrna, est, rna, other
# depending whats in the web_data column in the database
sub add_dna_align_feature {
  my ($self, $key, $hashref) = @_;
  
  return unless $self->_check_menus('dna_align_cdna');
  
  my ($keys, $data) = $self->_merge($hashref->{'dna_align_feature'}, 'dna_align_feature');
  
  foreach my $key_2 (@$keys) {
    my $k = $data->{$key_2}{'type'} || 'other';
    my $menu = $self->tree->get_node("dna_align_$k");
    if ($menu) {
      my $display = (grep { $data->{$key_2}{'display'} eq $_ } @{$self->{'alignment_renderers'}}) ? $data->{$key_2}{'display'} : 'off'; # needed because the same logic_name can be a gene and an alignment
      $menu->append($self->create_track('dna_align_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, {
        db           => $key,
        glyphset     => '_alignment',
        sub_type     => lc($k),
        colourset    => 'feature',
        colour_key   => $data->{$key_2}{'colour_key'},
        zmenu        => $data->{$key_2}{'zmenu'},
        logicnames   => $data->{$key_2}{'logic_names'},
        caption      => $data->{$key_2}{'caption'},
        description  => $data->{$key_2}{'description'},
        display      => $display,
        renderers    => $self->{'alignment_renderers'},
        strand       => 'b',
        show_strands => $data->{$key_2}{'show_strands'} || '', # show alignments all on one strand if configured as such
      }));
    }
  }
}

# add_protein_align_feature
# loop through all core databases - and attach the protein align
# features from the protein_align_feature tables...
sub add_protein_align_feature {
  my ($self, $key, $hashref) = @_;
  
  return unless $self->_check_menus('protein_align');
  
  my ($keys, $data) = $self->_merge($hashref->{'protein_align_feature'}, 'protein_align_feature');
  my $menu = $self->tree->get_node('protein_align');
  
  foreach my $key_2 (@$keys) {
    # needed because the same logic_name can be a gene and an alignment, need to fix default rederer  the web_data
    my $display = (grep { $data->{$key_2}{'display'} eq $_ } @{$self->{'alignment_renderers'}}) ? $data->{$key_2}{'display'} : 'off';
    
    $menu->append($self->create_track('protein_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, {
      db          => $key,
      glyphset    => '_alignment',
      sub_type    => 'protein',
      object_type => 'ProteinAlignFeature',
      colourset   => 'feature',
      logicnames  => $data->{$key_2}{'logic_names'},
      caption     => $data->{$key_2}{'caption'},
      description => $data->{$key_2}{'description'},
      display     => $display,
      renderers   => $self->{'alignment_renderers'},
      strand      => 'b'
    }));
  }
}

sub add_trans_associated {
  my ($self, $key, $hashref) = @_;
  
  return unless $self->get_node('trans_associated');
  
  my ($keys, $data) = $self->_merge($hashref->{'simple_feature'});
  my $menu = $self->tree->get_node('trans_associated');
  
  foreach my $key_2 (@$keys) {
    next unless $data->{$key_2}{'transcript_associated'};
    
    $menu->append($self->create_track('simple_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, {
      db          => $key,
      glyphset    => '_simple',
      logicnames  => $data->{$key_2}{'logic_names'},
      colourset   => 'simple',
      caption     => $data->{$key_2}{'caption'},
      description => $data->{$key_2}{'description'},
      display     => $data->{$key_2}{'display'} || 'off',
      renderers   => [qw(off Off normal Normal)],
      strand      => $data->{$key_2}{'strand'} || 'r',
    }));
  }
}

sub add_simple_feature {
  my ($self, $key, $hashref) = @_;
  
  return unless $self->get_node('simple');
  
  my ($keys, $data) = $self->_merge($hashref->{'simple_feature'});
  my $menu = $self->tree->get_node('simple');
  
  foreach my $key_2 (@$keys) {
    next if $data->{$key_2}{'transcript_associated'};
    
    $menu->append($self->create_track('simple_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, {
      db          => $key,
      glyphset    => '_simple',
      logicnames  => $data->{$key_2}{'logic_names'},
      colourset   => 'simple',
      caption     => $data->{$key_2}{'caption'},
      description => $data->{$key_2}{'description'},
      ext_url     => $data->{$key_2}{'ext_url'},
      display     => $data->{$key_2}{'display'} || 'off',
      renderers   => [qw(off Off normal Normal)],
      strand      => 'r',
    }));
  }
}

sub add_prediction_transcript {
  my ($self, $key, $hashref) = @_;
  
  return unless $self->get_node('prediction');
  
  my ($keys, $data) = $self->_merge($hashref->{'prediction_transcript'});
  my $menu = $self->tree->get_node('prediction');
  
  foreach my $key_2 (@$keys) {
    $menu->append($self->create_track('transcript_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, {
      db          => $key,
      glyphset    => '_prediction_transcript',
      logicnames  => $data->{$key_2}{'logic_names'},
      caption     => $data->{$key_2}{'caption'},
      colourset   => 'prediction',
      colour_key  => lc($key_2),
      description => $data->{$key_2}{'description'},
      display     => $data->{$key_2}{'display'} || 'off',
      renderers   => [ qw(off Off), 'transcript_nolabel' => 'No labels', 'transcript_label' => 'With labels' ],
      strand      => 'b'
    }));
  }
}

sub add_ditag_feature {
  my ($self, $key, $hashref) = @_;
  
  return unless $self->_check_menus('ditag');
  
  my ($keys, $data) = $self->_merge($hashref->{'ditag_feature'});
  my $menu = $self->tree->get_node('ditag');
  
  foreach my $key_2 (@$keys) {
    $menu->append($self->create_track('ditag_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, {
      db          => $key,
      glyphset    => '_ditag',
      logicnames  => $data->{$key_2}{'logic_names'},
      caption     => $data->{$key_2}{'caption'},
      description => $data->{$key_2}{'description'},
      display     => $data->{$key_2}{'display'} || 'off',
      renderers   => [qw(off Off normal Normal)],
      strand      => 'b'
    }));
  }
}

# add_gene...
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
sub add_gene {
  my ($self, $key, $hashref) = @_;
  
  # Gene features end up in each of these menus
  return unless $self->_check_menus(@{$self->{'transcript_types'}});

  my ($keys, $data) = $self->_merge($hashref->{'gene'}, 'gene');
  my $flag = 0;
  
  foreach my $type (@{$self->{'transcript_types'}}) {
    my $menu = $self->get_node($type);

    next unless $menu;
    
    foreach my $key_2 (@$keys) {
      $menu->append($self->create_track($type . '_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, {
        db          => $key,
        glyphset    => ($type =~ /_/ ? '' : '_') . $type, # QUICK HACK
        logicnames  => $data->{$key_2}{'logic_names'},
        colours     => $self->species_defs->colour('gene'),
        caption     => $data->{$key_2}{'caption'},
        colour_key  => $data->{$key_2}{'colour_key'},
        label_key   => $data->{$key_2}{'label_key'},
        zmenu       => $data->{$key_2}{'zmenu'},
        description => $data->{$key_2}{'description'},
        display     => $data->{$key_2}{'display'} || 'off',
        strand      => $type eq 'gene' ? 'r' : 'b',
        renderers   => $type eq 'transcript' ?
          [ qw(off Off), 
            'gene_nolabel'       => 'No exon structure without labels',
            'gene_label'         => 'No exon structure with labels',
            'transcript_nolabel' => 'Expanded without labels',
            'transcript_label'   => 'Expanded with labels',
            'collapsed_nolabel'  => 'Collapsed without labels',
            'collapsed_label'    => 'Collapsed with labels',
          ] : 
          [ qw(off Off gene_nolabel), 'No labels', 'gene_label', 'With labels' ],
      }));
      
      $flag = 1;
    }
  }
  
  # Need to add the gene menu track here
  $self->add_track('information', 'gene_legend', 'Gene Legend', 'gene_legend', { strand => 'r' }) if $flag;
}

sub add_marker_feature {
  my($self, $key, $hashref) = @_;
  
  return unless $self->get_node('marker');
  
  my($keys, $data) = $self->_merge($hashref->{'marker_feature'});
  my $menu = $self->get_node('marker');
  
  foreach my $key_2 (@$keys) {
    $menu->append($self->create_track('marker_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, {
      db          => $key,
      glyphset    => '_marker',
      labels      => 'on',
      logicnames  => $data->{$key_2}{'logic_names'},
      caption     => $data->{$key_2}{'caption'},
      colours     => $self->species_defs->colour('marker'),
      description => $data->{$key_2}{'description'},
      priority    => $data->{$key_2}{'priority'},
      display     => $data->{$key_2}{'display'} || 'off',
      renderers   => [qw(off Off normal Normal)],
      strand      => 'r'
    }));
  }
}

sub add_qtl_feature {
  my ($self, $key, $hashref) = @_;
  
  my $menu = $self->get_node('marker');
  
  return unless $menu && $hashref->{'qtl'} && $hashref->{'qtl'}{'rows'} > 0;
  
  $menu->append($self->create_track('qtl_' . $key, 'QTLs', {
    db          => $key,
    glyphset    => '_qtl',
    caption     => 'QTLs',
    colourset   => 'qtl',
    description => 'Quantative trait loci',
    display     => 'normal',
    renderers   => [qw(off Off normal Normal)],
    strand      => 'r'
  }));
}

sub add_misc_feature {
  my ($self, $key, $hashref) = @_;
  
  # set some defaults and available tracks
  my $default_tracks = {
    cytoview   => {
      tilepath => { default   => 'normal' },
      encode   => { threshold => 'no' }
    },
    contigviewbottom => {
      ntctgs => { available => 'no' },
      encode => { threshold => 'no' }
    }
  };
  
  my $menu = $self->get_node('misc_feature');
  
  return unless $menu;
  
  my $config_name = $self->{'type'};
  my $data = $hashref->{'misc_feature'}{'sets'}; # Different loop - no analyses - just misc_sets
  
  foreach my $key_2 (sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data) {
    next if $key_2 eq 'NoAnnotation' || $default_tracks->{$config_name}{$key_2}{'available'} eq 'no';
    
    my $dets = {
      glyphset    => '_clone',
      db          => $key,
      set         => $key_2,
      colourset   => 'clone',
      caption     => $data->{$key_2}{'name'},
      description => $data->{$key_2}{'desc'},
      max_length  => $data->{$key_2}{'max_length'},
      strand      => 'r',
      display     => $default_tracks->{$config_name}{$key_2}{'default'}||$data->{$key_2}{'display'} || 'off',
      renderers   => [qw(off Off normal Normal)],
    };
    
    $dets->{'outline_threshold'} = 350000 unless $default_tracks->{$config_name}{$key_2}{'threshold'} eq 'no';
    $menu->append($self->create_track('misc_feature_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, $dets));
  }
}

sub add_oligo_probe {
  my ($self, $key, $hashref) = @_; 
  my $menu = $self->get_node('oligo');
  
  return unless $menu;
  
  my $data = $hashref->{'oligo_feature'}{'arrays'};
  my $description = $hashref->{'oligo_feature'}{'analyses'}{'AlignAffy'}{'desc'};  # Different loop - no analyses - base on probeset query results
  
  foreach my $key_2 (sort keys %$data) {
    my $key_3 = $key_2;
    $key_2 =~ s/:/__/;
    
    $menu->append($self->create_track('oligo_' . $key . '_' . uc $key_2, uc $key_3, {
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

sub add_protein_feature {
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
    
    foreach my $key_2 (@$keys) {
      next if $self->tree->get_node($type . '_' . $key_2);
      next if $type ne ($data->{$key_2}{'type'} || 'feature'); # Don't separate by db in this case
      
      $menu->append($self->create_track($type . '_' . $key_2, $data->{$key_2}{'name'}, {
        strand      => $gset =~ /P_/ ? 'f' : 'b',
        depth       => 1e6,
        glyphset    => $gset,
        logicnames  => $data->{$key_2}{'logic_names'},
        name        => $data->{$key_2}{'name'},
        caption     => $data->{$key_2}{'caption'},
        colourset   => 'protein_feature',
        description => $data->{$key_2}{'description'},
        display     => $renderer,
        renderers   => [qw(off Off normal Normal)],
      }));
    }
  }
}

sub add_repeat_feature {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('repeat');
  
  return unless $menu && $hashref->{'repeat_feature'}{'rows'} > 0;
  
  my $data = $hashref->{'repeat_feature'}{'analyses'};
  
  $menu->append($self->create_track('repeat_' . $key, 'All repeats', {
    db          => $key,
    glyphset    => '_repeat',
    logicnames  => [ undef ], # All logic names
    types       => [ undef ], # All repeat types
    name        => 'All repeats',
    description => 'All repeats',
    colourset   => 'repeat',
    display     => 'off',
    renderers   => [qw(off Off normal Normal)],
    optimizable => 1,
    depth       => 0.5,
    bump_width  => 0,
    strand      => 'r'
  }));
  
  my $flag = keys %$data > 1;
  
  foreach my $key_2 (sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data) {
    if ($flag) {
      # Add track for each analysis
      $menu->append($self->create_track('repeat_' . $key . '_' . $key_2, $data->{$key_2}{'name'}, {
        db          => $key,
        glyphset    => '_repeat',
        logicnames  => [ $key_2 ], # Restrict to a single supset of logic names
        types       => [ undef ],
        name        => $data->{$key_2}{'name'},
        description => $data->{$key_2}{'desc'},
        colours     => $self->species_defs->colour('repeat'),
        display     => 'off',
        renderers   => [qw(off Off normal Normal)],
        optimizable => 1,
        depth       => 0.5,
        bump_width  => 0,
        strand      => 'r'
      }));
    }
    
    my $d2 = $data->{$key_2}{'types'};
    
    if (keys %$d2 > 1) {
      foreach my $key_3 (sort keys %$d2) {
        (my $key_3a = $key_3) =~ s/\W/_/g;
        my $n = $key_3;
        $n .= " ($data->{$key_2}{'name'})" unless $data->{$key_2}{'name'} eq 'Repeats';
         
        # Add track for each repeat_type;
        $menu->append($self->create_track('repeat_' . $key . '_' . $key_2 . '_' . $key_3a, $n, {
          db          => $key,
          glyphset    => '_repeat',
          logicnames  => [ $key_2 ],
          types       => [ $key_3 ],
          name        => $n,
          description => "$data->{$key_2}{'desc'} ($key_3)",
          colours     => $self->species_defs->colour('repeat'),
          display     => 'off',
          renderers   => [qw(off Off normal Normal)],
          optimizable => 1,
          depth       => 0.5,
          bump_width  => 0,
          strand      => 'r'
        }));
      }
    }
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from compara like databases....
#----------------------------------------------------------------------#

sub add_synteny {
  my ($self, $key, $hashref, $species) = @_;
  my $menu = $self->get_node('synteny');
  
  return unless $menu;
  
  my @synteny_species = sort keys %{$hashref->{'SYNTENY'}{$species}||{}};

  return unless @synteny_species;
  
  my $self_label = $self->species_defs->species_label($species, 'no_formatting');

  foreach my $species_2 (@synteny_species) {
    (my $species_readable = $species_2) =~ s/_/ /g;
    my ($a, $b) = split / /, $species_readable;
    my $caption = substr($a, 0, 1) . ".$b synteny";
    my $label   = $self->species_defs->species_label($species_2, 'no_formatting');
    (my $name   = "Synteny with $label") =~ s/<.*?>//g;
    
    $menu->append($self->create_track('synteny_' . $species_2, $name, {
      db          => $key,
      glyphset    => '_synteny',
      species     => $species_2,
      species_hr  => $species_readable,
      caption     => $caption,
      description => qq{<a href="/info/docs/compara/analyses.html#synteny" class="cp-external">Synteny regions</a> between $self_label and $label},
      colours     => $self->species_defs->colour('synteny'),
      display     => 'off',
      renderers   => [qw(off Off normal Normal)],
      height      => 4,
      strand      => 'r'
    }));
  }
}

sub add_alignments {
  my ($self, $key, $hashref, $species) = @_;

  return unless $self->_check_menus(qw( multiple_align pairwise_tblat pairwise_blastz pairwise_other ));
  return if $self->species_defs->ENSEMBL_SITETYPE eq 'Pre';
  
  my $alignments = {};
  my $vega       = $self->species_defs->ENSEMBL_SITETYPE eq 'Vega';
  my $self_label = $self->species_defs->species_label($species, 'no_formatting');
  my $regexp     = $species =~ /^([A-Z])[a-z]*_([a-z]{3})/ ? "-?$1.$2-?" : 'xxxxxx';
  
  foreach my $row (values %{$hashref->{'ALIGNMENTS'}}) {
    next unless $row->{'species'}{$species};
    
    if ($row->{'class'} =~ /pairwise_alignment/) {
      my ($other_species) = grep { !/^$species|merged|ancestral_sequences$/ } keys %{$row->{'species'}};
      $other_species ||= $species if $vega && $row->{'species'}->{$species} && scalar keys %{$row->{'species'}} == 2;
      
      my $other_label = $self->species_defs->species_label($other_species, 'no_formatting');
      my $menu_key;
      my $description;
      
      if ($row->{'type'} =~ /BLASTZ/) {
        $menu_key    = 'pairwise_blastz';
        $description = qq{<a href="/info/docs/compara/analyses.html" class="cp-external">BLASTz net pairwise alignments</a> between $self_label and $other_label};
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
        name                       => $other_label,
        caption                    => $row->{'name'},
        type                       => $row->{'type'},
        species                    => $other_species,
        method_link_species_set_id => $row->{'id'},
        description                => $description,
        order                      => $other_label,
        colourset                  => 'pairwise',
        strand                     => 'r',
        display                    => 'off',
        renderers                  => [qw(off Off compact Compact normal Normal)],
      };
    } else {
      my $n_species = grep { !/^ancestral_sequences|merged$/ } keys %{$row->{'species'}};
      
      if ($row->{'conservation_score'}) {
        my ($program) = $hashref->{'CONSERVATION_SCORES'}{$row->{'conservation_score'}}{'type'} =~ /(.+)_CONSERVATION_SCORE/;
        
        $alignments->{'multiple_align'}{"$row->{'id'}_scores"} = {
          db                         => $key,
          glyphset                   => '_alignment_multiple',
          name                       => "Conservation score for $row->{'name'}",
          short_name                 => $row->{'name'},
          caption                    => "$n_species way $program scores",
          type                       => $row->{'type'},
          species_set_id             => $row->{'species_set_id'},
          method_link_species_set_id => $row->{'id'},
          class                      => $row->{'class'},
          conservation_score         => $row->{'conservation_score'},
          description                => qq{<a href="/info/docs/compara/analyses.html#conservation" class="cp-external">$program conservation scores</a> based on the $row->{'name'}},
          colourset                  => 'multiple',
          order                      => sprintf('%12d::%s::%s', 1e12-$n_species*10, $row->{'type'}, $row->{'name'}),
          strand                     => 'f',
          display                    => $row->{'id'} == 352 ? 'tiling' : 'off',
          renderers                  => [ 'off' => 'Off', 'tiling' => 'Tiling array' ]
        };
        
        $alignments->{'multiple_align'}{"$row->{'id'}_constrained"} = {
          db                         => $key,
          glyphset                   => '_alignment_multiple',
          name                       => "Constrained elements for $row->{'name'}",
          short_name                 => $row->{'name'},
          caption                    => "$n_species way $program elements",
          type                       => $row->{'type'},
          species_set_id             => $row->{'species_set_id'},
          method_link_species_set_id => $row->{'id'},
          class                      => $row->{'class'},
          constrained_element        => $row->{'constrained_element'},
          description                => qq{<a href="/info/docs/compara/analyses.html#conservation" class="cp-external">$program constrained elements</a> based on the $row->{'name'}},
          colourset                  => 'multiple',
          order                      => sprintf('%12d::%s::%s', 1e12-$n_species*10+1, $row->{'type'}, $row->{'name'}),
          strand                     => 'f',
          display                    => $row->{'id'} == 352 ? 'compact' : 'off',
          renderers                  => [qw(off Off compact Normal)]
        };
      }
      
      $alignments->{'multiple_align'}{$row->{'id'}} = {
        db                         => $key,
        glyphset                   => '_alignment_multiple',
        name                       => $row->{'name'},
        short_name                 => $row->{'name'},
        caption                    => $row->{'name'},
        type                       => $row->{'type'},
        species_set_id             => $row->{'species_set_id'},
        method_link_species_set_id => $row->{'id'},
        class                      => $row->{'class'},
        description                => qq{<a href="/info/docs/compara/analyses.html#conservation">$n_species way whole-genome multiple alignments</a>. } . 
                                      join('; ', sort map { $self->species_defs->species_label($_, 'no_formatting') } grep { $_ ne 'ancestral_sequences' } keys %{$row->{'species'}}),
        colourset                  => 'multiple',
        order                      => sprintf('%12d::%s::%s', 1e12-$n_species*10-1, $row->{'type'}, $row->{'name'}),
        strand                     => 'f',
        display                    => 'off', ## Default to on at the moment - change to off by default!
        renderers                  => [qw( off Off compact Normal )],
      };
    } 
  }
  
  foreach my $menu_key (keys %$alignments) {
    my $menu = $self->get_node($menu_key);
    next unless $menu;
    
    foreach my $key_2 (sort { $alignments->{$menu_key}{$a}{'order'} cmp  $alignments->{$menu_key}{$b}{'order'} } keys %{$alignments->{$menu_key}}) {
      my $row = $alignments->{$menu_key}{$key_2};
      $menu->append($self->create_track('alignment_' . $key . '_' . $key_2, $row->{'caption'}, $row));
    }
  }
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

sub create_track {
  my ($self, $code, $caption, $options) = @_;
  
  my $details = { 
    name      => $caption,
    node_type => 'track',
    %{$options||{}}
  };
  
  $details->{'strand'}    ||= 'b';      # Make sure we have a strand setting
  $details->{'display'}   ||= 'normal'; # Show unless we explicitly say no
  $details->{'renderers'} ||= [qw(off Off normal Normal)];
  $details->{'colours'}   ||= $self->species_defs->colour($options->{'colourset'}) if exists $options->{'colourset'};
  $details->{'glyphset'}  ||= $code;
  $details->{'caption'}   ||= $caption;
  
  return $self->tree->create_node($code, $details);
}

sub add_track {
  my ($self, $menu_key, $key, $caption, $glyphset, $params) = @_;
  my $menu = $self->get_node($menu_key);
  
  return unless $menu;
  return if $self->get_node($key); # Don't add duplicates
  
  $params->{'glyphset'} = $glyphset;
  $menu->append($self->create_track($key, $caption, $params));
}

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

#----------------------------------------------------------------------#
# Functions to add tracks from functional genomics like database....
#----------------------------------------------------------------------#

# needs configuring so tracks only display if data in species fg_database
sub add_regulation_feature {
  my ($self, $key, $hashref, $species) = @_;  
  my $menu = $self->get_node('functional');
  
  return unless $menu;

  my $results           = $hashref->{'result_set'};
  my $features          = $hashref->{'feature_set'};
  my %funcgen           = (%$results, %$features);
  my ($keys, $data)     = $self->_merge($features);
  my ($keys_a, $data_a) = $self->_merge($results);
  my @all_keys          = (@$keys, @$keys_a);
  my %all_data          = (%$data, %$data_a);
  my $fg_data           = \%all_data;
  
  foreach my $key_2 (sort @all_keys) { 
    my $k = $fg_data->{$key_2}{'type'} || 'other';    
    next if $k eq 'other' || $k eq 'ctcf' || $k =~/histone/;
    
    my $render      = [ 'off' => 'Off', 'normal' => 'Normal' ];
    my $legend_flag = 0; 
    my $cisred_flag = 0;

    if ($fg_data->{$key_2}{'renderers'}) {
      my %renderers = %{$fg_data->{$key_2}{'renderers'}};
      my @temp;
      
      foreach (sort keys %renderers){      
        my $value = $renderers{$_};          
        push @temp, $_ => $value; 
      }
      
      $render = \@temp;
    }
    
    $legend_flag = 1 if $k =~/fg_reg/;
    $cisred_flag = 1 if $fg_data->{$key_2}{'description'} =~ /cisRED/;
  
    if ($key_2 =~/reg_feats/){
      my @cell_lines = sort keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
      # Add MultiCell first
      unshift @cell_lines, 'AAAMultiCell';   
      my $multi_flag;

      foreach my $cell_line (sort  @cell_lines){ 
        $cell_line =~s/AAA|\:\w*//g;
        return if $cell_line eq 'MultiCell' && $multi_flag;

        my $track_key = $key_2. '_' .$cell_line;  
        my $display = 'off';
        my $name = $fg_data->{$key_2}{'name'} .' '. $cell_line;
        if ($cell_line =~/MultiCell/){  
          $display = $fg_data->{$key_2}{'display'} || 'off';
          $name = $fg_data->{$key_2}{'name'}; 
          $multi_flag =1;
        }
        my $cell_line_menu = $self->create_submenu('regulatory_features' .$cell_line, $cell_line .' tracks', {submenu => 1} );
        $cell_line_menu->append($self->create_track($track_key, $name || $fg_data->{$key_2}{'logic_names'}, {
          db          => $key,
          glyphset    => $k,
          sources     => 'undef',
          strand      => 'r',
          depth       => $fg_data->{$key_2}{'depth'} || 0.5,
          colourset   => $fg_data->{$key_2}{'colourset'} || $k,
          description => $fg_data->{$key_2}{'description'},
          display     => $display,
          renderers   => $render,
          cell_line   => $cell_line
        }));
    

        ### Add tracks for cell_line peaks and wiggles only if we have data to display!
        my %focus_set_ids     = %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'meta'}{'focus_feature_set_ids'} || {}};
        my %feature_type_ids  = %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'meta'}{'feature_type_ids'} || {}};
        my @ftypes = keys %{$feature_type_ids{$cell_line}};  
        my @focus_sets = keys %{$focus_set_ids{$cell_line}};  
        my $config_link = ', use the "Configure Cell/Tissue" tab to select features sets to display.';
        
        if ( scalar @focus_sets <= scalar @ftypes) { 
          # Add Core evidence tracks 
          $cell_line_menu->append($self->create_track($key_2."_core_".$cell_line, "Core evidence " .$cell_line . $config_link, {
            db          => $key,
            glyphset    => 'fg_multi_wiggle',
            strand      => 'r',
            depth       => $fg_data->{$key_2}{'depth'} || 0.5,
            colourset   => 'feature_set',
            description => $fg_data->{$key_2}{'description'},
            display     => 'off',
            menu        => 'no',
            renderers   => [ 'off' => 'Off', 'compact' => 'Peaks', 'tiling' => 'Wiggle plot', 'tiling_feature' => 'Both'  ],         
            cell_line   => $cell_line, 
            type        => 'core',
          }));
        } 
 
        if (scalar @ftypes != scalar @focus_sets  && $cell_line ne 'MultiCell'){ 
          # Add 'Other' evidence tracks
          $cell_line_menu->append($self->create_track($key_2."_other_".$cell_line, "Other evidence " .$cell_line . $config_link, {
            db          => $key,
            glyphset    => 'fg_multi_wiggle',    
            strand      => 'r',
            depth       => $fg_data->{$key_2}{'depth'} || 0.5,
            colourset   => 'feature_set',
            description => $fg_data->{$key_2}{'description'},
            display     => 'off',
            menu        => 'no',
            renderers   => [ 'off' => 'Off', 'compact' => 'Peaks', 'tiling' => 'Wiggle plot', 'tiling_feature' => 'Both' ],
            cell_line   => $cell_line,
            type        => 'other',
          })); 
        }
        $menu->append($cell_line_menu);
      } 
    } else {
      $menu->append($self->create_track($k . '_' . $key . '_' . $key_2, $fg_data->{$key_2}{'name'} || $fg_data->{$key_2}{'logic_names'}, { 
        db          => $key,
        glyphset    => $k,
        sources     => 'undef',
        strand      => 'r',
        labels      => 'on',
        depth       => $fg_data->{$key_2}{'depth'} || 0.5,
        colourset   => $fg_data->{$key_2}{'colourset'} || $k,
        description => $fg_data->{$key_2}{'description'},
        display     => $fg_data->{$key_2}{'display'} || 'off', 
        renderers   => $render, 
      }));
    } 
=cut    
    if ($wiggle_flag) {
      $menu->append($self->create_track($k . '_' . $key .  '_blocks_' . $key_2, ($fg_data->{$key_2}{'name'} || $fg_data->{$key_2}{'logic_names'}) . ' peaks', {
        db          => $key,
        glyphset    => $k,
        sources     => 'undef',
        strand      => 'r',
        labels      => 'on',
        depth       => $fg_data->{$key_2}{'depth'} || 0.5,
        colourset   => $fg_data->{$key_2}{'colourset'} || $k,
        description => $fg_data->{$key_2}{'description'},
        display     => $fg_data->{$key_2}{'display'} || 'off',
        renderers   => [ 'off' => 'Off', 'compact' => 'Normal' ],
      }));
    }
=cut    
    $self->add_track('information', 'fg_regulatory_features_legend', 'Reg. Features Legend', 'fg_regulatory_features_legend', { colourset => 'fg_regulatory_features', strand => 'r' }) if $legend_flag;
    
    if ($cisred_flag) {
      $menu->append($self->create_track($k . '_' . $key . '_search', 'cisRED Search Regions', {
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
# Functions to add tracks from variation like databases....
#----------------------------------------------------------------------#

sub add_variation_feature {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('variation');
  
  return unless $menu && $hashref->{'variation_feature'}{'rows'} > 0;
  my ($somatic_flag, $somatic_mutations);    

  my $sequence_variation = $self->create_submenu('sequence_variations', 'Sequence variants', { submenu => 1 });
  
  $sequence_variation->append($self->create_track("variation_feature_$key", 'Sequence variants (all sources)', {
    db          => $key,
    glyphset    => '_variation',
    sources     => undef,
    strand      => 'r',
    depth       => 0.5,
    bump_width  => 0,
    colourset   => 'variation',
    description => 'Sequence variants from all sources',
    display     => 'off'
  }));
  
  foreach my $key_2 (sort keys %{$hashref->{'source'}{'counts'}||{}}) {
   next unless $hashref->{'source'}{'counts'}{$key_2} > 0;
    my $description = $hashref->{'source'}{'descriptions'}{$key_2}; 
    (my $k = $key_2) =~ s/\W/_/g;

    # Submenu for somatic mutations
    if ( $key_2 eq 'COSMIC'){
      $somatic_mutations = $self->create_submenu('somatic_mutations', 'Somatic mutations', { submenu => 1 });
      $somatic_mutations->append($self->create_track('somatic_mutation_' . $k, "$key_2 somatic mutations (all)", {
        db          => $key,
        glyphset    => '_variation',
        caption     => $key_2,
        strand      => 'r',
        depth       => 0.5,
        bump_width  => 0,
        colourset   => 'variation',
        description => $description,
        display     => 'off'
      }));
      $somatic_flag = 1;
      
      ## Add tracks for each tumour site
      my %tumour_sites = %{$self->species_defs->databases->{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'}{$key_2} || {}}; 
      foreach my $description (sort  keys %tumour_sites){
        my $phenotype_id = $tumour_sites{$description}; 
        my ($source, $type, $site ) = split(/\:/, $description);
        my $formatted_site = $site;
        $formatted_site   =~s/\_/ /g;      
        $somatic_mutations->append($self->create_track('somatic_mutation_' . $k .'_'. $site, "$key_2 somatic mutations in $formatted_site", {
          db          => $key,
          glyphset    => '_variation',
          caption     => $key_2 .' '. $site .' tumours',
          filter      => $phenotype_id,
          strand      => 'r',
          depth       => 0.5,
          bump_width  => 0,
          colourset   => 'variation',
          description => $description,
          display     => 'off',
          class       => 'level2'
        }));
         
      }
    } else {     
      $sequence_variation->append($self->create_track('variation_feature_' . $key . '_' . $k, "$key_2 variations", {
        db          => $key,
        glyphset    => '_variation',
        caption     => $key_2,
        sources     => [ $key_2 ],
        strand      => 'r',
        depth       => 0.5,
        bump_width  => 0,
        colourset   => 'variation',
        description => $description,
        display     => 'off'
      }));
    }
  }
 
  # add in read coverage wiggle plots  
  foreach my $strain_info (split /,/, $hashref->{'read_coverage_collection_strains'}) {
    my ($strain_name, $sample_id) =  split /_/, $strain_info;
    
    $sequence_variation->append($self->create_track('read_wiggle_' . $key . '_' . $strain_name, "RC $strain_name", {
      db          => $key,
      sources     => undef,
      strand      => 'r',
      labels      => 'on',
      colourset   => 'read_coverage',
      height      =>  6,
      description => 'Read Coverage for '. $strain_name,
      display     => 'off'
    }));
  }
  
  $menu->append($sequence_variation);
  if ($somatic_flag) {$menu->append($somatic_mutations)} 

  $self->add_track('information', 'variation_legend', 'Variation Legend', 'variation_legend', { strand => 'r' });

  # add in variation sets
  if ($hashref->{'variation_set'}{'rows'} > 0){
    foreach my $toplevel_set (sort values %{$hashref->{'variation_set'}{'supersets'}}){
      my $name = $toplevel_set->{'name'};
      my $description = $toplevel_set->{'description'};

      my $set_variation = $self->create_submenu('set_variation_'.$name, $name, { submenu => 1 });
      $set_variation->append($self->create_track('variation_set_'.$name, $name, 
      {   
        db          => $key,
        glyphset    => '_variation',
        caption     => $name,
        sources     => undef,
        sets        => [ $name ],
        strand      => 'r', 
        depth       => 0.5,
        bump_width  => 0,
        colourset   => 'variation',
        description => $description,
        display     => 'off',
      }));
      $menu->append($set_variation);
  
      # add in sub sets
      my @sub_sets = @{$toplevel_set->{'subsets'}};
      foreach my $subset_id (sort @sub_sets){
        my $sub_set_name = $hashref->{'variation_set'}{'subsets'}{$subset_id}{'name'}; 
        my $sub_set_description = $hashref->{'variation_set'}{'subsets'}{$subset_id}{'description'};
        $set_variation->append($self->create_track('variation_set_'.$name.'_'.$sub_set_name, $sub_set_name,
        {
          db          => $key,
          glyphset    => '_variation',
          caption     => $sub_set_name,
          sources     => undef,
          sets        => [ $sub_set_name ],
          strand      => 'r',
          depth       => 0.5,
          bump_width  => 0,
          colourset   => 'variation',
          description => $sub_set_description,
          display     => 'off',
          class       => 'level2',
        }));
      }
    }
  }
  
  # add in structural variations
  return unless $hashref->{'structural_variation'}{'rows'} > 0;
  
  my $structural_variation = $self->create_submenu('structural_variation', 'Structural variants', { submenu => 1 });
  
  $structural_variation->append($self->create_track('variation_feature_structural', 'Structural variants (all sources)', {   
    db          => $key,
    glyphset    => 'structural_variation',
    caption     => 'All Structural variants',
    sources     => undef,
    strand      => 'r', 
    depth       => 0.5,
    bump_width  => 0,
    colourset   => 'structural_variant',
    description => 'Structural variants from all sources',
    display     => 'off',
  }));
  
  foreach my $key_2 (sort keys %{$hashref->{'structural_variation'}{'counts'}||{}}) {
    my $description = $hashref->{'source'}{'descriptions'}{$key_2};
    
    $structural_variation->append($self->create_track("variation_feature_structural_$key_2", "$key_2 structural variations", {
      db          => $key,
      glyphset    => 'structural_variation',
      caption     => $key_2,
      sources     => [ $key_2 ],
      strand      => 'r',
      depth       => 0.5,
      bump_width  => 0,
      colourset   => 'structural_variant',
      description => $description,
      display     => 'off',
    }));  
  }
  
  $menu->append($structural_variation);
}

# return a list of glyphsets
sub glyphset_configs {
  my $self = shift;
  return grep { $_->data->{'node_type'} eq 'track' } $self->tree->nodes;
}

sub get_node {
  my $self = shift;
  return $self->tree->get_node(@_);
}

sub create_submenu {
  my ($self, $code, $caption, $options) = @_;
  
  my $details = {
    caption   => $caption, 
    node_type => 'menu',
    %{$options||{}}
  };
  
  return $self->tree->create_node($code, $details);
}


sub create_option {
  my ($self, $code, $caption, $values, $renderers, $display) = @_;
  
  $values    ||= {qw(off 0 normal 1)};
  $renderers ||= [qw(off Off normal On)];
  
  return $self->tree->create_node($code, {
    node_type => 'option',
    caption   => $caption,
    name      => $caption,
    values    => $values,
    renderers => $renderers,
    display   => $display || 'normal'
  });
}

sub get_option {
  my ($self, $code, $key) = @_;
  my $node = $self->get_node($code);
  return $node ? $node->get($key || 'values')->{$node->get('display')} : 0;
}

sub get_user_settings {
  my $self = shift;
  return $self->tree->user_data;
}

sub artefacts { 
  my $self = shift; 
  return @{$self->{'general'}->{$self->{'type'}}->{'_artefacts'}||[]} 
};

sub remove_artefacts {
  my $self = shift;
  my %artefacts = map {( $_, 1 )} @_;
  @{$self->{'general'}->{$self->{'type'}}->{'_artefacts'}} =  grep !$artefacts{$_}, $self->subsections;
}
  
sub add_artefacts {
  my $self = shift;
  $self->_set($_, 'on', 'on') foreach @_;
  push @{$self->{'general'}->{$self->{'type'}}->{'_artefacts'}}, @_;
}

# add general and artefact settings
sub add_settings {
  my $self = shift;
  my $settings = shift;
  $self->{'general'}->{$self->{'type'}}->{$_} = $settings->{$_} for keys %{$settings};
}

sub _set {
  my ($self, $entry, $key, $value) = @_;
  $self->{'general'}->{$self->{'type'}}->{$entry}->{$key} = $value;
}

sub save {
  my ($self) = @_;
  warn "ImageConfig->save - Deprecated call now handled by session";
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

sub subsections {
  my ($self, $flag) = @_;
  my @keys;
  @keys = grep { /^managed_/ } keys %{$self->{'user'}} if $flag == 1;
  return @{$self->{'general'}->{$self->{'type'}}->{'_artefacts'}}, @keys;
}

sub image_height {
  my $self = shift;
  $self->set_parameter('_height', shift) if @_;
  return $self->get_parameter('_height');
}

sub scalex {
  my $self = shift;
  
  if (@_) {
    $self->{'_scalex'} = shift;
    $self->{'_texthelper'}->scalex($self->{'_scalex'});
  }
  
  return $self->{'_scalex'};
}

sub set_width {
  my ($self, $val) = @_;
  $self->set_parameter('width', $val);
}

1;
