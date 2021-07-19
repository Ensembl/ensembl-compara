=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::IOWrapper;

### A lightweight interpreter layer on top of the ensembl-io parsers, 
### providing the extra functionality required by the website

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(max first);

use Bio::EnsEMBL::IO::Parser;
use Bio::EnsEMBL::IO::Utils;

use EnsEMBL::Draw::Utils::ColourMap;

use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_use);

sub new {
  ### Constructor
  ### Instantiates a parser for the appropriate file type 
  ### and opens the file for reading
  ### @param file EnsEMBL::Web::File object
  my ($class, $self) = @_;

  $self->{'greyscale'} = [qw(e2e2e2 c6c6c6 aaaaaa 8d8d8d 717171 555555 383838 1c1c1c 000000)]; 

  ## 'Nearest' should be relative to the size of the genome
  my $scale = 1;
  if ($self->{'hub'}) {
    my $species = $self->{'species'} || $self->{'hub'}->species;
    $scale = $self->{'hub'}->species_defs->get_config($species, 'ENSEMBL_GENOME_SIZE');
    $scale = 1 if $scale == 0;
  }
  $self->{'nearest_window_size'} = 100000 * $scale; 

  bless $self, $class;  
  return $self;
}

sub colourset { return 'userdata'; }

sub open {
  ## Factory method - creates a wrapper of the appropriate type
  ## based on the format of the file given
  my ($file, %args) = @_;

  my %format_to_class = Bio::EnsEMBL::IO::Utils::format_to_class;
  my $format          = $file->get_format;
  my $subclass        = $format_to_class{$format};

  my $wrapper = {
                  'file'   => $file, 
                  'format' => $format,
                  %args,
                };
  my $class;

  if ($subclass) {
    $class = 'EnsEMBL::Web::IOWrapper::'.$subclass;

    if (dynamic_use($class, 1)) {
      my $parser;
      if ($file->source eq 'url') {
        my $result = $file->read;
          if ($result->{'content'}) {
          $parser = Bio::EnsEMBL::IO::Parser::open_content_as($format, $result->{'content'});
        }
      }
      else {
        ## Open file from where we wrote to, otherwise it can cause issues
        $parser = Bio::EnsEMBL::IO::Parser::open_as($format, $file->absolute_write_path);
      }

      if ($parser) {
        $wrapper->{'parser'} = $parser;
      } 
    } 
  }
  else {
    ## Unparsed uploads, e.g. VEP results filter
    $class = 'EnsEMBL::Web::IOWrapper::'.$format;
    $class = undef unless (dynamic_use($class, 1));
  }

  return $wrapper ? $class->new($wrapper) : {};
}

sub parser {
  ### a
  my $self = shift;
  return $self->{'parser'};
}

sub file {
  ### a
  my $self = shift;
  return $self->{'file'};
}

sub format {
  ### a
  my ($self, $format) = @_;
  $self->{'format'} = $format if $format;
  return $self->{'format'};
}

sub hub {
  ### a
  my $self = shift;
  return $self->{'hub'};
}

sub config_type {
  ### a
  my $self = shift;
  return $self->{'config_type'};
}

sub track {
  ### a
  my $self = shift;
  return $self->{'track'};
}

sub convert_to_gradient {
### Convert a 0-1000 score to a value on a colour gradient
### Default is greyscale
  my ($self, $score, $colour, $steps, $min, $max) = @_;
  $steps ||= 10;

  ## Default to black
  $score = 1000 unless defined($score);
  $score = 1000 if $score eq 'INF';
  $score = 0    if $score eq '-INF';

  my @gradient = @{$self->{'gradient'}||[]};

  unless (scalar @gradient) {
    if ($colour) {
      if (ref $colour eq 'ARRAY') {
        @gradient = $self->create_gradient($colour, $steps);
      }
      else {
        @gradient = $self->create_gradient(['white', $colour], $steps);
      }
    }
    else {
      @gradient = @{$self->{'greyscale'}||[]};
    }
    $self->{'gradient'} = \@gradient;
  }

  my $value;

  my $interval = 1000 / $steps;
  $min ||= $interval;
  $max ||= 1000 - $interval;

  if ($score <= $min) {
    $value = $gradient[0];
  }
  elsif ($score >= $max) {
    $value = $gradient[-1];
  }
  else {
    my $step = $score / $interval;
    $value = $gradient[$step];
  }
  return $value; 
}

