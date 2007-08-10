#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::AlignIO;
use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $root_id;
my $url;
my $help = 0;
my $aln_out;
my $nh_out;
my $nhx_out;
my $verbose = 0;
my $aa = 0;

$| = 1;

GetOptions('help'      => \$help,
           'root_id=i' => \$root_id,
           'url=s'     => \$url,
           'aln_out=s' => \$aln_out,
           'nh_out=s'  => \$nh_out,
           'nhx_out=s' => \$nhx_out,
           'verbose=s' => \$verbose,
           'aa'        => \$aa);

if ($help) {
  print "
$0 --root_id 1 --url mysql://ensro\@ens-livemirror:3306/42

--root_id integer gives the root_id to which all the gene trees are connected
--url string      database url location of the form,
                  mysql://username[:password]\@host[:port]/[release_version]
--aln_out string  alignment output filename (extension .emf.gz will be added)
--nh_out string   newick output filename (extension .emf.gz will be added)
--nhx_out string  extended newick output filename (extension .emf.gz will be added)
--aa              dump alignment in amino acid (default is in DNA)

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

my $aln_out_fh;
my $nh_out_fh;
my $nhx_out_fh;

if (defined $aln_out) {
  open F1, "|gzip -c > $aln_out.gz";
  $aln_out_fh = \*F1;
  print $aln_out_fh "##FORMAT (gene_alignment)\n";
  print $aln_out_fh "##DATE $localtime\n";
  print $aln_out_fh "##RELEASE $release\n";
}

if (defined $nh_out) {
  open F2, "|gzip -c > $nh_out.gz";
  $nh_out_fh = \*F2;
  print $nh_out_fh "##FORMAT (gene_tree)\n";
  print $nh_out_fh "##DATE $localtime\n";
  print $nh_out_fh "##RELEASE $release\n";
}

if (defined $nhx_out) {
  open F3, "|gzip -c > $nhx_out.gz";
  $nhx_out_fh = \*F3;
  print $nhx_out_fh "##FORMAT (gene_tree)\n";
  print $nhx_out_fh "##DATE $localtime\n";
  print $nhx_out_fh "##RELEASE $release\n";
}

my $cluster_count = 0;
foreach my $child (@{$root->children}) {
  $cluster_count++;
  my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count if ($verbose);
  print STDERR $verbose_string if ($verbose &&  ($cluster_count % $verbose == 0));
  dumpTreeMultipleAlignment($child, $aln_out_fh) if ($aln_out);
  dumpNewickTree($child,$nh_out_fh,0) if (defined $nh_out);
  dumpNewickTree($child,$nhx_out_fh,1) if (defined $nhx_out);
  $child->release_tree;
#  last;
}

close $aln_out_fh if (defined $aln_out_fh);
close $nh_out_fh if (defined $nh_out_fh);
close $nhx_out_fh if (defined $nhx_out_fh);

sub dumpTreeMultipleAlignment
{
  my $tree = shift;
  my $fh = shift;
  my @aligned_seqs;
  foreach my $leaf (@{$tree->get_all_leaves}) {
    #SEQ organism peptide_stable_id chr sequence_start sequence_stop strand gene_stable_id display_label
    my $species = $leaf->genome_db->name;
    $species =~ s/ /_/;
    print $fh "SEQ $species ".$leaf->stable_id." ".$leaf->chr_name." ".$leaf->chr_start." ".$leaf->chr_end." ".$leaf->chr_strand." ".$leaf->gene_member->stable_id." ".($leaf->gene_member->display_label || "NULL") ."\n";

    my $alignment_string;
    if ($aa) {
      $alignment_string = $leaf->alignment_string;
    } else {
      $alignment_string = $leaf->cdna_alignment_string;
      $alignment_string =~ s/\s+//g;
    }
    for (my $i = 0; $i<length($alignment_string); $i++) {
      $aligned_seqs[$i] .= substr($alignment_string, $i, 1);
    }
  }
#  $tree->release_tree;
#  undef $tree;
# will need to update the script when we will produce omega score for each column
# of the alignment.
# print "SCORE NULL\n";
  print $fh "DATA\n";
  print $fh join("\n", @aligned_seqs);
  print $fh "\n//\n";
}

sub dumpNewickTree
{
  my $tree = shift;
  my $fh = shift;
  my $nhx = shift;
#  print STDERR "node_id: ",$tree->node_id,"\n";
  my @aligned_seqs;
  foreach my $leaf (@{$tree->get_all_leaves}) {
    #SEQ organism peptide_stable_id chr sequence_start sequence_stop strand gene_stable_id display_label
    my $species = $leaf->genome_db->name;
    $species =~ s/ /_/;
    print $fh "SEQ $species ".$leaf->stable_id." ".$leaf->chr_name." ".$leaf->chr_start." ".$leaf->chr_end." ".$leaf->chr_strand." ".$leaf->gene_member->stable_id." ".($leaf->gene_member->display_label || "NULL") ."\n";
  }
# will need to update the script when we will produce omega score for each column
# of the alignment.
# print "SCORE NULL\n";
  print $fh "DATA\n";
  if ($nhx) {
    print $fh $tree->nhx_format;
  } else {
    print $fh $tree->newick_simple_format;
  }
  print $fh "\n//\n";
#  $tree->release_tree;
#  undef $tree;
}
