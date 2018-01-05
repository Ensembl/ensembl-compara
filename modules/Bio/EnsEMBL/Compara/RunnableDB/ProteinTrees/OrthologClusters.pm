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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OrthologClusters

=head1 DESCRIPTION

This is the RunnableDB makes clusters consisting of given species list  orthologues(connected components, not necessarily complete graphs).

example:

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OrthologClusters

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OrthologClusters;

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Compara::Utils::ConnectedComponents;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');


sub param_defaults {
    return {
            'sort_clusters'         => 1,
            'immediate_dataflow'    => 0,
            'add_model_id'          => 0,
    };
}


=head2 fetch_input

	Description: pull orthologs for all pairwise combination of species in the list of given species

=cut

sub fetch_input {

	my $self = shift;

	$self->param('previous_dba' , $self->get_cached_compara_dba('ref_ortholog_db') );
	$self->param('prev_homolog_adaptor', $self->param('previous_dba')->get_HomologyAdaptor);
	$self->param('prev_mlss_adaptor', $self->param('previous_dba')->get_MethodLinkSpeciesSetAdaptor);
	$self->param('prev_genetree_adaptor', $self->param('previous_dba')->get_GeneTreeAdaptor);
	$self->param('mlss_adaptor', $self->compara_dba->get_MethodLinkSpeciesSetAdaptor);


    # Find the intersection of species -> used to make clusters
    my $this_mlss = $self->param('mlss_adaptor')->fetch_by_dbID($self->param_required('mlss_id'));
    my %curr_gdb_id = map {$_->dbID => 1} @{$this_mlss->species_set->genome_dbs};
    my $ref_mlss = $self->param('prev_mlss_adaptor')->fetch_all_by_method_link_type($this_mlss->method->type)->[0];
    my @gdb_objs = grep {$curr_gdb_id{$_->dbID}} @{$ref_mlss->species_set->genome_dbs};
    print "Species used to make clusters: ".join(", ", map {$_->name} @gdb_objs)."\n" if $self->debug;

    $self->param('member_type', $this_mlss->method->type eq 'PROTEIN_TREES' ? 'protein' : 'ncrna');

    $self->dbc and $self->dbc->disconnect_if_idle();

	my @allOrthologs;

	for (my $gb1_index =0; $gb1_index < scalar @gdb_objs; $gb1_index++) {

		for (my $gb2_index = $gb1_index +1; $gb2_index < scalar @gdb_objs; $gb2_index++ ) {

			my $mlss = $self->param('prev_mlss_adaptor')->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES',
                       [ $gdb_objs[$gb1_index], $gdb_objs[$gb2_index] ]);
			print "\n   ", $mlss->dbID, "    mlss id ".$mlss->toString."\n" if $self->debug() ;
			my $homologs = $self->param('prev_homolog_adaptor')->fetch_all_by_MethodLinkSpeciesSet($mlss);
			print scalar @{ $homologs}, " homolog size \n" if $self->debug() ;
			push (@allOrthologs, @{$homologs});
			print scalar @allOrthologs, "  all size \n" if $self->debug() ;
                        Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($self->param('previous_dba')->get_AlignedMemberAdaptor, $homologs);
		}
	} 
	$self->param('connected_split_genes', new Bio::EnsEMBL::Compara::Utils::ConnectedComponents);
	$self->param('ortholog_objects', \@allOrthologs );
        $self->param('previous_dba')->dbc->disconnect_if_idle();
}

sub run {
	my $self = shift;

    $self->_buildConnectedComponents($self->param('ortholog_objects'));

}

sub write_output {
    my $self = shift @_;

    $self->store_clusterset('default', $self->param('allclusters'));
}

sub _buildConnectedComponents {
	my $self = shift;
	my ($ortholog_objects) = @_;
    $self->dbc and $self->dbc->disconnect_if_idle();
    my $c = 0;
    my %allclusters = ();
    my %tree_model_id;
    my %member_model_id;
    $self->param('allclusters', \%allclusters);
    while ( my $ortholog = shift( @{ $ortholog_objects } ) ) {
		my $gene_members = $ortholog->get_all_Members();
		my $seq_mid1 = $gene_members->[0]->dbID;
		my $seq_mid2 = $gene_members->[1]->dbID;
		print "seq mem ids   :   $seq_mid1     :    $seq_mid2   \n " if $self->debug() ;
		$self->param('connected_split_genes')->add_connection($seq_mid1, $seq_mid2);
		$c++;
#		last if $c >= 30;
		if ($self->param('add_model_id')) {
                        unless ($tree_model_id{$ortholog->_gene_tree_root_id}) {
                            $tree_model_id{$ortholog->_gene_tree_root_id} = $ortholog->gene_tree->get_value_for_tag('model_id');
                            #my $tree = $self->param('prev_genetree_adaptor')->fetch
                        }
                        $member_model_id{$seq_mid1} = $tree_model_id{$ortholog->_gene_tree_root_id};
                        $member_model_id{$seq_mid2} = $tree_model_id{$ortholog->_gene_tree_root_id};
                }
	}
        printf("%d elements split into %d distinct components\n", $self->param('connected_split_genes')->get_element_count, $self->param('connected_split_genes')->get_component_count) if $self->debug();
	my $cluster_id=0;
        foreach my $comp (@{$self->param('connected_split_genes')->get_components}) {
            $allclusters{$cluster_id} = { 'members' => $comp };
            # By construction all the members of a component come from the
            # same tree, so there is a single possible model_id (when it exists)
            $allclusters{$cluster_id}->{'model_id'} = $member_model_id{$comp->[0]} if $member_model_id{$comp->[0]};
            $cluster_id++;
        }
        print Dumper(\%allclusters) if $self->debug;
}

1; 
