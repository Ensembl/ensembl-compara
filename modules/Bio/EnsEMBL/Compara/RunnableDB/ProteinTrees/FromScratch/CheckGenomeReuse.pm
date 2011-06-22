
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability

=head1 DESCRIPTION

This Runnable checks whether a certain genome_db data can be reused for the purposes of ProteinTrees pipeline

The format of the input_id follows the format of a Perl hash reference.
Example:
    { 'genome_db_id' => 90 }

supported keys:
    'genome_db_id'  => <number>
        the id of the genome to be checked (main input_id parameter)
        
    'release'       => <number>
        number of the current release

    'prev_release'  => <number>
        (optional) number of the previous release for reuse purposes (may coincide, may be 2 or more releases behind, etc)

    'registry_dbs'  => <list_of_dbconn_hashes>
        list of hashes with registry connection parameters (tried in succession).

    'reuse_this'    => <0|1>
        (optional) if defined, the code is skipped and this value is passed to the output

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FromScratch::CheckGenomeReuse;

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Compara::GenomeDB;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
	my $self = shift @_;

	return if(defined($self->param('reuse_this')));  # bypass fetch_input() and run() in case 'reuse_this' has already been passed

	my $reuse_db = $self->param('reuse_db');
	my $reuse_this = 0;

	if (!$reuse_db) {
		$self->warning("reuse_db hash has not been set, so cannot reuse");
	} else {

		# Need to check that the genome_db_id has not changed (treat the opposite as a signal not to reuse) :
		my $reuse_compara_dba = $self->go_figure_compara_dba($reuse_db);    # may die if bad parameters
		my $reuse_genome_db_adaptor = $reuse_compara_dba->get_GenomeDBAdaptor();
		my $reuse_genome_db;
		eval {
			$reuse_genome_db = $reuse_genome_db_adaptor->fetch_by_taxon_id($self->param('ncbi_taxon_id'));
		};
		if ($reuse_genome_db) {
			$reuse_this = $reuse_genome_db->dbID;
			#$reuse_this = ($self->param('ncbi_taxon_id') > 1000 ? 0 : $reuse_genome_db->dbID);
			#$reuse_this = 0;
		} else {
			$self->warning("Could not fetch genome_db object for taxon_id ".$self->param('ncbi_taxon_id')." from reuse_db");
		}
	}

	# same base composition of the output, independent of the branch:
	my $output_hash = {
		'filename'           => $self->param('filename'),
		'ncbi_taxon_id'      => $self->param('ncbi_taxon_id'),
		'species_name'       => $self->param('species_name'),
		'reuse_this'         => $reuse_this ? 1 : 0,
	};
	if ($reuse_this) {
		${$output_hash}{'genome_db_id'} = $reuse_this;
	}

	# The flow is split between branches 2 and 3 depending on $reuse_this:
	$self->dataflow_output_id( $output_hash, $reuse_this ? 3 : 2);
}

1;
