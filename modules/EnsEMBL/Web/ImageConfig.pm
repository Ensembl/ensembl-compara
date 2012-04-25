# $Id$

package EnsEMBL::Web::ImageConfig;

use strict;

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use JSON qw(from_json);
use URI::Escape qw(uri_unescape);

use Bio::EnsEMBL::ExternalData::DAS::Coordinator;

use Sanger::Graphics::TextHelper;

use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Tree;

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
  my $code    = shift;
  my $type    = $class =~ /([^:]+)$/ ? $1 : $class;
  my $style   = $hub->species_defs->ENSEMBL_STYLE || {};
  my $cache   = $hub->cache;
  
  my $self = {
    hub              => $hub,
    _font_face       => $style->{'GRAPHIC_FONT'} || 'Arial',
    _font_size       => ($style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'}) || 20,
    _texthelper      => new Sanger::Graphics::TextHelper,
    code             => $code,
    type             => $type,
    species          => $species,
    _useradded       => {}, # contains list of added features
    _r               => undef,
    no_load          => undef,
    storable         => 1,
    altered          => 0,
    has_das          => 1,
    _core            => undef,
    _tree            => new EnsEMBL::Web::Tree,
    transcript_types => [qw(transcript alignslice_transcript tsv_transcript gsv_transcript TSE_transcript)],
    _parameters      => { # Default parameters
      image_width => $ENV{'ENSEMBL_IMAGE_WIDTH'} || 800,
      margin       => 5,
      spacing      => 2,
      label_width  => 113,
      show_labels  => 'yes',
      slice_number => '1|1'
    },
    extra_menus      => {
      active_tracks    => 1,
      favourite_tracks => 1,
      search_results   => 1,
      display_options  => 1
    },
    unsortable_menus => {
      decorations => 1,
      information => 1,
      options     => 1,
      other       => 1
    },
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
  
  # Check memcached for defaults
  if (my $defaults = $cache ? $cache->get("::${class}::${species}::$code") : undef) {
    $self->{$_} = $defaults->{$_} for keys %$defaults;
  } else {
    # No cached defaults found, so initialize them and cache
    $self->init;
    $self->modify;
    
    if ($cache) {
      my $defaults = {
        _tree       => $self->{'_tree'},
        _parameters => $self->{'_parameters'},
        extra_menus => $self->{'extra_menus'},
      };
      
      $cache->set("::${class}::${species}::$code", $defaults, undef, 'IMAGE_CONFIG', $species);
    }
  }
  
  my $sortable = $self->get_parameter('sortable_tracks');
  
  $self->set_parameter('sortable_tracks', 1)  if $sortable eq 'drag' && $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d+)/ && $1 < 7; # No sortable tracks on images for IE6 and lower
  $self->{'extra_menus'}->{'track_order'} = 1 if $sortable;
  
  $self->{'no_image_frame'} = 1;
  
  # Add user defined data sources
  $self->load_user_tracks;
  
  # Combine info and decorations into a single menu
  my $decorations = $self->get_node('decorations') || $self->get_node('other');
  my $information = $self->get_node('information');
  
  if ($decorations && $information) {
    $decorations->set('caption', 'Information and decorations');
    $decorations->append_children($information->nodes);
  }
  
  return $self;
}

sub menus {
  return $_[0]->{'menus'} ||= {
    # Sequence
    seq_assembly        => 'Sequence and assembly',
    sequence            => [ 'Sequence',               'seq_assembly' ],
    misc_feature        => [ 'Misc. regions & clones', 'seq_assembly' ],
    marker              => [ 'Markers',                'seq_assembly' ],
    simple              => [ 'Simple features',        'seq_assembly' ],
    ditag               => [ 'Ditag features',         'seq_assembly' ],
    
    # Transcripts/Genes
    gene_transcript     => 'Genes and transcripts',
    transcript          => [ 'Genes',                  'gene_transcript' ],
    prediction          => [ 'Prediction transcripts', 'gene_transcript' ],
    lrg                 => [ 'LRG transcripts',        'gene_transcript' ],
    rnaseq              => [ 'RNA-Seq models',         'gene_transcript' ],
    
    # Supporting evidence
    splice_sites        => 'Splice sites',
    evidence            => 'Evidence',
    
    # Alignments
    mrna_prot           => 'mRNA and protein alignments',
    dna_align_cdna      => [ 'mRNA alignments',    'mrna_prot' ],
    dna_align_est       => [ 'EST alignments',     'mrna_prot' ],
    protein_align       => [ 'Protein alignments', 'mrna_prot' ],
    protein_feature     => [ 'Protein features',   'mrna_prot' ],
    dna_align_other     => 'Other DNA alignments',
    dna_align_rna       => 'ncRNA',
    
    # Proteins
    domain              => 'Protein domains',
    gsv_domain          => 'Protein domains',
    feature             => 'Protein features',
    
    # Variations
    variation           => 'Germline variation',
    somatic             => 'Somatic mutations',
    ld_population       => 'Population features',
    
    # Regulation
    functional          => 'Regulation',
    
    # Encode (data hub)
    encode              => 'ENCODE data',
    
    # Compara
    compara             => 'Comparative genomics',
    pairwise_blastz     => [ 'BLASTz/LASTz alignments',    'compara' ],
    pairwise_other      => [ 'Pairwise alignment',         'compara' ],
    pairwise_tblat      => [ 'Translated blat alignments', 'compara' ],
    multiple_align      => [ 'Multiple alignments',        'compara' ],
    conservation        => [ 'Conservation regions',       'compara' ],
    synteny             => 'Synteny',
    
    # Other features
    repeat              => 'Repeat regions',
    oligo               => 'Oligo probes',
    trans_associated    => 'Transcript features',
    
    # Info/decorations
    information         => 'Information',
    decorations         => 'Additional decorations',
    other               => 'Additional decorations',
    
    # External data
    user_data           => 'Your data',
    external_data       => 'External data',
  };
}

sub init   {}
sub modify {} # For plugins

sub storable :lvalue { $_[0]->{'storable'}; } # Set to 1 if configuration can be altered
sub altered  :lvalue { $_[0]->{'altered'};  } # Set to 1 if the configuration has been updated
sub has_das  :lvalue { $_[0]->{'has_das'};  } # Set to 1 if there are DAS tracks

sub hub                 { return $_[0]->{'hub'};                                                                     }
sub code                { return $_[0]->{'code'};                                                                    }
sub core_objects        { return $_[0]->hub->core_objects;                                                           }
sub colourmap           { return $_[0]->hub->colourmap;                                                              }
sub species_defs        { return $_[0]->hub->species_defs;                                                           }
sub sd_call             { return $_[0]->species_defs->get_config($_[0]->{'species'}, $_[1]);                         }
sub databases           { return $_[0]->sd_call('databases');                                                        }
sub texthelper          { return $_[0]->{'_texthelper'};                                                             }
sub transform           { return $_[0]->{'transform'};                                                               }
sub tree                { return $_[0]->{'_tree'};                                                                   }
sub species             { return $_[0]->{'species'};                                                                 }
sub multi_species       { return 0;                                                                                  }
sub bgcolor             { return $_[0]->get_parameter('bgcolor') || 'background1';                                   }
sub bgcolour            { return $_[0]->bgcolor;                                                                     }
sub get_node            { return shift->tree->get_node(@_);                                                          }
sub get_user_settings   { return $_[0]->tree->user_data;                                                             }
sub get_parameters      { return $_[0]->{'_parameters'};                                                             }
sub get_parameter       { return $_[0]->{'_parameters'}{$_[1]};                                                      }
sub set_width           { $_[0]->set_parameter('width', $_[1]);                                                      } # TODO: find out why we have width and image_width. delete?
sub image_height        { return shift->parameter('image_height',    @_);                                            }
sub image_width         { return shift->parameter('image_width',     @_);                                            }
sub container_width     { return shift->parameter('container_width', @_);                                            }
sub slice_number        { return shift->parameter('slice_number',    @_);                                            } # TODO: delete?
sub get_tracks          { return grep { $_->{'data'}{'node_type'} eq 'track' } $_[0]->tree->nodes;                   } # return a list of track nodes
sub get_sortable_tracks { return grep { $_->get('sortable') && $_->get('menu') ne 'no' } @{$_[0]->glyphset_configs}; }

