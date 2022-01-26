=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Utils::HubParser;

### Parser for the configuration files used by a trackhub, i.e.
### hub.txt, genomes.txt and trackDb.txt

### Note that this parser does not fetch the individual .txt files - 
### it requires a wrapper object such as EnsEMBL::Web::Utils::TrackHub

use strict;
use warnings;

## We need to lookup some track information by id during parsing
our $track_lookup = {};

## Some hubs don't set the track type, so...
our %format_lookup = (
                      'bb'      => 'bigBed',
                      'bigbed'  => 'bigBed',
                      'bw'      => 'bigWig',
                      'bigwig'  => 'bigWig',
                      'bam'     => 'BAM',
                      'cram'    => 'CRAM',
                      );
 
sub new {
  my ($class, %args) = @_;

  ## Munge the URL so we can deal easily with relative paths
  my $url = $args{'url'};
  my @split_url = split '/', $url;
  my ($base_url, $hub_file);

  if ($split_url[-1] =~ /[.?]/) {
    $args{'hub_file'} = pop @split_url;
    $args{'base_url'} = join '/', @split_url;
  } else {
    $args{'hub_file'} = 'hub.txt';
    $args{'base_url'} =~ s|/$||;
  }

  my $self = \%args;
  bless $self, $class;

  return $self;
}

sub base_url {
  my $self = shift;
  return $self->{'base_url'};
}

sub hub_file_path {
  my $self = shift;
  return join('/', $self->{'base_url'}, $self->{'hub_file'});
}

sub get_hub_info {
### Parses a hub.txt file for metadata
### @param data String - file contents
### @return Hashref
  my ($self, $data) = @_;
  my $hub_info = {};

  foreach (split /\n/, $data) {
    $_ =~ s/\s+$//;
    my @line = split /\s/, $_, 2;
    ## Genomes file path is usually given relative to hub.txt
    if ($line[0] eq 'genomesFile' && $line[1] !~ /^(http|ftp)/) {
      $line[1] = $self->{'base_url'}.'/'.$line[1];
    }
    $hub_info->{$line[0]} = $line[1];
  }
  return $hub_info;
}

sub get_genome_info {
### Parses a genomes.txt file for metadata
### @param data String - file contents
### @param assembly_lookup Hashref (optional) - assemblies to include
### @return Hashref
  my ($self, $data, $assembly_lookup) = @_;
  my $genome_info   = {};
  my $other_genomes = [];
  my $genome;

  (my $genome_file = $data) =~ s/\r//g;

  foreach (split /\n/, $genome_file) {
    next unless $_ =~ /\w+/; ## Skip empty lines
    my ($k, $v) = split(/\s/, $_);
    if ($k eq 'genome') {
      $genome = $v;
      ## Optionally filter out unknown assemblies
      ## because we don't want to waste time parsing them
      ## (but save them because we might need them for error-handling)
      if ($assembly_lookup && !$assembly_lookup->{$genome}) {
        push @$other_genomes, $genome;
        $genome = undef;
        next;
      }
    }
    else {
      ## Skip this if we're skipping this genome
      next unless $genome;
      ## TrackDb file path is usually given relative to hub.txt
      if ($k =~ /trackDb|htmlPath/ && $v !~ /^[http|ftp]/) {
        $v = $self->{'base_url'}.'/'.$v;
      }
      $genome_info->{$genome}{$k} = $v;
    }
  }

  return ($genome_info, $other_genomes);
}

