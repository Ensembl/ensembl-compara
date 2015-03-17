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

package EnsEMBL::Web::File::Utils::TrackHub;

### Wrapper around Bio::EnsEMBL::IO::Parser::TrackHubParser 
### which also fetches each file in the trackhub configuration

use strict;

use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::ExternalData::DataHub::SourceParser;

use EnsEMBL::Web::File::Utils::URL qw(read_file);
use EnsEMBL::Web::Tree;

### Because the Sanger web proxy caches hub files aggressively,
### users cannot easily refresh a trackhub that has changed.
### Thus we need to work around this by forcing no caching in the proxy
### and instead caching the files in memcached for a sensible period

### Headers to send to proxy
our $headers = {
                'Cache-Control'     => 'no-cache',
                'If-Modified-Since' => 'Thu, 1 Jan 1970 00:00:00 GMT',
                };

### Memcached refresh period
our $cache_timeout = 60*60*24*7;

sub new {
### c
  my ($class, %args) = @_;

  ## TODO - replace with Bio::EnsEMBL::IO version when it's ready
  unless ($args{'parser'}) {
    $args{'parser'} = Bio::EnsEMBL::ExternalData::DataHub::SourceParser->new('url' => $args{'url'});
  }

  my $self = \%args;
  bless $self, $class;

  return $self;
}

sub parser {
### a
  my $self = shift;
  return $self->{'parser'};
}

sub web_hub {
### a
### Gets EnsEMBL::Web::Hub (not to be confused with track hub!)
  my $self = shift;
  return $self->{'hub'};
}

sub url {
### a
  my $self = shift;
  return $self->{'url'};
}

sub get_hub {
### Fetch metadata about the hub and (optionally) its tracks
### @param args Hashref (optional) 
###                     - parse_tracks Boolean
###                     - assembly_lookup Hashref
### @return Hashref               
  my ($self, $args) = @_;

  ## First check the cache
  my $cache = $self->web_hub ? $self->web_hub->cache : undef;
  my $cache_key = 'trackhub_'.md5_hex($self->url);
  my $trackhub;

  if ($cache) {
    $trackhub = $cache->get($cache_key);
    return $trackhub if $trackhub;
  }

  ## Prepare to parse!
  my $parser = $self->parser;
  my $file_args = {'hub' => $self->{'hub'}, 'nice' => 1, 'headers' => $headers}; 

  ## First read the hub.txt file and get the hub's metadata
  my $response = read_file($parser->hub_file_path, $file_args);
  my ($content, @errors);
 
  if ($response->{'error'}) {
    return $response;
  }
  else {
    $content = $response->{'content'};
  }

  my $hub_info = $parser->get_hub_info($content);

  return { error => ['No genomesFile found'] } unless $hub_info->{'genomesFile'}; 
 
  ## Now get genomes file and find out what species and assemblies it has
  $response = read_file($hub_info->{'genomesFile'}, $file_args); 
  if ($response->{'error'}) {
    return $response;
  }
  else {
    $content = $response->{'content'};
  }

  my $genome_info = $parser->get_genome_info($content, $args->{'assembly_lookup'});

  if (keys %$genome_info) {
    ## Only get track information if it's requested, as there can
    ## be thousands of the darned things!
    if ($args->{'parse_tracks'}) {
      while (my($genome, $info) = each (%$genome_info)) {
 
        my $tree = EnsEMBL::Web::Tree->new;
        my $options = {'tree' => $tree};

        if ($args->{'genome'} && $args->{'genome'} eq $genome) {
          $options->{'genome'} = $args->{'genome'};
        }
        else {
          my $file = $info->{'trackDb'};
          $options->{'file'} = $file;

          $response = read_file($file, $file_args); 

          if ($response->{'error'}) {
            push @errors, "$genome ($file): ".@{$response->{'error'}};
            $tree->append($tree->create_node("error_$genome", { error => @{$response->{'error'}}, file => $file }));
          }
          else {
            $options->{'content'} = $response->{'content'};
          }
        }

        if ($options->{'genome'} || $options->{'content'}) {
          $genome_info->{$genome}{'tree'} = $self->get_track_info($options);
        }
      }
    }
  }
  else {
    push @errors, "This track hub does not contain any genomes compatible with this website";
  }

  if (scalar @errors) {
    return { error => \@errors };
  }
  else {
    my $trackhub = { details => $hub_info, genomes => $genome_info };
    if ($cache) {
      $cache->set($cache_key, $trackhub, $cache_timeout, 'TRACKHUBS');
    }
    return $trackhub;
  }
}

sub get_track_info {
### Get information about the tracks for one genome in the hub
### @param args Hashref
### @return tree EnsEMBL::Web::Tree
  my ($self, $args) = @_;

  ## Get data from cache if available
  my $cache = $self->web_hub ? $self->web_hub->cache : undef;
  my $url       = $self->url;
  my $cache_key = 'trackhub_'.md5_hex($url);
  my $trackhub;

  if ($cache && $args->{'genome'}) {
    $trackhub = $cache->get($cache_key);
    if ($trackhub) {
      my $tree = $trackhub->{'genomes'}{$args->{'genome'}}{'tree'};
      return $tree if $tree;
    }
  }

  ## Return tree as-is, if we have no file to parse
  my $tree = $args->{'tree'};
  return $tree unless $args->{'content'};
  
  ## OK, parse the file content
  my $parser  = $self->parser;
  my %tracks = $parser->get_tracks($args->{'content'}, $args->{'file'});
  
  # Make sure the track hierarchy is ok before trying to make the tree
  foreach (values %tracks) {
    if ($_->{'parent'} && !$tracks{$_->{'parent'}}) {
      return $tree->append($tree->create_node(
                                        'error_missing_parent', 
                                        {'error' => "Parent track $_->{'parent'} is missing", 
                                         'file'  => $args->{'file'} }
                                      ));
    }
  }

  $self->make_tree($tree, \%tracks);
  $self->fix_tree($tree);
  $self->sort_tree($tree);

  ## Update cache
  if ($cache) {
    $trackhub = $cache->get($cache_key);
    if ($trackhub) {
      $trackhub->{'genomes'}{$args->{'genome'}}{'tree'} = $tree;
      $cache->set($cache_key, $trackhub, $cache_timeout, 'TRACKHUBS');
    }
  }
  
  return $tree;
}

sub make_tree {
### Turn the tracks hash into a proper web tree so we can use it as a menu
### @param node EnsEMBL::Web::Tree
### @param tracks Hashref
### @return Void
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

sub fix_tree {
### Apply horrible hacks to make the data display in the same way as UCSC
### @param tree EnsEMBL::Web::Tree
### @return Void
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
### Sort tracks on priority when it exists, followed by shortLabel
### @param node EnsEMBL::Web::Tree
### @return Void
  my ($self, $node) = @_;
  my @children = @{$node->child_nodes};
  
  if (scalar @children > 1) {
    @children = map $_->[2], sort { !$a->[0] <=> !$b->[0] || $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] } map [ $_->data->{'priority'}, $_->data->{'shortLabel'}, $_ ], @children;
    
    $node->remove_children;
    $node->append_children(@children);
  }
  
  $self->sort_tree($_) for @children;
}

1;
