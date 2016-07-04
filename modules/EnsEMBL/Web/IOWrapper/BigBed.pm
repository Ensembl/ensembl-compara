=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::IOWrapper::BigBed;

### Wrapper around Bio::EnsEMBL::IO::Parser::BigBed

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::IOWrapper::Bed;

use parent qw(EnsEMBL::Web::IOWrapper::Indexed);

sub create_hash { return EnsEMBL::Web::IOWrapper::Bed::create_hash(@_); }

sub create_structure { return EnsEMBL::Web::IOWrapper::Bed::create_structure(@_); }

sub create_tracks {
  my ($self, $slice, $metadata) = @_;

  ## Allow for seq region synonyms
  my $seq_region_names = [$slice->seq_region_name];
  if ($metadata->{'use_synonyms'}) {
    push @$seq_region_names, map {$_->name} @{ $slice->get_all_synonyms };
  }

  ## Limit file seek to current slice
  my $parser = $self->parser;
  foreach my $seq_region_name (@$seq_region_names) {
    last if $parser->seek($seq_region_name, $slice->start, $slice->end);
  }

  $self->SUPER::create_tracks($slice, $metadata);
}


1;
