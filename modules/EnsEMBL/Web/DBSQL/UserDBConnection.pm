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

package EnsEMBL::Web::DBSQL::UserDBConnection;

use strict;
use warnings;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::DBSQL::DirectDBConnection);

our $cache = EnsEMBL::Web::Cache->new;

my $dbh;

sub import {
  my ($class,$species_defs) = @_;

  my $caller = caller;
  $class->direct_connection($caller,
                            $species_defs->ENSEMBL_USERDB_NAME,
                            $species_defs->ENSEMBL_USERDB_HOST,
                            $species_defs->ENSEMBL_USERDB_PORT,
                            $species_defs->ENSEMBL_USERDB_USER,
                            $species_defs->ENSEMBL_USERDB_PASS);
  $caller->cache($cache) if $cache;
}

1;
