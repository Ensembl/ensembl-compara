=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::IOWrapper::GFF3;

### Wrapper for Bio::EnsEMBL::IO::Parser::GFF3, which builds
### simple hash features suitable for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

use Data::Dumper;

use parent qw(EnsEMBL::Web::IOWrapper::GXF);

sub post_process {
### Reassemble sub-features back into features
  my ($self, $data) = @_;
  #warn '>>> ORIGINAL DATA '.Dumper($data);
  $self->{'ok_features'} = [];

  while (my ($track_key, $content) = each (%$data)) {
    ## Build a 'tree' of features - use an array, because IDs may not be unique
    my $tree = [];
    my %seen_gene;

    foreach my $f (@{$content->{'features'}||[]}) {
      warn ">>> FEATURE ".$f->{'id'};
      if (scalar @{$f->{'parents'}||[]}) {
        foreach (@{$f->{'parents'}}) {
          $self->_add_to_parent($tree, $f, $_);
          ## Make a note of parent gene for later
          if ($f->{'type'} eq 'transcript' || $f->{'type'} =~ /rna/i) {
            $seen_gene{$_}++;
          }
        }
      }
      else {
        push @$tree, $f;
      }
    }
    #warn ">>> TREE ".Dumper($tree);

    ## Convert 'tree' into structured features
    foreach my $f (@$tree) {
      $f->{'href'} = $self->href($f->{'href_params'});
      $self->{'stored_features'}{$f->{'id'}} = $f;
      if ($f->{'children'}) {
        $self->_structured_feature($f);
      }
    }
    #warn ">>> STORED ".Dumper($self->{'stored_features'});

    ## Finally, add all structured features to the list
    foreach my $f (values %{$self->{'stored_features'}}) {
      next if ($f->{'type'} eq 'gene' && ($seen_gene{$f->{'id'}} || $seen_gene{$f->{'name'}}));
      $f->{'start'} = $f->{'min_start'} unless $f->{'start'};
      $f->{'end'}   = $f->{'max_end'} unless $f->{'end'};
      push @{$self->{'ok_features'}}, $self->_drawable_feature($f);
    }

    $content->{'features'}  = $self->{'ok_features'}; 
  }
  #warn '################# PROCESSED DATA '.Dumper($data);
}

sub _structured_feature {
  my ($self, $f) = @_;

  foreach my $k (keys %{$f->{'children'}||{}}) {
    foreach my $child (sort {$a->{'start'} <=> $b->{'start'}} @{$f->{'children'}{$k}||[]}) {
      if (keys %{$child->{'children'}||{}}) {
        ## Transcript or similar
        $self->{'stored_features'}{$child->{'id'}} = $child;
        $self->_build_transcript($child);
      }
      my $child_href_params       = $child->{'href_params'};
      $child->{'href'}            = $self->href($child_href_params);
      ## Add a dummy exon to the end if the transcript extends beyond the end of the slice
      #if (scalar @{$f->{'structure'}||[]} && $f->{'end'} > $f->{'structure'}[-1]{'end'}) {
      #  push @{$f->{'structure'}}, {'start' => $self->{'slice_length'} + 1, 'end' => $f->{'end'}};
      #}
    }
  }
} 

