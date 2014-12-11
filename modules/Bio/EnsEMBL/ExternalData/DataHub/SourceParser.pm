=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::ExternalData::DataHub::SourceParser

=head1 SYNOPSIS


=head1 DESCRIPTION

Parses UCSC-style datahub configuration files for track information

=head1 AUTHOR

Anne Parker <ap5@sanger.ac.uk>

=cut

package Bio::EnsEMBL::ExternalData::DataHub::SourceParser;

use strict;

use EnsEMBL::Web::File::Utils::URL qw(read_file);
use EnsEMBL::Web::Tree;

=head1 METHODS

=head2 new

  Arg [..]   : none
  Example    :
  Description: Constructor
  Returntype : Bio::EnsEMBL::ExternalData::DataHub::SourceParser
  Exceptions : none 
  Caller     : general
  Status     : Stable 
  
=cut

sub new {
  my ($class, %args) = @_;

  my $self = \%args;
  bless $self, $class;

  return $self;
}

=head2 get_hub_info

  Arg [1]    : URL of datahub
  Example    : $parser->get_hub_info();
  Description: Contacts the given data hub, reads the base config file 
              (hub.txt) and from there gets a list of configuration files 
  Returntype : hashref
  Exceptions : 
  Caller     : EnsEMBL::Web::ConfigPacker
  Status     : Under development

=cut

sub get_hub_info {
  my ($self, $url, $assembly_lookup) = @_;
  my @split_url = split '/', $url;
  my $hub_file;
  
  if ($split_url[-1] =~ /[.?]/) {
    $hub_file = pop @split_url;
    $url      = join '/', @split_url;
  } else {
    $hub_file = 'hub.txt';
    $url      =~ s|/$||;
  }

  my $response = read_file("$url/$hub_file", {'hub' => $self->{'hub'}});
  my $content;
 
  if ($response->{'error'}) {
    return $response;
  }
  else {
    $content = $response->{'content'};
  }
  my %hub_details;
  
  ## Get file name for file with genome info
  foreach (split /\n/, $content) {
    my @line = split /\s/, $_, 2;
    $hub_details{$line[0]} = $line[1];
  }
  return { error => ['No genomesFile found'] } unless $hub_details{'genomesFile'};
 
  ## Now get genomes file and parse 
  $response = read_file("$url/$hub_details{'genomesFile'}", {'hub' => $self->{'hub'}}); 
  if ($response->{'error'}) {
    return $response;
  }
  else {
    $content = $response->{'content'};
  }

  (my $genome_file = $content) =~ s/\r//g;
  my %genome_info;
  my @lines = split /\n/, $genome_file;
  my ($genome, $file, %ok_genomes);
  foreach (split /\n/, $genome_file) {
    my ($k, $v) = split(/\s/, $_);
    if ($k =~ /genome/) {
      $genome = $v;
      ## Check if any of these genomes are available on this site,
      ## because we don't want to waste time parsing them if not!
      if ($assembly_lookup && $assembly_lookup->{$genome}) {
        $ok_genomes{$genome} = 1;
      }
      else {
        $genome = undef;
      }
    }
    elsif ($genome && $k =~ /trackDb/) {
      $file = $v;
      $genome_info{$genome} = $file;
      ($genome, $file) = (undef, undef);
    }
  }

  my @errors;

  if (keys %ok_genomes) {
     ## Parse list of config files
      foreach my $genome (keys %ok_genomes) {
      $file = $genome_info{$genome};
 
      $response = read_file("$url/$file", {'hub' => $self->{'hub'}}); 

      if ($response->{'error'}) {
        push @errors, "$genome ($url/$file): ".@{$response->{'error'}};
      }
      else {
        $content = $response->{'content'};
      }

      my @track_list;
      $content =~ s/\r//g;
    
      # Hack here: Assume if file contains one include it only contains includes and no actual data
      # Would be better to resolve all includes (read the files) and pass the complete config data into 
      # the parsing function rather than the list of file names
      foreach (split /\n/, $content) {
        next if /^#/ || !/\w+/ || !/^include/;
      
        s/^include //;
        push @track_list, "$url/$_";
      }
    
      if (scalar @track_list) {
        ## replace trackDb file location with list of track files
        $genome_info{$genome} = \@track_list;
      } else {
        $genome_info{$genome} = [ "$url/$file" ];
      }
    }
  }
  else {
    push @errors, "This track hub does not contain any genomes compatible with this website";
  }

  return scalar @errors ? { error => \@errors } : { details => \%hub_details, genomes => \%genome_info };
}

=head2 parse

  Arg [1]    : Arrayref of config file URLs
  Example    : $parser->parse($files);
  Description: Contacts the given data hub, fetches each config 
               file and parses the results. Returns an array of 
               track configurations (see parse_file_content for details)
  Returntype : arrayref
  Exceptions : 
  Caller     : EnsEMBL::Web::ConfigPacker
  Status     : Under development

=cut

