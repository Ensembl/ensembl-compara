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
  my $seqname       = $self->parser->get_seqname;
  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $strand        = $self->parser->get_strand;
  my $score         = $self->parser->get_score;

  my $colour_params  = {
                        'metadata'  => $metadata, 
                        'strand'    => $strand, 
                        'score'     => $score,
                        'itemRgb'   => $self->parser->get_itemRgb,
                        };
  my $colour = $self->set_colour($colour_params);

  my $id = $self->parser->can('get_id') ? $self->parser->get_id
            : $self->parser->can('get_name') ? $self->parser->get_name : undef;

  my $href = $self->href({
                        'id'          => $id,
                        'url'         => $metadata->{'url'},
                        'seq_region'  => $seqname,
                        'start'       => $feature_start,
                        'end'         => $feature_end,
                        });

  return {
    'start'         => $feature_start - $slice->start,
    'end'           => $feature_end - $slice->start,
    'seq_region'    => $seqname,
    'strand'        => $strand,
    'score'         => $score,
    'label'         => $self->parser->get_name,
    'colour'        => $colour,
    'structure'     => $self->create_structure($feature_start, $slice->start),
    'href'          => $href,
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
      $block->{'non_coding'} = 1; 
    }
    else {
      if ($thick_start && $thick_start > $start) {## 5' UTR
        if ($thick_start > $end) {
          $block->{'non_coding'} = 1; 
        }
        else {
          $block->{'utr_5'} = $thick_start - $start;
        }
      }
      elsif ($thick_end && $thick_end < $end) { ## 3' UTR
        if ($thick_end < $start) {
          $block->{'non_coding'} = 1; 
        }
        else {
          $block->{'utr_3'} = $thick_end - $start;
        }
      }
    }
    push @$structure, $block;
  }

  return $structure;
}

1;
