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
  my ($self, $slice, $extra_config) = @_;
  my $data = [];

  ## For speed, our track consists of an array of values, not an array of feature hashes
  my $parser = $self->parser;
  my $bins   = $extra_config->{'bins'};
  my $values = $parser->fetch_summary_array($slice->seq_region_name, $slice->start, $slice->end, $bins);
  my $metadata = {
                  'max_score'   => max(@$values),
                  'min_store'   => min(@$values), 
                  %$extra_config,
                  };
  if ($extra_config->{'display'} eq 'compact') {
    my @gradient = $self->create_gradient(['white', $extra_config->{'colour'}]);
    $metadata->{'gradient'} = \@gradient;
  }
  else {
    $metadata->{'gradient'} = [$metadata->{'colour'}];
  }
  my $strand = $extra_config->{'default_strand'} || 1;
  return [{'metadata' => $metadata, 'features' => {$strand => $values}}];
}

1;
