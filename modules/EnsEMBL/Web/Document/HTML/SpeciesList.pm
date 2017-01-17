=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self      = shift;
  my $sitename  = $self->hub->species_defs->ENSEMBL_SITETYPE;

  return sprintf qq(<div class="clear static_all_species"><h3>All genomes</h3>
    <p><select class="_all_species"><option value="">-- Select a species --</option></select></p>
    <p><a href="/info/about/species.html">View full list of all %s species</a></p>
    </div>), $sitename;
}

1;
