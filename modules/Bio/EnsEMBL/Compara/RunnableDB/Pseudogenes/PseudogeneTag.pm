package Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::PseudogeneTag;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


## Defines the default parameters for the Job
sub param_defaults 
{
    return 
	{
		'gene_tree_id' => undef,
		'input_clusterset_id' => 'raxml_update',
    };
}

## This subroutine is called before run in order to check that all the parameters are correct
sub fetch_input
{
    my $self = shift @_;

	die "The tree stable ID must be specified" unless defined($self->param('gene_tree_id'));

	## Gets the adaptor form the database
	$self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
	$self->param('gene_tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);
	$self->param('homology_adaptor', $self->compara_dba->get_HomologyAdaptor);
	$self->param('seq_member_adaptor', $self->compara_dba->get_SeqMemberAdaptor);
}

sub run
{
	my $self = shift @_;

	my $tree_id = $self->param('gene_tree_id');

	# Retreive adaptators from the parameters
	my $gene_tree_adaptor = $self->param('gene_tree_adaptor');
	my $gene_member_adaptor = $self->param('gene_member_adaptor');
	my $seq_member_adaptor = $self->param('seq_member_adaptor');

	my $tree = $gene_tree_adaptor->fetch_by_dbID($tree_id);
	die sprintf('Cannot find a tree for tree_id=%d', $self->param('gene_tree_id')) unless $tree;	
	$tree = $tree->alternative_trees->{$self->param('input_clusterset_id')};
	die sprintf('Cannot find a "%s" tree for tree_id=%d', $self->param('input_clusterset_id'), $self->param('gene_tree_id')) unless $tree;

	my $root = $tree->root;
	my %pseudogene_child_count; #Pseudogene child count contains a value 
	my %tag_to_add;

	my %pseudogene_node;

	my $func;
	$func = sub
	{
		my $node = shift;
		#bless  $node, "Bio::EnsEMBL::Compara::GeneTreeNode";
		if($node->is_leaf)
		{
			my $seq = $seq_member_adaptor->fetch_by_stable_id($node->name);
			if(defined($seq))
			{
				my $gene_member = $seq->gene_member;
				$pseudogene_node{$node->dbID} = 1;
				return (defined($gene_member) && $gene_member->biotype_group =~ /pseudogene/);
			}
			else
			{
				warn("No sequence found with stable id : ", $node->name);
				return 0;
			}
		}
		else
		{		
			my $children = $node->children;
			my $pseudo_child_count = 0;
			my @values;
			foreach my $local_node(@$children)
			{
				#bless $local_node, "Bio::EnsEMBL::Compara::GeneTreeNode";
				#print $local_node, "\n";
				if ($func->($local_node))
				{
					$pseudo_child_count += 1;
					push @values, $local_node->dbID;
				}
			}
			if($pseudo_child_count >= scalar @$children)
			{
				$pseudogene_node{$node->dbID} = 1;
				return 1;
			}
			if($pseudo_child_count > 0)
			{
				foreach my $value(@values)
				{
					print("Adding Pseudogene Tag to Node ", $node->dbID, " with value $value\n");
					$node->store_tag('pseudogene', $value);
				}
			}
			return 0;
		}
	};
	
	#add_pseudogene_tag($root);
	$func->($root);
	$tree->release_tree;
}
1;