sub _build_transcript {
  my ($self, $transcript) = @_;

  my @exons = sort {$a->{'start'} <=> $b->{'start'}} @{$transcript->{'children'}{'exon'}};
  my $true_exons = 1;

  unless (scalar @exons) {
    ## Add CDS as initial exons
    @exons = sort {$a->{'start'} <=> $b->{'start'}} @{$transcript->{'children'}{'cds'}};
    $true_exons = 0;
  }

  ## Now work out where the UTRs are

  ## Start by looking for UTRs in the data file
  if ($true_exons) {
    my %utr_lookup = ('three_prime_utr' => 'utr_3', 'five_prime_utr' => 'utr_5');
    ## Mark the UTR points in the relevant exons
    my $utrs_done = 0;
    foreach my $key (keys %utr_lookup) {
      next unless $transcript->{'children'}{$key};
      ## Assume that if at least one UTR is defined, we're OK - because the alternative
      ## is that the data is just a mess!
      $utrs_done = 1;
      foreach my $utr (sort {$a->{'start'} <=> $b->{'start'}} @{$transcript->{'children'}{$key}}) {
        foreach my $exon (@exons) {
          ## Does this UTR match an exon?
          if ($utr->{'start'} >= $exon->{'start'} && $utr->{'end'} <= $exon->{'end'}) {     
            if ($utr->{'start'} == $exon->{'start'} && $utr->{'end'} == $exon->{'end'}) {
              ## Exact match == non-coding exon
              $exon->{'non_coding'} = 1;
            }
            elsif ($utr->{'end'} < $exon->{'end'}) {
              $exon->{$utr_lookup{$key}} = $utr->{'end'};
            }
            elsif ($utr->{'start'} > $exon->{'start'}) {
              $exon->{$utr_lookup{$key}} = $utr->{'start'};
            }
          }
        }
      }
    }
    ## We have exons but no explicit UTRs, so we need to use the CDS to create them
    if (!$utrs_done && scalar @{$transcript->{'children'}{'cds'}}) {
      foreach my $exon (@exons) {
        foreach my $cds (sort {$a->{'start'} <=> $b->{'start'}} @{$transcript->{'children'}{'cds'}}) {
          if ($cds->{'start'} >= $exon->{'start'} && $cds->{'start'} <= $exon->{'end'}) {
            $exon->{'utr_5'} = $cds->{'start'};
          }
          ## NOTE: Don't make this an elsif, because the whole CDS could lie within one exon
          if ($cds->{'end'} >= $exon->{'start'} && $cds->{'end'} <= $exon->{'end'}) {
            $exon->{'utr_3'} = $cds->{'end'};
          }
        }
      }
    }
  }
  else {
    ## No exons, so we have to add the UTRs to the CDS to make exons, so ordering is crucial!
    if ($transcript->{'strand'} == 1) {
      ## Add 5-prime UTRs to start in reverse order
      my $count = 0;
      foreach my $utr (sort {$b->{'start'} <=> $b->{'start'}} @{$transcript->{'children'}{'five_prime_utr'}}) {
        my $first_exon = $exons[0];
        if ($count == 0 && ($first_exon->{'start'} - $utr->{'end'} < 2)) {
          ## Adjacent, so glue them together
          $first_exon->{'start'} = $utr->{'start'};
          $first_exon->{'utr_5'} = $utr->{'end'};
        }
        else {
          $utr->{'non_coding'} = 1;
          unshift @exons, $utr;
        }
        $count++;
      }

      ## Then add 3-prime UTRs in order
      $count == 0;
      foreach my $utr (sort {$a->{'start'} <=> $b->{'start'}} @{$transcript->{'children'}{'three_prime_utr'}}) {
        my $last_exon = $exons[-1];
        if ($count == 0 && ($utr->{'start'} - $last_exon->{'end'} < 2)) {
          ## Adjacent, so glue them together
          $last_exon->{'end'} = $utr->{'end'};
          $last_exon->{'utr_3'} = $utr->{'start'};
        }
        else {
          $utr->{'non_coding'} = 1;
          push @exons, $utr;
        }
        $count++;
      }
       
    }
    else {
      ## Negative strand, so add 3-prime UTRs to start in reverse order
      my $count = 0;
      foreach my $utr (sort {$b->{'start'} <=> $b->{'start'}} @{$transcript->{'children'}{'three_prime_utr'}}) {
        my $first_exon = $exons[0];
        if ($count == 0 && ($first_exon->{'start'} - $utr->{'end'} < 2)) {
          ## Adjacent, so glue them together
          $first_exon->{'start'} = $utr->{'start'};
          $first_exon->{'utr_3'} = $utr->{'end'};
        }
        else {
          $utr->{'non_coding'} = 1;
          unshift @exons, $utr;
        }
        $count++;
      }
      ## Then add 5-prime UTRs in order
      $count = 0;
      foreach my $utr (sort {$a->{'start'} <=> $b->{'start'}} @{$transcript->{'children'}{'five_prime_utr'}}) {
        my $last_exon = $exons[-1];
        if ($count == 0 && ($utr->{'start'} - $last_exon->{'end'} < 2)) {
          ## Adjacent, so glue them together
          $last_exon->{'end'} = $utr->{'end'};
          $last_exon->{'utr_5'} = $utr->{'start'};
        }
        else {
          $utr->{'non_coding'} = 1;
          push @exons, $utr;
        }
        $count++;
      }
    }
  }
  $transcript->{'structure'} = \@exons;
  warn Dumper($transcript->{'structure'});
  delete $transcript->{'children'};
}

