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

package EnsEMBL::Web::IOWrapper::BigWig;

### Wrapper around Bio::EnsEMBL::IO::Parser::BigWig

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(max min);

use EnsEMBL::Web::IOWrapper::Wig;

use parent qw(EnsEMBL::Web::IOWrapper::Indexed);

sub create_hash { return EnsEMBL::Web::IOWrapper::Wig::create_hash(@_); }

sub create_structure { return EnsEMBL::Web::IOWrapper::Wig::create_structure(@_); }

sub create_tracks {
  my ($self, $slice, $metadata) = @_;

  ## Limit file seek to current slice
  my $parser = $self->parser;
  if ($metadata->{'aggregate'}) {
    my $values = $parser->fetch_summary_array($slice->seq_region_name, $slice->start, $slice->end, 1000);
    ## For speed, our track consists of an array of values, not an array of feature hashes
    return [{'metadata' => {
                            'unit'    => $slice->length / 1000,
                            'length'  => $slice->length,
                            'strand'  => $slice->strand,
                            'colour'  => $metadata->{'colour'},
                            'max'     => max(@$values),
                            'min'     => min(@$values), 
                            },
            'features' => $values,
           }];
  }
  elsif ($slice->length > 1000) {
    $parser->fetch_summary_data($slice->seq_region_name, $slice->start, $slice->end, 1000);
    $self->SUPER::create_tracks($slice, $metadata);
  }
  else {
    $parser->seek($slice->seq_region_name, $slice->start, $slice->end);
    $self->SUPER::create_tracks($slice, $metadata);
  }
}

1;
