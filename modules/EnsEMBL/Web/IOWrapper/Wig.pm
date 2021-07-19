=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::IOWrapper::Wig;

### Wrapper for Bio::EnsEMBL::IO::Parser::Wig, which builds
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


  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $seqname       = $self->parser->get_seqname;
  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $score         = $self->parser->get_score;
  my $start         = $feature_start - $slice->start + 1;
  my $end           = $feature_end - $slice->start + 1;
  return if $end < 0 || $start > $slice->length;

  $metadata ||= {};

  my $colour_params  = {
                        'metadata'  => $metadata,
                        'score'     => $score,
                        };

  my $colour = $self->set_colour($colour_params);

  my $feature = {
    'seq_region'    => $seqname,
    'score'         => $score,
    'colour'        => $colour,
    'join_colour'   => $metadata->{'join_colour'} || $colour,
    'label_colour'  => $metadata->{'label_colour'} || $colour,
  };

  if ($metadata->{'display'} eq 'text') {
    $feature->{'start'} = $feature_start;
    $feature->{'end'}   = $feature_end;
  }
  else {
    $feature->{'start'} = $start;
    $feature->{'end'}   = $end;
    $feature->{'href'}  = $self->href({
                                        'seq_region'  => $seqname,
                                        'start'       => $feature_start,
                                        'end'         => $feature_end,
                                        'strand'      => 0,
                                      });
  }

  return $feature;
}

1;
