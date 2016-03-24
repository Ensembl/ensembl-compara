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

package EnsEMBL::Web::IOWrapper::VCF4;

### Wrapper for Bio::EnsEMBL::IO::Parser::VCF4, which builds
### simple hash features suitable for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Web::IOWrapper);

sub colourset { return 'variation'; }

sub create_hash {
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;

  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $start         = $feature_start - $slice->start;
  my $end           = $feature_end - $slice->start;
  return if $end < 0 || $start > $slice->length;

  my $seqname       = $self->parser->get_seqname;
  my @feature_ids   = @{$self->parser->get_IDs};

  $metadata ||= {};

  my $href = $self->href({
                        'seq_region'  => $seqname,
                        'start'       => $feature_start,
                        'end'         => $feature_end,
                        });

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my @alleles = ($self->parser->get_reference);
  push @alleles, @{$self->parser->get_alternatives};
  my $feature = {
    'seq_region'    => $seqname,
    'label'         => join(',', @feature_ids),
    'colour'        => $metadata->{'colour'},
    'label_colour'  => $metadata->{'label_colour'},
    };
  if ($metadata->{'display'} eq 'text') {
    $feature->{'start'} = $feature_start;
    $feature->{'end'}   = $feature_end;
    $feature->{'extra'} = [
                        {'name' => 'Alleles', 'value' => join('/', @alleles)},
                        {'name' => 'Quality', 'value' => $self->parser->get_score},
                        {'name' => 'Filter',  'value' => $self->parser->get_raw_filter_results},
                        {'name' => 'Info',    'value' => $self->parser->get_raw_info},
                        ];
  }
  else {
    $feature->{'start'} = $start;
    $feature->{'end'}   = $end;
    $feature->{'href'}  = $href;
  }
  return $feature;
}

1;
