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

package EnsEMBL::Web::Object::Search;

### NAME: EnsEMBL::Web::Object::Search
### An empty wrapper object, used by search results pages 

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Has no data access functionality, just page settings

### DESCRIPTION


use strict;

use base qw(EnsEMBL::Web::Object);

sub default_action { return 'New'; }
sub short_caption  { my $sitetype = $_[0]->species_defs->ENSEMBL_SITETYPE || 'Ensembl'; return $_[1] eq 'global' ? 'New Search' : "Search $sitetype"; }
sub caption        { my $sitetype = $_[0]->species_defs->ENSEMBL_SITETYPE || 'Ensembl'; return "$sitetype text search"; }
sub counts         {}

1;
