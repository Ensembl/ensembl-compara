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

### Parent class for all the image configs (This class should not be instantiated)
### Most of the times, only 'init_cacheable' and 'init_non_cacheable' will need to be overridden in child classes

use strict;
use warnings;
no warnings "uninitialized";

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities decode_entities);
use URI::Escape qw(uri_unescape);
use JSON qw(from_json to_json);

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Exceptions qw(WebException);

use EnsEMBL::Draw::Utils::TextHelper;
use EnsEMBL::Draw::Utils::Transform;

use EnsEMBL::Web::DataStructure::DoubleLinkedList;

use EnsEMBL::Web::ImageConfigExtension::Nodes;
use EnsEMBL::Web::ImageConfigExtension::Tracks;
use EnsEMBL::Web::ImageConfigExtension::UserTracks;

use parent qw(EnsEMBL::Web::Config);

sub cache_code :Accessor;

# quick methods to get/set some of the parameters
sub font_face           { return shift->_parameter('font_face',       @_);  }
sub font_size           { return shift->_parameter('font_size',       @_);  }
sub image_height        { return shift->_parameter('image_height',    @_);  }
sub image_width         { return shift->_parameter('image_width',     @_);  }
sub container_width     { return shift->_parameter('container_width', @_);  }

sub core_object         { return $_[0]->hub->core_object($_[1]);                               }
sub colourmap           { return $_[0]->hub->colourmap;                                        }
sub databases           { return $_[0]->species_defs->get_config($_[0]->species, 'databases'); }
sub get_node            { return shift->tree->get_node(@_);                                    }

sub storable {
  ## Abstract method implementation
  shift->get_parameter('storable');
}

sub config_type {
  ## Abstract method implementation
  return 'image_config';
}

sub cache_key {
  ## override
  my $self        = shift;
  my $cache_key   = $self->SUPER::cache_key;
     $cache_key  .= '::'.$self->cache_code;

  return $cache_key;
}

sub _new {
  ## @override
  ## @param Hub object
  ## @param (String) Species
  ## @param (String) Type
  ## @param (String) Cache Code
  my ($class, $hub, $species, $type, $cache_code) = @_;

  my $self = $class->SUPER::_new($hub, $species, $type);

  $self->{'code'}             = $type;        # TODO - remove usage of code as type in the subclasses
  $self->{'cache_code'}       = $cache_code;  # TODO - remove this once above is done
  $self->{'_parameters'}      = {}, # hash to contain all parameters
  $self->{'track_order'}      = []; # state changes for track order as saved in db
  $self->{'user_track_count'} = 0;
  $self->{'userdata_threshold'}   = $hub->species_defs->USERDATA_THRESHOLD || 20;
  $self->{'default_trackhub_tracks'} = {};

  return $self;
}