sub create_gradient {
### Simple wrapper around colourmap function. Parameters are optional, as the method
### defaults to a 10-step greyscale
### @param colours ArrayRef (optional) - at least two colours to mix
### @param steps Integer (optional) - number of steps in the scale
  my ($self, $colours, $steps) = @_;
  unless ($colours && ref $colours eq 'ARRAY') {
    $colours = [qw(white black)];
  }
  $steps ||= 10;
  my $colourmap = new EnsEMBL::Draw::Utils::ColourMap;
  my @gradient = $colourmap->build_linear_gradient($steps, $colours);
  return @gradient;
}

sub create_tracks {
### Loop through the file and create one or more tracks
### Orders tracks by priority value if it exists
### @param slice (optional) - Bio::EnsEMBL::Slice object
### @param extra_config (optional) Hashref - additional configuration e.g. default colours
### @return arrayref of one or more hashrefs containing track information 
  my ($self, $slice, $extra_config) = @_;
  my $hub         = $self->hub;
  my $parser      = $self->parser;
  my $strandable  = !!$self->parser->can('get_strand');
  my $data        = {};
  my $order       = [];
  my $prioritise  = 0;
  my $bins        = $extra_config->{'bins'};
  my $slices      = {};
  my $bin_sizes   = {};

  my $seq_region_names = [];
  my $drawn_chrs  = $hub->species_defs->get_config($hub->data_species, 'ENSEMBL_CHROMOSOMES');
  my $adaptor     = $hub->get_adaptor('get_SliceAdaptor');

  if ($slice) {
    my $chr = $slice->seq_region_name;
    $seq_region_names = [$chr];
    if ($bins) {
      $bin_sizes->{$chr} = $slice->length / $bins; 
    }
    ## Allow for seq region synonyms
    if ($extra_config->{'use_synonyms'}) {
      push @$seq_region_names, map {$_->name} @{ $slice->get_all_synonyms };
    }
  }
  else {
    ## Sort out chromosome info
    foreach my $chr (@$drawn_chrs) {
      push @$seq_region_names, $chr;
      my $slice = $adaptor->fetch_by_region('toplevel', $chr);
      ## Cache the slice temporarily, as we may need it later
      $slices->{$chr} = $slice;
      if ($bins) {
        $bin_sizes->{$chr} = $slice->length / $bins; 
      }
      ## Allow for seq region synonyms
      if ($extra_config->{'use_synonyms'}) {
        push @$seq_region_names, map {$_->name} @{ $slice->get_all_synonyms };
      }
    }
  }

  my $max_seen = -1;
  ## We already fetched the data in the child module in one fell swoop!
  if ($parser->can('cache') && $parser->cache->{'summary'}) {
    my $track_key = $self->build_metadata($parser, $data, $extra_config, $order);
    my $metadata  = $data->{$track_key}{'metadata'};
    $prioritise   = 1 if $metadata->{'priority'};

    my $raw_features  = $parser->cache->{'summary'} || [];
    my $features      = [];
    my $max_score     = 0;
    my $min_score     = 0;

    foreach my $f (@$raw_features) {
      my ($seqname, $start, $end, $score) = @$f;
      ## Skip features that lie outside the current slice
      next if (!(first {$seqname eq $_} @$seq_region_names)
                || $end < $slice->start || $start > $slice->end);
      push @$features, {
                        'seq_region' => $seqname,
                        'start'      => $start,
                        'end'        => $end,
                        'score'      => $score,
                        'colour'     => $metadata->{'colour'},
                        };
      if ($score && $score !~ /,/) { ## Ignore pairwise "scores" that are RGB colours
        $max_score = $score if $score >= $max_score; 
        $min_score = $score if $score <= $min_score; 
      }
    }
    $data->{$track_key}{'metadata'}{'max_score'} = $max_score;
    $data->{$track_key}{'metadata'}{'min_score'} = $min_score;

    $data->{$track_key}{'features'} = $features;
  }
  else {
    while ($parser->next) {
      my $track_key = $self->build_metadata($parser, $data, $extra_config, $order);
      my %metadata  = %{$data->{$track_key}{'metadata'}||{}};
      $prioritise   = 1 if $metadata{'priority'};

      ## Set up density bins if needed
      if (!$bins && !keys %{$data->{$track_key}{'bins'}}) {
        foreach my $chr (keys %$bin_sizes) {
          $data->{$track_key}{'bins'}{$chr}{$_} = 0 for 1..$bins;
        }
      }

      my ($seqname, $start, $end) = $self->coords;
      my $strand = $strandable ? $self->parser->get_strand : 0;
      if ($slice && $extra_config->{'pix_per_bp'} && $extra_config->{'skip_overlap'}) {
        ## Skip if already have something on this pixel
        my $here = int($start*$extra_config->{'pix_per_bp'});
        next if $max_seen >= $here;
        $max_seen = $here;
      }

      if ($slice) {
        ## Skip features that are on the 'wrong' strand or lie outside the current slice
        my $omit = $extra_config->{'strand_to_omit'};
        next if (($strandable && (($omit && $strand == $omit)
                            || (!$strand && $omit == 1) ## force unstranded data onto forward strand
                            || ($extra_config->{'omit_unstrandable'} && $strand == 0)))
                  || !(first {$seqname eq $_} @$seq_region_names)
                  || $end < $slice->start || $start > $slice->end);
        $self->build_feature($data, $track_key, $slice, $strandable);
      }
      else {
        ## Skip non-chromosomal seq regions unless explicitly told to parse everything
        next unless ($seqname && first {$seqname eq $_} @$seq_region_names);
        if (grep(/$seqname/, @$drawn_chrs)) {
          $data->{$track_key}{'metadata'}{'mapped'}++;
          if ($bins) {
            ## Add this feature to the appropriate density bin
            my $bin_size    = $bin_sizes->{$seqname};
            my $bin_number  = int($start / $bin_size) + 1;
            $data->{$track_key}{'bins'}{$seqname}{$bin_number}++;
          }
          else {
            my $slice = $slices->{$seqname} || $adaptor->fetch_by_region('chromosome', $seqname); 
            $self->build_feature($data, $track_key, $slice, $strandable) if $slice;
          }
        }
        else {
          $data->{$track_key}{'metadata'}{'unmapped'}++;
        }
      }
    }
  }

  ## Indexed formats cache their data, so the above loop won't produce a track
  ## at all if there are no features in this region. In order to draw an
  ## 'empty track' glyphset we need to manually create the empty track
  if (!keys %$data) {
    $order  = ['data'];
    $data   = {'data' => {'metadata' => $extra_config || {}}};
    if ($slice) {
      $data->{'data'}{'features'} = [];
    }
    else {
      $data->{'data'}{'bins'} = {};
    }
  }

  if (!$slice) {
    $self->munge_densities($data);
  }

  ## We need slice length for formats that assemble transcripts from individual features, e.g. GFF3
  $self->{'slice_length'} = $slice ? $slice->length : 0;
  $self->post_process($data);

  ## Finally sort the completed tracks
  my $tracks = $self->sort_tracks($data, $order, $prioritise); 

  return $tracks;
}

