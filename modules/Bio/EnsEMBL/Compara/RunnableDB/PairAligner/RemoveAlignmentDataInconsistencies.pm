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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies

=cut

=head1 SYNOPSIS


$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

Checks for data inconsistencies in the genomic_align_block and genomic_align tables eg there are 2 genomic_aligns for each genomic_align_block. Removes any inconsistencies.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies;

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
  $self->remove_alignment_data_inconsistencies;
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

sub remove_alignment_data_inconsistencies {
  my $self = shift;

  my $dba = $self->compara_dba;

  $dba->dbc->do("analyze table genomic_align_block");
  $dba->dbc->do("analyze table genomic_align");

  #Delete genomic align blocks which have no genomic aligns. Assume not many of these
  #

  my $sql_gab = "delete from genomic_align_block where genomic_align_block_id in ";
  my $sql_ga = "delete from genomic_align where genomic_align_id in ";

  my $gab_sel = '';
  my @gab_args;
  if($self->param('method_link_species_set_id')) {
    $gab_sel = 'AND gab.method_link_species_set_id =?';
    push(@gab_args, $self->param('method_link_species_set_id'));
  }
  my $sql = "SELECT gab.genomic_align_block_id FROM genomic_align_block gab LEFT JOIN genomic_align ga ON gab.genomic_align_block_id=ga.genomic_align_block_id WHERE ga.genomic_align_block_id IS NULL ${gab_sel}";

	print "Running: ${sql}\n" if $self->debug();

  my $sth = $dba->dbc->prepare($sql);
  $sth->execute(@gab_args);

  my @gab_ids;
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($gab_id) = @$aref;
    push @gab_ids, $gab_id;
  }
  $sth->finish;

  #check if any results found
  if (scalar @gab_ids) {
      $self->warning("Found " . scalar @gab_ids . " genomic_align_blocks with no genomic_aligns");

    my $sql_gab_to_exec = $sql_gab . "(" . join(",", @gab_ids) . ");";
    my $sth = $dba->dbc->prepare($sql_gab_to_exec);
    $sth->execute;
    $sth->finish;
  }

  #
  #Delete genomic align blocks which have 1 genomic align. Assume not many of these
  #
  my @del_args;
  if($self->param('method_link_species_set_id')) {
    $sql = 'SELECT gab.genomic_align_block_id, ga.genomic_align_id FROM genomic_align_block gab LEFT JOIN genomic_align ga USING (genomic_align_block_id) WHERE gab.method_link_species_set_id =? GROUP BY genomic_align_block_id HAVING count(*)<2';
    push(@del_args, $self->param('method_link_species_set_id'));
  }
  else {
    $sql = 'SELECT genomic_align_block_id, genomic_align_id FROM genomic_align GROUP BY genomic_align_block_id HAVING count(*)<2';
  }

  print "Running: ${sql}\n" if $self->debug();

  $sth = $dba->dbc->prepare($sql);
  $sth->execute(@del_args);

  @gab_ids = ();
  my @ga_ids;
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($gab_id, $ga_id) = @$aref;
    push @gab_ids, $gab_id;
    push @ga_ids, $ga_id;
  }
  $sth->finish;

  if (scalar @gab_ids) {
      $self->warning("Found " . scalar @gab_ids . " genomic_align_blocks with only one genomic_align.");

    my $sql_gab_to_exec = $sql_gab . "(" . join(",", @gab_ids) . ")";
    my $sql_ga_to_exec = $sql_ga . "(" . join(",", @ga_ids) . ")";

    foreach my $sql ($sql_ga_to_exec,$sql_gab_to_exec) {
      my $sth = $dba->dbc->prepare($sql);
      $sth->execute;
      $sth->finish;
    }
  }
}


1;
