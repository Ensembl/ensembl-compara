#!/software/bin/perl

use warnings;
use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Getopt::Long;
use Bio::EnsEMBL::Utils::Exception qw(throw);

#
#Script to take a full species tree and either a set of required species taken from
#a database or a list of genome_db_ids and prune it to leave only the required species.
#

my $help;
my $genome_db_list;
my $url;
my $tree_file;
my $output_taxon_file;
my $output_tree_file;
my $taxon_program;

GetOptions('help'        => \$help,
           'url=s'       => \$url,
           'tree_file=s'       => \$tree_file,
	   'genome_db_ids=s' => \$genome_db_list,
	   'taxon_output_filename=s' => \$output_taxon_file,
	   'njtree_output_filename=s' => \$output_tree_file,
	   'taxon_program=s' => \$taxon_program,
);

if ($help) { usage(); }

my $genome_dbs;
my @genome_db_ids;
my $compara_dba;

#try to guess based on where this script is
if(!defined $taxon_program) {
    #Extract the directory of this script
    $0=~/^(.+[\\\/])[^\\\/]+[\\\/]*$/;
    my $dir= $1 || "./";
    $taxon_program = $dir . "../tree/testTaxonTree.pl";
    print "dir $dir $taxon_program\n";
    if (!-e $taxon_program && defined $output_taxon_file) {
	throw("Unable to find testTaxonTree.pl script. Please give as an argument --taxon_program");
    }
}

if ($url && $url =~ /^mysql:\/\//) {
    $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url => $url);
} else {
    throw("Must define a url");
}

if (defined $genome_db_list) {
    my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$url);
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    @genome_db_ids = split ":", $genome_db_list;
    foreach my $genome_db_id (@genome_db_ids) {
	my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
	push @$genome_dbs, $genome_db;
    }
} else {
    $genome_dbs = $compara_dba->get_GenomeDBAdaptor->fetch_all();
}

my $newick_tree = qx"cat $tree_file";

my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick_tree);

#Assume only can have either genome_db or genome_db_ids
my %leaves_names;
my @taxon_ids;
foreach my $genome_db (@$genome_dbs) {
    my $name = $genome_db->name;
    next if (lc($name) eq "ancestral_sequences");
    push @taxon_ids, $genome_db->taxon_id;
    $leaves_names{$name} = 1;
}
print "\n";

foreach my $genome_db_id (@genome_db_ids) {
    $leaves_names{$genome_db_id} = 1;
}

 foreach my $leaf (@{$tree->get_all_leaves}) {
     unless (defined $leaves_names{lc($leaf->name)}) {
 	#print $leaf->name," leaf disavowing parent\n";
 	$leaf->disavow_parent;
 	$tree = $tree->minimize_tree;
     }
}
print "Taxon_ids: \n", join ("_", @taxon_ids) . "\n";

print "Tree after pruning:\n", $tree->newick_simple_format(), "\n";

if (defined $output_taxon_file) {
    my $taxon_id_str = join ("_", @taxon_ids);

    my $cmd = "$taxon_program" . " -url $url -create_species -extrataxon_sequenced $taxon_id_str -no_previous 1 -njtree_output_filename $output_taxon_file -no_other_files 2>/dev/null";

    unless (system($cmd) == 0) {
	throw("$cmd execution failed\n");
    }

    #open FH, ">$output_taxon_file" or die "$!";
    #print FH join ("_", @taxon_ids) . "\n";
    #close FH;
}

if (defined $output_tree_file) {
    open FH, ">$output_tree_file" or die "$!";
    print FH $tree->newick_simple_format() . "\n";
    close FH;
}

sub usage {
  warn "Specifically used in the LowCoverageGenomeAlignment pipeline\n";
  warn "prune_tree.pl [options]\n";
  warn "  -help                          : print this help\n";
  warn "  -url <url>                     : connect to compara at url and use \n";
  warn "  -tree_file <file>              : read in full newick tree from file\n";
  warn "  -genome_db_ids <list>          : ':' separated list of genome_db_ids\n";
  warn "  -taxon_output_filename <file>  : filename to write taxon_ids to\n";
  warn "  -njtree_output_filename <file> : filename to write pruned treee to\n";
  exit(1);  
}