sub init_cacheable {
  ## Abstract method implementation
  ## Override this method to add menus and tracks and to set any default parameters
  my $self  = shift;
  my $style = $self->species_defs->ENSEMBL_STYLE || {};

  # Set default parameters for all image configs
  $self->set_parameters({
    'storable'          => 1,               # changes can be stored in session records?
    'image_resizeable'  => 0,               # is image resizing allowed?
    'can_trackhubs'     => 0,               # can the image display trackhub tracks?
    'no_labels'         => 0,               # should we ignore the labels?
    'multi_species'     => 0,               # is it a multi species image?
    'margin'            => 5,
    'spacing'           => 2,
    'label_width'       => 130,             # width of the labels on the left hand side of the image
    'slice_number'      => '1|1',
    'bgcolor'           => 'background1',
    'top_toolbar'       => 1,
    'bottom_toolbar'    => 0,
    'font_face'         => $style->{'GRAPHIC_FONT'} || 'Arial',
    'font_size'         => ($style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'}) || 20,
  });

  # Add extra menus
  $self->add_extra_menu(qw(
    active_tracks
    favourite_tracks
    search_results
    display_options
  ));
}

sub init_non_cacheable {
  ## Abstract method implementation
  ## Override this method to add menus and tracks that do not exist in all cases, or modify the ones already present if needed, or to modify any request specific parameters
  my $self  = shift;
  my $hub   = $self->hub;

  # Image width depends upon browser/user settings
  $self->set_parameter('image_width', $hub->image_width);

  # Sortable tracks depend upon browser version
  my $sortable = $self->get_parameter('sortable_tracks');
  $self->set_parameter('sortable_tracks', 1) if $sortable eq 'drag' && $hub->ie_version && $hub->ie_version < 7; # No sortable tracks on images for IE6 and lower
  $self->add_extra_menu('track_order') if $sortable;

  # Add user defined data sources
  $self->load_user_tracks;
  $self->display_threshold_message;

  # Combine info and decorations into a single menu
  my $decorations = $self->get_node('decorations') || $self->get_node('other');
  my $information = $self->get_node('information');

  if ($decorations && $information) {
    $decorations->set_data('caption', 'Information and decorations');
    $decorations->append_children(@{$information->child_nodes});
    $information->remove;
  }
}

sub apply_user_settings {
  ## Abstract method implementation
  my $self          = shift;
  my $hub           = $self->hub;
  my $species       = $self->species;
  my $user_settings = $self->get_user_settings;

  # no user setting to apply to the tracks
  return unless keys %$user_settings;

  # copy track order
  $self->{'track_order'} = $user_settings->{'track_order'} && $user_settings->{'track_order'}{$species} || [];

  foreach my $track_key (keys %{$user_settings->{'nodes'} || {}}) {

    my $node = $self->get_node($track_key);

    ## Filthy hack for merging the two regulation matrices
    my $real_key = $track_key;
    if ($track_key =~ /reg_feats_non_core/ && !$node) {
      ## All regulation tracks are now attached to the core node, even if they're non-core
      $track_key =~ s/non_//;
      $node = $self->get_node($track_key);
    }

    # track doesn't exist, move the data aside temporarily (it could be a track on another species, or externally attached one)
    if (!$node) {
      $user_settings->{'_missing_nodes'}{$track_key} = delete $user_settings->{'nodes'}{$track_key};
      next;
    }

    my $data = $user_settings->{'nodes'}{$real_key} || {};
    next unless keys %$data; # no changes to this track

    # add track specific user data to the corresponding track node
    while (my ($setting, $value) = each %$data) {

      # if changing the track renderer
      if ($setting eq 'display') {
        $self->update_track_renderer($node, $value // '');
      } else {
        $node->set_user_setting($setting, $value) if defined $value;
      }
    }
  }
}

sub apply_user_cache_tags {
  ## @override
  ## Add an extra cache tag for user data
  my $self  = shift;
  my $menu  = $self->get_node('user_data');

  # get image_config cache tag
  $self->SUPER::apply_user_cache_tags;

  # set user_data cache tag
  if ($menu && $menu->has_child_nodes) {
    $self->hub->controller->add_cache_tags({'user_data' => sprintf('USER_DATA[%s]', md5_hex(join '|', map $_->id, @{$menu->get_all_nodes}))});
  }
}

sub get_cacheable_object {
  ## Abstract method implementation
  my $self    = shift;
  my $object  = { map { $_ => $self->{$_} } qw(code _parameters species type _extra_menus _tree) };

  return $object;
}

sub reset_user_settings {
  ## Abstract method implementation
  my $self          = shift;
  my $reset_type    = shift || '';
  my $params        = shift || {};
  my $menu_ids      = $params->{'menu_ids'} ? from_json($params->{'menu_ids'}) : [];
  my $user_settings = $self->get_user_settings;
  my ($reset_tracks, $reset_order);
  my @altered;

  if ($reset_type eq 'matrix') {
    # Reset all reg matrix tracks
    my %node_keys;
    if ($user_settings->{'nodes'}) {
      %node_keys = %{$user_settings->{'nodes'}};
    }
    if ($self->{'default_trackhub_tracks'}) {
      %node_keys = (%node_keys, %{$self->{'default_trackhub_tracks'}});
    }

    foreach my $node_key (keys %node_keys) {
      if ($node_key =~/^reg_feats|^seg_Segmentation|^trackhub_/) {
        if (my $node = $self->get_node($node_key)) {
          # For trackhubs we turn off all tracks and then update the selected ones.
          # If you do a reset it will reset to default renderers which makes it turn on.
          if ($node_key =~ /^trackhub_/ ) {
            foreach my $menu_id (@$menu_ids) {
              if (index($node_key, $menu_id) > -1) {
                $self->update_track_renderer($node, 'off');
              }
            }
          }
          else {
            $node->reset_user_settings;
          }
          push @altered, $node->get_data('name') || $node->get_data('caption') || 1;
        }
      }
    }
  }
  else {
    ($reset_tracks, $reset_order) = $reset_type eq 'all' ? (1, 1) : ($reset_type eq 'track_order' ? (0, 1) : (1, 0));
  }

  if ($reset_order && @{$self->{'track_order'}}) {
    $self->{'track_order'} = [];
    push @altered, 'Track order';
  }

  if ($reset_tracks) {
    foreach my $node_key (keys %{$user_settings->{'nodes'} || {}}) {
      if (my $node = $self->get_node($node_key)) {
        $node->reset_user_settings;
        push @altered, $node->get_data('name') || $node->get_data('caption') || 1;
      }
    }

    push @altered, 1 if delete $user_settings->{'_missing_nodes'}; # remove the data from other missing nodes too
  }

  return @altered;
}

sub config_url_params {
  ## Abstract method implementation
  return $_[0]->type;
}

sub update_from_url {
  ## Abstract method implementation
  my ($self, $params) = @_;

  foreach my $key_val (grep $_, split(/,/, $params->{$self->type} || '')) {
    $self->altered($self->update_track_renderer(split /=/, $key_val));
  }

  $self->save_user_settings if $self->is_altered;

  if ($self->is_altered) {
    my $tracks = join(', ', grep $_ ne '1', @{$self->altered});
    $self->hub->session->set_record_data({
      'type'      => 'message',
      'function'  => '_info',
      'code'      => 'image_config',
      'message'   => "The link you followed has made changes to these tracks: $tracks.",
    });
  }
  return $self->is_altered;
}

sub update_from_input {
  ## Abstract method implementation
  my ($self, $params) = @_;

  # if user is resetting the configs
  if (my $reset = $params->{'reset'}) {

    $self->altered($self->reset_user_settings($reset));

  } else {
    my $diff = delete $params->{$self->config_type};

    # Reset regulation matrix tracks by default
    if ($params->{'matrix'} == 1) {
      $self->altered($self->reset_user_settings('matrix', $params));
    }

    if (keys %$diff) {

      # update renderers
      foreach my $track_key (grep exists $diff->{$_}{'renderer'}, keys %$diff) {
        $self->altered($self->update_track_renderer($track_key, $diff->{$track_key}{'renderer'}));
      }

      # update track order
      if ($diff->{'track_order'}) {
        $self->reset_user_settings('track_order');
        $self->altered('Track order') if $self->update_track_order(@{$diff->{'track_order'}});
      }

      # update favourite tracks
      if (my @fav_setting = grep exists $diff->{$_}{'favourite'}, keys %$diff) {
        $self->altered(1) if $self->update_favourite_tracks({ map { $_ => $diff->{$_}{'favourite'} || 0 } @fav_setting });
      }

      ## update graph axes
      foreach my $track_key (keys %$diff) {
        if (exists $diff->{$track_key}{'y_min'} || exists $diff->{$track_key}{'y_max'}) {
          $self->altered($self->update_track_axes($track_key, $diff->{$track_key}{'y_min'}, $diff->{$track_key}{'y_max'}));
        }
      }

    } else {

      # TODO - is it in use?
      if (exists $params->{'track'} && (my $node = $self->get_node(delete $params->{'track'}))) {
        $self->altered(1) if $node->set_user_setting('userdepth', delete $params->{'depth'});
      }

      # update favourite tracks
      my %fav = map { $params->{$_} =~ /favourite_(on|off)/ ? ($_ => $1 eq 'on' ? 1 : 0) : () } keys %$params;
      if (keys %fav) {
        delete $params->{$_};
        $self->altered(1) if $self->update_favourite_tracks(\%fav);
      }

      # update track highlights
      my %hl_track = map { $params->{$_} =~ /highlight_(on|off)/ ? ($_ => $1 eq 'on' ? 1 : 0) : () } keys %$params;
      if (keys %hl_track) {
        delete $params->{$_};
        $self->altered(1) if $self->update_track_highlights(\%hl_track);
      }

      # update renderers if any param's left
      $self->altered($self->update_track_renderer($_, $params->{$_})) for keys %$params;
    }
  }

  $self->save_user_settings if $self->is_altered;

  return $self->is_altered;
}

sub update_track_renderer {
  ## Updated renderer for a given track
  ## @param Track node or Track key
  ## @param Renderer string
  ## @return Track name if renderer changed
  my ($self, $node, $renderer) = @_;

  $node = $self->get_node($node) unless ref $node;
  return unless $node;

  if (my $renderers = $node->get_data('renderers')) {

    my %valid = @$renderers;

    # Set renderer to something sensible if user has specified invalid one. 'off' is usually first option, so take next one
    $renderer = $valid{'normal'} ? 'normal' : $renderers->[2] if $renderer ne 'off' && !$valid{$renderer};

    if ($node->set_user_setting('display', $renderer)) {
      return $node->get_data('name') || $node->get_data('caption') || 1;
    }
  }
}

sub update_track_axes {
  ## Updated axes for a given track
  ## @param Track key
  ## @param y_min float
  ## @param y_max float
  ## @return Track name if renderer changed
  my ($self, $key, $y_min, $y_max) = @_;

  my $record;
  if ($key =~ /^(upload|url)_/) {
    my ($type, $code, $record_id) = split('_', $key);
    $record = $self->hub->session->get_record_data({'type' => $type, 'code' => sprintf '%s_%s', $code, $record_id});
    if ($record) {
      $record->{'y_min'} = $y_min if defined $y_min;
      $record->{'y_max'} = $y_max if defined $y_max;
      $self->hub->session->set_record_data($record);
      return $record->{'name'} || 1;
    }
  }
  else {
    my $node = $self->get_node($key);
    my $user_data = $node->tree->user_data;
    my $id        = $node->id;
    my $updated = 0;
    ## N.B. Don't use 'set_user_setting' method here, as axes might not be set yet
    if (defined $y_min) {
      $user_data->{$id}{'y_min'} = $y_min;
      $updated = 1;
    }
    if (defined $y_max) {
      $user_data->{$id}{'y_max'} = $y_max;
      $updated = 1;
    }
    if ($updated) {
      return $node->get_data('name') || $node->get_data('caption') || 1;
    }
  }
}

sub update_favourite_tracks {
  ## Update favourite track list for the user
  ## @param Hashref with keys as track names and values as 1 or 0 accordingly to set/unset favourite tracks
  ## @return 1 if settings changed, 0 otherwise
  my ($self, $updated_fav) = @_;

  my $fav_tracks  = $self->_favourite_tracks;
  my $altered     = 0;
  foreach my $track_key (keys %$updated_fav) {
    if ($updated_fav->{$track_key}) {
      if (!$fav_tracks->{$track_key}) {
        $fav_tracks->{$track_key} = 1;
        $altered = 1;
      }
    } else {
      if (exists $fav_tracks->{$track_key}) {
        delete $fav_tracks->{$track_key};
        $altered = 1;
      }
    }
  }

  return $altered;
}


sub update_track_highlights {
  ## Update track highlight list for the user
  ## @param Hashref with keys as track names and values as 1 or 0 accordingly to set/unset track highlights
  ## @return 1 if settings changed, 0 otherwise
  my ($self, $updated_tr_hl) = @_;

  my $user_settings  = $self->get_user_settings;
  my $altered     = 0;
  foreach my $track_key (keys %$updated_tr_hl) {
    my $node = $self->get_node($track_key);

    if ($node && $updated_tr_hl->{$track_key}) {
      if (!$node->get('track_highlight')) {
        if ($node->set_user_setting('track_highlight', 1)) {
          $altered = 1;          
        }
      }
    } else {
      if ($node) {
        $node->delete_user_setting('track_highlight');;
        $altered = 1;
      }
    }
  }

  return $altered;
}

sub update_track_order {
  ## Updates track order for the image
  ## @params Track order changes (array of arrayrefs [ track1, prev_track1 ], [ track2, prev_track2 ], ... )
  my $self = shift;

  push @{$self->{'track_order'}}, @_;

  return 1;
}

sub _favourite_tracks {
  ## @private
  ## Gets a list of tracks favourited by the user (as saved in session/user record)
  ## List of favourite tracks is not specific to one image config - if a track exists in multiple images and is favourited in one, it gets favourited in all
  my $self = shift;

  $self->{'_favourite_tracks'} ||= $self->hub->session->get_record_data({'type' => 'favourite_tracks', 'code' => 'favourite_tracks'});
  return $self->{'_favourite_tracks'} || {};
}

sub is_track_favourite {
  ## Tells if a given track is marked favourite by the user
  ## @param Track name
  ## @return 0 or 1 accordingly
  my ($self, $track) = @_;
  return $self->_favourite_tracks->{$track} ? 1 : 0;
}

sub is_track_highlighted {
  ## Tells if a given track is highlighted by the user
  ## @param Track name
  ## @return 0 or 1 accordingly
  my ($self, $track) = @_;
  return $self->get_user_settings->{'nodes'}{$track}{'track_highlight'} ? 1 : 0;
}

sub save_user_settings {
  ## @override
  ## Before saving record, modify record data according to the changed nodes on tree
  ## Also save favourite tracks record along with main config data record
  my $self          = shift;
  my $hub           = $self->hub;
  my $fav_data      = $self->_favourite_tracks;
  my $user_data     = $self->tree->user_data;
  my $record_data   = $self->get_user_settings;
  #use Data::Dumper;
  #$Data::Dumper::Sortkeys = 1;
  #$Data::Dumper::Maxdepth = 2;
  #warn ">>> RECORD DATA: ".Dumper($record_data);

  # Save the favourite record (this record is shared by other image configs, so doesn't have code set as the current image config's name)
  $hub->session->set_record_data({ %$fav_data, 'type' => 'favourite_tracks', 'code' => 'favourite_tracks' });

  # Move data for the missing nodes to the main 'nodes' key before saving
  $record_data->{'nodes'} = delete $record_data->{'_missing_nodes'} || {};

  # Copy user setting from the tree back to the record data
  $record_data->{'nodes'}{$_} = $user_data->{$_} for keys %$user_data;

  # Save track order
  $record_data->{'track_order'}{$self->species} = $self->{'track_order'};

  return $self->SUPER::save_user_settings(@_);
}

sub set_parameters {
  ## Sets multiple parameter values at once
  ## @param Hashref containing keys and values of the params
  my ($self, $params) = @_;
  $self->{'_parameters'}{$_} = $params->{$_} for keys %$params;
}

sub set_parameter {
  ## Sets a parameter value
  ## @param Parameter name
  ## @param Parameter value
  my ($self, $key, $value) = @_;
  $self->{'_parameters'}{$key} = $value;
}

sub get_parameter {
  ## Gets a parameter value
  ## @param Parameter name
  my ($self, $key) = @_;
  return $self->{'_parameters'}{$key} // '';
}

sub _parameter {
  ## @private
  ## Gets (or sets non-zero value to) the given parameter
  ## @param Parameter name
  ## @param (Optional) Non-zero parameter value
  my ($self, $key, $value) = @_;
  $self->set_parameter($key, $value) if $value;
  return $self->get_parameter($key);
}

sub add_extra_menu {
  ## Adds extra menu item
  ## @params List of menu names
  my $self = shift;

  $self->{'_extra_menus'} ||= {};
  $self->{'_extra_menus'}{$_} = 1 for @_;
}

sub remove_extra_menu {
  ## Removes an extra menu item
  ## @params List of menu names (removes all if no argument provided)
  my $self = shift;

  delete $self->{'_extra_menus'}{$_} for @_ ? @_ : keys %{$self->{'_extra_menus'}};
}

sub has_extra_menu {
  ## Check whether the given extra menu is present
  ## @param Menu name
  ## @return 0 or 1 accordingly
  my ($self, $menu_name) = @_;
  return $self->{'_extra_menus'}{$menu_name} || 0;
}

sub modify_configs {
  ## Modifies given config data on multiple track nodes at once
  ## @param Arrayref of node ids
  ## @param Hasref of configs to be updated with keys as config name and value as new value to be set
  my ($self, $node_ids, $config) = @_;

  foreach my $node (map { $self->get_node($_) || () } @$node_ids) {
    foreach my $track (grep $_->get_data('node_type') eq 'track', $node, @{$node->get_all_nodes}) {
      $track->set_data($_, $config->{$_}) for keys %$config;
    }
  }
}

sub get_sortable_tracks {
  ## Get a list of all sortable tracks (after applying user sorting and display preferences)
  ## @param (Optional) if true, will return only the ones that are not hidden
  my ($self, $no_hidden) = @_;
  return grep {
    $_->get_data('sortable') && $_->get_data('menu') ne 'no' && ($no_hidden ? $_->get('display') ne 'off' : 1)
  } @{$self->glyphset_tracks};
}

sub orientation {
  ## Tell about the orientation of the image - ie. horizontal or vertical
  return 'horizontal';
}

sub transform_object {
  ## Gets the Transform object needed by the drawing code to draw the final image
  my $self = shift;

  $self->{'_transform_object'} ||= EnsEMBL::Draw::Utils::Transform->new;
}

sub texthelper {
  ## Gets the TextHelper object needed by the drawing code
  my $self = shift;

  $self->{'_texthelper'} ||= EnsEMBL::Draw::Utils::TextHelper->new({'scalex' => 1, 'scaley' => 1});
}

sub menus {
  ## Gets the menus for the image configs (see method add_menus for it's usage)
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
    longreads           => [ 'Long reads',             'gene_transcript' ],
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
    pairwise_cactus_hal_pw => [ 'Progressive cactus pairwise','compara' ],
    synteny             => 'Synteny',

    # Other features
    repeat              => 'Repeat regions',
    oligo               => 'Oligo probes',
    genome_targeting    => 'Genome targeting',
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

sub unsortable_menus {
  ## Menus nodes for the tracks that can not be sorted by the user
  ## @return Hashref with keys as the menu names
  return [qw(decorations information options other)];
}

sub get_tracks {
  ## Gets a list of all the track nodes
  my @tracks = grep { ($_->get_data('node_type') || '') eq 'track' } $_[0]->tree->nodes;
  return \@tracks;
}

sub _order_tracks_by_sections {
  ## @private
  ## Order a list of given tracks by track sections to keep tracks from same section next to each other
  ## @param Arrayref of tracks to be ordered
  ## @param Arrayref of ordered tracks
  my ($self, $tracks) = @_;

  my (%sections, @ordered);

  foreach my $track (@$tracks) {

    my $section = $track->get_data('section');

    if ($section) {

      if (!exists $sections{$section}) {
        $sections{$section} = [];
        push @ordered, $sections{$section};
      }

      push @{$sections{$section}}, $track;

    } else {
      push @ordered, $track;
    }
  }

  @ordered = map { ref $_ eq 'ARRAY' ? @$_ : $_ } @ordered;

  return \@ordered;
}

sub _order_tracks_by_strands {
  ## @private
  ## Order a list of given tracks by track strands (and creates duplicate tracks for dual stranded ones)
  ## @param Arrayref of tracks to be ordered
  ## @param Arrayref of ordered tracks
  my ($self, $tracks) = @_;

  my @ordered;

  foreach my $track (@$tracks) {

    my $strand = $track->get_data('strand');

    # append to the start of the list
    if ($strand eq 'f') {
      unshift @ordered, $track;

    # append to the end of the list
    } elsif ($strand eq 'r') {
      push @ordered, $track;

    # create an extra clone track and add one to the start and other to the end
    } else {
      my $clone = $track->parent_node->prepend_child($self->tree->clone_node($track));

      $clone->set_data('drawing_strand', 'f');
      $track->set_data('drawing_strand', 'r');

      unshift @ordered, $clone;
      push    @ordered, $track;
    }
  }

  return \@ordered;
}

sub glyphset_tracks {
  ## Gets the ordered list of tracks that need be drawn on the image
  ## @return Array of track nodes
  my $self = shift;

  if (!$self->{'_glyphset_tracks'}) {

    # Get tracks ordered by sections and strands
    my $tracks = $self->_order_tracks_by_strands($self->_order_tracks_by_sections($self->get_tracks));

    # User sortable image?
    if ($self->get_parameter('sortable_tracks')) {

      # Add sortable flag to each track
      my %unsortable_menus = map { $_ => 1 } @{$self->unsortable_menus};
      for (@$tracks) {
        next if $_->get_data('sortable'); # if it's already configured as sortable in the configs, don't change it
        $_->set_data('sortable', $unsortable_menus{$_->parent_node->id} ? 0 : 1);
      }

      # sort the tracks according to user preferences
      my $user_track_order = $self->{'track_order'};
      if (@$user_track_order) {

        my ($pointer, $first_track, $last_immovable_track, %lookup, $glyphset_tracks);

        # make a 'double linked list' to make it easy to apply user sorting on it
        $first_track = EnsEMBL::Web::DataStructure::DoubleLinkedList->from_array($tracks);

        # add all qualifying tracks to the lookup
        $pointer = $first_track;
        while ($pointer) {
          my $track = $pointer->node;

          if ($track->get_data('sortable')) {
            $lookup{ join('.', $track->id, $track->get_data('drawing_strand') || ()) } = $pointer;
          } else {
            if (!scalar keys %lookup) { # if we haven't found any sortable tracks yet, and the current one isn't sortable, then save the current pointer as last immovable track
              $last_immovable_track = $pointer;
            }
          }

          $pointer = $pointer->next;
        }

        # go through the state changes made by the user, one by one, and reorder the tracks accordingly
        for (@$user_track_order) {
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
        $tracks = $first_track->to_array({'unlink' => 1});
      }

      # Set the 'order' key according to the final order
      my $order = 1;
      $_->set_data('order', $order++) for @$tracks;
    }

    $self->{'_glyphset_tracks'} = $tracks;
  }

  return $self->{'_glyphset_tracks'};
}

sub get_shareable_settings {
  ## @override
  ## Add custom uplaoded/url tracks to the shareable data
  my $self            = shift;
  my $share_settings  = $self->SUPER::get_shareable_settings;
  my $hub             = $self->hub;
  my $record_owners   = {'user' => $hub->user, 'session' => $hub->session};
  my @data_menus      = $self->get_shareable_nodes;

  my (%share_data, %done_record);

  foreach my $data_menu (@data_menus) {
    my $parent_linked_record = $data_menu->get_data('linked_record');

    foreach my $track (@{$data_menu->get_all_nodes}) {
      my $linked_record = $track->get_data('linked_record') || $parent_linked_record;

      next unless $linked_record;

      # if track is turned off the user, we can skip sharing the linked user data record
      if ($track->get('display') eq 'off') {

        # user has set track display 'off' - if the default is also 'off', it would be a redundant setting to share
        delete $share_settings->{'nodes'}{$track->id} if $share_settings->{'nodes'} && $track->get_data('display') eq 'off';

      } else {

        my $key = join '-', $linked_record->{'record_type'}, $linked_record->{'type'}, $linked_record->{'code'};

        next if $done_record{$key};
        $done_record{$key} = 1;

        $key = md5_hex($key);

        my $record = $record_owners->{$linked_record->{'record_type'}}->record({'type' => $linked_record->{'type'}, 'code' => $linked_record->{'code'}});
        if ($record) {
          $share_data{$key} = $record->data->raw;
          $share_data{$key}{'type'}   = $record->type;
          $share_data{$key}{'code'}   = $record->code;
          $share_data{$key}{'shared'} = 1;
        }
      }
    }
  }

  $share_settings->{'user_data'} = \%share_data if keys %share_data;

  return $share_settings;
}

sub receive_shared_settings {
  ## @override
  ## Adds custom track list
  my ($self, $settings) = @_;

  my $session   = $self->hub->session;
  my $user_data = delete $settings->{'user_data'};

  $self->hub->session->set_record_data($user_data->{$_}) for keys %{$user_data || {}};

  return $self->SUPER::receive_shared_settings($settings);
}

sub get_shareable_nodes {
  ## Gets the nodes for user data that can be shared with other users
  ## @return List of nodes that contain user data
  my $self  = shift;
  my @nodes = ($self->get_node('user_data') || ());

  push @nodes, grep $_->get_data('trackhub_menu'), $self->tree->nodes if $self->get_parameter('can_trackhubs');

  return @nodes;
}

sub cache {
  my $self = shift;
  my $key  = shift;
  $self->{'_cache'}{$key} = shift if @_;
  return $self->{'_cache'}{$key}
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

sub _update_missing {
  my ($self, $object) = @_;
  my $species_defs    = $self->species_defs;
  my $count_missing   = grep { !$_->get('display') || $_->get('display') eq 'off' } @{$self->get_tracks};
  my $missing         = $self->get_node('missing');

  $missing->set_data('extra_height', 4) if $missing;
  $missing->set_data('text', $count_missing > 0 ? "There are currently $count_missing tracks turned off." : 'All tracks are turned on') if $missing;

  my $info = sprintf(
    '%s %s version %s.%s (%s) %s: %s - %s',
    $species_defs->ENSEMBL_SITETYPE,
    $species_defs->SPECIES_SCIENTIFIC_NAME,
    $species_defs->ENSEMBL_VERSION,
    $species_defs->SPECIES_RELEASE_VERSION,
    $species_defs->ASSEMBLY_NAME,
    $object->seq_region_type_and_name,
    $object->thousandify($object->seq_region_start),
    $object->thousandify($object->seq_region_end)
  );

  my $information = $self->get_node('info');
  $information->set_data('text', $info) if $information;
  $information->set_data('extra_height', 2) if $information;

  return { count => $count_missing, information => $info };
}

################ Deprecated methods

sub legend :Deprecated('ImageConfig::legend - where is it called?') {
  ## Gets the current legend settings
  ## TODO - is being used?
  my $self = shift;

  return $self->{'_legend'} ||= { '_settings' => { 'max_length' => 0 } };
}

sub add_to_legend :Deprecated('ImageConfig::add_to_legend - where is it called?') {
  ## Add a track's legend entries to the master legend
  ## TODO - is being used?
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

sub get_config        :Deprecated('Use species_defs->get_config') { return $_[0]->species_defs->get_config($_[0]->species, $_[1]); }
sub glyphset_configs  :Deprecated('Use glyphset_tracks')          { return shift->glyphset_tracks(@_); }

1;
