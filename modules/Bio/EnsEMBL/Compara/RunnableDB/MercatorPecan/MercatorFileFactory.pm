=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::MercatorFileFactory 

=head1 DESCRIPTION
Create jobs for DumpMercatorFiles

Supported keys:
    'mlss_id' => <number>
     Pecan method link species set id. Obligatory

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::MercatorFileFactory;

use strict;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
  my( $self) = @_;

  if (!defined $self->param('mlss_id')) {
      die "'mlss_id' is an obligatory parameter";
  }

  return 1;
}

sub run
{
  my $self = shift;
}

sub write_output {
  my ($self) = @_;

  my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor()->fetch_by_dbID($self->param('mlss_id'));
  my $gdbs = $mlss->species_set_obj->genome_dbs;
  my @genome_db_ids;
  foreach my $gdb (@$gdbs) {
      push @genome_db_ids, $gdb->dbID;
  }

  while (my $gdb_id1 = shift @genome_db_ids) {

      my $list_gdbs = "[" . (join ",", @genome_db_ids) . "]";
      my $output_id = "{genome_db_id => " . $gdb_id1 . ", genome_db_ids => ' $list_gdbs " . "'}";
      $self->dataflow_output_id($output_id, 2);
  }

  return 1;
}

1;
