#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $reg = "Bio::EnsEMBL::Registry";

my $registry_file;
my $url;
my $compara_url;
my $tree_id = 3;  # This is a protein-tree

GetOptions(
  "url=s" => \$url,
  "compara_url=s" => \$compara_url,
  "conf|registry=s" => \$registry_file,
  "tree_id=i" => \$tree_id,
);

my $compara_dba;
if ($compara_url) {
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
  $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url);
} else {
  if ($registry_file) {
    die if (!-e $registry_file);
    $reg->load_all($registry_file);
  } elsif ($url) {
    $reg->load_registry_from_url($url);
  } else {
    $reg->load_registry_from_db(
      -host=>'ensembldb.ensembl.org',
      -user=>'anonymous',
    );
  }
  $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
}

my $tree = $compara_dba->get_GeneTreeAdaptor()->fetch_by_dbID($tree_id);
die "The ID supplied ($tree_id) is not a valid ProteinTree ID or NCTree ID\n" unless (defined $tree);
my $member_type = $tree->member_type;

print "Running the script with $member_type tree with ID: $tree_id\n\n";
print "The new 'role-your-own' option in NestedSet's format_newick method allows you to specify the format you want for your tree\n";
print "Here you can find 7 examples showing you all the details of this functionality\n\n";
print "You can press Ctrl-C at any moment to exit this script\n\n";
print "Press \"enter\" to continue...";
<>;
print "\n\n";
print "1. A 'format' is made of 'tokens' and 'string literals'. Tokens are enclosed between '%{' and '} and must have a letter-attribute. Here is a complete list of these:'\n\n";
print <<EOL;
n --> then "name" of the node (\$tree->name)
d --> distance to parent (\$tree->distance_to_parent)
c --> the common name (\$tree->get_value_for_tag('genbank common name'))
g --> gdb_id (\$tree->adaptor->db->get_GenomeDBAdaptor->fetch_by_taxon_id(\$tree->taxon_id)->dbID)
t --> timetree (\$tree->get_value_for_tag('ensembl timetree mya')
l --> display_label (\$tree->gene_member->display_label)
s --> genome short name (\$tree->genome_db->get_short_name)
i --> stable_id (\$tree->gene_member->stable_id)
p --> peptide Member (\$tree->get_canonical_SeqMember->stable_id)
x --> taxon_id (\$tree->taxon_id)
m --> seq_member_id (\$tree->seq_member_id)
o --> node_id (\$tree->node_id)
S --> species_name (\$tree->genome_db->name)

EOL
print "For example, to print the name of each node you can use the 'format' string '%{n}'\n\n";
print "\$tree->newick_format('ryo','%{n}')\n",
      " [Please wait, printing tree...]\n\n";
print $tree->newick_format("ryo",'%{n}'), "\n\n";
print "Press \"enter\" to continue...";
<>;
print "\n\n";
print "2. If you want to include the branch distances you should include another token: '%{n}:%{d}'. This reads 'for each node give me its name, a ':' and the distance to its parent\n\n";
print "\$tree->newick_format('ryo','%{n}:%{d}')\n",
      " [Please wait, printing tree...]\n\n";
print $tree->newick_format("ryo",'%{n}:%{d}'),"\n\n";
print "Press \"enter\" to continue...";
<>;
print "\n\n";
print "3. You may also include the colon (or other string literals) inside the token, but if placed there they must be double-quoted. The meaning is slightly different though, if a string literal is placed inside the token, it will be printed only if the main attribute of the token is defined. For example '%{n}{\":\"d}'\n\n";
print "\$tree->newick_format('ryo','%{n}%{\":\"d}')\n",
      " [Please wait, printing tree...]\n\n";
print $tree->newick_format('ryo','%{n}%{":"d}'), "\n\n";
print "Press \"enter\" to continue...";
<>;
print "\n\n";
print "4. Tokens may also have 'modifiers'. For example, if you want only the \"distance to parent\" in the nodes that are leaves you can use a dash '-' just before the one-letter attribute: '%{n}%{\":\"-d}'. Note that in this case, both the colon and the distance are absent in internal nodes\n\n";
print "\$tree->newick_format('ryo','%{n}%{\":\"-d}')\n",
      " [Please wait, printing tree...]\n\n";
print $tree->newick_format('ryo','%{n}%{":"-d}'),"\n\n";
print "Press \"enter\" to continue...";
<>;
print "\n\n";
print "5. The same can be done with only internal nodes by appending the dash just after the attribute: '%{n}%{\":\"d-}'. You should be aware that if an attribute is undefined for a node, it will not be printed, so '%{n}' is the same as '%{-n}' since internal nodes are unnamed\n\n";
print "\$tree->newick_format('ryo','%{n}%{\":\"d-}')\n",
      " [Please wait, printing tree...]\n\n";
print $tree->newick_format('ryo','%{n}%{":"d-}'),"\n\n";
print "Press \"enter\" to continue...";
<>;
print "\n\n";
print "6. You can also specify alternatives in the one-letter attributes. For example, the following format would print for each node the protein member ID or (if it is not defined) its name: '%{p|n}'\n\n";
print "\$tree->newick_format('ryo','%{p|n}')\n",
      " [Please wait, printing tree...]\n\n";
print $tree->newick_format('ryo','%{p|n}'),"\n\n";
print "Press \"enter\" to continue...";
<>;
print "\n\n";
print "7. The last modifier that you can use is a caret (^) just at the beginning of the token. This modifier means that the token only applies to nodes that has a parent (\$tree->has_parent method returns a 'true' value). An example of use could be: '%{^o}'. This will print the node_id of all the nodes that has a parent\n\n";
print "\$tree->newick_format('ryo','%{^o}')\n",
      " [Please wait, printing tree...]\n\n";
print $tree->newick_format('ryo','%{^o}'),"\n\n";
print "Press \"enter\" to continue...";
<>;
print "\n\n";
print "8. To keep the formats clean and help the parser all these modifiers should be in order. Here is a template, all modifiers are optional and only the main one-letter attribute is mandatory: '%{^\"_\"p-|on\"_\"}'. Here are a couple of more examples:\n\n";
print "otu_id --> '%{-s\"|\"}%{-l}%{n}:%{d}'\n",
      " [Please wait, printing tree...]\n\n";
print $tree->newick_format('ryo','%{-s"|"}%{-l}%{n}:%{d}'),"\n\n";
print "Press \"enter\" to continue...";
<>;
print "\n\n";
print "display_label_composite --> '%{-l\"_\"}%{n}%{\"_\"-s}:%{d}'\n",
      " [Please wait, printing tree...]\n\n";
print $tree->newick_format('ryo','%{-l"_"}%{n}%{"_"-s}:%{d}'),"\n\n";
print "All examples run successfully\n\n";


#my $newick_tree = $tree_newick_format('full');

#my $newick_tree = $tree->newick_format("full_common");
#my $newick_tree = $tree->newick_format('%{n}%{" "-c}%{"."-g}%{"_"-t"_MYA"}');

#my $newick_tree = $tree->newick_format("int_node_id");
#my $newick_tree = $tree->newick_format('%{-n}%{o-}');

#my $newick_tree = $tree->newick_format("display_label_composite");
#my $newick_tree = $tree->newick_format('%{-l"_"}%{n}%{"_"-s}');

#my $newick_tree = $tree->newick_format("gene_stable_id_composite");
#my $newick_tree = $tree->newick_format('%{-i"_"}%{n}%{"_"-s}');

#my $newick_tree = $tree->newick_format("full_web");
#my $newick_tree = $tree->newick_format("ryo",'%{n-}%{-n|p}%{"_"-s"_"}%{":"d}');

#my $newick_tree = $tree->newick_format("gene_stable_id");
#my $newick_tree = $tree->newick_format('%{-i}');

#my $newick_tree = $tree->newick_format("otu_id");
#my $newick_tree = $tree->newick_format('%{-s"|"}%{-l}%{n}');

#my $newick_tree = $tree->newick_format("simple");
#my $newick_tree = $tree->newick_format('%{^-n}');

#my $newick_tree = $tree->newick_format("member_id_taxon_id");
#my $newick_tree = $tree->newick_format('%{^-m}%{^"_"-x}');

#my $newick_tree = $tree->newick_format("member_id");
#my $newick_tree = $tree->newick_format('%{^-m}');

#my $newick_tree = $tree->newick_format("species");
#my $newick_tree = $tree->newick_format('%{^-S|p}');

#my $newick_tree = $tree->newick_format("species_short_name");
#my $newick_tree = $tree->newick_format('%{^-s|p}');

#my $newick_tree = $tree->newick_format("ncbi_taxon");
#my $newick_tree = $tree->newick_format('%{^o}');

#my $newick_tree = $tree->newick_format("ncbi_name");
#my $newick_tree = $tree->newick_format("ryo",'%{^n}');

#my $newick_tree = $tree->newick_format("phylip");

#print "$newick_tree\n";




