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

package EnsEMBL::Web::ImageConfig;

use strict;

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities decode_entities);
use JSON qw(from_json);
use URI::Escape qw(uri_unescape);

use EnsEMBL::Draw::Utils::TextHelper;
use EnsEMBL::Draw::Utils::Transform;
use EnsEMBL::Web::Utils::FormatText qw(add_links);
use EnsEMBL::Web::Command::UserData::AddFile;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Tree;
use EnsEMBL::Web::DataStructure::DoubleLinkedList;

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
  
  my $self = {
    hub              => $hub,
    _font_face       => $style->{'GRAPHIC_FONT'} || 'Arial',
    _font_size       => ($style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'}) || 20,
    _texthelper      => EnsEMBL::Draw::Utils::TextHelper->new,
    transform_object => EnsEMBL::Draw::Utils::Transform->new,
    code             => $code,
    type             => $type,
    species          => $species,
    altered          => [],
    _tree            => EnsEMBL::Web::Tree->new,
    transcript_types => [qw(transcript alignslice_transcript tsv_transcript gsv_transcript TSE_transcript)],
    _parameters      => { # Default parameters
      storable     => 1,      
      trackhubs    => 0,
      image_width  => $hub->image_width,
      image_resize => 0,
      margin       => 5,
      spacing      => 2,
      label_width  => 113,
      show_labels  => 'yes',
      slice_number => '1|1',
      toolbars     => { top => 1, bottom => 0 },
    },
    extra_menus => {
      active_tracks    => 1,
      favourite_tracks => 1,
      search_results   => 1,
      display_options  => 1,
    },
    unsortable_menus => {
      decorations => 1,
      information => 1,
      options     => 1,
      other       => 1,
    },
    alignment_renderers => [
      'off',                  'Off',
      'as_alignment_nolabel', 'Normal',
      'as_alignment_label',   'Labels',
      'half_height',          'Half height',
      'stack',                'Stacked',
      'unlimited',            'Stacked unlimited',
      'ungrouped',            'Ungrouped',
    ],
    _legend => {'_settings' => {'max_length' => 0}},
  };
  
  return bless $self, $class;
}

sub initialize {
  my $self      = shift;
  my $class     = ref $self;
  my $species   = $self->species;
  my $code      = $self->code;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;
  
  # Check memcached for defaults
  if (my $defaults = $cache && $cache_key ? $cache->get($cache_key) : undef) {
    my $user_data = $self->tree->user_data;
    
    $self->{$_} = $defaults->{$_} for keys %$defaults;
    $self->tree->push_user_data_through_tree($user_data);
  } else {
    # No cached defaults found, so initialize them and cache
    $self->init;
    $self->save_to_cache;
  }
  
  my $sortable = $self->get_parameter('sortable_tracks');
  
  $self->set_parameter('sortable_tracks', 1) if $sortable eq 'drag' && $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d+)/ && $1 < 7; # No sortable tracks on images for IE6 and lower
  $self->{'extra_menus'}{'track_order'} = 1  if $sortable;
  
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
}

sub orientation {
  ## Tell about the orientation of the image - ie. horizontal or vertical
  return 'horizontal';
}

sub type { return $_[0]->{'type'}; }

