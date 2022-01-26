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

package EnsEMBL::Web::IOWrapper::Psl;

### Wrapper for Bio::EnsEMBL::IO::Parser::Bed, which builds
### simple hash features suitable for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Web::IOWrapper);

sub create_hash {
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;
  $metadata ||= {};

  my ($seq_region, $feature_start, $feature_end) = $self->coords;
  my $start         = $feature_start - $slice->start + 1;
  my $end           = $feature_end - $slice->start + 1;
  return if $end < 0 || $start > $slice->length;

  ## Only set colour from strand if we have something in file, otherwise
  ## we will override the default colour in the drawing code
  my $strand  = $self->parser->get_strand || 0;
  
  ## Not sure if this is the right way to calculate score, but it seems reasonable!
  my $score = ($self->parser->get_matches / ($self->parser->get_misMatches || 1)) * 1000;

  my $colour_params  = {
                        'metadata'  => $metadata,
                        'strand'    => $strand,
                        'score'     => $score,
                        };
  my $colour = $self->set_colour($colour_params);

  my $label = $self->parser->get_qName;
  my $href = $self->href({
                        'id'          => $label,
                        'url'         => $metadata->{'url'} || '',
                        'seq_region'  => $seq_region,
                        'start'       => $feature_start,
                        'end'         => $feature_end,
                        'strand'      => $strand,
                        });

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $hash = {
    'seq_region'    => $seq_region,
    'strand'        => $strand,
    'score'         => $score,
    'label'         => $label,
    'href'          => $href,
    'colour'        => $colour, 
    'join_colour'   => $metadata->{'join_colour'} || $colour,
    'label_colour'  => $metadata->{'label_colour'} || $colour,
  };
  if ($metadata->{'display'} eq 'text') {
    $hash->{'start'}      = $feature_start;
    $hash->{'end'}        = $feature_end;
    $hash->{'extra'} = [
                        {'name' => 'Hit end', 'value' => $self->parser->get_qEnd},
                        {'name' => 'Matches', 'value' => $self->parser->get_matches},
                        {'name' => 'Mismatches', 'value' => $self->parser->get_misMatches},
                        {'name' => 'N Matches', 'value' => $self->parser->get_nCount},
                        {'name' => 'Q base inserts', 'value' => $self->parser->get_qBaseInsert},
                        {'name' => 'Q num inserts', 'value' => $self->parser->get_qNumInsert},
                        {'name' => 'Query size', 'value' => $self->parser->get_qSize},
                        {'name' => 'Repeat matches', 'value' => $self->parser->get_repMatches},
                        {'name' => 'T num inserts', 'value' => $self->parser->get_tNumInsert},
                        ];
  }
  else {
    $hash->{'start'}      = $start;
    $hash->{'end'}        = $end;
    $hash->{'structure'}  = $self->create_structure($slice->start);
  }
  return $hash;
}

sub create_structure {
  my ($self, $slice_start) = @_;

  if (!$self->parser->get_blockCount || !$self->parser->get_blockSizes 
          || !$self->parser->get_tStarts) {
    return undef; 
  } 

  my $structure = [];

  my @block_starts  = @{$self->parser->get_tStarts};
  my @block_lengths = @{$self->parser->get_blockSizes};

  foreach(0..($self->parser->get_blockCount - 1)) {
    my $start   = shift @block_starts;
    ## Need to adjust to be relative to slice
    $start     -= $slice_start;
    my $length  = shift @block_lengths;
    my $end     = $start + $length;

    ## The drawing code uses 'coding' to indicate a filled block
    my $block = {'start' => $start, 'end' => $end, 'coding' => 1};
    
    push @$structure, $block;
  }

  return $structure;
}

sub coords {
  ### Simple accessor to return the coordinates from the parser
  my $self = shift;
  return ($self->parser->get_tName, $self->parser->get_tStart, $self->parser->get_tEnd);
}

1;
