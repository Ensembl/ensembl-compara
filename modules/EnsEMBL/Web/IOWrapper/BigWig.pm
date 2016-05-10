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
  my $data = [];

  ## For speed, our track consists of an array of values, not an array of feature hashes
  my $parser    = $self->parser;
  my $bins      = $metadata->{'bins'};
  my $strand    = $metadata->{'default_strand'} || 1;
  my $features  = [];
  my $values    = [];

  ## Allow for seq region synonyms
  my $seq_region_names = [$slice->seq_region_name];
  if ($metadata->{'use_synonyms'}) {
    push @$seq_region_names, map {$_->name} @{ $slice->get_all_synonyms };
  }

  if ($metadata->{'display'} eq 'text') {
    my $arrays;
    foreach my $seq_region_name (@$seq_region_names) {
      $arrays = $parser->fetch_summary_data($seq_region_name, $slice->start, $slice->end, $bins) || [];
      last if @$arrays;
    }
    foreach (@$arrays) {
      push @$features, {
                      'seq_region' => $_->[0],
                      'start'      => $_->[1],
                      'end'        => $_->[2],
                      'score'      => $_->[3], 
                      };
      push @$values, $_->[3];
    }
  }
  else {
    foreach my $seq_region_name (@$seq_region_names) {
      $values = $parser->fetch_summary_array($seq_region_name, $slice->start, $slice->end, $bins) || [];
      last if @$values;
    }
    $features = $values;
    if ($metadata->{'display'} eq 'compact') {
      my @gradient = $self->create_gradient(['white', $metadata->{'colour'}]);
      $metadata->{'gradient'} = \@gradient;
    }
  }

  $metadata->{'max_score'} = max(@$values);
  $metadata->{'min_score'} = min(@$values);
  return [{'metadata' => $metadata, 'features' => $features}];
}

1;