sub glyphset_configs {
  my $self = shift;
  
  if (!$self->{'ordered_tracks'}) {
    my @tracks      = $self->get_tracks;
    my $track_order = $self->track_order;
    my $i           = 1;
    my @default_order;
    
    foreach my $track (@tracks) {
      my $strand = $track->get('strand');
      
      if ($strand =~ /^[rf]$/) {
        if ($strand eq 'f') {
          unshift @default_order, $track;
        } else {
          push @default_order, $track;
        }
      } else {
        my $clone = $self->tree->create_node($track->id . '_tmp'); # Id is replaced in the for loop below
        $clone->{$_} = $_ eq 'data' ? { %{$track->{'data'}} } : $track->{$_} for keys %$track; # Make a new hash for data, so that drawing_strand can differ
        
        $clone->set('drawing_strand', 'f');
        $track->set('drawing_strand', 'r');
        
        unshift @default_order, $clone;
        push    @default_order, $track;
      }
    }
    
    if ($self->get_parameter('sortable_tracks')) {
      $_->set('sortable', 1) for grep !$self->{'unsortable_menus'}->{$_->parent_key}, @default_order;
    }
    
    my @ordered_tracks;
    my %order     = map { join('.', grep $_, $_->id, $_->get('drawing_strand')) => [ $i++, $_ ] } @default_order;
    $order{$_}[0] = $track_order->{$_} for grep $order{$_}, keys %$track_order;
    
    foreach (sort { $a->[0] <=> $b->[0] } values %order) {
      $_->[1]->set('order', $_->[0]);
      push @ordered_tracks, $_->[1];
    }
    
    $self->{'ordered_tracks'} = \@ordered_tracks;
  }
  
  return $self->{'ordered_tracks'};
}

sub get_favourite_tracks {
  my $self = shift;
  
  if (!$self->{'favourite_tracks'}) {
    my $hub  = $self->hub;
    my $user = $hub->user;
    my $data = $hub->session->get_data(type => 'favourite_tracks', code => 'favourite_tracks') || {};
    
    $self->{'favourite_tracks'} = $data->{'tracks'} || {};
    $self->{'favourite_tracks'} = { %{$self->{'favourite_tracks'}}, %{$user->get_favourite_tracks} } if $user;
  }
  
  return $self->{'favourite_tracks'};
}

sub track_order {
  my $self = shift;
  my $node = $self->get_node('track_order');
  return $node ? $node->get($self->species) || {} : {};
}

