=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonSummary

=cut

=head1 DESCRIPTION

This module updates the method_link_species_set_tag table with pair aligner coding exon statistics from the statistics table

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonSummary;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
  my ($self) = @_;

  #Find the mlss_id from the method_link_type and genome_db_ids
  my $mlss;
  my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  if (defined $self->param('mlss_id')) {
      $mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));
  } else{
      if (defined $self->param('method_link_type') && $self->param('genome_db_ids')) {
	  die ("No method_link_species_set") if (!$mlss_adaptor);
	  $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($self->param('method_link_type'), $self->param('genome_db_ids'));
	  $self->param('mlss_id', $mlss->dbID);
      } else {
	  die("must define either mlss_id or method_link_type and genome_db_ids");
      }
  }

  my $genome_dbs = $mlss->species_set->genome_dbs;
  my ($ref_genome_db, $non_ref_genome_db) = @$genome_dbs;
  unless (($genome_dbs->[0]->name eq $mlss->get_value_for_tag('reference_species'))
      && (!$mlss->has_tag('reference_component') || ($genome_dbs->[0]->genome_component eq $mlss->get_value_for_tag('reference_component')))) {
        ($non_ref_genome_db, $ref_genome_db) = @$genome_dbs;
  }
  $self->param('ref_genome_db', $ref_genome_db);
  $self->param('non_ref_genome_db', $non_ref_genome_db);

  return 1;
}

sub run {
  my $self = shift;

  return 1;
}

sub write_output {
  my $self = shift;

  return if ($self->param('skip'));

  my $compara_dba = $self->compara_dba;
  my $mlss_id = $self->param('mlss_id');
  my ($coding_exon_length, $matches, $mis_matches, $ref_insertions, $uncovered);

  my $sql = "SELECT SUM(coding_exon_length), SUM(matches), SUM(mis_matches), SUM(ref_insertions), SUM(uncovered) FROM statistics WHERE genome_db_id = ? AND method_link_species_set_id = ?";
  my $sth = $self->dbc->prepare($sql);

  #Ref species
  $sth->execute($self->param('ref_genome_db')->dbID, $mlss_id);

  $sth->bind_columns(\$coding_exon_length, \$matches, \$mis_matches, \$ref_insertions, \$uncovered);
  $sth->fetch();
  #print "coding_exon_length $coding_exon_length $matches $mis_matches $ref_insertions $uncovered\n";

  my $method_link_species_set = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
  $method_link_species_set->store_tag("ref_coding_exon_length", $coding_exon_length);
  $method_link_species_set->store_tag("ref_matches", $matches);
  $method_link_species_set->store_tag("ref_mis_matches", $mis_matches);
  $method_link_species_set->store_tag("ref_insertions", $ref_insertions);
  $method_link_species_set->store_tag("ref_uncovered", $uncovered);

  #Non-ref species
  $sth->execute($self->param('non_ref_genome_db')->dbID, $mlss_id);
  $sth->fetch();
  #print "coding_exon_length $coding_exon_length $matches $mis_matches $ref_insertions $uncovered\n";

  $method_link_species_set->store_tag("non_ref_coding_exon_length", $coding_exon_length);
  $method_link_species_set->store_tag("non_ref_matches", $matches || 0);
  $method_link_species_set->store_tag("non_ref_mis_matches", $mis_matches || 0);
  $method_link_species_set->store_tag("non_ref_insertions", $ref_insertions || 0);
  $method_link_species_set->store_tag("non_ref_uncovered", $uncovered);

  return 1;

}


1;
