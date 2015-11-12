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

package EnsEMBL::Web::IOWrapper::PairwiseTabix;

### Wrapper around Bio::EnsEMBL::IO::Parser::PairwiseTabix

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Web::IOWrapper::Indexed);

sub create_tracks {
  my ($self, $slice, $metadata) = @_;

  ## Limit file seek to current slice
  my $parser = $self->parser;
  $parser->seek($slice->seq_region_name, $slice->start, $slice->end);

  $self->SUPER::create_tracks($slice, $metadata);
}

sub coords {
### Simple accessor to return the coordinates from the parser
### Note that for pairwise features we want the whole span of the pair
  my $self = shift;
  my $feature_2 = $self->parser->get_interacting_region;
  return ($self->parser->get_seqname, $self->parser->get_start, $feature_2->[2]);
}

sub create_hash {
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;
  $metadata ||= {};
  ## Pairwise interactions have no strand
  $metadata->{'strands'}{0}++;

  ## Skip this feature if the interaction crosses chromosomes
  my ($seqname_2, $feature_2_start, $feature_2_end, $score) = @{$self->parser->get_information};
  return if $seqname_2 ne $slice->seq_region_name;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $slice_start     = $slice->start;
  my $feature_1_start = $self->parser->get_start - $slice_start;
  my $feature_1_end   = $self->parser->get_end - $slice_start;
  $feature_2_start   -= $slice_start;
  $feature_2_end     -= $slice_start;

  ## Set colour for feature
  my $colour_params  = {
                        'metadata'  => $metadata,
                        'strand'    => 1,
                        };
  if ($score) {
    if ($score =~ /\d+,\d+,\d+/) {
      $colour_params->{'itemRgb'} = $score;
    }
    else {
      $metadata->{'useScore'}   = 1;
      $colour_params->{'score'} = $score;
    }
  }
  my $colour = $self->set_colour($colour_params);

  my $structure = [
                  {'start' => $feature_1_start, 'end' => $feature_1_end},
                  {'start' => $feature_2_start, 'end' => $feature_2_end},
                  ];

  return {
    'start'         => $feature_1_start,
    'end'           => $feature_2_end,
    'seq_region'    => $self->parser->get_seqname,
    'direction'     => $self->parser->get_direction,
    'score'         => $score,
    'colour'        => $colour,
    'join_colour'   => $metadata->{'join_colour'} || $colour,
    'label_colour'  => $metadata->{'label_colour'} || $colour,
    'structure'     => $structure,
  };
}

1;
