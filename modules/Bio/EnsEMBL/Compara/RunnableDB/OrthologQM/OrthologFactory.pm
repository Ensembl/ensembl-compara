=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory

=head1 SYNOPSIS

=head1 DESCRIPTION
	Takes as input the mlss id of the lastz pairwise alignment. 
	Grabs all the homologs 
	from the homologs, only keeps the orthologs
	exports two hashes where the values are the list of orthologs and the keys are the dnafrag DBIDs. one each hash the other species is used as the reference species.

    Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory -mlss_id <mlss id>
=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;


=head2 param_defaults

    Description : Implements param_defaults() interface method of Bio::EnsEMBL::Hive::Process that defines module defaults for parameters. Lowest level parameters

=cut

sub param_defaults {
    my $self = shift;
    return {
            %{ $self->SUPER::param_defaults() },
		'mlss_id'	=>	'100021',
		'compara_db' => 'mysql://ensro@compara4/OrthologQM_test_db',
#		'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82',
    };
}

=head2 fetch_input

	Description: pull orthologs for species 1 and 2 from EnsEMBL and save as param

=cut

sub fetch_input {
	my $self = shift;

#	my $mlss_id = $self->param_required('mlss_id');
#	print "yayayayayaya  ", $mlss_id, " hahahahahah \n\n";
#	my $registry = 'Bio::EnsEMBL::Registry';
	#$registry->load_registry_from_url( 'mysql://ensro@ens-livemirror/80', 0 );
	#my $homolog_adaptor = $registry->get_adaptor( 'Multi', 'compara', 'Homology' );
	#my $mlss_adaptor = $registry->get_adaptor( 'Multi', 'compara', 'MethodLinkSpeciesSet');

	$self->param('homolog_adaptor', $self->compara_dba->get_HomologyAdaptor);
	$self->param('mlss_adaptor', $self->compara_dba->get_MethodLinkSpeciesSetAdaptor);
	$self->param('gdb_adaptor', $self->compara_dba->get_GenomeDBAdaptor);

	my $species1_dbid;
	my $species2_dbid;
	my $mlss = $self->param('mlss_adaptor')->fetch_by_dbID($self->param_required('mlss_id'));
#	print $mlss , "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n\n";
	my $speciesSet_obj= $mlss->species_set_obj();
	my $speciesSet = $speciesSet_obj->genome_dbs();
	if ($speciesSet) {
		$species1_dbid = $speciesSet->[0]->dbID();
		$species2_dbid = $speciesSet->[1]->dbID();
	}
	my $homologs = $self->param('homolog_adaptor')->fetch_all_by_MethodLinkSpeciesSet($mlss);
	$self->param('ref_species_dbid', $species1_dbid);
	$self->param('non_ref_species_dbid', $species2_dbid);
	$self->param( 'ortholog_objects', $homologs );
	$self->param('mlss_ID', $self->param_required('mlss_id'));
#	print "$species1_dbid \n\n $species2_dbid \n\n";
}

=head2 run

	Description: parse Bio::EnsEMBL::Compara::Homology objects to get start and end positions
	of genes

=cut
sub run {
	my $self = shift;

	my $ref_ortholog_info_hashref;
	my $non_ref_ortholog_info_hashref;
	my $c = 0;
#	print scalar @{ $self->param('ortholog_objects') };
#	print "\nHHHHHHHHHHHHHHHHHHHH\n\n";
#	print $self->param('ref_species_dbid'), "\n\n", $self->param('non_ref_species_dbid'), "\n\n";
	
	while ( my $ortholog = shift( @{ $self->param('ortholog_objects') } ) ) {
		my $ref_gene_member = $ortholog->get_all_GeneMembers($self->param('ref_species_dbid'))->[0];
#		print $ref_gene_member , "\n\n";
		my $non_ref_gene_member = $ortholog->get_all_GeneMembers($self->param('non_ref_species_dbid'))->[0];
#		print $non_ref_gene_member , "\n\n";
		if ($ref_gene_member->get_canonical_SeqMember()->source_name() eq "ENSEMBLPEP") {
			$ref_ortholog_info_hashref->{$ref_gene_member->dnafrag_id()}{$ortholog->dbID()} = $ref_gene_member->dnafrag_start();
		}

		if ($non_ref_gene_member->get_canonical_SeqMember()->source_name() eq "ENSEMBLPEP") {
			$non_ref_ortholog_info_hashref->{$non_ref_gene_member->dnafrag_id()}{$ortholog->dbID()} = $non_ref_gene_member->dnafrag_start();
			$c++;
		}

#		last if $c >= 200;
	}
#	print $self->param('ref_species_dbid'), "  -------------------------------------------------------------Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Orthologs \n\n\n\n";
#	print Dumper($ref_ortholog_info_hashref);

#	print $self->param('non_ref_species_dbid'), "  -------------------------------------------------------------Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Orthologs \n\n\n\n";
#	print Dumper($non_ref_ortholog_info_hashref);
#$self->param( 'ortholog_info_hashref', {'ortholog_info_hashref' => $ref_ortholog_info_hashref} );
	$self->dataflow_output_id( {'ortholog_info_hashref' => $ref_ortholog_info_hashref, 'ref_species_dbid' => $self->param('ref_species_dbid'), 'non_ref_species_dbid' => $self->param('non_ref_species_dbid'), 'mlss_ID' => $self->param('mlss_ID') } , 2 );
#$self->param( 'ortholog_info_hashref', {'ortholog_info_hashref' => $non_ref_ortholog_info_hashref} );
	$self->dataflow_output_id( {'ortholog_info_hashref' => $non_ref_ortholog_info_hashref, 'ref_species_dbid' => $self->param('non_ref_species_dbid'), 'non_ref_species_dbid' => $self->param('ref_species_dbid'), 'mlss_ID' => $self->param('mlss_ID') } , 2 );
	#will be used in the ortholog_max_score runnable to pull only the percent scores for the orthologs belonging to this particular mlss id. Useful when the ortholog metric table contains orthologs from more than one pair of species like in the protein trees pipeline
	$self->dataflow_output_id( {'mlss_ID' => $self->param('mlss_ID')} , 1);

}

1;
#sub write_output {
#	my $self = shift;

	#$self->dataflow_output_id( $self->param('block_regions') );
#	$self->dataflow_output_id( { 'ortholog_objects' => $self->param('ortholog_objects'), 'ref_species_dbid' => $self->param('ref_species_dbid'), 'non_ref_species_dbid' => $self->param('non_ref_species_dbid')}, 2 );
#}

#1;