sub build_metadata {
  my ($self, $parser, $data, $extra_config, $order) = @_;

  my $track_key = $parser->get_metadata_value('name') if $parser->can('get_metadata_value');
  $track_key ||= 'data';

  unless ($data->{$track_key}) {
    ## Default track order is how they come out of the file
    push @$order, $track_key;
  }
  
  ## If we haven't done so already, grab all the metadata for this track
  my %metadata;
  if (!keys %{$data->{$track_key}{'metadata'}||{}}) {
    if ($parser->can('get_all_metadata')) {
      %metadata = %{$parser->get_all_metadata};
    }

    ## Add in any extra configuration provided by caller, which takes precedence over metadata
    if (keys %{$extra_config||{}}) {
      @metadata{keys %{$extra_config||{}}} = values %{$extra_config||{}};
    }
    $metadata{'name'} ||= $track_key; ## Default name
    $data->{$track_key}{'metadata'} = \%metadata;
  }

  return $track_key;
}

sub build_feature {
  my ($self, $data, $track_key, $slice) = @_;
  my $metadata = $data->{$track_key}{'metadata'};

  my $hash = $self->create_hash($slice, $data->{$track_key}{'metadata'});
  return unless keys %$hash;

  if ($hash->{'score'} && $hash->{'score'} !~ /,/) { ## Ignore pairwise "scores" that are RGB colours
    $metadata->{'max_score'} = $hash->{'score'} if $hash->{'score'} >= $metadata->{'max_score'};
    $metadata->{'min_score'} = $hash->{'score'} if $hash->{'score'} <= $metadata->{'min_score'};
  }

  if ($data->{$track_key}{'features'}) {
    push @{$data->{$track_key}{'features'}}, $hash; 
  }
  else {
    $data->{$track_key}{'features'} = [$hash];
  }
}

