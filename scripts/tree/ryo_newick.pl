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

my $help;
my $registry_file;
my $url;
my $compara_url;
my $tree_id = 2;
my $fmt = '%{n}%{":"d}';
my $quiet = 0;

GetOptions(
  "help" => \$help,
  "url=s" => \$url,
  "compara_url=s" => \$compara_url,
  "conf|registry=s" => \$registry_file,
  "id|tree_id:i" => \$tree_id,
  "format:s" => \$fmt,
  "quiet" => \$quiet,
);

if ($help) {
  print <<'EOH';
ryo_newick.pl -- Output formatted trees based on a user supplied format

Options
     [-i|--id]     => Protein tree ID (defaults to 2)
     [-f|--format] => roll-your-own format to output the tree (defaults to '%{n}%{":"d}')
     [-h|--help]   => Prints this document and exits

See the documentation of Bio::EnsEMBL::Compara::Utils::FormatTree.pm for details.
Briefly, allowed one-letter attributes are:

n --> then "name" of the node ($tree->name)
d --> distance to parent ($tree->distance_to_parent)
c --> the common name ($tree->get_value_for_tag('genbank common name'))
g --> gdb_id ($tree->adaptor->db->get_GenomeDBAdaptor->fetch_by_taxon_id($tree->taxon_id)->dbID)
t --> timetree ($tree->get_value_for_tag('ensembl timetree mya')
l --> display_label ($tree->gene_member->display_label)
s --> genome short name ($tree->genome_db->get_short_name)
i --> stable_id ($tree->gene_member->stable_id)
p --> peptide Member ($tree->get_canonical_SeqMember->stable_id)
x --> taxon_id ($tree->taxon_id)
m --> member_id ($tree->seq_member_id)
o --> node_id ($self->node_id)
S --> species_name ($tree->genome_db->name)

EOH
exit;
}

if ($quiet) {
  $reg->no_version_check(1);
} else {
  print "tree_id => $tree_id\n";
  print "format => $fmt\n\n";
}

if ($registry_file) {
  die if (!-e $registry_file);
  $reg->load_all($registry_file);
} elsif ($url) {
  $reg->load_registry_from_url($url);
} elsif (!$compara_url) {
  $reg->load_all();
}

my $compara_dba;
if ($compara_url) {
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
  $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url);
} else {
  $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
}

my $tree_adaptor = $compara_dba->get_GeneTreeAdaptor();
my $tree = $tree_adaptor->fetch_by_dbID($tree_id);

print $tree->newick_format('ryo',$fmt),"\n";
