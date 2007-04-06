#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::AlignIO;
use Bio::EnsEMBL::Registry;
use Getopt::Long;




my $root_id;
my $url;
my $help = 0;

GetOptions('help'      => \$help,
           'root_id=i' => \$root_id,
           'url=s'     => \$url);

if ($help) {
  print "
$0 --root_id 1 --url mysql://ensro\@ens-livemirror:3306/42

--root_id integer gives the root_id to which all the gene trees are connected
--url string      database url location of the form,
                  mysql://username[:password]\@host[:port]/[release_version]

This scripts assumes that the compara db and all the core dbs related
to it are on the same server
\n";
  exit 0;
}

unless (defined $root_id && $root_id > 0) {
  print "\n--root_id is not defined properly. It should be an integer > 0\nEXIT 1\n\n";
  exit 1;
}
unless (defined $url) {
  print "\n--url is not defined. It should be something like mysql://ensro\@ens-livemirror:3306/42\nEXIT 2\n\n";
  exit 2;
}

Bio::EnsEMBL::Registry->no_version_check(1);
Bio::EnsEMBL::Registry->load_registry_from_url($url);

#my $dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
#  (-host => 'ens-livemirror',
#   -port => 3306,
#   -user => 'ensro',
#   -dbname => 'ensembl_compara_42');

my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor('Multi','compara');

my $mc = $dba->get_MetaContainer;
my $release = $mc->get_schema_version;

my $pta = $dba->get_ProteinTreeAdaptor;


my $localtime = localtime;
my $root = $pta->fetch_node_by_node_id($root_id);

print "##FORMAT (gene_alignment)\n";
print "##DATE $localtime\n";
print "##RELEASE $release\n";


foreach my $child (@{$root->children}) {
  dumpTreeMultipleAlignment($child);
  $child->release_tree;
#  last;
}

sub dumpTreeMultipleAlignment
{
  my $tree = shift;
  my @aligned_seqs;
  foreach my $leaf (@{$tree->get_all_leaves}) {
    #SEQ organism peptide_stable_id chr sequence_start sequence_stop strand gene_stable_id display_label
    my $species = $leaf->genome_db->name;
    $species =~ s/ /_/;
    print "SEQ $species ".$leaf->stable_id." ".$leaf->chr_name." ".$leaf->chr_start." ".$leaf->chr_end." ".$leaf->chr_strand." ".$leaf->gene_member->stable_id." ".($leaf->gene_member->display_label || "NULL") ."\n";
    
    my $alignment_string = $leaf->cdna_alignment_string;
    $alignment_string =~ s/\s+//g;
    for (my $i = 0; $i<length($alignment_string); $i++) {
      $aligned_seqs[$i] .= substr($alignment_string, $i, 1);
    }
  }
# will need to update the script when we will produce omega score for each column
# of the alignment.
# print "SCORE NULL\n";
  print "DATA\n";
  print join("\n", @aligned_seqs);
  print "\n//\n";
}
