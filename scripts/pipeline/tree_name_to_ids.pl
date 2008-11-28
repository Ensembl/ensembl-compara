use warnings;use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url => $ARGV[1]);
my $file = $ARGV[0];
my $newick_tree = qx"cat $file";
print "INPUT TREE:\n$newick_tree\n";
my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick_tree);

print "TREE AFTER PARSING:\n", $tree->newick_simple_format(), "\n";

my $genome_dbs = $compara_dba->get_GenomeDBAdaptor->fetch_all();

my $species_name_to_dbID;
foreach my $this_genome_db (@$genome_dbs) {
    $species_name_to_dbID->{$this_genome_db->name} = $this_genome_db->dbID;
}
my $no_id = 1000;

foreach my $this_leaf (@{$tree->get_all_leaves}) {  
    my $leaf_name = $this_leaf->name;
    $leaf_name =~ s/_/ /;
    if (defined($species_name_to_dbID->{$leaf_name})) { 
	$this_leaf->name($species_name_to_dbID->{$leaf_name});
    } else {    
	warn "No dbID for species <".$this_leaf->name.">\n";    
	$this_leaf->name($no_id++);  
    }
}

print "TREE WITH INTERNAL IDS\n", $tree->newick_simple_format(), "\n";