sub set_user_settings {
  my ($self, $data) = @_;
  
  foreach my $key (keys %$data) {
    my $node = $self->get_node($key);
    
    next unless $node;
    
    my $renderers = $node->data->{'renderers'};
    my %valid     = @$renderers;
    
    foreach (keys %{$data->{$key}}) {
      if ($_ eq 'display' && !$valid{$data->{$key}{$_}}) {
        $node->set_user($_, $valid{'normal'} ? 'normal' : $renderers->[2]); # index 2 contains the code for the first "on" renderer
      } else {
        $node->set_user($_, $data->{$key}{$_});
      }
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
    $node->remove;
    $self->remove_disabled_menus($parent) if $parent && !scalar @{$parent->child_nodes};
  }
}

# create_menus - takes an array to configure the menus to be seen on the display
sub create_menus {
  my $self = shift;
  my $tree = $self->tree;
  
  foreach (@_) {
    my $menu = $self->menus->{$_};
    
    if (ref $menu) {
      my $parent = $tree->get_node($menu->[1]) || $tree->append_child($self->create_submenu($menu->[1], $self->menus->{$menu->[1]}));
      $parent->append_child($self->create_submenu($_, $menu->[0]));
    } else {
      $tree->append_child($self->create_submenu($_, $menu));
    }
  }
}

sub create_submenu {
  my ($self, $code, $caption, $options) = @_;
  
  my $details = {
    caption    => $caption, 
    node_type  => 'menu',
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
  $details->{'renderers'} ||= [qw(off Off normal On)];
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
    $menu->append($self->create_track($key, $caption, $params));
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

sub load_user_tracks {
  my $self = shift;
  my $menu = $self->get_node('user_data');
  
  return unless $menu;
  
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $user    = $hub->user;
  my $das     = $hub->get_all_das;
  my (%url_sources, %upload_sources);
  
  foreach my $source (sort { ($a->caption || $a->label) cmp ($b->caption || $b->label) } values %$das) {
    next if     $self->get_node('das_' . $source->logic_name);
    next unless $source->is_on($self->{'type'});
    
    $self->add_das_tracks('user_data', $source);
  }

  # Get the tracks that are temporarily stored - as "files" not in the DB....
  # Firstly "upload data" not yet committed to the database...
  # Then those attached as URLs to either the session or the User
  # Now we deal with the url sources... again flat file
  foreach my $entry ($session->get_data(type => 'url')) {
    next unless $entry->{'species'} eq $self->{'species'};

    $url_sources{"url_$entry->{'code'}"} = {
      source_type => 'session',
      source_name => $entry->{'name'} || $entry->{'url'},
      source_url  => $entry->{'url'},
      species     => $entry->{'species'},
      format      => $entry->{'format'},
      style       => $entry->{'style'},
      colour      => $entry->{'colour'},
      display     => $entry->{'display'},
      timestamp   => $entry->{'timestamp'} || time,
    };
  }
  
  foreach my $entry ($session->get_data(type => 'upload')) {
    next unless $entry->{'species'} eq $self->{'species'};
   
    if ($entry->{'analyses'}) {
      foreach my $analysis (split /, /, $entry->{'analyses'}) {
        $upload_sources{$analysis} = {
          source_name => $entry->{'name'},
          source_type => 'session',
          assembly    => $entry->{'assembly'},
        };
        
        $self->_compare_assemblies($entry, $session);
      }
    } elsif ($entry->{'species'} eq $self->{'species'} && !$entry->{'nonpositional'}) {
      my ($strand, $renderers) = $self->_user_track_settings($entry->{'style'});
      $strand = $entry->{'strand'} if $entry->{'strand'};
      
      $menu->append($self->create_track("upload_$entry->{'code'}", $entry->{'name'}, {
        external    => 'tmp',
        glyphset    => '_flat_file',
        colourset   => 'classes',
        sub_type    => 'tmp',
        file        => $entry->{'filename'},
        format      => $entry->{'format'},
        caption     => $entry->{'name'},
        renderers   => $renderers,
        description => 'Data that has been temporarily uploaded to the web server.',
        display     => 'off',
        strand      => $strand,
      }));
    }
  }
  
  if ($user) {
    my @groups  = $user->groups;
    
    foreach my $entry (grep $_->species eq $self->{'species'}, map $_->urls, $user, @groups) {
      $url_sources{'url_' . $entry->code} = {
        source_name => $entry->name || $entry->url,
        source_type => 'user', 
        source_url  => $entry->url,
        species     => $entry->species,
        format      => $entry->format,
        style       => $entry->style,
        colour      => $entry->colour,
        display     => 'off',
        timestamp   => $entry->timestamp,
      };
    }
    
    foreach my $entry (grep $_->species eq $self->{'species'}, map $_->uploads, $user, @groups) {
      my ($name, $assembly) = ($entry->name, $entry->assembly);
      
      foreach my $analysis (split /, /, $entry->analyses) {
        $upload_sources{$analysis} = {
          source_name => $name,
          source_type => 'user',
          assembly    => $assembly,
        };
        
        $self->_compare_assemblies($entry, $session);
      }
    }
  }

  foreach my $code (sort { $url_sources{$a}{'source_name'} cmp $url_sources{$b}{'source_name'} } keys %url_sources) {
    my $add_method = lc "_add_$url_sources{$code}{'format'}_track";
    
    if ($self->can($add_method)) {
      $self->$add_method(key => $code, menu => $menu, source => $url_sources{$code});
    } else {
      $self->_add_flat_file_track($menu, 'url', $code, $url_sources{$code}{'source_name'},
        sprintf('
          Data retrieved from an external webserver. This data is attached to the %s, and comes from URL: %s',
          encode_entities($url_sources{$code}{'source_type'}), encode_entities($url_sources{$code}{'source_url'})
        ),
        url    => $url_sources{$code}{'source_url'},
        format => $url_sources{$code}{'format'},
        style  => $url_sources{$code}{'style'},
      );
    }
  }
  
  # We now need to get a userdata adaptor to get the analysis info
  if (keys %upload_sources) {
    my $dbs        = new EnsEMBL::Web::DBSQL::DBConnection($self->{'species'});
    my $dba        = $dbs->get_DBAdaptor('userdata');
    my $an_adaptor = $dba->get_adaptor('Analysis');
    my @tracks;
    
    foreach my $logic_name (keys %upload_sources) {
      my $analysis = $an_adaptor->fetch_by_logic_name($logic_name);
      
      next unless $analysis;
      
      my ($strand, $renderers) = $self->_user_track_settings($analysis->program_version);
      $strand = $upload_sources{$logic_name}{'strand'} if $upload_sources{$logic_name}{'strand'};
      my $external    = $upload_sources{$logic_name}{'source_type'} eq 'user' ? 'user' : 'tmp';
      my $source_name = encode_entities($upload_sources{$logic_name}{'source_name'});
      my $description = encode_entities($analysis->description) || "User data from dataset $source_name";
      my $caption     = encode_entities($analysis->display_label);
         $caption     = "$source_name: $caption" unless $caption eq $upload_sources{$logic_name}{'source_name'};
      
      push @tracks, [ $logic_name, $caption, {
        external    => $external,
        glyphset    => '_user_data',
        colourset   => 'classes',
        sub_type    => $external,
        renderers   => $renderers,
        source_name => $source_name,
        logic_name  => $logic_name,
        caption     => $caption,
        data_type   => $analysis->module,
        description => $description,
        display     => 'off',
        style       => $analysis->web_data,
        format      => $analysis->program_version,
        strand      => $strand,
      }];
    }
   
    $menu->append($self->create_track(@$_)) for sort { lc($a->[2]{'source_name'}) cmp lc($b->[2]{'source_name'}) || lc($a->[1]) cmp lc($b->[1]) } @tracks;
  }
  
  $ENV{'CACHE_TAGS'}{'user_data'} = sprintf 'USER_DATA[%s]', md5_hex(join '|', map $_->id, $menu->nodes) if $menu->has_child_nodes;
}

sub load_configured_bam    { shift->load_file_format('bam');    }
sub load_configured_bigbed { shift->load_file_format('bigbed'); }
sub load_configured_bigwig { shift->load_file_format('bigwig'); }
sub load_configured_vcf    { shift->load_file_format('vcf');    }

sub load_file_format {
  my ($self, $format)  = @_;
  my $internal_sources = $self->sd_call(sprintf 'ENSEMBL_INTERNAL_%s_SOURCES', uc $format) || {}; # get the internal sources from config
  my $function         = "_add_${format}_track";

  foreach my $source_name (sort keys %$internal_sources) {
    # get the target menu 
    my $menu = $self->get_node($internal_sources->{$source_name});
    my ($source, $view);
    
    if ($menu) {
      $source = $self->sd_call($source_name);
    } else {
      ## Probably an external datahub source
      $source           = $internal_sources->{$source_name};
      $view             = $source->{'view'},
      my $menu_key      = $source->{'menu_key'};
      my $menu_name     = $source->{'menu_name'};
      my $submenu_key   = $source->{'submenu_key'};
      my $submenu_name  = $source->{'submenu_name'};
      my $main_menu     = $self->get_node($menu_key)    || $self->tree->prepend_child($self->create_submenu($menu_key, $menu_name));
         $menu          = $self->get_node($submenu_key) || $main_menu->append_child($self->create_submenu($submenu_key, $submenu_name));
    }
    
    $self->$function(key => $source_name, menu => $menu, source => $source, description => $source->{'description'}, internal => 1, view => $view) if $source;
  }
}

sub _add_bam_track {
  my $self = shift;
  my $desc = '
    The read end bars indicate the direction of the read and the colour indicates the type of read pair:
    Green = both mates mapped to the same chromosome, Blue = second mate was not mapped, Red = second mate mapped to a different chromosome.
  ';
  
  $self->_add_file_format_track(
    format      => 'BAM',
    description => $desc,
    renderers   => [
      'off',       'Off', 
      'normal',    'Normal', 
      'unlimited', 'Unlimited', 
      'histogram', 'Coverage only'
    ], 
    options => {
      external => 'url',
      sub_type => 'bam'
    },
    @_
  );
}

sub _add_bigbed_track {
  my ($self, %args) = @_;
 
  my $renderers = [
      'off',    'Off', 
      'normal', 'Normal', 
      'labels', 'Labels',
  ];
 
  my $options = {
      external => 'url',
      sub_type => 'url',
      colourset => 'feature',
  };

  if ($args{'view'} && $args{'view'} =~ /peaks/i) {
    $options->{'border'} = 'off';  
  }
  else {
    push @$renderers, ('tiling', 'Wiggle plot');
  } 

  $self->_add_file_format_track(
    format      => 'BigBed',
    description => 'Bigbed file',
    renderers   =>  $renderers,
    options     =>  $options,
    %args,
  );
}

sub _add_bigwig_track {
  my ($self, %args) = @_;
  
  $self->_add_file_format_track(
    format    => 'BigWig', 
    renderers =>  [
      'off',    'Off',
      'tiling', 'Wiggle plot',
    ], 
    options => {
      external => 'url',
      sub_type => 'bigwig',
      colour   => $args{'menu'}{'colour'} || $args{'source'}{'colour'} || 'red',
    },
    %args
  );
}

sub _add_vcf_track {
  shift->_add_file_format_track(
    format    => 'VCF', 
    renderers => [
      'off',       'Off',
      'histogram', 'Normal',
      'compact',   'Compact'
    ], 
    options => {
      external   => 'url',
      sources    => undef,
      depth      => 0.5,
      bump_width => 0,
      colourset  => 'variation'
    },
    @_
  );
}

sub _add_flat_file_track {
  my ($self, $menu, $sub_type, $key, $name, $description, %options) = @_;
  
  $menu ||= $self->get_node('user_data');
  
  return unless $menu;
 
  my ($strand, $renderers) = $self->_user_track_settings($options{'style'});

  my $track = $self->create_track($key, $name, {
    display     => 'off',
    strand      => $strand,
    external    => 'url',
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

sub _add_file_format_track {
  my ($self, %args) = @_;
  my $menu = $args{'menu'} || $self->get_node('user_data');
  
  return unless $menu;
  
  my $type    = lc $args{'format'};
  my $article = $args{'format'} =~ /^[aeiou]/ ? 'an' : 'a';
  my $desc;
  
  if ($args{'internal'}) {
    $desc = sprintf('Data served from a %s file: %s', $args{'format'}, $args{'description'});
  } else {
    $desc = sprintf(
      "Data retrieved from %s %s file on an external webserver. %s
      This data is attached to the %s, and comes from URL: %s",
      $article,
      $args{'format'},
      $args{'description'},
      encode_entities($args{'source'}{'source_type'}), 
      encode_entities($args{'source'}{'source_url'})
    );
  }
  my $track = $self->create_track($args{'key'}, $args{'source'}{'source_name'}, {
    display     => 'off',
    strand      => 'f',
    format      => $args{'format'},
    glyphset    => $type,
    colourset   => $type,
    renderers   => $args{'renderers'},
    caption     => $args{'source'}{'source_name'},
    url         => $args{'source'}{'source_url'},
    description => $desc,
    %{$args{'options'}}
  });
 
  $menu->append($track) if $track;
}

sub _user_track_settings {
  my ($self, $style) = @_;
  my ($strand, @user_renderers);
      
  if ($style =~ /^(wiggle|WIG)$/) {
    $strand         = 'r';
    @user_renderers = ( 'off', 'Off', 'tiling', 'Wiggle plot' );
  } else {
    $strand         = 'b'; 
    @user_renderers = @{$self->{'alignment_renderers'}};
  }
  
  return ($strand, \@user_renderers);
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

sub update_from_input {
  my $self  = shift;
  my $input = $self->hub->input;
  
  return $self->reset if $input->param('reset');
  
  my $diff   = $input->param('image_config');
  my $reload = 0;
  
  if ($diff) {
    my $track_reorder = 0;
    
    $diff = from_json($diff);
    
    $self->update_track_renderer($_, $diff->{$_}->{'renderer'}) for grep exists $diff->{$_}->{'renderer'}, keys %$diff;
    $reload        = $self->altered;
    $track_reorder = $self->update_track_order($diff) if $diff->{'track_order'};
    $reload      ||= $track_reorder;
    $self->update_favourite_tracks($diff);
  } else {
    my %favourites;
    
    foreach my $p ($input->param) {
      my $val = $input->param($p);
      
      if ($val =~ /favourite_(on|off)/) {
        $favourites{$p} = { favourite => $1 eq 'on' ? 1 : 0 };
      } else {
        $self->update_track_renderer($p, $val);
      }
    }
    
    $reload = $self->altered;
    
    $self->update_favourite_tracks(\%favourites) if scalar keys %favourites;
  }
  
  return $reload;
}

sub update_from_url {
## Tracks added "manually" in the URL (e.g. via a link)
  my ($self, @values) = @_;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $species = $hub->species;
  
  foreach my $v (@values) {
    my @split    = split /=/, $v;
    my ($key, $renderer);
    if (scalar(@split) > 1) { 
      ($key, $renderer) = @split;
    }
    else {
      $key = $split[0];
      $renderer = 'normal';
    }

    if ($key =~ /^(\w+)[\.:](.*)$/) {
      my ($type, $p) = ($1, $2);
      
      if ($type eq 'url') {
        my $format      = $hub->param('format');
        my $all_formats = $hub->species_defs->DATA_FORMAT_INFO;
        
        if (!$format) {
          $p = uri_unescape($p);
          
          my @path = split(/\./, $p);
          my $ext  = $path[-1] eq 'gz' ? $path[-2] : $path[-1];
          
          while (my ($name, $info) = each (%$all_formats)) {
            if ($ext =~ /^$name$/i) {
              $format = $name;
              last;
            }  
          }
        }

        my $style = $all_formats->{lc($format)}{'display'} eq 'graph' ? 'wiggle' : $format;
        my $code  = md5_hex("$species:$p");
        my $n     = $p =~ /\/([^\/]+)\/*$/ ? $1 : 'un-named';
        
        # We have to create a URL upload entry in the session
        $session->set_data(
          type    => 'url',
          url     => $p,
          species => $species,
          code    => $code, 
          name    => $n,
          format  => $format,
          style   => $style,
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
          url   => $p,
          style => $style
        );
        
        $self->update_track_renderer("url_$code", $renderer);
      } elsif ($type eq 'das') {
        $p = uri_unescape($p);
        
        my $logic_name = $session->add_das_from_string($p, $self->{'type'}, { display => $renderer });
        
        if ($logic_name) {
          $session->add_data(
            type     => 'message',
            function => '_info',
            code     => 'das:' . md5_hex($p),
            message  => sprintf('You have attached a DAS source with DSN: %s %s.', encode_entities($p), $self->get_node("das_$logic_name") ? 'to this display' : 'but it cannot be displayed on the specified image')
          );
        }
      }
    } else {
      $self->update_track_renderer($key, $renderer, $hub->param('toggle_tracks'));
    }
  }
  
  if ($self->altered) {
    $session->add_data(
      type     => 'message',
      function => '_info',
      code     => 'image_config',
      message  => 'The link you followed has made changes to the tracks displayed on this page.',
    );
  }
}

sub update_track_renderer {
  my ($self, $key, $renderer, $on_off) = @_;
  my $node = $self->get_node($key);
  
  return unless $node;
  
  my $renderers = $node->data->{'renderers'};
  my %valid     = @$renderers;
  my $flag      = 0;

  ## Set renderer to something sensible if user has specified invalid one. 'off' is usually first option, so take next one
  $renderer = $valid{'normal'} ? 'normal' : $renderers->[2] if $renderer ne 'off' && !$valid{$renderer};

  # if $on_off == 1, only allow track enabling/disabling. Don't allow enabled tracks' renderer to be changed.
  $flag += $node->set_user('display', $renderer) if (!$on_off || $renderer eq 'off' || $node->get('display') eq 'off');
  
  $self->altered = 1 if $flag;
}

sub update_favourite_tracks {
  my ($self, $diff) = @_;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $user    = $hub->user;
  my %args    = ( type => 'favourite_tracks', code => 'favourite_tracks' );
  
  $args{'tracks'} = $self->get_favourite_tracks;
  
  foreach (grep exists $diff->{$_}->{'favourite'}, keys %$diff) {
    if ($diff->{$_}->{'favourite'} == 1) {
      $args{'tracks'}{$_} = 1;
    } elsif (exists $diff->{$_}->{'favourite'}) {
      delete $args{'tracks'}{$_};
    }
  }
  
  if (scalar keys %{$args{'tracks'}}) {
    $session->set_data(%args);
  } else {
    delete $args{'tracks'};
    $session->purge_data(%args);
  }
  
  $user->set_favourite_tracks($args{'tracks'}) if $user;
  
  delete $self->{'favourite_tracks'};
}

sub update_track_order {
  my ($self, $diff) = @_;
  my $species    = $self->species;
  my $node       = $self->get_node('track_order');
  $self->altered = $node->set_user($species, { %{$node->get($species) || {}}, %{$diff->{'track_order'}} });
  return $self->altered if $self->get_parameter('sortable_tracks') ne 'drag';
}

sub reset {
  my $self = shift;
  
  if ($self->hub->input->param('reset') eq 'track_order') {
    my $node    = $self->get_node('track_order');
    my $species = $self->species;
    
    if ($node->{'user_data'}{'track_order'}{$species}) {
      $self->altered = 1;
      delete $node->{'user_data'}{'track_order'}{$species};
      delete $node->{'user_data'}{'track_order'} unless scalar keys %{$node->{'user_data'}{'track_order'}};
    }
  } else {
    my $tree = $self->tree;
    
    foreach my $node ($tree, $tree->nodes) {
      my $user_data = $node->{'user_data'};
      
      foreach (keys %$user_data) {
        $self->altered = 1 if $user_data->{$_}->{'display'};
        delete $user_data->{$_}->{'display'};
        delete $user_data->{$_} unless scalar keys %{$user_data->{$_}};
      }
    }
  }
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
  my $count_missing   = grep { $_->get('display') eq 'off' || !$_->get('display') } $self->get_tracks; 
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
      'add_data_files',             # Add to gene/rnaseq tree
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
      'add_regulation_builds',      # Add to regulation_feature tree
      'add_regulation_features',    # Add to regulation_feature tree
      'add_oligo_probes'            # Add to oligo tree
    ],
    variation => [
      'add_sequence_variations',          # Add to variation_feature tree
      'add_structural_variations',        # Add to variation_feature tree
      'add_copy_number_variant_probes',   # Add to variation_feature tree
      'add_somatic_mutations',            # Add to somatic tree
      'add_somatic_structural_variations' # Add to somatic tree
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
  $self->tree->append_child($self->create_option('track_order')) if $self->get_parameter('sortable_tracks');
}

sub load_configured_das {
  my $self          = shift;
  my $extra         = ref $_[0] eq 'HASH' ? shift : {};
  my %allowed_menus = map { $_ => 1 } @_;
  my $all_menus     = !scalar @_;
  my @adding;
  my %seen;
  
  foreach my $source (sort { $a->caption cmp $b->caption } values %{$self->species_defs->get_all_das}) {
    next unless $source->is_on($self->{'type'});
    
    my ($category, $sub_category) = split ' ', $source->category;
    
    if ($category == 1) {
      $self->add_das_tracks('external_data', $source, $extra); # Unconfigured, will go into External data section
      next;
    }
    
    next unless $all_menus || $allowed_menus{$category};
    
    my $menu = $self->get_node($category);
    my $key;
    
    if (!$menu && grep { $category eq $_ } @{$self->{'transcript_types'}}) {
      foreach (@{$self->{'transcript_types'}}) {
        $category = $_ and last if $menu = $self->get_node($_);
      }
    }
    
    if (!$menu) {
      push @{$adding[0]}, $category unless $seen{$category}++;
      push @{$adding[1]{$category}}, $sub_category if $sub_category && !$seen{$sub_category}++;
      next;
    }
    
    if ($sub_category) {
      $key  = join '_', $category, lc $sub_category;
      
      my $sub_menu = $menu->get_node($key);
      
      if (!$sub_menu) {
        warn "$sub_category, $seen{$sub_category}";
        push @{$adding[1]{$category}}, $sub_category unless $seen{$sub_category}++;
        next;
      }
      
      if ($sub_menu && grep !$_->get('external'), @{$sub_menu->child_nodes}) {
        $menu = $sub_menu;
        $key  = "${key}_external";
      }
    } else {
      $key = "${category}_external";
    }
    
    $menu->append($self->create_submenu($key, 'External data (DAS)', { external => 1 })) if $menu && !$menu->get_node($key);
    
    $self->add_das_tracks($key, $source, $extra);
  }
  
  # Add new menus, then run the function again - ensures that everything is printed in the right place
  if (scalar @adding) {
    my $external     = $self->get_node('external_data');
    my $menus        = $self->menus;
    my @new_menus    = @{$adding[0] || []};
       %seen         = map { $_ => 1 } @new_menus;
    
    foreach (@new_menus) {
      my $parent = ref $menus->{$_} ? $self->get_node($menus->{$_}[1]) : undef;
      
      my $menu = $self->get_node($_);
      
      $self->create_menus($_) unless $menu;
      
      $menu = $self->get_node($_);
      
      next unless $menu;
      
      $external->after(ref $menus->{$_} ? $self->get_node($menus->{$_}[1]) : $menu) unless $parent;
    }
    
    foreach my $k (keys %{$adding[1]}) {
      $self->create_menus(@{$adding[1]{$k}});
      
      foreach (@{$adding[1]{$k}}) {
        my $key      = join '_', $k, lc $_;
        my $menu     = $self->get_node($k);
        my $sub_menu = $menu->get_node($key);
        
        if (!$sub_menu) {
          (my $caption = $_) =~ s/_/ /g;
          $menu->append($self->create_submenu($key, $caption));
        }
      }
      
      push @new_menus, $k unless $seen{$_};
    }
    
    $self->load_configured_das($extra, @new_menus) if scalar @new_menus;
  }
}

# Attach all das sources from an image config
sub attach_das {
  my $self = shift;

  # Look for all das sources which are configured and turned on
  my @das_nodes = map { $_->get('glyphset') eq '_das' && $_->get('display') ne 'off' ? @{$_->get('logic_names')||[]} : () } $self->tree->nodes;
  
  return unless @das_nodes; # Return if no sources to be drawn
  
  my $hub = $self->hub;

  # Check to see if they really exists, and get entries from get_all_das call
  my %T = %{$hub->get_all_das};
  my @das_sources = @T{@das_nodes};

  return unless @das_sources; # Return if no sources exist
  
  my $species_defs = $hub->species_defs;

  # Cache the DAS Coordinator object (with key das_coord)
  $self->cache('das_coord',  
    new Bio::EnsEMBL::ExternalData::DAS::Coordinator(
      -sources => \@das_sources,
      -proxy   => $species_defs->ENSEMBL_WWW_PROXY,
      -noproxy => $species_defs->ENSEMBL_NO_PROXY,
      -timeout => $species_defs->ENSEMBL_DAS_TIMEOUT
    )
  );
}

sub _merge {
  my ($self, $_sub_tree, $sub_type) = @_;
  my $tree        = $_sub_tree->{'analyses'};
  my $config_name = $self->{'type'};
  my $data        = {};
  
  foreach my $analysis (keys %$tree){ 
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
        $data->{$key}{'multiple'}      = "This track comprises multiple analyses;" if $data->{$key}{'description'};
        $data->{$key}{'description'} ||= '';
        $data->{$key}{'description'}  .= ($data->{$key}{'description'} ? '; ' : '') . $sub_tree->{'desc'};
      }
    } else {
      $data->{$key}{'description'} = $sub_tree->{'desc'};
    }
    
    $data->{$key}{'format'} = $sub_tree->{'format'};
    
    push @{$data->{$key}{'logic_names'}}, $analysis;
  }
  
  foreach my $key (keys %$data) {
    $data->{$key}{'name'}      ||= $tree->{$key}{'name'};
    $data->{$key}{'caption'}   ||= $data->{$key}{'name'} || $tree->{$key}{'name'};
    $data->{$key}{'display'}   ||= 'off';
    $data->{$key}{'strand'}    ||= 'r';
    $data->{$key}{'description'} = "$data->{$key}{'multiple'} $data->{$key}{'description'}" if $data->{$key}{'multiple'};
  }
  
  return ([ sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data ], $data);
}

sub generic_add {
  my ($self, $menu, $key, $name, $data, $options) = @_;
  
  $menu->append($self->create_track($name, $data->{'name'}, {
    %$data,
    db        => $key,
    renderers => [ 'off', 'Off', 'normal', 'On' ],
    %$options
  }));
}

sub add_das_tracks {
  my ($self, $menu, $source, $extra) = @_;
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
    %{$extra || {}},
    external    => 'DAS',
    glyphset    => '_das',
    display     => 'off',
    logic_names => [ $source->logic_name ],
    caption     => $caption,
    description => $desc,
    renderers   => [
      'off',      'Off', 
      'nolabels', 'No labels', 
      'normal',   'Normal', 
      'labels',   'Labels'
    ],
  });
  
  if ($track) {
    $node->append($track);
    $self->has_das ||= 1;
  }
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
  
  return unless $self->get_node('dna_align_cdna');
  
  my ($keys, $data) = $self->_merge($hashref->{'dna_align_feature'}, 'dna_align_feature');
  
  foreach my $key_2 (@$keys) {
    my $k    = $data->{$key_2}{'type'} || 'other';
    my $menu = ($k =~ /rnaseq|simple/) ? $self->tree->get_node($k) : $self->tree->get_node("dna_align_$k");
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

      if ($data->{$key_2}{'display'} && $data->{$key_2}{'display'} eq 'simple'){
        $display = 'simple';
        $alignment_renderers = ['off', 'Off', 'simple', 'On'];  
      }
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

sub add_data_files {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->tree->get_node('rnaseq');

  return unless $menu;
  
  my ($keys, $data) = $self->_merge($hashref->{'data_file'});
  
  foreach (@$keys) {
    $self->generic_add($menu, $key, "data_file_${key}_$_", $data->{$_}, { 
      glyphset  => $data->{$_}{'format'} || '_alignment', 
      strand    => 'f',
      colourset => $data->{$_}{'colour_key'} || 'feature',
      renderers => [
        'off',       'Off', 
        'normal',    'Normal', 
        'unlimited', 'Unlimited', 
        'histogram', 'Coverage only'
      ], 
    });
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
# * transcript              # ordinary transcripts
# * alignslice_transcript   # transcripts in align slice co-ordinates
# * tse_transcript          # transcripts in collapsed intro co-ords
# * tsv_transcript          # transcripts in collapsed intro co-ords
# * gsv_transcript          # transcripts in collapsed gene co-ords
# depending on which menus are configured
sub add_genes {
  my ($self, $key, $hashref) = @_;
  
  # Gene features end up in each of these menus
  return unless grep $self->get_node($_), @{$self->{'transcript_types'}};

  my ($keys, $data) = $self->_merge($hashref->{'gene'}, 'gene');
  my $colours       = $self->species_defs->colour('gene');
  my $flag          = 0;
  
  foreach my $type (@{$self->{'transcript_types'}}) {
    my $menu = $self->get_node($type);
    
    next unless $menu;
    
    foreach my $key2 (@$keys) {
      my $t = $type;
      
      # hack just for human rnaseq genes to force them into the rna-seq menu
      $t = 'rnaseq' if $data->{$key2}{'type'} eq 'rnaseq';
      
      my $menu = $self->get_node($t);
      
      next unless $menu;
      
      $self->generic_add($menu, $key, "${t}_${key}_$key2", $data->{$key2}, {
        glyphset    => ($t =~ /_/ ? '' : '_') . $type, # QUICK HACK
        colours     => $colours,
        strand      => $t eq 'gene' ? 'r' : 'b',
        canvas      => { type => 'Gene' },
        renderers   => $t eq 'transcript' ? [
          'off',                     'Off',
          'gene_nolabel',            'No exon structure without labels',
          'gene_label',              'No exon structure with labels',
          'transcript_nolabel',      'Expanded without labels',
          'transcript_label',        'Expanded with labels',
          'collapsed_nolabel',       'Collapsed without labels',
          'collapsed_label',         'Collapsed with labels',
          'transcript_label_coding', 'Coding transcripts only (in coding genes)',
        ] : $t eq 'rnaseq' ? [
         'off',                'Off',
         'transcript_nolabel', 'Expanded without labels',
         'transcript_label',   'Expanded with labels',
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
      canvas   => {
        bumpLabels     => JSON::true,
        maxLabelRegion => 5e4
      }
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
    renderers   => [ 'off', 'Off', 'normal', 'On' ],
    strand      => 'r',
    canvas      => {
      bump         => JSON::true,
      labelOverlay => JSON::true
    }
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
      outline_threshold => $default_tracks->{$config_name}{$_}{'threshold'} eq 'no' ? undef : 350000,
      canvas            => { type => 'Clone' }
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
      label_key   => '[display_label]',
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

  return unless grep $self->get_node($_), keys %menus;

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
    renderers   => [qw(off Off normal On)],
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
          renderers   => [qw(off Off normal On)],
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
  
  if ($key eq 'core' && $hashref->{'karyotype'}{'rows'} > 0 && !$self->get_node('ideogram')) {
    $menu->append($self->create_track("chr_band_$key", 'Chromosome bands', {
      db          => $key,
      glyphset    => 'chr_band',
      display     => 'normal',
      strand      => 'f',
      description => 'Cytogenetic bands',
      colourset   => 'ideogram',
      sortable    => 1,
      canvas      => {
        labelOverlay => JSON::true,
        allData      => JSON::true
      }
    }));
  }
  
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
      colourset     => 'assembly_exception',
      canvas        => { type => 'Patch' }
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
      renderers   => [qw(off Off normal On)],
      height      => 4,
      strand      => 'r',
      canvas      => { type => 'Synteny' }
    }));
  }
}

sub add_alignments {
  my ($self, $key, $hashref, $species) = @_;
  
  return unless grep $self->get_node($_), qw(multiple_align pairwise_tblat pairwise_blastz pairwise_other conservation);
  
  my $species_defs = $self->species_defs;
  
  return if $species_defs->ENSEMBL_SITETYPE eq 'Pre';
  
  my $alignments = {};
  my $vega       = $species_defs->ENSEMBL_SITETYPE eq 'Vega';
  my $self_label = $species_defs->species_label($species, 'no_formatting');
  my $regexp     = $species =~ /^([A-Z])[a-z]*_([a-z]{3})/ ? "-?$1.$2-?" : 'xxxxxx';
  
  foreach my $row (values %{$hashref->{'ALIGNMENTS'}}) {
    next unless $row->{'species'}{$species};
    
    if ($row->{'class'} =~ /pairwise_alignment/) {
      my ($other_species) = grep { !/^$species$|ancestral_sequences$/ } keys %{$row->{'species'}};
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
        name                       => "$other_label - $row->{'type'}",
        caption                    => $other_label,
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
      my $n_species = grep { $_ ne "ancestral_sequences" } keys %{$row->{'species'}};
      
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
        
        $options{'description'} = qq{<a href="/info/docs/compara/analyses.html#conservation">$program conservation scores</a> based on the $row->{'name'}};
        
        $alignments->{'conservation'}{"$row->{'id'}_scores"} = {
          %options,
          conservation_score => $row->{'conservation_score'},
          name               => "Conservation score for $row->{'name'}",
          caption            => "$n_species way $program scores",
          order              => sprintf('%12d::%s::%s', 1e12-$n_species*10, $row->{'type'}, $row->{'name'}),
          display            => $row->{'id'} == 352 ? 'tiling' : 'off',
          renderers          => [ 'off', 'Off', 'tiling', 'Tiling array' ],
        };
        
        $alignments->{'conservation'}{"$row->{'id'}_constrained"} = {
          %options,
          constrained_element => $row->{'constrained_element'},
          name                => "Constrained elements for $row->{'name'}",
          caption            => "$n_species way $program elements",
          order               => sprintf('%12d::%s::%s', 1e12-$n_species*10+1, $row->{'type'}, $row->{'name'}),
          display             => $row->{'id'} == 352 ? 'compact' : 'off',
          renderers           => [ 'off', 'Off', 'compact', 'On' ],
        };
      }
      
      $alignments->{'multiple_align'}{$row->{'id'}} = {
        %options,
        name        => $row->{'name'},
        caption     => $row->{'name'},
        order       => sprintf('%12d::%s::%s', 1e12-$n_species*10-1, $row->{'type'}, $row->{'name'}),
        display     => 'off',
        renderers   => [ 'off', 'Off', 'compact', 'On' ],
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
  
  my $reg_regions = $menu->append($self->create_submenu('functional_other_regulatory_regions', 'Other regulatory regions'));
  
  $reg_regions->before($self->create_submenu('functional_dna_methylation', 'DNA Methylation'));
  
  my ($keys_1, $data_1) = $self->_merge($hashref->{'feature_set'});
  my ($keys_2, $data_2) = $self->_merge($hashref->{'result_set'});
  my %fg_data           = (%$data_1, %$data_2);
  
  foreach my $key_2 (sort grep { !/RegulatoryRegion|seg_/ } @$keys_1, @$keys_2) {
    my $type = $fg_data{$key_2}{'type'};
    
    next if !$type || $type eq 'ctcf';
    
    my @renderers;
    
    if ($fg_data{$key_2}{'renderers'}) {
      push @renderers, $_, $fg_data{$key_2}{'renderers'}{$_} for sort keys %{$fg_data{$key_2}{'renderers'}}; 
    } else {
      @renderers = qw(off Off normal On);
    }
    
    $reg_regions->append($self->create_track("${type}_${key}_$key_2", $fg_data{$key_2}{'name'}, { 
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
      $reg_regions->append($self->create_track("${type}_${key}_search", 'cisRED Search Regions', {
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
  my $db_tables         = $self->databases->{'DATABASE_FUNCGEN'}->{'tables'};
  my $key_2             = 'RegulatoryRegion';
  my $type              = $fg_data{$key_2}{'type'};
  
  return unless $type;
  
  $menu = $menu->append($self->create_submenu('regulatory_features', 'Regulatory features'));
  
  my $reg_feats = $menu->append($self->create_submenu('reg_features', 'Regulatory features'));
  my $reg_segs  = $menu->append($self->create_submenu('seg_features', 'Segmentation features'));
  
  my @cell_lines = sort keys %{$db_tables->{'cell_type'}{'ids'}};
  my (@renderers, $multi_flag);

  if ($fg_data{$key_2}{'renderers'}) {
    push @renderers, $_, $fg_data{$key_2}{'renderers'}{$_} for sort keys %{$fg_data{$key_2}{'renderers'}}; 
  } else {
    @renderers = qw(off Off normal On);
  }
  
  # Add MultiCell first
  unshift @cell_lines, 'AAAMultiCell';   
  
  foreach my $cell_line (sort  @cell_lines) {
    $cell_line =~ s/AAA|\:\w*//g;
    
    next if $cell_line eq 'MultiCell' && $multi_flag;

    my $track_key = "reg_feats_$cell_line";
    my $display   = 'off';
    my $label;
    
    if ($cell_line =~ /MultiCell/) {  
      $display    = $fg_data{$key_2}{'display'} || 'off';
      $multi_flag = 1;
    } else {
      $label = ": $cell_line";
    }
    
    $reg_feats->append($self->create_track($track_key, "$fg_data{$key_2}{'name'}$label", {
      db          => $key,
      glyphset    => $type,
      sources     => 'undef',
      strand      => 'r',
      depth       => $fg_data{$key_2}{'depth'}     || 0.5,
      colourset   => $fg_data{$key_2}{'colourset'} || $type,
      description => $fg_data{$key_2}{'description'}{'reg_feats'},
      display     => $display,
      renderers   => \@renderers,
      cell_line   => $cell_line
    }));
    
    if ($fg_data{"seg_$cell_line"}{'key'} eq "seg_$cell_line") {
      $reg_segs->append($self->create_track("seg_$cell_line", "Reg. Segs: $cell_line", {
        db          => $key,
        glyphset    => "fg_segmentation_features",
        sources     => 'undef',
        strand      => 'r',
        labels      => 'on',
        depth       => 0,
        colourset   => 'fg_segmentation_features',
        display     => 'off',
        description => $fg_data{"seg_$cell_line"}{'description'},
        renderers   => \@renderers,
        cell_line   => $cell_line,
        caption     => "Reg. Segs $cell_line",
      }));
    }
    
    ### Add tracks for cell_line peaks and wiggles only if we have data to display
    my @ftypes     = keys %{$db_tables->{'regbuild_string'}{'feature_type_ids'}{$cell_line}      || {}};  
    my @focus_sets = keys %{$db_tables->{'regbuild_string'}{'focus_feature_set_ids'}{$cell_line} || {}};  
    
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
        'tiling',         'Signal', 
        'tiling_feature', 'Both' 
      ],         
    );
    
    if (scalar @focus_sets && scalar @focus_sets <= scalar @ftypes) {
      # Add Core evidence tracks
      $reg_feats->append($self->create_track("reg_feats_core_$cell_line", "Open chromatin & TFBS$label", { %options, type => 'core', description => $options{'description'}{'core'} }));
    } 

    if (scalar @ftypes != scalar @focus_sets  && $cell_line ne 'MultiCell') {
      # Add 'Other' evidence tracks
      $reg_feats->append($self->create_track("reg_feats_other_$cell_line", "Histones & Polymerases$label", { %options, type => 'other', description => $options{'description'}{'other'} }));
    }
  }
  
  if ($db_tables->{'cell_type'}{'ids'}) {
    $self->add_track('information', 'fg_regulatory_features_legend',   'Reg. Features Legend',          'fg_regulatory_features_legend',   { strand => 'r', colourset => 'fg_regulatory_features'});        
    $self->add_track('information', 'fg_segmentation_features_legend', 'Reg. Segments Legend',          'fg_segmentation_features_legend', { strand => 'r', colourset => 'fg_segmentation_features'});
    $self->add_track('information', 'fg_multi_wiggle_legend',          'Cell/Tissue Regulation Legend', 'fg_multi_wiggle_legend',          { strand => 'r', display => 'off' });
  }
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
    
    $menu->append($self->create_track("oligo_${key}_" . uc $key_2, $key_3, {
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
  
  my $options = {
    db         => $key,
    glyphset   => '_variation',
    strand     => 'r',
    depth      => 0.5,
    bump_width => 0,
    colourset  => 'variation',
    display    => 'off'
  };
  
  if ($hashref->{'menu'}) {
    $self->add_sequence_variations_meta($key, $hashref, $options);
  } else {
    $self->add_sequence_variations_default($key, $hashref, $options);
  }

  $self->add_track('information', 'variation_legend', 'Variation Legend', 'variation_legend', { strand => 'r' });
}

# adds variation tracks in structure defined in variation meta table
sub add_sequence_variations_meta {
  my ($self, $key, $hashref, $options) = @_;
  my $menu = $self->get_node('variation');
  
  foreach my $menu_item(@{$hashref->{'menu'}}) {
    next if $menu_item->{'type'} eq 'sv_set'; # sv_set type
    
    my $node;
    
    if ($menu_item->{'type'} eq 'menu') { # just a named submenu
      $node = $self->create_submenu($menu_item->{'key'}, $menu_item->{'long_name'});
    } elsif ($menu_item->{'type'} eq 'source') { # source type
      my $temp_name     = $menu_item->{'long_name'};
         $temp_name     =~ s/ variants$//;
      my $other_sources = $menu_item->{'long_name'} =~ /all other sources/;
      
      $node = $self->create_track($menu_item->{'key'}, $menu_item->{'long_name'}, {
        %$options,
        caption     => $menu_item->{'long_name'},
        sources     => $other_sources ? undef : [ $temp_name ],
        description => $other_sources ? 'Sequence variants from all sources' : $hashref->{'source'}{'descriptions'}{$temp_name},
      });
    } elsif ($menu_item->{'type'} eq 'set') { # set type
      my $temp_name = $menu_item->{'key'};
         $temp_name =~ s/^variation_set_//;
      my $caption   = $menu_item->{'long_name'};
         $caption   =~ s/1000 Genomes/1KG/; # shorten name for side of image
      my $set_name  = $menu_item->{'long_name'};
         $set_name  =~ s/All HapMap/HapMap/; # hack for HapMap set name - remove once variation team fix data for 68
      
      next if $set_name =~ /HapMap.+/;
      
      $node = $self->create_track($menu_item->{'key'}, $menu_item->{'long_name'}, {
        %$options,
        caption     => $caption,
        sources     => undef,
        sets        => [ $set_name ],
        set_name    => $set_name,
        description => $hashref->{'variation_set'}{'descriptions'}{$temp_name}
      });
    }
    
    # get the node onto which we're going to add this item, then append it
    ($self->get_node($menu_item->{'parent'}) || $menu)->append($node) if $node;
  }
}

# adds variation tracks the old, hacky way
sub add_sequence_variations_default {
  my ($self, $key, $hashref, $options) = @_;
  my $menu               = $self->get_node('variation');
  my $sequence_variation = $self->create_submenu('sequence_variations', 'Sequence variants');
  
  $sequence_variation->append($self->create_track("variation_feature_$key", 'Sequence variants (all sources)', {
    %$options,
    sources     => undef,
    description => 'Sequence variants from all sources',
  }));
  
  foreach my $key_2 (sort keys %{$hashref->{'source'}{'counts'} || {}}) {
    next unless $hashref->{'source'}{'counts'}{$key_2} > 0;
    next if     $hashref->{'source'}{'somatic'}{$key_2} == 1;
    
    (my $k = $key_2) =~ s/\W/_/g;
    
    $sequence_variation->append($self->create_track("variation_feature_${key}_$k", "$key_2 variations", {
      %$options,
      caption     => $key_2,
      sources     => [ $key_2 ],
      description => $hashref->{'source'}{'descriptions'}{$key_2},
    }));
  }
  
  $menu->append($sequence_variation);

  # add in variation sets
  if ($hashref->{'variation_set'}{'rows'} > 0) {
    my $variation_sets = $self->create_submenu('variation_sets', 'Variation sets');
    
    $menu->append($variation_sets);
    
    foreach my $toplevel_set (
      sort { !!scalar @{$a->{'subsets'}} <=> !!scalar @{$b->{'subsets'}} } 
      sort { $a->{'name'} =~ /^failed/i <=> $b->{'name'} =~ /^failed/i } 
      sort { $a->{'name'} cmp $b->{'name'} } 
      values %{$hashref->{'variation_set'}{'supersets'}}
    ) {
      my $name          = $toplevel_set->{'name'};
      my $caption       = $name . (scalar @{$toplevel_set->{'subsets'}} ? ' (all data)' : '');
      my $key           = $toplevel_set->{'short_name'};
      my $set_variation = scalar @{$toplevel_set->{'subsets'}} ? $self->create_submenu("set_variation_$key", $name) : $variation_sets;
      
      $set_variation->append($self->create_track("variation_set_$key", $caption, {
        %$options,
        caption     => $caption,
        sources     => undef,
        sets        => [ $name ],
        set_name    => $name,
        description => $toplevel_set->{'description'},
      }));
      
      # add in sub sets
      if (scalar @{$toplevel_set->{'subsets'}}) {
        foreach my $subset_id (sort @{$toplevel_set->{'subsets'}}) {
          my $sub_set             = $hashref->{'variation_set'}{'subsets'}{$subset_id};
          my $sub_set_name        = $sub_set->{'name'}; 
          my $sub_set_description = $sub_set->{'description'};
          my $sub_set_key         = $sub_set->{'short_name'};
          
          $set_variation->append($self->create_track("variation_set_$sub_set_key", $sub_set_name, {
            %$options,
            caption     => $sub_set_name,
            sources     => undef,
            sets        => [ $sub_set_name ],
            set_name    => $sub_set_name,
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
    height     => 6,
    colourset  => 'structural_variant',
    display    => 'off',
    canvas     => { type => 'StructuralVariation' },
  );
  
  $structural_variation->append($self->create_track('variation_feature_structural', 'Structural variants (all sources)', {   
    %options,
    caption     => 'Structural variants',
    sources     => undef,
    description => 'Structural variants from all sources. For an explanation of the display, see the <a rel="external" href="http://www.ncbi.nlm.nih.gov/dbvar/content/overview/#representation">dbVar documentation</a>.',
    depth       => 10
  }));
  
  foreach my $key_2 (sort keys %{$hashref->{'structural_variation'}{'counts'} || {}}) {
    my $description = $hashref->{'source'}{'descriptions'}{$key_2};
    (my $k = $key_2) =~ s/\W/_/g;
    
    $structural_variation->append($self->create_track("variation_feature_structural_$k", "$key_2 structural variations", {
      %options,
      caption     => $key_2,
      source      => $key_2,
      description => $description,
      depth       => 0.5
    }));  
  }
  
  # Structural variation sets
  foreach my $menu_item (@{$hashref->{'menu'}}) {
    next if $menu_item->{'type'} ne 'sv_set';
    
    my $temp_name = $menu_item->{'key'};
       $temp_name =~ s/^structural_variation_set_//;
    my $node_name = "$menu_item->{'long_name'} (structural variants)";
      
    $structural_variation->append($self->create_track($menu_item->{'key'}, $node_name, {
      %options,
      caption     => $node_name,
      sources     => undef,
      sets        => [ $menu_item->{'long_name'} ],
      set_name    => $menu_item->{'long_name'},
      description => $hashref->{'structural_variation_set'}{'descriptions'}{$temp_name},
    }));
  }
  
  $menu->append($structural_variation);
}
  
sub add_copy_number_variant_probes {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('variation');
  
  return unless $menu && $hashref->{'structural_variation'}{'rows'} > 0;
  
  $menu = $self->get_node('structural_variation') || $menu->append($self->create_submenu('structural_variation', 'Structural variants'));
  
  my %options = (
    db         => $key,
    glyphset   => 'cnv_probes',
    strand     => 'r', 
    bump_width => 0,
    height     => 6,
    colourset  => 'structural_variant',
    display    => 'off'
  );
  
  $menu->append($self->create_track('variation_feature_cnv', 'Copy number variant probes (all sources)', {   
    %options,
    caption     => 'CNV probes',
    sources     => undef,
    depth       => 10,
    description => 'Copy number variant probes from all sources'
  }));
  
  foreach my $key_2 (sort keys %{$hashref->{'structural_variation'}{'cnv_probes'}{'counts'} || {}}) {
    my $description = $hashref->{'source'}{'descriptions'}{$key_2};
    (my $k = $key_2) =~ s/\W/_/g;
    
    $menu->append($self->create_track("variation_feature_cnv_$k", "$key_2", {
      %options,
      caption     => $key_2,
      source      => $key_2,
      depth       => 0.5,
      description => $description
    }));  
  }
}

sub add_somatic_mutations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('somatic');
  
  return unless $menu;
  
  my $somatic = $self->create_submenu('somatic_mutation', 'Somatic variants');
  
  my %options = (
    db         => $key,
    glyphset   => '_variation',
    strand     => 'r',
    depth      => 0.5,
    bump_width => 0,
    colourset  => 'variation',
    display    => 'off',
  );
  
  foreach my $key_2 (sort grep { $hashref->{'source'}{'somatic'}{$_} == 1 } keys %{$hashref->{'source'}{'somatic'}}) {
    next unless $hashref->{'source'}{'counts'}{$key_2} > 0;
    
    my $description  = $hashref->{'source'}{'descriptions'}{$key_2};
    (my $k = $key_2) =~ s/\W/_/g;
    
    $somatic->append($self->create_track("somatic_mutation_$k", "Somatic variants (all sources)", {
      %options,
      caption     => 'Somatic variants (all sources)',
      description => 'Somatic variants from all sources'
    }));

    ## Add tracks for each tumour site
    my %tumour_sites = %{$self->species_defs->databases->{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'}{$key_2} || {}};
    
    foreach my $description (sort  keys %tumour_sites) {
      my $phenotype_id           = $tumour_sites{$description};
      my ($source, $type, $site) = split /\:/, $description;
      my $formatted_site         = $site;
      $site                      =~ s/\W/_/g;
      $formatted_site            =~ s/\_/ /g;
      
      $somatic->append($self->create_track("somatic_mutation_${k}_$site", "$key_2 somatic mutations in $formatted_site", {
        %options,
        caption     => "$key_2 $formatted_site tumours",
        filter      => $phenotype_id,
        description => $description
      }));    
    }
  }
  
  $menu->append($somatic);
}

sub add_somatic_structural_variations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('somatic');
  
  return unless $menu && $hashref->{'structural_variation'}{'rows'} > 0;
  
  my $somatic = $self->create_submenu('somatic_structural_variation', 'Somatic structural variants');
  
  my %options = (
    db         => $key,
    glyphset   => 'structural_variation',
    strand     => 'r', 
    bump_width => 0,
    height     => 6,
    colourset  => 'structural_variant',
    display    => 'off',
  );
  
  $somatic->append($self->create_track('somatic_sv_feature', 'Somatic structural variants (all sources)', {   
    %options,
    caption     => 'Somatic structural variants',
    sources     => undef,
    description => 'Somatic structural variants from all sources. For an explanation of the display, see the <a rel="external" href="http://www.ncbi.nlm.nih.gov/dbvar/content/overview/#representation">dbVar documentation</a>. In addition, we display the breakpoints in yellow.',
    depth       => 10
  }));
  
  foreach my $key_2 (sort keys %{$hashref->{'structural_variation'}{'somatic'}{'counts'} || {}}) {
    my $description = $hashref->{'source'}{'descriptions'}{$key_2};
    (my $k = $key_2) =~ s/\W/_/g;
    
    $somatic->append($self->create_track("somatic_sv_feature_$k", "$key_2 somatic structural variations", {
      %options,
      caption     => "$key_2 somatic",
      source      => $key_2,
      description => $description,
      depth       => 0.5
    }));  
  }
  
  $menu->append($somatic);
}

1;
