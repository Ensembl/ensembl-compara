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

package EnsEMBL::Web::Utils::TrackHub;

### Wrapper around Utils::HubParser 
### which also fetches each file in the trackhub configuration

use strict;

use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::Utils::HubParser;
use EnsEMBL::Web::File::Utils::URL qw(read_file);
use EnsEMBL::Web::Utils::FormatText qw(thousandify);
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

sub new {
### c
  my ($class, %args) = @_;

  my $hub = $args{'hub'};
  $args{'timeout'} = $hub ? ($hub->param('udcTimeout') || $hub->species_defs->TRACKHUB_TIMEOUT)
                          : 0;

  unless ($args{'parser'}) {
    $args{'parser'} = EnsEMBL::Web::Utils::HubParser->new('url' => $args{'url'});
  }

  my $self = \%args;
  bless $self, $class;

  return $self;
}

sub format_to_class {
  return (
          'bam'             => 'Bam',
          'bcf'             => 'BCF',
          'bed'             => 'Bed',
          'bedgraph'        => 'Bed',
          'bigbed'          => 'BigBed',
          'bigwig'          => 'BigWig',
          'emf'             => 'EMF',
          'fasta'           => 'Fasta',
          'gff'             => 'GTF',
          'gff3'            => 'GFF3',
          'gtf'             => 'GTF',
          'gvf'             => 'GVF',
          'pairwise'        => 'PairwiseSimple',
          'pairwisetabix'   => 'PairwiseTabix',
          'psl'             => 'Psl',
          'vcf'             => 'VCF4',
          'vcf4tabix'       => 'VCF4Tabix',
          'vep_input'       => 'VEP_input',
          'vep_output'      => 'VEP_output',
          'wig'             => 'Wig',
          );
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

sub get_hub_internal {
### Fetch metadata about the hub and (optionally) its tracks
### @param args Hashref (optional) 
###                     - parse_tracks Boolean
###                     - assembly_lookup Hashref
### @return Hashref              
###
### This method can be run with or without the ability to check the cache.
### A wrapper method (called just get_hub) tries it first with and, if there
### is an error, then without. This means that caches shouldn't get "poisoned"
### if they fail due to an intermittent failure on first population. 
  my ($self, $args, $search_cache) = @_;

  ## First check the cache
  my $cache     = $self->web_hub ? $self->web_hub->cache : undef;
  my $cache_key = 'trackhub_'.md5_hex($self->url);
  my $file_args = {'hub' => $self->{'hub'}, 'nice' => 1, 'headers' => $headers}; 
  my ($trackhub, $content, @errors);

  if ($cache && $search_cache) {
    $trackhub = $cache->get($cache_key);
    ## Throw cache away unless it makes sense
    $trackhub = undef unless (ref($trackhub) eq 'HASH' && keys %$trackhub);
  }

  my $parser        = $self->parser;
  my $genome_info   = {};
  my $other_genomes = [];
  my $response;

  if ($trackhub) {
    $genome_info = $trackhub->{'genomes'} || {};
  }
  else {
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

    ($genome_info, $other_genomes) = $parser->get_genome_info($content, $args->{'assembly_lookup'});
    $trackhub = { details => $hub_info, genomes => $genome_info };
  }

  if (keys %$genome_info) {
    ## Only get track information if it's requested, as there can
    ## be thousands of the darned things!
    if ($args->{'parse_tracks'}) {
      while (my($genome, $info) = each (%$genome_info)) {

        if ($args->{'tree'} && $info->{'tree'}) {
          return $info->{'tree'};
        }

        if ($info->{'data'}) {
          return $info->{'data'};
        }
        
        my $options;

        if ($args->{'make_tree'}) {
          $options = {'tree' => EnsEMBL::Web::Tree->new};
        }

        if ($args->{'genome'} && $args->{'genome'} eq $genome) {
          $options->{'genome'} = $args->{'genome'};
        }
        else {
          my $file = $info->{'trackDb'};
          if ($file !~ /^http|ftp/) {
            $file = $parser->base_url.'/'.$file;
          }
          $options->{'file'} = $file;

          $response = read_file($file, $file_args); 

          if ($response->{'error'} || !$response->{'content'}) {
            my $error = $response->{'error'}[0] || "trackDB file empty for genome $genome";
            push @errors, $error;
          }
          else {
            $options->{'content'} = $response->{'content'};
          }
        }

        if ($options->{'genome'} || $options->{'content'}) {
          my ($track_info, $total) = $self->get_track_info($options);

          my $limit = $self->web_hub->species_defs->TRACKHUB_MAX_TRACKS;
          if ($total >= $limit) {
            return { error => [sprintf('Sorry, we cannot attach this trackhub as it has more than %s tracks and will therefore overload our server', $self->thousandify($limit))] }
          }
          else {
            $genome_info->{$genome}{'track_count'} = $total;
            if ($args->{'make_tree'}) {
              $genome_info->{$genome}{'tree'} = $track_info;
            }
            else {
              $genome_info->{$genome}{'data'} = $track_info;
            }
          }
        }
      }
    }
  }
  else {
    push @errors, "This track hub does not contain any genomes compatible with this website";
  }

  if (scalar @errors) {
    my $feedback = { error => \@errors};
    $feedback->{'unsupported_genomes'} = $other_genomes if scalar @{$other_genomes||[]};
    return $feedback;
  }
  else {
    if ($cache) {
      $cache->set($cache_key, $trackhub, $self->{'timeout'}, 'TRACKHUBS');
    }
    return $trackhub;
  }
}

sub get_hub {
### Fetch metadata about the hub and (optionally) its tracks
### @param args Hashref (optional) 
###                     - parse_tracks Boolean
###                     - assembly_lookup Hashref
### @return Hashref              
###
### This method calls get_hub_internal first with and, if there
### is an error, then without. This means that caches shouldn't get "poisoned"
### if they fail due to an intermittent failure on first population. 
  my ($self, $args) = @_;

  my $out = $self->get_hub_internal($args,1);
  if(!$out || $out->{'error'}) {
    $out = $self->get_hub_internal($args,0);
  }
  return $out;
}

sub get_track_info {
### Get information about the tracks for one genome in the hub
### @param args Hashref
### @return data Arrayref or Tree object, depending on args passed
  my ($self, $args) = @_;
  my ($trackhub, $info);

  ## Get data from cache if available
  my $cache = $self->web_hub ? $self->web_hub->cache : undef;
  my $url       = $self->url;
  my $cache_key = 'trackhub_'.md5_hex($url);

  if ($cache && $args->{'genome'}) {
    $trackhub = $cache->get($cache_key);
    if ($trackhub) {
      $info = $args->{'tree'} ? $trackhub->{'genomes'}{$args->{'genome'}}{'tree'} 
                              : $trackhub->{'genomes'}{$args->{'genome'}}{'data'};
      return $info;
    }
  }

  ## No cache, so check we have content to parse
  return undef unless $args->{'content'};

  ## OK, parse the file content
  my $parser  = $self->parser;
  my $limit   = $self->web_hub->species_defs->TRACKHUB_MAX_TRACKS;
  my ($tracks, $total) = $parser->get_tracks($args->{'content'}, $args->{'file'}, $limit);
  
  # Make sure the track hierarchy is ok before trying to make the tree
  my $tree = $args->{'tree'}; 
  if ($tree) {
    $self->make_tree($tree, $tracks);
    $self->fix_tree($tree);
    $self->sort_tree($tree->root);
    $info = $tree;
  }
  else {
    $info = $tracks;
  }

  ## Update cache
  if ($cache) {
    $trackhub = $cache->get($cache_key);
    if ($trackhub) {
      if ($args->{'tree'}) {
        $trackhub->{'genomes'}{$args->{'genome'}}{'tree'} = $info;
      }
      else {
        $trackhub->{'genomes'}{$args->{'genome'}}{'data'} = $info;
      }
      $cache->set($cache_key, $trackhub, $self->{'timeout'}, 'TRACKHUBS');
    }
  }
  
  return ($info, $total);
}

sub make_tree {
### Turn the tracks hash into a proper web tree so we can use it as a menu
### @param tracks Hashref
### @return Void
  my ($self, $tree, $tracks) = @_;
  my $redo = [];

  my $progress_made = 0; # to detect infinite loops due to borken hubs
  foreach (@$tracks) {
    if ($_->{'parent'}) {
      my $parent = $tree->get_node($_->{'parent'});
      
      if ($parent) {
        $progress_made = 1;
        $parent->append($tree->create_node($_->{'track'}, $_));
      } else {
        push @$redo, $_;
      }
    } else {
      $progress_made = 1;
      $tree->root->append($tree->create_node($_->{'track'}, $_));
    }
  }
  
  $self->make_tree($tree, $redo) if scalar @$redo and $progress_made;
}

sub fix_tree {
### Apply horrible hacks to make the data display in the same way as UCSC
### @param tree EnsEMBL::Web::Tree
### @return Void
  my ($self, $tree) = @_;
  
  foreach my $node (@{$tree->root->child_nodes}) {
    my $data       = $node->data;
    my @views      = grep $_->data->{'view'}, @{$node->child_nodes};
    my $dimensions = $data->{'dimensions'};
    
    ## If there's only one view and all the tracks are inside it, make the 
    ## view's labels be the same as its parent's label so the config menu entry is nicer
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
### Sort tracks on priority when it exists
### @param node EnsEMBL::Web::TreeNode
### @return Void
  my ($self, $node) = @_;
  my @children = @{$node->child_nodes};
  
  if (scalar @children > 1 && $children[0]->data->{'priority'}) {
    @children = sort {$a->data->{'priority'} <=> $b->data->{'priority'} } @children;
    
    $node->remove_children;
    $node->append_children(@children);
  }
  
  $self->sort_tree($_) for @children;
}

1;
