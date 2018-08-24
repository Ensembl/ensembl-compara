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
Bio::EnsEMBL::Compara::RunnableDB::ImportAltAlleGroupAsHomologies
=head1 AUTHORSHIP
Ensembl Team. Individual contributions can be found in the GIT log.
=cut

package StoreHomologies;

use strict;
use warnings;

use Data::Dumper;
use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:row_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

## Defines the default parameters for the Job
sub param_defaults 
{
    return 
	{
		'protein_tree_stable_id' => undef,
		'homologies' => [],
		'ordered_data' => 1,
		'pseudogene_column' => 0,
		'functionnal_gene_column' => 1,
		'delimiter' => ' ',
		'db_conn' => undef,
    };
}

## This subroutine is called before run in order to check that all the parameters are correct
sub fetch_input {
    my $self = shift @_;

	die "Tree stable ID must be defined" unless defined($self->param('protein_tree_stable_id'));

	my $db_conn = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url => $self->param('db_conn')) or die "Could not connect to Master DB";

    # Adaptors in the current Compara DB
    $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
    $self->param('homology_adaptor', $self->compara_dba->get_HomologyAdaptor);
	$self->param('gene_tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);
	$self->param('master_gene_tree_adaptor', $db_conn->get_GeneTreeAdaptor);
	$self->param('tree_node_adaptor', $self->compara_dba->get_GeneTreeNodeAdaptor);
}	## TODO : Insert a sub in order to compute the alignement ? Or maybe do it in another module        

sub run 
{
    my $self = shift @_;

	my $gene_member_adaptor = $self->param('gene_member_adaptor');
	my $master_gene_tree_adaptor = $self->param('master_gene_tree_adaptor');
	my $gene_tree_adaptor = $self->param('gene_tree_adaptor');
	my $treenode_adaptor = $self->param('tree_node_adaptor');

	my $compara_db = $self->param('compara_db');
	my $db_conn = $self->param('db_conn');

	my @genes;
	my $pseudogene_stable_id;
	my $parent_stable_id;
	my $pseudogene;
	my $functionnal_gene;
	my $mlss;

	my $pseudogene_transcript;
	my $functionnal_gene_transcript;

	my $specie1_genome_db_id;
	my $specie2_genome_db_id;
	my @gdbids;
	my $method_name;
	my $tag = "";

	## Fetching the root of the tree in the Master db
	my $tree_stable_id = $self->param('protein_tree_stable_id');
	my $tree = $master_gene_tree_adaptor->fetch_by_stable_id($tree_stable_id);

	die "No tree with id $tree_stable_id in source database" unless defined($tree);

	my $root = $tree->root;
	my $root_id = $root->dbID;
	my $description;

	$tree = $gene_tree_adaptor->fetch_by_stable_id($tree_stable_id);
	die "No tree with $tree_stable_id in target database" unless(defined($tree));
	## For each member line of the parametrer file
	foreach my $pair(@{$self->param('homologies')})
	{
		print($pair);
		chomp($pair);
		## Fecthing informations fr om the file
		@genes = split($self->param('delimiter'), $pair);
		$pseudogene_stable_id = $genes[$self->param('pseudogene_column')];
		$parent_stable_id = $genes[$self->param('functionnal_gene_column')];

		## Fecthing genes from stable IDs
		$pseudogene = $gene_member_adaptor->fetch_by_stable_id($pseudogene_stable_id);
		$functionnal_gene = $gene_member_adaptor->fetch_by_stable_id($parent_stable_id);

		## Skip unless both the pseudogene and the parent gene are in the database and the pseudogene and the parent gene are different	
		next unless defined($pseudogene) && defined($functionnal_gene) && !($pseudogene->stable_id eq $functionnal_gene->stable_id);

		## Get the right mlss according to the two genes
		if (defined($self->param('homology_adaptor')->fetch_by_Member_Member($pseudogene, $functionnal_gene)))
		{
			## Remove when working on a Clean System
			warn "Homology between $pseudogene_stable_id and $parent_stable_id already exist";  
			my $seq = $pseudogene->get_canonical_SeqMember;
			$tag .= $seq->stable_id.',';		
			if(!defined($tree->find_leaf_by_name($seq->stable_id)))
			{	
				my $node_to_insert = new Bio::EnsEMBL::Compara::GeneTreeMember;
				$node_to_insert->seq_member_id($seq->dbID);
				$tree->root->add_child($node_to_insert); # Will connect the objects together, which will tell the adaptor the parent_id
				$node_to_insert->tree($tree); # Will connect the objects together, which will tell the adaptor the root_id
				$treenode_adaptor->store_node($node_to_insert);
			}
			next;
		}

		## Checking if the two members have changed, in order to save a MLSS fetching
		$specie1_genome_db_id = $pseudogene->genome_db_id;
		$specie2_genome_db_id = $functionnal_gene->genome_db_id;
		
		if ( $specie1_genome_db_id == $specie2_genome_db_id)
		{
			@gdbids = ($specie1_genome_db_id);
			$method_name = 'ENSEMBL_PSEUDOGENES_PARALOGUES';
			$description = 'pseudogene_paralog';
		}
		else
		{
			@gdbids = ($specie1_genome_db_id, $specie2_genome_db_id);
			$method_name = 'ENSEMBL_PSEUDOGENES_ORTHOLOGUES';
			$description = 'pseudogene_ortholog';
		}

		$mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_genome_db_ids($method_name, \@gdbids)
			            or die sprintf('Cannot find the MLSS %s[%s%s] in the database', $method_name, $gdbids[0], defined($gdbids[1]) ? "/".$gdbids[1] : "");

		## Converting genes member into SeqMembers and then AlignedMembers
		$pseudogene_transcript = $pseudogene->get_canonical_SeqMember;
		$functionnal_gene_transcript = $functionnal_gene->get_canonical_SeqMember;

		bless $pseudogene_transcript, 'Bio::EnsEMBL::Compara::AlignedMember';
		bless $functionnal_gene_transcript, 'Bio::EnsEMBL::Compara::AlignedMember';

        # Create the homology Object

        	my $homology = new Bio::EnsEMBL::Compara::Homology;

		## TODO : Add more type of description for pseudogenes objects (if needed)        
		$homology->description($description);
		$homology->is_tree_compliant(0);
		$homology->method_link_species_set($mlss);

		$homology->add_Member($pseudogene_transcript);
		$homology->add_Member($functionnal_gene_transcript);

		my $seq = $pseudogene->get_canonical_SeqMember;
		$tag .= $seq->stable_id.',';

		if(!defined($tree->find_leaf_by_name($seq->stable_id)))
		{	
			my $node_to_insert = new Bio::EnsEMBL::Compara::GeneTreeMember;
			$node_to_insert->seq_member_id($seq->dbID);
			$tree->root->add_child($node_to_insert); # Will connect the objects together, which will tell the adaptor the parent_id
			$node_to_insert->tree($tree); # Will connect the objects together, which will tell the adaptor the root_id
			$treenode_adaptor->store_node($node_to_insert);
		}

		$self->param('homology_adaptor')->store($homology); #unless $self->param('dry_run');
    }

	## Add the added gene tag to all the objects
	$tree->store_tag('added_genes_list', $tag);
	$self->dataflow_output_id({'gene_tree_id' => $root_id}, 1)
}

1;