sub sort_tracks {
  my ($self, $data, $default_order, $prioritise) = @_;

  my @order = $prioritise ? sort {$data->{$a}{'metadata'}{'priority'} <=> $data->{$b}{'metadata'}{'priority'}} keys %$data
                          : @$default_order;

  my $sorted_data;
  foreach (@order) {
    push @{$sorted_data}, $data->{$_};
  }
  return $sorted_data;
}

sub post_process {} # Stub

sub munge_densities {
### Work out per-track densities
  my ($self, $data) = @_;
  while (my ($key, $info) = each (%$data)) {
    my $track_max = 0;
    foreach my $chr (keys %{$info->{'bins'}}) {
      my $chr_max = max(values %{$info->{'bins'}{$chr}});
      $track_max = $chr_max if $chr_max > $track_max;
    }
    $info->{'metadata'}{'max_value'} = $track_max;
  }
}

sub href {
  my ($self, $params) = @_;
  return $self->hub->url('ZMenu', {
                                    'action'            => $params->{'action'} || 'UserData', 
                                    'config'            => $self->config_type,  
                                    'track'             => $self->track,
                                    'format'            => $self->format, 
                                    'fake_click_chr'    => $params->{'seq_region'}, 
                                    'fake_click_start'  => $params->{'start'}, 
                                    'fake_click_end'    => $params->{'end'},
                                    'fake_click_strand' => $params->{'strand'},
                                    'feature_id'        => $params->{'id'},              
                                    %{$params->{'zmenu_extras'}||{}},
                                    %{$params->{'custom_fields'}||{}},
                                  });
}

sub create_hash {
  ### Stub - needs to be implemented in each child
  ### The purpose of this method is to convert IO-specific terms 
  ### into ones familiar to the webcode, and also munge data for
  ### the web display
}

sub validate {
  ### Wrapper around the parser's validation method
  my $self = shift;
  my $response = $self->parser->validate;
  my $message = 'File did not validate as format '.$self->format;

  ## For formats that still use old validation method
  if (ref($response) ne 'HASH') {
  return $response == 1 ? undef : $message;
  }

  if (! keys %$response) {
    if ($self->parser->format) {
      $self->format($self->parser->format->name);
    }
    return undef;
  }
  else {
    $message .= '<ul>';
    foreach (sort keys %$response) {
      $message .= sprintf('<li>%s: %s</li>', $_, $response->{$_});
    }
    $message .= '</ul>';
    return $message;
  }
}

sub coords {
  ### Simple accessor to return the coordinates from the parser
  my $self = shift;
  return ($self->parser->get_seqname, $self->parser->get_start, $self->parser->get_end);
}

