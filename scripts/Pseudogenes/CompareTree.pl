use strict;
use warnings;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host=>'mysql-ens-compara-prod-3.ebi.ac.uk', -port=>4523, -user=>'ensro', -dbname=>'ggiroussens_pseudogenes_v6');
my $stable_id = 'ENSGT00390000010863';
## print the tree to given format
my $path1 = "./originaltree.txt";
my $path2 = "./pseudogenetree.txt";

my $gene_tree_adaptor = $compara_dba->get_GeneTreeAdaptor;

my $tree = $gene_tree_adaptor->fetch_by_stable_id($stable_id);
my $tree_with_pseudogenes = $tree->alternative_trees->{'default'}; ## Tree in the RAxML update cluster_set

my $original_tree = $tree->alternative_trees->{'copy'}; ## Tree in the copy clusterset hasnt't been modified

my @pseudogenes_nodes = @{$tree_with_pseudogenes->root->get_all_nodes_by_tag_value ("pseudogene")};

for my $this_node(@pseudogenes_nodes)
{
	for my $leave(@{$this_node->get_all_leaves})
	{
		if($leave->gene_member->biotype_group =~ /pseudogene/)
		{
			print("Removing Leaf $leave->db_ID Tree...");
			$leave->disavow_parent();
			$tree_with_pseudogenes->minimize_tree();
		}
	}
	## $this_node->find_node_by_node_id($this_node->get_value_for_tag("pseudogene"))->disavow_parent();
}

## Write the first tree
open(my $f, '>', $path1);
printf( $f $original_tree->newick_format);
close($f);

## Wirte the second tree
open($f, '>', $path2);
printf( $f $tree_with_pseudogenes->newick_format);
close($f);

## Runs the command to blabla
system("/nfs/software/ensembl/latest/linuxbrew/Cellar/ktreedist/1.0.0/bin/Ktreedist.pl -rt $path1 -ct $path2 > ./output.txt");
system("/nfs/software/ensembl/latest/linuxbrew/bin/treebest treedist $path1 $path2 >> ./output.txt");
system("cat output.txt");
