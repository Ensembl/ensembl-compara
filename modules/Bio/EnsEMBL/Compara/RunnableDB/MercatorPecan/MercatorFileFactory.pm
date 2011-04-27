=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::MercatorFileFactory 

=head1 SYNOPSIS


=head1 DESCRIPTION
Create jobs for DumpMercatorFiles

Supported keys:
    'mlss_id' => <number>
     Pecan method link species set id. Obligatory

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::MercatorFileFactory;

use strict;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
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
  my $gdbs = $mlss->species_set;
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