sub parse {
  my ($self, $files) = @_;
  
  if (!$files && !scalar @$files) {
    warn 'No datahub URL specified!';
    return;
  }
  
  my $tree = EnsEMBL::Web::Tree->new;
  my $response;
  
  ## Get all the text files in the hub directory
  foreach (@$files) {
    $response = read_file($_, {'hub' => $self->{'hub'}});

    if ($response->{'error'}) {
      $tree->append($tree->create_node("error_$_", { error => @{$response->{'error'}}, file => $_ }));
    } else {
      $self->parse_file_content($tree, $response->{'content'} =~ s/\r//gr, $_);
    }
  }
  
  return $tree;
}

sub parse_file_content {
  my ($self, $tree, $content, $file) = @_;
  my %tracks;
  my $url      = $file =~ s|^(.+)/.+|$1|r; # URL relative to the file (up until the last slash before the file name)
  my @contents = split /track /, $content;
  shift @contents;
  
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
    $tracks{$id}{'parent'} = delete $tracks{$id}{'superTrack'} if $tracks{$id}{'superTrack'} && $tracks{$id}{'superTrack'} ne 'on' && !$tracks{$id}{'parent'};
    
    # any track which doesn't have any of these is definitely invalid
    if ($tracks{$id}{'type'} || $tracks{$id}{'shortLabel'} || $tracks{$id}{'longLabel'}) {
      $tracks{$id}{'track'}           = $id;
      $tracks{$id}{'description_url'} = "$url/$id.html" unless $tracks{$id}{'parent'};
      
      if ($tracks{$id}{'dimensions'}) {
        # filthy last-character-of-string hack to support dimensions in the same way as UCSC
        my @dimensions = keys %{$tracks{$id}{'dimensions'}};
        $tracks{$id}{'dimensions'}{lc substr $_, -1, 1} = delete $tracks{$id}{'dimensions'}{$_} for @dimensions;
      }
    } else {
      delete $tracks{$id};
    }
  }
  
  # Make sure the track hierarchy is ok before trying to make the tree
  foreach (values %tracks) {
    return $tree->append($tree->create_node('error_missing_parent', { error => "Parent track $_->{'parent'} is missing", file => $file })) if $_->{'parent'} && !$tracks{$_->{'parent'}};
  }
  
  $self->make_tree($tree, \%tracks);
  $self->fix_tree($tree);
  $self->sort_tree($tree);
}

sub make_tree {
  my ($self, $tree, $tracks) = @_;
  my %redo;
  
  foreach (sort { !$b->{'parent'} <=> !$a->{'parent'} } values %$tracks) {
    if ($_->{'parent'}) {
      my $parent = $tree->get_node($_->{'parent'});
      
      if ($parent) {
        $parent->append($tree->create_node($_->{'track'}, $_));
      } else {
        $redo{$_->{'track'}} = $_;
      }
    } else {
      $tree->append($tree->create_node($_->{'track'}, $_));
    }
  }
  
  $self->make_tree($tree, \%redo) if scalar keys %redo;
}

# Apply horrible hacks to make the data display in the same way as UCSC
sub fix_tree {
  my ($self, $tree) = @_;
  
  foreach my $node (@{$tree->child_nodes}) {
    my $data       = $node->data;
    my @views      = grep $_->data->{'view'}, @{$node->child_nodes};
    my $dimensions = $data->{'dimensions'};
    
    # If there's only one view and all the tracks are inside it, make the view's labels be the same as it's parent's label
    # so that the config menu entry is nicer
    if (scalar @views == 1 && scalar @{$node->child_nodes} == 1) {
      $views[0]->data->{$_} = $data->{$_} for qw(shortLabel longLabel);
    }
    
    # FIXME: only accounting for top level when doing dimensions
    
    # If only one of x and y is defined, use the view as the other dimension, if it exists.
    # Collapse the views into the parent node, so the menu structure is reasonable.
    # NOTE: This assumes that if a view exists, all nodes at that level in the tree are views.
    if ($dimensions && (!$dimensions->{'x'} ^ !$dimensions->{'y'})) {
      if (scalar @views) {
        my $id = $node->id;
        
        $dimensions->{$dimensions->{'x'} ? 'y' : 'x'} = 'view';
        
        $node->remove_children;
        
        foreach my $v (@views) {
          my $tracks = $v->child_nodes;
          my $data   = $v->data;
          
          delete $data->{'view'};
          
          foreach my $track (@{$v->child_nodes}) {
            $track->data->{$_}     ||= $data->{$_} for keys %$data;
            $track->data->{'parent'} = $id;
            $node->append_child($track);
          }
        }
      }
    }
  }
}

sub sort_tree {
  my ($self, $node) = @_;
  my @children = @{$node->child_nodes};
  
  if (scalar @children > 1) {
    # Sort on priority when it exists, followed by shortLabel.
    @children = map $_->[2], sort { !$a->[0] <=> !$b->[0] || $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] } map [ $_->data->{'priority'}, $_->data->{'shortLabel'}, $_ ], @children;
    
    $node->remove_children;
    $node->append_children(@children);
  }
  
  $self->sort_tree($_) for @children;
}

1;
