#!/usr/bin/perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Member;
use Getopt::Long;

my $reg = "Bio::EnsEMBL::Registry";

#my $tree_id = 112589;
my $tree_id = 2;
my $fmt = '%{n}%{":"d}';
my $help = 0;

my $opts = GetOptions(
		      "id:i" => \$tree_id,
		      "format:s" => \$fmt,
		      "help" => \$help
		     );

if ($help) {
  print <<'EOH';
ryo_newick.pl -- Output formatted trees based on a user supplied format

Options
     [-i|--id]     => Protein tree ID (defaults to 2)
     [-f|--format] => roll-your-own format to output the tree (defaults to '%{n}%{":"d}')
     [-h|--help]   => Prints this document and exits

See the documentation of Bio::EnsEMBL::Compara::FormatTree.pm for details.
Briefly, allowed one-letter attributes are:

n --> then "name" of the node ($tree->name)
d --> distance to parent ($tree->distance_to_parent)
c --> the common name ($tree->get_tagvalue('genbank common name'))
g --> gdb_id ($tree->adaptor->db->get_GenomeDBAdaptor->fetch_by_taxon_id($tree->taxon_id)->dbID)
t --> timetree ($tree->get_tagvalue('ensembl timetree mya')
l --> display_label ($tree->gene_member->display_label)
s --> genome short name ($tree->genome_db->short_name)
i --> stable_id ($tree->gene_member->stable_id)
p --> peptide Member ($tree->get_canonical_peptide_Member->stable_id)
x --> taxon_id ($tree->taxon_id)
m --> member_id ($tree->member_id)
o --> node_id ($self->node_id)
S --> species_name ($tree->genome_db->name)

EOH
exit;
}

print "tree_id => $tree_id\n";
print "format => $fmt\n\n";

$reg->load_registry_from_db(
                            -host => "127.0.0.1", # -host => "ens-livemirror",
                            -port => 2902,        # -port => 3306,
                            -user => "ensro",
                            -verbose => 0
                           );

my $compara_dba = $reg->get_DBAdaptor("Multi","compara");

# First get all the nc_tree_ids:

my $clusterset_id = 1;
my $tree_Adaptor = $compara_dba->get_ProteinTreeAdaptor(); # Repeat with TreeAdaptor
my $tree = $tree_Adaptor->fetch_node_by_node_id($tree_id);

print $tree->newick_format('ryo',$fmt),"\n";
