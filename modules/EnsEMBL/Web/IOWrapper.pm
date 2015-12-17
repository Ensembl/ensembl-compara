=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use List::Util qw(max);

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
  my $subclass = $format_to_class{$file->get_format};
  return undef unless $subclass;
  my $class = 'EnsEMBL::Web::IOWrapper::'.$subclass;

  my $format = $file->get_format;
  return undef unless $format;

  my $wrapper;
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

    $wrapper = $class->new({
                            'parser' => $parser, 
                            'file'   => $file, 
                            'format' => $format,
                            %args,
                            });  
  }
  return $wrapper;
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
  my $self = shift;
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
  my ($self, $score, $colour) = @_;
  ## Default to black
  $score = 1000 unless defined($score);

  my @gradient = $colour ? $self->create_gradient(['white', $colour]) : @{$self->{'greyscale'}||[]};

  my $value;
  if ($score <= 166) {
    $value = $gradient[0];
  }
  else {
    my $step = int(($score - 166) / 110) + 1;
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
  my $tracks      = [];
  my $data        = {};
  my $prioritise  = 0;
  my (@order, $bin_sizes, $bins);

  if (!$slice) {
    ## Sort out chromosome info
    my $drawn_chrs  = $hub->species_defs->get_config($hub->data_species, 'ENSEMBL_CHROMOSOMES');
    $bins           = $extra_config->{'bins'} || 150;
    my $adaptor     = $hub->get_adaptor('get_SliceAdaptor');
    foreach my $chr (@$drawn_chrs) {
      my $slice = $adaptor->fetch_by_region('chromosome', $chr);
      $bin_sizes->{$chr} = $slice->length / $bins; 
    }
  }

  while ($parser->next) {
    my $track_key = $parser->get_metadata_value('name') if $parser->can('get_metadata_value');
    $track_key ||= 'data';

    unless ($data->{$track_key}) {
      ## Default track order is how they come out of the file
      push @order, $track_key;
      ## Set up density bins if needed
      if (!$slice) {
        foreach my $chr (keys %$bin_sizes) {
          $data->{$track_key}{'bins'}{$chr}{$_} = 0 for 1..$bins;
        }
      }
    }

    ## If we haven't done so already, grab all the metadata for this track
    my %metadata;
    if (!keys %{$data->{$track_key}{'metadata'}||{}}) {
      if ($parser->can('get_all_metadata')) {
        %metadata = %{$parser->get_all_metadata};
        $prioritise = 1 if $metadata{'priority'};
      }
 
      ## Add in any extra configuration provided by caller, which takes precedence over metadata
      if (keys %{$extra_config||{}}) {
        @metadata{keys %{$extra_config||{}}} = values %{$extra_config||{}};
      }
      $metadata{'name'} ||= $track_key; ## Default name
      $data->{$track_key}{'metadata'} = \%metadata;
    }

    my ($seqname, $start, $end) = $self->coords;
    if ($slice) {
      ## Skip features that lie outside the current slice
      next if ($seqname ne $slice->seq_region_name
                || ($end < $slice->start && $start > $slice->end));
      $self->build_feature($data, $track_key, $slice, $strandable);
    }
    else {
      next unless $seqname;
      my $feature_strand = $self->parser->get_strand if $strandable;
      $feature_strand  ||= $metadata{'default_strand'};
      ## Add this feature to the appropriate density bin
      my $bin_size    = $bin_sizes->{$seqname};
      my $bin_number  = int($start / $bin_size) + 1;
      $data->{$track_key}{'bins'}{$feature_strand}{$seqname}{$bin_number}++;
    }
  }

  if (!$slice) {
    $self->munge_densities($data);
  }

  if ($prioritise) {
    @order = sort {$data->{$a}{'metadata'}{'priority'} <=> $data->{$b}{'metadata'}{'priority'}} 
              keys %$data;
  }

  foreach (@order) {
    push @$tracks, $data->{$_};
  }

  return $tracks;
}

sub build_feature {
  my ($self, $data, $track_key, $slice) = @_;
  my $hash = $self->create_hash($slice, $data->{$track_key}{'metadata'});
  return unless keys %$hash;

  my $feature_strand = $hash->{'strand'} || $data->{$track_key}{'metadata'}{'default_strand'};

  if ($data->{$track_key}{'features'}) {
    push @{$data->{$track_key}{'features'}{$feature_strand}}, $hash; 
  }
  else {
    $data->{$track_key}{'features'}{$feature_strand} = [$hash];
  }
}

sub post_process {} ## Stub

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
                                    'action'            => 'UserData', 
                                    'config'            => $self->config_type,  
                                    'track'             => $self->track,
                                    'format'            => $self->format, 
                                    'fake_click_chr'    => $params->{'seq_region'}, 
                                    'fake_click_start'  => $params->{'start'}, 
                                    'fake_click_end'    => $params->{'end'},
                                    'feature_id'        => $params->{'id'},              
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
  my $valid = $self->parser->validate;

  return $valid ? undef : 'File did not validate as format '.$self->format;
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

  if ($score && ($metadata->{'useScore'} || $metadata->{'spectrum'})) {
    $colour = $self->convert_to_gradient($score, $metadata->{'color'});
  }
  elsif ($rgb && $metadata->{'itemRgb'} eq 'On') {
    $colour = $self->rgb_to_hex($rgb);
  }
  elsif ($strand && $metadata->{'colorByStrand'}) {
    my ($pos, $neg) = split(' ', $metadata->{'colorByStrand'});
    my $rgb = $strand == 1 ? $pos : $neg;
    $colour = $self->rgb_to_hex($rgb);
  }
  elsif ($metadata->{'color'}) {
    $colour = $metadata->{'color'};
  }
  elsif ($metadata->{'colour'}) {
    $colour = $metadata->{'colour'};
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

sub nearest_feature {
### Try to find the nearest feature to the browser's current location
  my $self = shift;

  my $location = $self->hub->param('r') || $self->hub->referer->{'params'}->{'r'}[0];
  return undef unless $location;

  my ($browser_region, $browser_start, $browser_end) = split(':|-', $location);
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
    return ($nearest_region, $nearest_start, $nearest_end, $count, 'nearest');
  }
  else {
    return ($first_region, $first_start, $first_end, $count, 'first');
  }
}

1;