sub get_tracks {
### Parse a trackDb.txt file and return metadata about all its tracks
### @param content String - file contents
### @param file String - path to file contents
### @param limit Integer - maximum number of tracks to return
### @return tracks Arrayref
  my ($self, $content, $file, $limit) = @_;
  my $tracks = [];
  my $url      = $file =~ s|^(.+)/.+|$1|r; # URL relative to the file (up until the last slash before the file name)
  my @all_lines = split(/\n/, $content);
  my (@lines, $multi_line, $track, $id);
  my $count = 0;
    
  ## Create an array of all meaningful lines
  foreach (@all_lines) {
    next unless /\w/;
      
    s/(^\s*|\s*$)//g; # Trim leading and trailing whitespace
      
    if (s/\\$//g) { # Lines ending in a \ are wrapped onto the next line
      $multi_line .= $_;
      next;
    }
      
    push @lines, $multi_line ? "$multi_line$_" : $_;
      
    $multi_line = '';
  }
    
  foreach (@lines) {
    next if $_ =~ /^#/; # Ignore commented-out attributes

    my ($key, $value) = split /\s+/, $_, 2;
      
    if ($key eq 'track') {
      ## Save any existing track
      if (scalar keys %{$track||{}}) {
        $self->save_track($track, $tracks, $url);
      }
      ## Start a new track
      last if $count > $limit;
      $id = $value || 'Unnamed';
      $track = {'track' => $value};
    }
    elsif ($key eq 'type') {
      my @values = split /\s+/, $value;
      my $type   = lc shift @values;
         $type   = 'vcf' if $type eq 'vcftabix';
        
      $track->{$key} = $type;
        
      if ($type =~ /bed/i) {
        $track->{'standard_fields'}   = shift @values;
        if (scalar @values) {
          $track->{'additional_fields'} = $values[0] eq '+' ? 1 : 0;
          $track->{'configurable'}      = $values[0] eq '.' ? 1 : 0; # Don't really care for now
        }
      } elsif ($type =~ /wig/i) {
        $track->{'signal_range'} = \@values;
      }
    } elsif ($key eq 'bigDataUrl') {
      ## Only tracks with an actual data file count as tracks in Ensembl
      $count++;
      if ($value =~ /^\//) { ## path is relative to server, not to hub.txt
        $url =~ /^(\w+:\/\/(\w|-|\.)+)/;
        my $root = $1;
        $track->{$key} = $root.$value;
      }
      else {
        $track->{$key} = $value =~ /^(ftp|https?):\/\// ? $value : "$url/$value";
      }
    } else {
      if ($key eq 'parent' || $key eq 'superTrack' || $key =~ /^subGroup[0-9]/) {

        my @values = split /\s+/, $value;
          
        if ($key eq 'parent' || $key eq 'superTrack') {
          if ($key eq 'superTrack' && $values[0] eq 'on') {
            $track->{'superTrack'}  = shift @values;
            my $on_off                  = shift @values if scalar @values;
            if ($on_off) {
              $track->{'on_off'}    = $on_off eq 'show' ? 'on' : 'off';
            }
          }
          else {
            ## Hack for incorrect hubs that use 'superTrack' in children instead of 'parent'
            $track->{'parent'}    = shift @values;
            my $on_off                = shift @values if scalar @values;
            if ($on_off) {
              $track->{'on_off'}  = ($on_off eq 'show' || $on_off eq 'on') ? 'on' : 'off';
            }
          }
          next;
        } else {
          $track->{$key}{'name'}  = shift @values;
          $track->{$key}{'label'} = shift @values;
           
          $value = join ' ', @values;
        }
      }
        
      # Deal with key=value attributes.
      # These are in the form key1=value1 key2=value2, but values can be quotes strings with spaces in them.
      # Short and long labels may contain =, but in these cases the value is just a single string
      if ($value =~ /=/ && $key !~ /^(short|long)Label$/) {
        my ($k, $v);
        my @pairs = split /\s([^=]+)=/, " $value";
        shift @pairs;
         
        for (my $i = 0; $i < $#pairs; $i += 2) {
          $k = $pairs[$i];
          $v = $pairs[$i + 1];
           
          # If the value starts with a quote, but doesn't end with it, this value contains the pattern \s(\w+)=, so has been split multiple times.
          # In that case, append all subsequent elements in the array onto the value string, until one is found which closes with a matching quote.
          if ($v =~ /^("|')/ && $v !~ /$1$/) {
            my $quote = $1;
             
            for (my $j = $i + 2; $j < $#pairs; $j++) {
              $v .= "=$pairs[$j]";
               
              if ($pairs[$j] =~ /$quote$/) {
                $i += $j - $i - 1;
                last;
              }
            }
          }
           
          $v =~ s/(^["']|['"]$)//g; # strip the quotes from the start and end of the value string
            
          $track->{$key}{$k} = $v;
        }
      } else {
        $track->{$key} = $value;
      }
    }
  }
  
  ## Save the final track!      
  $self->save_track($track, $tracks, $url);
    
  return ($tracks, $count);
}

sub save_track {
  my ($self, $track, $tracks, $url) = @_;

  # any track which doesn't have any of these is definitely invalid
  return unless ($track->{'type'} || $track->{'shortLabel'} || $track->{'longLabel'});

  my $id = $track->{'track'};

  my $description_url;
  if ($track->{'html'}) {
    $description_url = $url.'/'.$track->{'html'};
  }
  elsif ($track->{'parent'} && $track_lookup->{$track->{'parent'}}{'html'}) {
    $description_url = $url.'/'.$track_lookup->{$track->{'parent'}}{'html'}; 
  }
  if ($description_url) {
    $description_url .= '.html' unless $description_url =~ /\.html$/;
    $track->{'description_url'} = $description_url;
  }
      
  if (!$track->{'type'} && !$track->{'superTrack'} && $track->{'bigDataUrl'}) {
    ## Set type based on file extension
    my @path = split(/\./, $track->{'bigDataUrl'});
    $track->{'type'} = $format_lookup{$path[-1]};
  }
      
  if ($track->{'dimensions'}) {
    # filthy last-character-of-string hack to support dimensions in the same way as UCSC
    my @dimensions = keys %{$track->{'dimensions'}};
    $track->{'dimensions'}{lc substr $_, -1, 1} = delete $track->{'dimensions'}{$_} for @dimensions;
  }

  ## OK, all done, so save this track!
  push @$tracks, $track;
  $track_lookup->{$id} = $track;
}

1;
