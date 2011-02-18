#!/usr/local/bin/perl -w

use strict;
use Bio::EnsEMBL::Hive::URLFactory;
use Bio::AlignIO;
use File::Spec;
use Getopt::Long;

my $tree_id_file;
my $one_tree_id;
my $url;
my $help = 0;
my $aln_out;
my $fasta_out;
my $fasta_cds_out;
my $nh_out;
my $nhx_out;
my $aa = 1;
my $nc = 0;
my $verbose = 0;
my $dirpath;

$| = 1;

GetOptions('help'           => \$help,
           'tree_id_file|infile=s' => \$tree_id_file,
           'tree_id=s'      => \$one_tree_id,
           'url=s'          => \$url,
           'a|aln_out=s'    => \$aln_out,
           'f|fasta_out=s'  => \$fasta_out,
           'fc|fasta_cds_out=s' => \$fasta_cds_out,
           'nh|nh_out=s'    => \$nh_out,
           'nhx|nhx_out=s'  => \$nhx_out,
           'nc=s'           => \$nc,
           'aa=s'           => \$aa,
           'verbose=s'      => \$verbose,
           'dirpath=s'      => \$dirpath,
);

if ($help) {
  print "
$0 --tree_id_file file.txt --url mysql://ensro\@compara1:3306/kb3_ensembl_compara_59

--tree_id_file    a file with a list of tree_ids (node_ids that are root_id=parent_id in protein_tree_node)
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

unless ( (defined $tree_id_file && (-r $tree_id_file)) or $one_tree_id ) {
  print "\n either --tree_id_file or --tree_id has to be defined.\nEXIT 1\n\n";
  exit 1;
}
unless (defined $url) {
  print "\n--url is not defined. It should be something like mysql://ensro\@compara1:3306/kb3_ensembl_compara_59\nEXIT 2\n\n";
  exit 2;
}

my $dba = Bio::EnsEMBL::Hive::URLFactory->fetch( $url.';type=compara' );

my ($prefix, $adaptor) = $nc
    ? ('ncrna_trees_.', $dba->get_NCTreeAdaptor)
    : ('protein_trees_.', $dba->get_ProteinTreeAdaptor);

my @tree_ids;
if($tree_id_file and -r $tree_id_file) {
    open LIST, "$tree_id_file" or die "couldnt open $tree_id_file: $!\n";
    @tree_ids = <LIST>;
    chomp @tree_ids;
    close LIST;
} else {
    @tree_ids = ($one_tree_id);
}

unless($dirpath) {
    if($tree_id_file) {
        my ($dummy_volume, $dummy_file);
        ($dummy_volume, $dirpath, $dummy_file) = File::Spec->splitpath( $tree_id_file );
    } else {
        $dirpath = '.';
    }
}

foreach my $tree_id (@tree_ids) {

  system("mkdir -p $dirpath") && die "Could not make directory '$dirpath: $!";

  my $root = $adaptor->fetch_node_by_node_id($tree_id);

  $tree_id = $prefix.$tree_id;

  my $fh1;
  my $fh2;
  my $fh3;
  my $fh4;
  my $fh5;

  last if (
           (-s "$dirpath/$tree_id.aln.emf") &&
           (-s "$dirpath/$tree_id.nh.emf") &&
           (-s "$dirpath/$tree_id.nhx.emf") &&
           (-s "$dirpath/$tree_id.aa.fasta") &&
           (-s "$dirpath/$tree_id.cds.fasta"));

  if ($aln_out) { open $fh1, ">$dirpath/$tree_id.aln.emf" or die "couldnt open $dirpath/$tree_id.aln.emf:$!\n"; }
  if ($nh_out)  { open $fh2, ">$dirpath/$tree_id.nh.emf"  or die "couldnt open $dirpath/$tree_id.nh.emf:$!\n";  }
  if ($nhx_out) { open $fh3, ">$dirpath/$tree_id.nhx.emf" or die "couldnt open $dirpath/$tree_id.nhx.emf:$!\n"; }
  if ($fasta_out) { open $fh4, ">$dirpath/$tree_id.aa.fasta" or die "couldnt open $dirpath/$tree_id.aa.fasta:$!\n"; }
  if ($fasta_cds_out) { open $fh5, ">$dirpath/$tree_id.cds.fasta" or die "couldnt open $dirpath/$tree_id.cds.fasta:$!\n"; }

  dumpTreeMultipleAlignment($root, $fh1) if ($aln_out);
  dumpNewickTree($root,$fh2,0)           if (defined $nh_out);
  dumpNewickTree($root,$fh3,1)           if (defined $nhx_out);
  dumpTreeFasta($root, $fh4,0)           if ($fasta_out);
  dumpTreeFasta($root, $fh5,1)           if ($fasta_cds_out);

  $root->release_tree;

  close $fh1 if (defined $fh1);
  close $fh2 if (defined $fh2);
  close $fh3 if (defined $fh3);
  close $fh4 if (defined $fh4);
  close $fh5 if (defined $fh5);
}

sub dumpTreeMultipleAlignment {
  my $tree = shift;
  my $fh = shift;

  my @aligned_seqs;
  foreach my $leaf (@{$tree->get_all_leaves}) {
    my $ret = $leaf->alignment_string; # we just put this in front to make sure it doesnt leave traces in the emf file
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
  print $fh "\n//\n\n";
}

sub dumpNewickTree {
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
  print $fh "\n//\n\n";
#  $tree->release_tree;
#  undef $tree;
}

sub dumpTreeFasta {
    my $tree = shift;
    my $fh = shift;
    my $cdna = shift;

    my @aligned_seqs;
    warn("missing tree\n") unless($tree);
    my $sa;

    $sa = $tree->get_SimpleAlign(-id_type => 'STABLE', -CDNA=>$cdna);
    $sa->set_displayname_flat(1);
    my $alignIO = Bio::AlignIO->newFh(-fh => $fh,
                                      -format => 'fasta'
                                     );
    print $alignIO $sa;
    print $fh "\n//\n\n";
}

