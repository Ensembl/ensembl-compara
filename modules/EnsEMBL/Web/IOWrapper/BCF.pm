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

package EnsEMBL::Web::IOWrapper::BCF;

### Wrapper around Bio::EnsEMBL::IO::Parser::VCF4Tabix

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::IO::Parser::BCF;

use parent qw(EnsEMBL::Web::IOWrapper::VCF4);

sub open {
  ## Factory method - creates a wrapper of the appropriate type
  ## based on the format of the file given
  my ($url, $args) = @_;

  my $wrapper;
  my $hub = $args->{'options'}{'hub'};
  if ($hub) {
    ## This is a bit clunky but at least it works!
    my $parser = Bio::EnsEMBL::IO::Parser::BCF::open_with_location('Bio::EnsEMBL::IO::Parser::BCF', $url, $hub->species_defs->ENSEMBL_USERDATA_DIR.'/temporary/bcf_index/');

    if ($parser) {

      $wrapper = EnsEMBL::Web::IOWrapper::BCF->new({
                              'parser' => $parser,
                              'format' => 'BCF',
                              %{$args->{options}||{}}
                            });
    }
  }
  return $wrapper;
}

sub nearest_feature { return undef; }

1;