sub set_colour {
  ### Set feature colour according to possible values in the metadata
  my ($self, $params) = @_;
  my $colour;

  ## Only set colour if we have something in file, otherwise
  ## we will override the default colour in the drawing code
  my $metadata  = $params->{'metadata'};
  my $strand    = $params->{'strand'};
  my $score     = $params->{'score'};
  my $rgb       = $params->{'rgb'};
  my $key       = $params->{'key'};

  if ($score && $metadata->{'spectrum'} eq 'on') {
    $self->{'gradient'} ||= $metadata->{'default_gradient'};
    $colour = $self->convert_to_gradient($score, $metadata->{'color'}, $metadata->{'steps'}, $metadata->{'scoreMax'}, $metadata->{'scoreMin'});
  }
  elsif ($params->{'itemRgb'}) { ## BigBed?
    $colour = $self->rgb_to_hex($params->{'itemRgb'});
  }
  elsif ($rgb && $metadata->{'itemRgb'} eq 'On') {
    $colour = $self->rgb_to_hex($rgb);
  }
  elsif ($strand && $metadata->{'colorByStrand'}) {
    my ($pos, $neg) = split(' ', $metadata->{'colorByStrand'});
    my $rgb = $strand == 1 ? $pos : $neg;
    $colour = $self->rgb_to_hex($rgb);
  }
  elsif ($metadata->{'colour'}) {
    $colour = $metadata->{'colour'};
  }
  elsif ($metadata->{'color'}) {
    $colour = $metadata->{'color'};
  }

  return $colour;
}

sub rgb_to_hex {
  ### For the web we really need hex colours, but file formats have traditionally used RGB
  ### @param String - three RGB values
  ### @return String - same colour in hex
  my ($self, $triple_ref) = @_;
  my @rgb = split(',', $triple_ref);
  return sprintf("%02x%02x%02x", @rgb);
}

sub get_metadata_value {
  my ($self, $key) = @_;
  return unless $key;

  my %metadata = %{$self->parser->get_all_metadata};
  return $metadata{$key};
}

sub nearest_feature {
### Try to find the nearest feature to the browser's current location
  my $self = shift;

  my $location = $self->hub->param('r') || $self->hub->referer->{'params'}->{'r'}[0];

  my ($browser_region, $browser_start, $browser_end) = $location ? split(':|-', $location) 
                                                                  : (0,0,0);
  my ($nearest_region, $nearest_start, $nearest_end, $first_region, $first_start, $first_end);
  my $nearest_distance;
  my $first_done = 0;
  my $count = 0;

  while ($self->parser->next) {
    next if $self->parser->is_metadata;
    my ($seqname, $start, $end) = $self->coords;
    next unless $seqname && $start;
    $count++;

    ## Capture the first feature, in case we don't find anything on the current chromosome
    unless ($first_done) {
      ($first_region, $first_start, $first_end) = ($seqname, $start, $end);
      $first_done = 1;
    }

    ## We only measure distance within the current chromosome
    next unless $seqname eq $browser_region;

    my $feature_distance  = $browser_start > $start ? $browser_start - $start : $start - $browser_start;
    $nearest_start      ||= $start;
    $nearest_distance     = $browser_start > $nearest_start ? $browser_start - $nearest_start 
                                                           : $nearest_start - $browser_start;

    if ($feature_distance <= $nearest_distance) {
      $nearest_start = $start;
      $nearest_end   = $end;
    }
  }

  if ($nearest_region) {
    ($nearest_start, $nearest_end) = $self->_adjust_coordinates($nearest_start, $nearest_end);
    return ($nearest_region, $nearest_start, $nearest_end, $count, 'nearest');
  }
  else {
    ($first_start, $first_end) = $self->_adjust_coordinates($first_start, $first_end);
    return ($first_region, $first_start, $first_end, $count, 'first');
  }
}

sub _adjust_coordinates {
  my ($self, $start, $end) = @_;

  ## Flip if necessary, for easier calculations
  ($end, $start) = ($start, $end) if $start > $end;
  ## Expand coordinates so we don't end up on a one-base-pair slice with no visible data!
  if (int($end - $start) < 100) {
    my $centre = int($end - $start) / 2;
    $start -= 50;
    $start = 0 if $start < 0;
    $end += 50;  
  }
  return ($start, $end);
}

1;
