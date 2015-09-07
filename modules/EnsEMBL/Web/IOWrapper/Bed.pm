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
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param metadata - Hashref of information about this track
### @param slice - Bio::EnsEMBL::Slice object
### @return Hashref
  my ($self, $metadata, $slice) = @_;
  $metadata ||= {};
  return unless $slice;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;

  ## Only set colour if we have something in file, otherwise
  ## we will override the default colour in the drawing code
  my $colour;
  my $strand  = $self->parser->get_strand;
  my $score   = $self->parser->get_score;

  if ($metadata->{'useScore'} || $metadata->{'spectrum'}) {
    $colour = $self->convert_to_gradient($score, $metadata->{'color'});
  }
  elsif ($metadata->{'itemRgb'} eq 'On') {
    my $rgb = $self->parser->get_itemRgb;
    if ($rgb) {
      $colour = $self->rgb_to_hex($rgb);
    }
  }
  elsif ($metadata->{'colorByStrand'} && $strand) {
    my ($pos, $neg) = split(' ', $metadata->{'colorByStrand'});
    my $rgb = $strand == 1 ? $pos : $neg;
    $colour = $self->rgb_to_hex($rgb);
  }
  elsif ($metadata->{'color'}) {
    $colour = $metadata->{'color'};
  }

  return {
    'start'         => $feature_start - $slice->start,
    'end'           => $feature_end - $slice->start,
    'seq_region'    => $self->parser->get_seqname,
    'strand'        => $strand,
    'score'         => $score,
    'label'         => $self->parser->get_name,
    'colour'        => $colour, 
    'structure'     => $self->create_structure($feature_start, $slice->start),
  };
}

sub create_structure {
  my ($self, $feature_start, $slice_start) = @_;

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
  else {
    ## Adjust to make relative to slice (and compensate for BED coords)
    $thick_start -= ($slice_start - 1);
    $thick_end   -= $slice_start;
  }

  ## Does this feature have _any_ coding sequence?
  my $has_coding = $thick_start || $thick_end ? 1 : 0;

  foreach(0..($self->parser->get_blockCount - 1)) {
    my $start   = shift @block_starts;
    ## Adjust to be relative to slice and compensate for BED format
    my $offset  = $feature_start - $slice_start;
    $start      = $start + $offset + 1;
    my $length  = shift @block_lengths;
    my $end     = $start + $length - 1;

    my $block = {'start' => $start, 'end' => $end};
    
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
      else {
        $block->{'coding'} = 1;
      }
    }
    push @$structure, $block;
  }

  return $structure;
}

1;
