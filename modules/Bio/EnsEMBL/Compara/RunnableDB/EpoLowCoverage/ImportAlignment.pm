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

Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::ImportAlignment

=head1 DESCRIPTION

This module imports a specified alignment. This is used in the low coverage genome alignment pipeline for importing the high coverage alignment which is used to build the low coverage genomes on.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::ImportAlignment;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

    #if the database name is defined in the url, then open that
    if ($self->param('from_db_url') =~ /mysql:\/\/.*@.*\/.+/) {
	$self->param('from_comparaDBA', new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$self->param('from_db_url')));
    } else {
	#open the most recent compara database
	$self->param('from_comparaDBA', Bio::EnsEMBL::Registry->get_DBAdaptor("Multi", "compara"));
    }

    $self->param('from_dbc', $self->param('from_comparaDBA')->dbc);
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Run gerp
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift;

    #Quick and dirty import, assuming the 2 databases are on the same server. Useful for debugging
    if ($self->param('quick')) {
	$self->importAlignment_quick();
    } else {
	$self->importAlignment();
    }

}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Write results to the database
    Returns :   1
    Args    :   none

=cut

sub write_output {
    my ($self) = @_;

    return 1;
}

#Uses copy_data method from Utils::CopyData module
sub importAlignment {
    my $self = shift;

    my $dbname = $self->param('from_dbc')->dbname;
    my $mlss_id = $self->param('method_link_species_set_id');

    my $ancestor_genome_db = $self->param('from_comparaDBA')->get_GenomeDBAdaptor()->fetch_by_name_assembly("ancestral_sequences");
    my $ancestral_dbID_constraint = $ancestor_genome_db ? ' AND genome_db_id != '.$ancestor_genome_db->dbID : '';

    #HACK to just copy over one chr (22) for testing purposes
    #my $dnafrag_id = 905407;

    my $dnafrag_id;

    if ($self->param('dnafrag_id')) {
	$dnafrag_id = $self->param('dnafrag_id');
    }

    #Copy the species_set_header
    copy_data($self->param('from_dbc'), $self->compara_dba->dbc,
	      "species_set_header",
	      "SELECT species_set_header.* FROM species_set_header JOIN method_link_species_set USING (species_set_id) WHERE method_link_species_set_id = $mlss_id");

    #Copy the method_link_species_set
    copy_table($self->param('from_dbc'), $self->compara_dba->dbc,
	      "method_link_species_set",
	      "method_link_species_set_id = $mlss_id");

    #Copy the species_set
    copy_data($self->param('from_dbc'), $self->compara_dba->dbc,
	      "species_set",
	      "SELECT species_set.* FROM species_set JOIN method_link_species_set USING (species_set_id) WHERE method_link_species_set_id = $mlss_id");

    #copy genomic_align_block table
    my $gab_sql;
    if ($dnafrag_id) {
        $gab_sql = "SELECT gab.* FROM genomic_align_block gab LEFT JOIN genomic_align ga USING (genomic_align_block_id) WHERE ga.method_link_species_set_id = $mlss_id AND dnafrag_id=$dnafrag_id";
    } else {
        $gab_sql = "SELECT * FROM genomic_align_block WHERE method_link_species_set_id = $mlss_id";
    }
    copy_data($self->param('from_dbc'), $self->compara_dba->dbc,
              "genomic_align_block",
              $gab_sql);

    #copy genomic_align_tree table
    my $gat_sql;
    if ($dnafrag_id) {
        $gat_sql = "SELECT gat.*".
                    " FROM genomic_align_tree gat  LEFT JOIN genomic_align USING (node_id)".
                    " WHERE node_id IS NOT NULL AND method_link_species_set_id = $mlss_id AND dnafrag_id=$dnafrag_id";
    } else {
        $gat_sql = "SELECT gat.*".
                    " FROM genomic_align ga".
                    " JOIN dnafrag USING (dnafrag_id)".
                    " LEFT JOIN genomic_align_tree gat USING (node_id) WHERE ga.node_id IS NOT NULL AND ga.method_link_species_set_id = $mlss_id $ancestral_dbID_constraint";
    }
    copy_data($self->param('from_dbc'), $self->compara_dba->dbc,
              "genomic_align_tree",
              $gat_sql);

    #copy genomic_align table
    my $ga_sql;
    if ($dnafrag_id) {
        $ga_sql = "SELECT ga.*".
                    " FROM genomic_align ga ".
                    " WHERE method_link_species_set_id = $mlss_id AND dnafrag_id=$dnafrag_id";
    } else {
	#Don't copy over ancestral genomic_aligns 
        $ga_sql = "SELECT genomic_align.*".
                    " FROM genomic_align JOIN dnafrag USING (dnafrag_id)".
                    " WHERE method_link_species_set_id = $mlss_id $ancestral_dbID_constraint";
    }
    copy_data($self->param('from_dbc'), $self->compara_dba->dbc,
              "genomic_align",
              $ga_sql);
}


#Assumes the from and to databases are on the same server and downloads all entries from genomic_align_block, genomic_align
#and genomic_align_tree
sub importAlignment_quick {
    my $self = shift;

    my $dbname = $self->param('from_dbc')->dbname;
    my $mlss_id = $self->param('method_link_species_set_id');

    #my $sql = "INSERT INTO genomic_align_block SELECT * FROM ?.genomic_align_block WHERE method_link_species_set_id = ?\n";
    my $sql = "INSERT INTO genomic_align_block SELECT * FROM $dbname.genomic_align_block\n";

    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    #$sth->execute($dbname, $mlss_id);
    $sth->finish();

     #$sql = "INSERT INTO genomic_align SELECT genomic_align.* FROM ?.genomic_align LEFT JOIN WHERE method_link_species_set_id = ?\n";
    $sql = "INSERT INTO genomic_align SELECT * FROM $dbname.genomic_align\n";
    $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    #$sth->execute($dbname, $mlss_id);
    $sth->finish();

    #$sql = "INSERT INTO genomic_align_tree SELECT genomic_align_tree.* FROM ?.genomic_align_tree LEFT JOIN ?.genomic_align_group USING (node_id) LEFT JOIN ?.genomic_align USING (genomic_align_id) LEFT JOIN ?.genomic_align_block WHERE genomic_align_block.method_link_species_set_id = ?\n";
    $sql = "INSERT INTO genomic_align_tree SELECT * FROM $dbname.genomic_align_tree\n";
    $sth = $self->compara_dba->dbc->prepare($sql);

    #$sth->execute($dbname, $dbname, $dbname, $dbname, $mlss_id);
    $sth->execute();
    $sth->finish();

}

1;