sub _drawable_feature {
### Simplify feature hash for drawing 
### (Note that we can't delete hash keys unless we dereference the hashref first, 
### because we need the children for building the complete feature)
  my ($self, $f) = @_;
  return {
          'seq_region'    => $f->{'seq_region'},
          'start'         => $f->{'start'},
          'end'           => $f->{'end'},
          'strand'        => $f->{'strand'},
          'type'          => $f->{'type'},
          'label'         => $f->{'label'},
          'score'         => $f->{'score'},
          'colour'        => $f->{'colour'},
          'join_colour'   => $f->{'join_colour'},
          'label_colour'  => $f->{'label_colour'},
          'href'          => $f->{'href'},
          'structure'     => $f->{'structure'},
          'extra'         => $f->{'extra'},
          };
}

sub _add_to_parent {
### Recurse into feature tree
  my ($self, $node, $feature, $parent) = @_;
  foreach my $child (@$node) {
    ## Is this a child of the current level?
    if ($child->{'id'} eq $parent) {
      my $type = lc $feature->{'type'};
      push @{$child->{'children'}{$type}}, $feature;
      last;
    }
    else {
      while (my($type, $children) = each (%{$child->{'children'}||{}})) {
        $self->_add_to_parent($children, $feature, $parent);
      }
    }
  }
  return;
}

sub create_hash {
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $start         = $feature_start - $slice->start;
  my $end           = $feature_end - $slice->start;
  return if $end < 0 || $start > $slice->length;

  my $seqname       = $self->parser->get_seqname;
  my $strand        = $self->parser->get_strand || 0;
  my $score         = $self->parser->get_score;

  $metadata ||= {};

  my $id    = $self->parser->get_attribute_by_name('ID');
  my $name = $self->parser->get_attribute_by_name('Name'); 
  my $alias = $self->parser->get_attribute_by_name('Alias');
  my $label;
  if ($name && $alias) {
    $label = sprintf('%s (%s)', $name, $alias);
  }
  else {
    $label = $name || $alias || $id;
  }

  ## Don't turn these into a URL yet, as we need to manipulate them later
  my $href_params = {
                      'id'          => $label,
                      'seq_region'  => $seqname,
                      'start'       => $feature_start,
                      'end'         => $feature_end,
                      'strand'      => $strand,
                      };

  my @parents = split(',', $self->parser->get_attribute_by_name('Parent'));

  my $type = $self->parser->get_type;
  my $feature = {
    'id'            => $id,
    'type'          => $type,
    'parents'       => \@parents,
    'seq_region'    => $seqname,
    'strand'        => $strand,
    'score'         => $score,
    'colour'        => $metadata->{'colour'},
    'join_colour'   => $metadata->{'join_colour'},
    'label_colour'  => $metadata->{'label_colour'},
    'label'         => $label,
    'href_params'   => $href_params,
  };

  if ($metadata->{'display'} eq 'text') {
    $feature->{'start'} = $feature_start;
    $feature->{'end'}   = $feature_end;
    $feature->{'extra'} = [
                        {'name' => 'Source',  'value' => $self->parser->get_source },
                        {'name' => 'Type',    'value' => $type },
                        ];
  }
  else {
    $feature->{'start'} = $start;
    $feature->{'end'}   = $end;
  }
  return $feature;
}


1;
