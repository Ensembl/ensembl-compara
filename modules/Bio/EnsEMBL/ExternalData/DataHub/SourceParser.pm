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

package Bio::EnsEMBL::ExternalData::DataHub::SourceParser;

use strict;

sub new {
### c
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
### a
  my $self = shift;
  return $self->{'base_url'};
}

sub hub_file_path {
### a
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
    if ($line[0] eq 'genomesFile' && $line[1] !~ /^[http|ftp]/) {
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
  my $genome_info = {};
  my $genome;

  (my $genome_file = $data) =~ s/\r//g;

  foreach (split /\n/, $genome_file) {
    next unless $_ =~ /\w+/; ## Skip empty lines
    my ($k, $v) = split(/\s/, $_);
    if ($k eq 'genome') {
      $genome = $v;
      ## Optionally filter out unknown assemblies
      ## because we don't want to waste time parsing them
      if ($assembly_lookup && !$assembly_lookup->{$genome}) {
        $genome = undef;
        next;
      }
    }
    else {
      ## TrackDb file path is usually given relative to hub.txt
      if ($k =~ /trackDb|htmlPath/ && $v !~ /^[http|ftp]/) {
        $v = $self->{'base_url'}.'/'.$v;
      }
      $genome_info->{$genome}{$k} = $v;
    }
  }

  return $genome_info;
}

sub get_tracks {
### Parse a trackDb.txt file and return metadata about all its tracks
### @param content String - file contents
### @param file String - path to file contents
### @return tracks Hash
  my ($self, $content, $file) = @_;
  my %tracks;
  my $url      = $file =~ s|^(.+)/.+|$1|r; # URL relative to the file (up until the last slash before the file name)
  my @contents = split /track /, $content;
  shift @contents;
 
  ## Some hubs don't set the track type, so...
  my %format_lookup = (
                      'bb' => 'bigBed',
                      'bw' => 'bigWig',
                      );
 
  foreach (@contents) {
    my @lines = split /\n/;
    my (@track, $multi_line);
    
    foreach (@lines) {
      next unless /\w/;
      
      s/(^\s*|\s*$)//g; # Trim leading and trailing whitespace
      
      if (s/\\$//g) { # Lines ending in a \ are wrapped onto the next line
        $multi_line .= $_;
        next;
      }
      
      push @track, $multi_line ? "$multi_line$_" : $_;
      
      $multi_line = '';
    }
    
    my $id = shift @track;
    
    next unless defined $id;
    
    $id = 'Unnamed' if $id eq '';
   
    foreach (@track) {
      my ($key, $value) = split /\s+/, $_, 2;
      
      next if $key =~ /^#/; # Ignore commented-out attributes
      
      if ($key eq 'type') {
        my @values = split /\s+/, $value;
        my $type   = lc shift @values;
           $type   = 'vcf' if $type eq 'vcftabix';
        
        $tracks{$id}{$key} = $type;
        
        if ($type eq 'bigbed') {
          $tracks{$id}{'standard_fields'}   = shift @values;
          $tracks{$id}{'additional_fields'} = $values[0] eq '+' ? 1 : 0;
          $tracks{$id}{'configurable'}      = $values[0] eq '.' ? 1 : 0; # Don't really care for now
        } elsif ($type eq 'bigwig') {
          $tracks{$id}{'signal_range'} = \@values;
        }
      } elsif ($key eq 'bigDataUrl') {
        if ($value =~ /^\//) { ## path is relative to server, not to hub.txt
          (my $root = $url) =~ s/^(ftp|https?):\/\/([\w|-|\.]+)//;
          $tracks{$id}{$key} = $root.$value;
        }
        else {
          $tracks{$id}{$key} = $value =~ /^(ftp|https?):\/\// ? $value : "$url/$value";
        }
      } else {
        if ($key eq 'parent' || $key =~ /^subGroup[0-9]/) {
          my @values = split /\s+/, $value;
          
          if ($key eq 'parent') {
            $tracks{$id}{$key} = $values[0]; # FIXME: throwing away on/off setting for now
            next;
          } else {
            $tracks{$id}{$key}{'name'}  = shift @values;
            $tracks{$id}{$key}{'label'} = shift @values;
            
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
            
            $tracks{$id}{$key}{$k} = $v;
          }
        } else {
          $tracks{$id}{$key} = $value;
        }
      }
    }
    
    # filthy hack to support superTrack setting being used as parent, because hubs are incorrect.
    $tracks{$id}{'parent'} = delete $tracks{$id}{'superTrack'} if $tracks{$id}{'superTrack'} && $tracks{$id}{'superTrack'} !~ /^on/ && !$tracks{$id}{'parent'};


    # any track which doesn't have any of these is definitely invalid
    if ($tracks{$id}{'type'} || $tracks{$id}{'shortLabel'} || $tracks{$id}{'longLabel'}) {
      $tracks{$id}{'track'}           = $id;
      $tracks{$id}{'description_url'} = "$url/$id.html" unless $tracks{$id}{'parent'};
      
      unless ($tracks{$id}{'type'}) {
        ## Set type based on file extension
        my @path = split(/\./, $tracks{$id}{'bigDataUrl'});
        $tracks{$id}{'type'} = $format_lookup{$path[-1]};
      }
      
      if ($tracks{$id}{'dimensions'}) {
        # filthy last-character-of-string hack to support dimensions in the same way as UCSC
        my @dimensions = keys %{$tracks{$id}{'dimensions'}};
        $tracks{$id}{'dimensions'}{lc substr $_, -1, 1} = delete $tracks{$id}{'dimensions'}{$_} for @dimensions;
      }
    } else {
      delete $tracks{$id};
    }
  }

  return %tracks;
}

1;
