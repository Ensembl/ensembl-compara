=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping

=cut

=head1 SYNOPSIS

Required inputs:
	- an arrayref of homology_ids
	- URL pointing to the previous release database
	- pointer to current database (usually doesn't require explicit definition)

Example:
	standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping -input_id "{'homology_ids' => [11,12,13,14,15], 'prev_rel_db' => 'mysql://ensro@compara5/cc21_ensembl_compara_84', 'compara_db' => 'mysql://ensro@compara2/mp14_protein_trees_85'}"

=cut

=head1 DESCRIPTION

Homology ids can change from one release to the next. This runnable detects
the homology id from the previous release database based on the gene members
of the current homologies.

Data should be flowed out to a table to be queried later by pipelines aiming
to reuse homology data.

=cut

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my @homology_ids = @{ $self->param_required('homology_ids') };
	my $mlss_id      =    $self->param_required('mlss_id');

	# # check orth mlss does not contain non-reuse species
	# my $non_reuse_species = $self->param('reuse_species_csv');
	# my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
	# my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);
	# my $species = $mlss->species_set->genome_dbs;



	my $current_homo_adaptor = $self->compara_dba->get_HomologyAdaptor;

	my $previous_db = $self->param('prev_rel_db');
	die("No prev_rel_db provided") unless ( defined $previous_db );
	my $previous_compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($previous_db);
	my $previous_homo_adaptor = $previous_compara_dba->get_HomologyAdaptor;
	my $prev_gene_member_adaptor = $previous_compara_dba->get_GeneMemberAdaptor;

	my @homology_mapping;
	foreach my $hid ( @homology_ids ) {
		my $curr_homology = $current_homo_adaptor->fetch_by_dbID( $hid );
		next unless $curr_homology;
		my @gene_members = @{ $curr_homology->get_all_GeneMembers() };

		my @prev_gene_members;
		foreach my $gm ( @gene_members ) {
			my $prev_gm = $prev_gene_member_adaptor->fetch_by_stable_id( $gm->stable_id ); # must use stable_id as gene_member_id can change between releases
			push ( @prev_gene_members, $prev_gm ) if defined $prev_gm;
		}

		my $prev_homology_id; # should be left undef if 2 gene members are not found
		if ( scalar @prev_gene_members == 2 ) {
			my $prev_homology = $previous_homo_adaptor->fetch_by_Member_Member( @prev_gene_members );
			$prev_homology_id = defined $prev_homology ? $prev_homology->dbID : undef;
		}
		push( @homology_mapping, { mlss_id => $mlss_id, prev_release_homology_id => $prev_homology_id, curr_release_homology_id => $curr_homology->dbID } );
		
	}

	$self->param( 'homology_mapping', \@homology_mapping );
}

sub write_output {
	my $self = shift;

	print "FLOWING: ";
	print Dumper $self->param('homology_mapping');

	$self->dataflow_output_id( $self->param( 'homology_mapping' ), 1 );
	$self->compara_dba->dbc->disconnect_if_idle();
}

1;