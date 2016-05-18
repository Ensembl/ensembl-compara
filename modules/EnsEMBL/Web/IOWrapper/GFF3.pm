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
    ## Build a tree of features - use an array, because IDs may not be unique
    my $tree = [];
    foreach my $f (@{$content->{'features'}||[]}) {
      if (scalar @{$f->{'parents'}||[]}) {
        $self->_add_to_parent($tree, $f, $_) for @{$f->{'parents'}};
      }
      else {
        push @$tree, $f;
      }
    }
    #warn ">>> TREE ".Dumper($tree);

    ## Convert tree into structured features
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
      $f->{'start'} = $f->{'min_start'} unless $f->{'start'};
      $f->{'end'}   = $f->{'max_end'} unless $f->{'end'};
      push @{$self->{'ok_features'}}, $self->_drawable_feature($f);
    }

    $content->{'features'} = $self->{'ok_features'};
  }
  #warn '################# PROCESSED DATA '.Dumper($data);
}

sub _structured_feature {
  my ($self, $f) = @_;

  if (scalar @{$f->{'children'}||[]}) {
    foreach my $child (sort {$a->{'start'} <=> $b->{'start'}} @{$f->{'children'}||{}}) {
      ## Transcript or similar
      if (scalar @{$child->{'children'}||[]}) {
        $self->{'stored_features'}{$child->{'id'}} = $child;
      }
      my $child_href_params       = $child->{'href_params'};
      $child->{'href'}            = $self->href($child_href_params);
      $self->_structured_feature($child);
    }
    ## Add a dummy exon to the end if the transcript extends beyond the end of the slice
    if (scalar @{$f->{'structure'}||[]} && $f->{'end'} > $f->{'structure'}[-1]{'end'}) {
      push @{$f->{'structure'}}, {'start' => $self->{'slice_length'} + 1, 'end' => $f->{'end'}};
    }
  }
  else {
    ## Exon, intron, CDS, etc
    foreach my $parent (@{$f->{'parents'}}) {
      my $transcript = $self->{'stored_features'}{$parent} || {};
      $self->_add_to_transcript($transcript, $f);  
      $self->{'stored_features'}{$parent} = $transcript;
    }
  }
} 

sub _add_to_transcript {
  my ($self, $transcript, $f) = @_;

  my $type    = $f->{'type'};
  my $start   = $f->{'start'};
  my $end     = $f->{'end'};
  my $strand  = $f->{'strand'};

  ## Add a dummy exon if the transcript starts before the beginning of the slice
  if (!$transcript->{'structure'} && $transcript->{'start'} < 0 && $start >= 0) {
    push @{$transcript->{'structure'}}, {'start' => $transcript->{'start'}, 'end' => -1};
  }

  ## Store max and min coordinates in case we don't have a 'real' parent in the file  
  $transcript->{'min_start'}  = $start if (!$transcript->{'min_start'} || $transcript->{'min_start'} > $start);
  $transcript->{'max_end'}    = $end if (!$transcript->{'max_end'} || $transcript->{'max_end'} > $end);

  ## Because the children are sorted, we can walk along the transcript to set coding regions
  if ($type =~ /UTR/) {
    ## Starts and ends are by coordinates, not transcript direction
    ## 5' UTR
    if ($start == $transcript->{'start'} && $strand == 1) {
      push @{$transcript->{'structure'}}, {'start' => $start, 'utr_5' => $end};
      $transcript->{'in_cds'} = 1;
    }
    elsif ($end == $transcript->{'end'} && $strand == -1) {
      $transcript->{'structure'}[-1]{'utr_5'} = $start;
      $transcript->{'structure'}[-1]{'end'} = $end;
      $transcript->{'in_cds'} = 0;
    }
    ## 3' UTR
    elsif ($start == $transcript->{'start'} && $strand == -1) {
      push @{$transcript->{'structure'}}, {'start' => $start, 'utr_3' => $end};
      $transcript->{'in_cds'} = 1;
    }
    elsif ($end == $transcript->{'end'} && $strand == 1) {
      $transcript->{'structure'}[-1]{'utr_3'} = $start;
      $transcript->{'structure'}[-1]{'end'} = $end;
      $transcript->{'in_cds'} = 0;
    } 
  }
  elsif ($type eq 'CDS') {
    $transcript->{'in_cds'} = 1;
    ## Was this CDS listed after the corresponding exon?
    my $previous_exon = scalar @{$transcript->{'structure'}||[]} ? $transcript->{'structure'}[-1] : undef;
    if ($previous_exon && $start >= $previous_exon->{'start'} && $start < $previous_exon->{'end'}) {
      $previous_exon->{'non_coding'} = 0;
      if ($start > $previous_exon->{'start'} && !$previous_exon->{'utr_5'} && !$previous_exon->{'utr_3'}) {
        ## Divide the previous exon at the UTR point, if we don't have one already
        my ($utr, $val);
        if ($strand == 1) {
          $utr = 'utr_5';
          $val = $start;
        }
        else {
          $utr = 'utr_3';
          $val = $end;
        }
        $previous_exon->{$utr} = $val;
      }
    }
  }
  elsif ($type eq 'exon') {
    my $exon = {'start' => $start, 'end' => $end};

    ## Non-coding exon
    if ($transcript->{'type'} eq 'transcript' && !$transcript->{'in_cds'}) {
      $exon->{'non_coding'} = 1;
    } 

    push @{$transcript->{'structure'}}, $exon;
  }

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
      push @{$child->{'children'}}, $feature;
    }
    elsif ($child->{'children'}) {
      $self->_add_to_parent($child->{'children'}, $feature, $parent);
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
