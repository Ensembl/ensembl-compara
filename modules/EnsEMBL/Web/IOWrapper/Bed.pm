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

package EnsEMBL::Web::IOWrapper::Bed;

### Wrapper for Bio::EnsEMBL::IO::Parser::Bed, which builds
### simple hash features suitable for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Web::IOWrapper);

sub create_hash {
  my ($self, $metadata, $slice) = @_;
  $metadata ||= {};

  ## Start and end need to be relative to slice
  my $start = $self->parser->get_start;
  my $end   = $self->parser->get_end;
  if ($slice) {
    $start  -= $slice->start;
    $end    -= $slice->start;
  }

  ## Only set colour if we have something in file, otherwise
  ## we will override the default colour in the drawing code
  my $colour;
  my $rgb = $self->parser->get_itemRgb;
  if ($rgb) {
    $colour = $self->rgb_to_hex($rgb);
  }

  return {
    'start'         => $start,
    'end'           => $end,
    'seq_region'    => $self->parser->get_seqname,
    'strand'        => $self->parser->get_strand,
    'score'         => $self->parser->get_score,
    'label'         => $self->parser->get_name,
    'colour'        => $colour, 
    'structure'     => $self->create_structure($start, $end, $slice->length),
  };
}

sub create_structure {
  my ($self, $feature_start, $feature_end, $slice_length) = @_;
  warn ">>> FEATURE $feature_start, $feature_end, $slice_length";

  if (!$self->parser->get_blockCount || !$self->parser->get_blockSizes 
          || !$self->parser->get_blockStarts) {
    return undef; 
  } 

  my $structure = [];

  my @block_starts  = @{$self->parser->get_blockStarts};
  my @block_lengths = @{$self->parser->get_blockSizes};
  my $thick_start   = $self->parser->get_thickStart;
  my $thick_end     = $self->parser->get_thickEnd;

  ## Fix for non-intuitive configuration of non-coding transcripts
  if ($thick_start == $thick_end) {
    $thick_start  = 0;
    $thick_end    = 0;
  }
  my $has_coding = $thick_start || $thick_end ? 1 : 0;

  ## Ignore thick start/end if it's outside the current region
  $thick_start = 0 if $thick_start < 1;
  $thick_end = 0 if $thick_end >= $slice_length;

  foreach(0..($self->parser->get_blockCount - 1)) {
    ## Blocks are defined relative to feature start, so we need to convert
    ## to actual image coordinates
    my $start   = shift @block_starts;
    $start     += $feature_start;
    my $length  = shift @block_lengths;
    my $end     = $start + $length;

    my $block = {'start' => $end, 'end' => $end};
    
    if (!$has_coding) {
      $block->{'coding'} = 0; 
    }
    else {
      if ($thick_start && $thick_start > $start) {## 5' UTR
        if ($thick_start > $end) {
          $block->{'coding'} = 0; 
        }
        else {
          $block->{'utr_5'} = $thick_start - $start;
        }
      }
      elsif ($thick_end && $thick_end < $end) { ## 3' UTR
        if ($thick_end < $start) {
          $block->{'coding'} = 0; 
        }
        else {
          $block->{'utr_3'} = $thick_end - $start;
        }
      }
    }
    push @$structure, $block;
  }
  use Data::Dumper; warn Dumper($structure);

  return $structure;
}

1;
