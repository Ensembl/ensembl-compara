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

use Bio::EnsEMBL::IO::Parser;
use Bio::EnsEMBL::IO::Utils;

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

sub open {
  ## Factory method - creates a wrapper of the appropriate type
  ## based on the format of the file given
  my ($file, %args) = @_;

  my %format_to_class = Bio::EnsEMBL::IO::Utils::format_to_class;
  my $subclass = $format_to_class{$file->get_format};
  return undef unless $subclass;
  my $class = 'EnsEMBL::Web::IOWrapper::'.$subclass;

  my $parser;
  my $format = $file->get_format;
  return undef unless $format;

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

  if (dynamic_use($class, 1)) {
    $class->new({
                'parser' => $parser, 
                'file'   => $file, 
                'format' => $format,
                %args,
                });  
  }
  else {
    warn ">>> NO SUCH MODULE $class";
  }
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

sub convert_to_gradient {
### Convert a 0-1000 score to a value on a colour gradient
### Default is greyscale
  my ($self, $score, $colour) = @_;
  ## Default to black
  $score = 1000 unless defined($score);

  my @gradient = $colour ? $self->_create_gradient($colour) : @{$self->{'greyscale'}||[]};

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

sub _create_gradient {
  my ($self, $colour) = @_;
  my $gradient = [];
  return $gradient;
}

sub create_tracks {
### Loop through the file and create one or more tracks
### Orders tracks by priority value if it exists
### @param slice - Bio::EnsEMBL::Slice object
### @return arrayref of one or more hashes containing track information
  my ($self, $slice) = @_;
  my $parser = $self->parser;
  my $tracks      = [];
  my $data        = {};
  my $prioritise  = 0;
  my @order;
  my $saved_key;

  while ($parser->next) {
    my $track_line = $parser->is_metadata;
    if ($track_line) {
      $parser->read_metadata;
    }
    else {
      my $track_key = $parser->get_metadata_value('name') || $saved_key || 'data';

      ## Slurp metadata into this track and wipe it from the parser
      ## so that we don't get values copied between tracks
      unless (keys %{$data->{$track_key}{'metadata'}||{}}) {
        $data->{$track_key}{'metadata'} = $parser->get_all_metadata;
        $prioritise = 1 if $data->{$track_key}{'metadata'}{'priority'};
        push @order, $track_key;
        $saved_key = $track_key;
        $parser->start_new_track;
      }

      my ($seqname, $start, $end) = $self->coords;
      ## Skip features that lie outside the current slice
      if ($slice) {
        next if ($seqname ne $slice->seq_region_name
                  || $end < $slice->start
                  || $start > $slice->end);
      }
      $self->build_feature($data, $track_key, $slice);
    }
  }

  $self->post_process($data);

  if ($prioritise) {
    @order = sort {$data->{$a}{'metadata'}{'priority'} <=> $data->{$b}{'metadata'}{'priority'}} 
              keys %$data;
  }

  foreach (@order) {
    push @$tracks, $data->{$_};
  }

  return $tracks;
}

sub post_process {} ## Stub

sub build_feature {
  my ($self, $data, $track_key, $slice) = @_;
  if ($data->{$track_key}{'features'}) {
    push @{$data->{$track_key}{'features'}}, $self->create_hash($data->{$track_key}{'metadata'}, $slice);
  }
  else {
    $data->{$track_key}{'features'} = [$self->create_hash($data->{$track_key}{'metadata'}, $slice)];
  }
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

  my $location = $self->hub->param('r');
  return undef unless $location;

  my ($browser_region, $browser_start, $browser_end) = split(':|-', $location);
  my ($nearest_region, $nearest_start, $nearest_end, $first_region, $first_start, $first_end);
  my $nearest_distance;
  my $first_done = 0;

  while ($self->parser->next) {
    next if $self->parser->is_metadata;
    my ($seqname, $start, $end) = $self->coords;
    next unless $seqname && $start;

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
    return ($nearest_region, $nearest_start, $nearest_end, 'nearest');
  }
  else {
    return ($first_region, $first_start, $first_end, 'first');
  }
}

1;
