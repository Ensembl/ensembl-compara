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
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;
  $metadata ||= {};

  ## Skip this feature if the interaction crosses chromosomes
  my ($seqname_2, $feature_2_start, $feature_2_end) = $self->parser->get_interacting_region;
  return if $seqname_2 ne $slice->seq_region_name;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $seqname         = $self->parser->get_seqname;
  return if $seqname ne $slice->seq_region_name;
  my $slice_start     = $slice->start;
  ## Capture real start and end coordinates for use in zmenu link
  my $click_start     = $self->parser->get_start;
  my $click_end       = $feature_2_end;

  my $offset          = $slice->start - 1;
  my $feature_1_start = $click_start - $offset;
  my $feature_1_end   = $self->parser->get_end - $offset;
  $feature_2_start   -= $offset;
  $feature_2_end     -= $offset;
  return if $feature_2_end < 0 || $feature_1_start > $slice->length;

  my $structure = [
                  {'start' => $feature_1_start, 'end' => $feature_1_end},
                  {'start' => $feature_2_start, 'end' => $feature_2_end},
                  ];

  my $href = $self->href({
                        'seq_region'  => $seqname,
                        'start'       => $click_start,
                        'end'         => $click_end,
                        'strand'      => 0,
                        });

  my $score = $self->parser->get_score;
  my $direction = $self->parser->get_direction;
  my $feature = {
    'seq_region'    => $self->parser->get_seqname,
    'direction'     => $direction,
    'score'         => $score,
    'structure'     => $structure,
    'extra'         => [{'name' => 'Direction', 'value' => $direction}],
  };
  if ($metadata->{'display'} eq 'text') {
    $feature->{'start'} = $click_start;
    $feature->{'end'}   = $click_end;
  }
  else {
    $feature->{'start'} = $feature_1_start;
    $feature->{'end'}   = $feature_2_end;
    $feature->{'href'}  = $href;
  }
  return $feature;
}

sub post_process {
### Adjust colours based on score
  my ($self, $data) = @_;
  my $colour_params;

  while (my ($key, $info) = each (%$data)) {
    foreach my $f (@{$info->{'features'}}) {
      $colour_params  = {'metadata'  => $info->{'metadata'}};
      my $score = $f->{'score'};
      next unless defined $score;

      if ($score =~ /\d+,\d+,\d+/) {
        $info->{'metadata'}{'itemRgb'}  = 'On';
        $colour_params->{'rgb'} = $score;
      }
      else {
        $info->{'metadata'}{'spectrum'}   = 'on';
        $colour_params->{'score'} = $score;
      }
      my $colour = $self->set_colour($colour_params);

      $f->{'colour'}      = $colour;
      $f->{'join_colour'} = $info->{'metadata'}{'join_colour'} || $colour;
    }
  }
}

1;