sub menus {
  return $_[0]->{'menus'} ||= {
    # Sequence
    seq_assembly        => 'Sequence and assembly',
    sequence            => [ 'Sequence',                'seq_assembly' ],
    misc_feature        => [ 'Clones & misc. regions',  'seq_assembly' ],
    genome_attribs      => [ 'Genome attributes',       'seq_assembly' ],
    marker              => [ 'Markers',                 'seq_assembly' ],
    simple              => [ 'Simple features',         'seq_assembly' ],
    ditag               => [ 'Ditag features',          'seq_assembly' ],
    dna_align_other     => [ 'GRC alignments',          'seq_assembly' ],
    dna_align_compara   => [ 'Imported alignments',     'seq_assembly' ],
    
    # Transcripts/Genes
    gene_transcript     => 'Genes and transcripts',
    transcript          => [ 'Genes',                  'gene_transcript' ],    
    prediction          => [ 'Prediction transcripts', 'gene_transcript' ],
    lrg                 => [ 'LRG',                    'gene_transcript' ],
    rnaseq              => [ 'RNASeq models',          'gene_transcript' ],
    
    # Supporting evidence
    splice_sites        => 'Splice sites',
    evidence            => 'Evidence',
    
    # Alignments
    mrna_prot           => 'mRNA and protein alignments',
    dna_align_cdna      => [ 'mRNA alignments',    'mrna_prot' ],
    dna_align_est       => [ 'EST alignments',     'mrna_prot' ],
    protein_align       => [ 'Protein alignments', 'mrna_prot' ],
    protein_feature     => [ 'Protein features',   'mrna_prot' ],
    dna_align_rna       => 'ncRNA',
    
    # Proteins
    domain              => 'Protein domains',
    gsv_domain          => 'Protein domains',
    feature             => 'Protein features',
    
    # Variations
    variation           => 'Variation',
    recombination       => [ 'Recombination & Accessibility', 'variation' ],
    somatic             => 'Somatic mutations',
    ld_population       => 'Population features',
    
    # Regulation
    functional          => 'Regulation',
    
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

sub storable     { shift->_parameter('storable', @_);     } # Set to 1 if configuration can be altered
sub image_resize { shift->_parameter('image_resize', @_); } # Set to 1 if there is image resize function

sub _parameter { # the other sub parameter doesn't set false values
  my $self  = shift;
  my $key   = shift;

  $self->{'_parameter'}{$key} = shift if @_;

  return $self->{'_parameter'}{$key};
}

sub hub                 { return $_[0]->{'hub'};                                               }
sub code                { return $_[0]->{'code'};                                              }
sub core_object        { return $_[0]->hub->core_object($_[1]);                                }
sub colourmap           { return $_[0]->hub->colourmap;                                        }
sub species_defs        { return $_[0]->hub->species_defs;                                     }
sub sd_call             { return $_[0]->species_defs->get_config($_[0]->{'species'}, $_[1]);   }
sub databases           { return $_[0]->sd_call('databases');                                  }
sub texthelper          { return $_[0]->{'_texthelper'};                                       }
sub transform_object    { return $_[0]->{'transform_object'};                                  }
sub tree                { return $_[0]->{'_tree'};                                             }
sub species             { return $_[0]->{'species'};                                           }
sub legend              { return $_[0]->{'_legend'};                                           }
sub multi_species       { return 0;                                                            }
sub cache_key           { return join '::', '', ref $_[0], $_[0]->species, $_[0]->code;        }
sub bgcolor             { return $_[0]->get_parameter('bgcolor') || 'background1';             }
sub bgcolour            { return $_[0]->bgcolor;                                               }
sub get_node            { return shift->tree->get_node(@_);                                    }
sub get_parameters      { return $_[0]->{'_parameters'};                                       }
sub get_parameter       { return $_[0]->{'_parameters'}{$_[1]};                                }
sub set_width           { $_[0]->set_parameter('width', $_[1]);                                } # TODO: find out why we have width and image_width. delete?
sub image_height        { return shift->parameter('image_height',    @_);                      }
sub image_width         { return shift->parameter('image_width',     @_);                      }
sub container_width     { return shift->parameter('container_width', @_);                      }
sub toolbars            { return shift->parameter('toolbars',        @_);                      }
sub slice_number        { return shift->parameter('slice_number',    @_);                      } # TODO: delete?
sub get_tracks          { return grep { $_->{'data'}{'node_type'} eq 'track' } $_[0]->tree->nodes; } # return a list of track nodes
sub get_sortable_tracks { return grep { $_->get('sortable') && $_->get('menu') ne 'no' } @{$_[0]->glyphset_configs}; }

sub altered {
  my $self = shift;
  push @{$self->{'altered'}}, @_ if @_;
  return $self->{'altered'};
}

sub is_altered {
  return @{$_[0]->{'altered'}} ? 1 : 0;
}

sub get_user_settings {
  my $self     = shift;
  my $settings = $self->tree->user_data;
  delete $settings->{'track_order'} if $settings->{'track_order'} && !scalar keys %{$settings->{'track_order'}};
  return $settings;
}

sub default_track_order {
  my ($self, @tracks) = @_;
 
  my (%sections,@out);
  push @{$sections{$_->get('section')||''}||=[]},$_ for @tracks;
  foreach my $track (@tracks) {
    my $section = $track->get('section');
    if($section and $sections{$section}) {
      push @out,@{$sections{$section}};
      $sections{$section} = [];
    } else {
      push @out,$track;  
    }
  }
  return @out;
}

sub glyphset_configs {
  my $self = shift;
  
  if (!$self->{'ordered_tracks'}) {
    my @tracks      = $self->get_tracks;
    my $track_order = $self->track_order;
    my @default_order;

    foreach my $track ($self->default_track_order(@tracks)) {
      my $strand = $track->get('strand');
      
      if ($strand =~ /^[rf]$/) {
        if ($strand eq 'f') {
          unshift @default_order, $track;
        } else {
          push @default_order, $track;
        }
      } else {
        my $clone = $self->_clone_track($track);
        
        $clone->set('drawing_strand', 'f');
        $track->set('drawing_strand', 'r');
        
        unshift @default_order, $clone;
        push    @default_order, $track;
      }
    }
    
    if ($self->get_parameter('sortable_tracks')) {

      my ($pointer, $first_track, $last_immovable_track, $i, %lookup, $ordered_tracks);

      # make a 'double linked list' to make it easy to apply user sorting on it
      $first_track = EnsEMBL::Web::DataStructure::DoubleLinkedList->from_array(\@default_order);

      # add all qualifying tracks to the lookup
      $pointer = $first_track;
      while ($pointer) {
        my $node      = $pointer->node;
        my $sortable  = $node->data->{'sortable'} || !$self->{'unsortable_menus'}{$node->parent_key};

        if ($sortable) {
          $node->set('sortable', 1);
          $lookup{ join('.', $node->id, $node->get('drawing_strand') || ()) } = $pointer;
        } else {
          if (!scalar keys %lookup) { # if we haven't found any sortable tracks yet, and the current one isn't sortable, then save the current pointer as last immovable track
            $last_immovable_track = $pointer;
          }
        }

        $pointer = $pointer->next;
      }

      # go through the state changes made by the user, one by one, and reorder the tracks accordingly
      for (@$track_order) {
        my $track = $lookup{$_->[0]} or next;
        my $prev  = $_->[1] && $lookup{$_->[1]} || $last_immovable_track; # if no prev track provided for the current track, move the track to just after the last immovable track

        # if $prev is undef and we don't have any immovable tracks, it means $track is supposed to moved to first position in the list
        if ($prev) {
          $prev->after($track);
        } else {
          $first_track->before($track);
          $first_track = $track;
        }
      }

      # break the linked list into an ordered array
      $ordered_tracks = $first_track->to_array({'unlink' => 1});

      # Set the 'order' key according to the final order
      $_->set('order', ++$i) for @$ordered_tracks;

      $self->{'ordered_tracks'} = $ordered_tracks;

    } else {
      $self->{'ordered_tracks'} = \@default_order;
    }
  }

  return $self->{'ordered_tracks'};
}

sub add_to_legend {
### Add a track's legend entries to the master legend
  my ($self, $new_legend) = @_;
  return unless ref $new_legend eq 'HASH';
  my $legend = $self->legend;

  while (my($key, $sublegend) = each (%$new_legend)) {
    if ($legend->{$key}) {
      ## Add to an existing legend
      ## TODO - currently this skips existing entries and settings. 
      ## Need to deal with possible clashes with existing data
      foreach (@{$sublegend->{'entry_order'}}) {
        next if $legend->{$key}{'entries'}{$_};
        push @{$legend->{$key}{'entry_order'}}, $_;
        my $entry_hash = $sublegend->{$key}{'entries'}{$_};
        $legend->{$key}{'entries'}{$_} = $entry_hash;
        my $label_length = length($entry_hash->{'title'});
        $legend->{'_settings'}{'max_length'} = $label_length if $label_length > $legend->{'_settings'}{'max_length'}; 
      }
    }
    else {
      ## Create a new section
      $legend->{$key} = $sublegend;
    }
  }
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
  my $self  = shift;
  my $node  = $self->get_node('track_order');
  my $order = $node && $node->get($self->species) || [];

  return ref $order eq 'ARRAY' ? $order : []; # ignore the older schema track order entry
}

sub set_user_settings {
  my ($self, $data) = @_;
  
  foreach my $key (keys %$data) {
    my $node = $self->get_node($key) || $self->tree->create_node($key); # If node doesn't exist, it is a track from a different species whose configuration needs to be retained
    
    next unless $node;
    
    my $renderers = $node->data->{'renderers'} || [];
    my %valid     = @$renderers;
    
    foreach (keys %{$data->{$key}}) {
      if ($_ eq 'display' && %valid && !$valid{$data->{$key}{$_}}) {
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

sub update_from_input {
  my $self  = shift;
  my $input = $self->hub->input;
  
  return $self->reset if $input->param('reset');
  
  my $diff   = $input->param('image_config');
  my $reload = 0;
  
  if ($diff) {
    my $track_reorder = 0;
    
    $diff = from_json($diff);
    $self->update_track_renderer($_, $diff->{$_}->{'renderer'}, undef, 1) for grep exists $diff->{$_}->{'renderer'}, keys %$diff;
    
    $reload        = $self->is_altered;
    $track_reorder = $self->update_track_order($diff) if $diff->{'track_order'};
    $reload      ||= $track_reorder;
    $self->update_favourite_tracks($diff);
  } else {
    my %favourites;
    
    foreach my $p ($input->param) {
      my $val = $input->param($p);
      
      if ($p eq 'track') {
        my $node = $self->get_node($val);
        $node->set_user('userdepth', $input->param('depth')) if $node;
        $self->altered($val);
      }
      elsif ($val =~ /favourite_(on|off)/) {
        $favourites{$p} = { favourite => $1 eq 'on' ? 1 : 0 };
      } 
      elsif ($p ne 'depth') {
        $self->update_track_renderer($p, $val);
      }
    }
    
    $reload = $self->is_altered;
    
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
    my $format = $hub->param('format');
    my ($url, $renderer, $attach);
    
    if ($v =~ /^url/) {
      $v =~ s/^url://;
      $attach = 1;
      ($url, $renderer) = split /=/, $v;
    }
   
    if ($attach || $hub->param('attach')) {
      ## Backwards compatibility with 'contigviewbottom=url:http...'-type parameters
      ## as well as new 'attach=http...' parameter
      my $p = uri_unescape($url);

      my $menu_name   = $hub->param('menu');
      my $all_formats = $hub->species_defs->multi_val('DATA_FORMAT_INFO');
       
      if (!$format) {
        my @path = split(/\./, $p);
        my $ext  = $path[-1] eq 'gz' ? $path[-2] : $path[-1];
          
        while (my ($name, $info) = each %$all_formats) {
          if ($ext =~ /^$name$/i) {
            $format = $name;
            last;
          }  
        }
        if (!$format) {
          # Didn't match format name - now try checking format extensions
          while (my ($name, $info) = each %$all_formats) {
            if ($ext eq $info->{'ext'}) {
              $format = $name;
              last;
            }  
          }
        }
      }

      my $style = $all_formats->{lc $format}{'display'} eq 'graph' ? 'wiggle' : $format;
      my $code  = join '_', md5_hex("$species:$p"), $session->session_id;
      my $n;
        
      if ($menu_name) {
        $n = $menu_name;
      } else {
        $n = $p =~ /\/([^\/]+)\/*$/ ? $1 : 'un-named';
      }
        
      # Don't add if the URL or menu are the same as an existing track
      if ($session->get_data(type => 'url', code => $code)) {
        $session->add_data(
            type     => 'message',
            function => '_warning',
            code     => "duplicate_url_track_$code",
            message  => "You have already attached the URL $p. No changes have been made for this data source.",
        );
          
        next;
      } elsif (grep $_->{'name'} eq $n, $session->get_data(type => 'url')) {
        $session->add_data(
            type     => 'message',
            function => '_error',
            code     => "duplicate_url_track_$n",
            message  => qq{Sorry, the menu "$n" is already in use. Please change the value of "menu" in your URL and try again.},
        );
          
        next;
      }

      # We then have to create a node in the user_config
      my %ensembl_assemblies = %{$hub->species_defs->assembly_lookup};

      if (uc $format eq 'TRACKHUB') {
        my $info;
        ($n, $info) = $self->_add_trackhub($n, $p);
        if ($info->{'error'}) {
          my @errors = @{$info->{'error'}||[]};
          $session->add_data(
              type     => 'message',
              function => '_warning',
              code     => 'trackhub:' . md5_hex($p),
              message  => "There was a problem attaching trackhub $n: @errors",
          );
        }
        else {
          my $assemblies = $info->{'genomes'}
                        || {$hub->species => $hub->species_defs->get_config($hub->species, 'ASSEMBLY_VERSION')};

          foreach (keys %$assemblies) {
            my ($data_species, $assembly) = @{$ensembl_assemblies{$_}||[]};
            if ($assembly) {
              my $data = $session->add_data(
                  type        => 'url',
                  url         => $p,
                  species     => $data_species,
                  code        => join('_', md5_hex($n . $data_species . $assembly . $p), $session->session_id),
                  name        => $n,
                  format      => $format,
                  style       => $style,
                  assembly    => $assembly,
              );
            }
          }
        }
      } else {
        ## Either upload or attach the file, as appropriate
        my $command = EnsEMBL::Web::Command::UserData::AddFile->new({'hub' => $hub});
        ## Fake the params that are passed by the upload form
        $hub->param('text', $p);
        $hub->param('format', $format);
        $command->upload_or_attach($renderer);
        ## Discard URL param, as we don't need it once we've uploaded the file,
        ## and it only messes up the page URL later
        $hub->input->delete('url');
      }
      # We have to create a URL upload entry in the session
      my $message  = sprintf('Data has been attached to your display from the following URL: %s', encode_entities($p));
      $session->add_data(
          type     => 'message',
          function => '_info',
          code     => 'url_data:' . md5_hex($p),
          message  => $message,
      );
    } else {
      ($url, $renderer) = split /=/, $v;
      $renderer ||= 'normal';
      $self->update_track_renderer($url, $renderer, $hub->param('toggle_tracks'));
    }
  }
  
  if ($self->is_altered) {
    my $tracks = join(', ', @{$self->altered});
    $session->add_data(
      type     => 'message',
      function => '_info',
      code     => 'image_config',
      message  => "The link you followed has made changes to these tracks: $tracks.",
    );
  }
}

sub update_track_renderer {
  my ($self, $key, $renderer, $on_off, $force) = @_;
  my $node = $self->get_node($key);
  
  return unless $node;
  
  my $renderers = $node->data->{'renderers'};
  
  return unless $renderers;
  
  my %valid = @$renderers;
  my $flag  = 0;

  ## Set renderer to something sensible if user has specified invalid one. 'off' is usually first option, so take next one
  $renderer = $valid{'normal'} ? 'normal' : $renderers->[2] if $renderer ne 'off' && !$valid{$renderer};

  # if $on_off == 1, only allow track enabling/disabling. Don't allow enabled tracks' renderer to be changed.
  $flag += $node->set_user('display', $renderer, $force) if (!$on_off || $renderer eq 'off' || $node->get('display') eq 'off');
  my $text = $node->data->{'name'} || $node->data->{'coption'};

  $self->altered($text) if $flag;
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
  if ($node->set_user($species, { %{$node->get($species) || {}}, %{$diff->{'track_order'}} })) {
    my $text = $node->data->{'name'} || $node->data->{'coption'};
    $self->altered($text);
  }
  return $self->is_altered if $self->get_parameter('sortable_tracks') ne 'drag';
}

sub reset {
  my $self  = shift;
  my $reset = $self->hub->input->param('reset');
  my ($tracks, $order) = $reset eq 'all' ? (1, 1) : $reset eq 'track_order' ? (0, 1) : (1, 0);
  
  if ($tracks) {
    my $tree = $self->tree;
    
    foreach my $node ($tree, $tree->nodes) {
      my $user_data = $node->{'user_data'};
      
      foreach (keys %$user_data) {
        my $text = $user_data->{$_}{'name'} || $user_data->{$_}{'coption'};
        $self->altered($text) if $user_data->{$_}{'display'};
        delete $user_data->{$_}{'display'};
        delete $user_data->{$_} unless scalar keys %{$user_data->{$_}};
      }
    }
  }
  
  if ($order) {
    my $node    = $self->get_node('track_order');
    my $species = $self->species;
    
    if ($node->{'user_data'}{'track_order'}{$species}) {
      delete $node->{'user_data'}{'track_order'}{$species};
      delete $node->{'user_data'}{'track_order'} unless scalar keys %{$node->{'user_data'}{'track_order'}};

      $self->altered('Track order');
    }
  }
}

sub get_track_key {
  my ($self, $prefix, $obj) = @_;
  
  return if $obj->gene && $obj->gene->isa('Bio::EnsEMBL::ArchiveStableId');

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

  $missing->set('extra_height', 4) if $missing;
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
  $information->set('extra_height', 2) if $information;
  
  return { count => $count_missing, information => $info };
}

sub share {
  # Remove anything from user settings that is:
  #   Custom data that the user isn't sharing
  #   A track from a trackhub that the user isn't sharing
  #   Not for the species in the image
  # Reduced track order of explicitly ordered tracks if they are after custom tracks which aren't shared
  
  my ($self, %shared_custom_tracks) = @_;
  my $user_settings     = EnsEMBL::Web::Root->deepcopy($self->get_user_settings);
  my $species           = $self->species;
  my $user_data         = $self->get_node('user_data');
  my @unshared_trackhubs = grep $_->get('trackhub_menu') && !$shared_custom_tracks{$_->id}, @{$self->tree->child_nodes};
  my @user_tracks       = map { $_ ? $_->nodes : () } $user_data;
  my %user_track_ids    = map { $_->id => 1 } @user_tracks;
  my %trackhub_tracks    = map { $_->id => [ map $_->id, $_->nodes ] } @unshared_trackhubs;
  my %to_delete;
  
  foreach (keys %$user_settings) {
    next if $_ eq 'track_order';
    next if $shared_custom_tracks{$_};
    
    my $node = $self->get_node($_);
    
    $to_delete{$_} = 1 unless $node && $node->parent_node; # delete anything that isn't for this species
    $to_delete{$_} = 1 if $user_track_ids{$_};             # delete anything that isn't shared
  }
  
  foreach (@unshared_trackhubs) {
    $to_delete{$_} = 1 for grep $user_settings->{$_}, @{$trackhub_tracks{$_->id} || []};  # delete anything for tracks in trackhubs that aren't shared
  }

  # Reduce track orders if custom tracks aren't shared
  if (scalar keys %to_delete) {
    my %track_ids_to_delete = map {( $_ => 1, "$_.b" => 1, "$_.f" => 1 )} keys %to_delete, map { @{$trackhub_tracks{$_->id} || []} } @unshared_trackhubs;

    $user_settings->{'track_order'}{$species} = [ grep { !$track_ids_to_delete{$_->[0]} && !$track_ids_to_delete{$_->[1]} } @{$user_settings->{'track_order'}{$species}} ];
  }

  # remove track order for other species
  delete $user_settings->{'track_order'}{$_} for grep $_ ne $species, keys %{$user_settings->{'track_order'}};

  return $user_settings;
}

sub save_to_cache {
  my $self      = shift;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;

  if ($cache && $cache_key) {
    $self->_hide_user_data;

    my $defaults = {
      _tree       => $self->{'_tree'},
      _parameters => $self->{'_parameters'},
      extra_menus => $self->{'extra_menus'},
    };

    $cache->set($cache_key, $defaults, undef, 'IMAGE_CONFIG', $self->species);
    $self->_reveal_user_data;
  }
}

# Better than setting and resetting because it keeps the same reference
# when revealed which other objects may have cached.
sub _hide_user_data {
  my $tree = shift->tree;
  foreach ($tree, $tree->nodes) {
    $_->{'hidden_user_data'} = $_->{'user_data'} unless exists $_->{'hidden_user_data'};
    $_->{'user_data'} = {};
  }
}

sub _reveal_user_data {
  my $tree = shift->tree;
  foreach ($tree, $tree->nodes) {
    $_->{'user_data'} = delete $_->{'hidden_user_data'} || {};
  }
}

sub _clone_track {
  my ($self, $track, $id) = @_;

  my $clone       = $self->tree->create_node;
  $clone->{$_}    = $_ eq 'data' ? { %{$track->{'data'}} } : $track->{$_} for keys %$track; # Make a new hash for data, so keys can differ
  $clone->{'id'}  = $id if $id;

  return $clone;
}

1;
