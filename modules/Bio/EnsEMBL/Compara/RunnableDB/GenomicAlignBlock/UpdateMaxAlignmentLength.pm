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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::UpdateMaxAlignmentLength

=cut

=head1 SYNOPSIS


$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

Updates the entries in the meta table for the largest alignment length for a give method link species set.
Checks for data inconsistencies in the genomic_align_block and genomic_align tables eg there are 2 genomic_aligns for each genomic_align_block. Removes any inconsistencies.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength;

use strict;
use warnings;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  if (defined $self->param('output_method_link') && defined $self->param('query_genome_db_id') && $self->param('target_genome_db_id')) {
    my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($self->param('output_method_link'), [$self->param('query_genome_db_id'),$self->param('target_genome_db_id')]);

    if (defined $mlss && !defined $self->param('method_link_species_set_id')) {
	$self->param('method_link_species_set_id', $mlss->dbID);
    }
  }

  return 1;
}


sub run
{
  my $self = shift;
  $self->update_mlss_tag_table;
  return 1;
}


sub write_output
{
  my $self = shift;
  return 1;
}


######################################
#
# subroutines
#
#####################################

sub update_mlss_tag_table {
  my $self = shift;

  my $dba = $self->compara_dba;

  $dba->dbc->do("analyze table genomic_align_block");
  $dba->dbc->do("analyze table genomic_align");

  #Get method_link_species_set object
  my $mlssa = $dba->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlssa->fetch_by_dbID($self->param('method_link_species_set_id'));

  #Don't like doing this but it looks to be the only way to avoid going mad WRT where & and clauses
  my @args;
  my ($mlss_where_clause, $mlss_and_clause) = ('','');
  if ($self->param('method_link_species_set_id')) {
    $mlss_where_clause = ' WHERE gab.method_link_species_set_id =? ';
    $mlss_and_clause = ' AND gab.method_link_species_set_id =? ';
    push(@args, $self->param('method_link_species_set_id'));
  }

  my $sql;
  if ($self->param('quick')) {
      $sql = "SELECT gab.method_link_species_set_id, max(gab.length) FROM genomic_align_block gab ${mlss_where_clause} GROUP BY gab.method_link_species_set_id";
  } else {
  	$sql = "SELECT ga.method_link_species_set_id, max(ga.dnafrag_end - ga.dnafrag_start + 1) FROM genomic_align_block gab, genomic_align ga WHERE gab.genomic_align_block_id = ga.genomic_align_block_id ${mlss_and_clause} GROUP BY ga.method_link_species_set_id";
  }

  print "Running: ${sql}\n" if $self->debug();

  my $sth = $dba->dbc->prepare($sql);

  $sth->execute(@args);

  my $max_alignment_length = 0;
  my ($method_link_species_set_id,$max_align);
  $sth->bind_columns(\$method_link_species_set_id,\$max_align);

  while ($sth->fetch()) {
      $mlss->delete_tag("max_align") if ($mlss->has_tag("max_align"));
      $mlss->store_tag("max_align", $max_align + 1);
      print STDERR "Stored key:max_align value:",$max_align + 1," in method_link_species_set_tag table\n";
  }

  $sth->finish;

}

1;
