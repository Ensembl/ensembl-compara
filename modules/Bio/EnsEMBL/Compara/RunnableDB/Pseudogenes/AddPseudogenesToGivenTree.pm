use strict;
use warnings;

package AddPseudogenesToGivenTree;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Compara::Utils::Preloader;

#use feature qw(switch);

#use Bio::EnsEMBL::Utils::Exception;
#use Bio::EnsEMBL::Compara::Utils::Cigars;

#use base ('Bio::EnsEMBL::Compara::SeqMember');


## Defines the default parameters for the Job
sub param_defaults 
{
    return 
	{
		'gene_tree_id' => undef,
    };
}

## This subroutine is called before run in order to check that all the parameters are correct
sub fetch_input
{
    my $self = shift @_;

	## Gets the adaptor form the database
	$self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
	$self->param('gene_tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);
	$self->param('homology_adaptor', $self->compara_dba->get_HomologyAdaptor);
	$self->param('seq_member_adaptor', $self->compara_dba->get_SeqMemberAdaptor);

}

sub run 
{
	my $self = shift @_;

	print("Fetching adaptors...");
	# Retreive adaptators from the parameters
	my $gene_tree_adaptor = $self->param('gene_tree_adaptor');
	my $gene_member_adaptor = $self->param('gene_member_adaptor');
	my $homology_adaptor = $self->param('homology_adaptor');
	my $seq_member_adaptor = $self->param('seq_member_adaptor');

	my $value;
	my $tree = $gene_tree_adaptor->fetch_by_root_id($self->param('gene_tree_id'));
	# my $tree = $gene_tree_adaptor->fetch_by_stable_id('ENSGT00390000001455');

	my $member;
	while(!defined($member))
	{
		$member = $seq_member_adaptor->fetch_by_stable_id(@{$tree->get_all_leaves}[0]->name)->gene_member;
	}
	die "Could not fecth a gene member from the tree" unless defined($member);
 	my ($pseudogenes_homologies, $gene_list) = $homology_adaptor->fetch_orthocluster_with_Member($member);


	my $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($self->compara_dba->get_AlignedMemberAdaptor, $pseudogenes_homologies);
	Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($gene_member_adaptor, $sms);
	print("Done\n");
	my $i;

	## For each member line of the parametrer file
	foreach my $this_homology(@{$pseudogenes_homologies})
	{
		next if(!$this_homology->description =~ /pseudogene/);
		my @genes = @{$this_homology->get_all_Members};

		my $pseudogene;
		my $gene;

		## print(scalar @{$genes}, "\n");
		if($genes[0]->gene_member->biotype_group =~ /pseudogene/ && !($genes[1]->gene_member->biotype_group =~ /pseudogene/))
		{
			$pseudogene = $genes[0]->gene_member;
			$gene = $genes[1]->gene_member;
		}

		elsif($genes[1]->gene_member->biotype_group =~ /pseudogene/ && !($genes[0]->gene_member->biotype_group =~ /pseudogene/))
		{
			$pseudogene = $genes[1]->gene_member;
			$gene = $genes[0]->gene_member;
		}

		else
		{
			## warn("WARNING : Both genes ", $genes[0]->gene_member->stable_id , ", ", $genes[1]->gene_member->stable_id , " have the same biotype [",$genes[0]->gene_member->biotype_group , "]");
			next;
		}

		my $treenode_adaptor = $tree->adaptor->db->get_GeneTreeNodeAdaptor;
		my $seq = $pseudogene->get_canonical_SeqMember;
		$value .= $seq->stable_id.',';
		if(!defined($tree->find_leaf_by_name($seq->stable_id)))
		{	
			my $node_to_insert = new Bio::EnsEMBL::Compara::GeneTreeMember;
			$node_to_insert->seq_member_id($seq->dbID);
			$tree->root->add_child($node_to_insert); # Will connect the objects together, which will tell the adaptor the parent_id
			$node_to_insert->tree($tree); # Will connect the objects together, which will tell the adaptor the root_id
			$treenode_adaptor->store_node($node_to_insert);
		}
		else
		{	
			warn("The pseudogene is already in tree for transcript ID : ", $seq->dbID, "[", $seq->stable_id, "]\n");
		}
	}

	$tree->store_tag('added_genes_list', $value);
}

1;
