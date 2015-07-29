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

package EnsEMBL::Web::IOWrapper::PairwiseSimple;

### Wrapper for Bio::EnsEMBL::IO::Parser::PairwiseSimple, which builds
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

  ## Skip this feature if the interaction crosses chromosomes
  my ($seqname_2, $feature_2_start, $feature_2_end) = $self->parser->get_interacting_region;
  return if $seqname_2 ne $slice->seq_region_name;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $slice_start     = $slice->start;
  my $feature_1_start = $self->parser->get_start - $slice_start;
  my $feature_1_end   = $self->parser->get_end - $slice_start;
  $feature_2_start   -= $slice_start;
  $feature_2_end     -= $slice_start;

  ## Only set colour if we have something in file, otherwise
  ## we will override the default colour in the drawing code
  my $colour;
  my $score = $self->parser->get_score;
  if ($score && $score =~ /\d+,\d+,\d+/) {
    ## Score field can be 'hacked' to set a colour
    $colour = $self->rgb_to_hex($score);
    $score  = undef;
  }
  else {
    $colour = $self->convert_to_gradient($score);
  }

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
    'structure'     => $structure,
  };
}

1;
