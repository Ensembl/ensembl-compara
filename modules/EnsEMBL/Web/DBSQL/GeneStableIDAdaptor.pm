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

package EnsEMBL::Web::DBSQL::GeneStableIDAdaptor;

### A simple adaptor to fetch gene autocomplete data from the ensembl_gene_autocomplete database


use strict;
use warnings;
no warnings 'uninitialized';

use DBI;

sub new {
  my ($class, $hub, $settings) = @_;
  $settings ||= {};
  
    my $self = {
    'NAME' => $settings->{'name'} || $hub->species_defs->multidb->{'DATABASE_GENE_AUTOCOMPLETE'}{'NAME'},
    'HOST' => $settings->{'host'} || $hub->species_defs->multidb->{'DATABASE_GENE_AUTOCOMPLETE'}{'HOST'},
    'PORT' => $settings->{'port'} || $hub->species_defs->multidb->{'DATABASE_GENE_AUTOCOMPLETE'}{'PORT'},
    'USER' => $settings->{'user'} || $hub->species_defs->multidb->{'DATABASE_GENE_AUTOCOMPLETE'}{'USER'},
    'PASS' => $settings->{'pass'} || $hub->species_defs->multidb->{'DATABASE_GENE_AUTOCOMPLETE'}{'PASS'},
  };
  bless $self, $class;
  return $self;
}

sub db {
  my $self = shift;
  return unless $self->{'NAME'};
  $self->{'dbh'} ||= DBI->connect(
      "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
      $self->{'USER'}, "$self->{'PASS'}"
  );
  return $self->{'dbh'};
}

1;