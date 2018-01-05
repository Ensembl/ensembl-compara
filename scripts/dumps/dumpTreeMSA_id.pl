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
use Bio::AlignIO;
use File::Spec;
use Getopt::Long;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter;
use Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter;
use Bio::EnsEMBL::Compara::Graph::CAFETreePhyloXMLWriter;
use Bio::EnsEMBL::Compara::Utils::Preloader;

my $tree_id_file;
my $one_tree_id;
my $url;
my $help = 0;
my $aln_out;
my $fasta_out;
my $fasta_cds_out;
my $nh_out;
my $nhx_out;
my $orthoxml;
my $phyloxml;
my $cafe_phyloxml;
my $aa = 1;
my $dirpath;
my $reg_conf;
my $reg_alias;

$| = 1;

GetOptions('help'           => \$help,
           'tree_id_file|infile=s' => \$tree_id_file,
           'tree_id=i'      => \$one_tree_id,

           'reg_conf=s'     => \$reg_conf,
           'reg_alias=s'    => \$reg_alias,
           'url=s'          => \$url,

           'a|aln_out=s'    => \$aln_out,
           'f|fasta_out=s'  => \$fasta_out,
           'fc|fasta_cds_out=s' => \$fasta_cds_out,
           'nh|nh_out=s'    => \$nh_out,
           'nhx|nhx_out=s'  => \$nhx_out,
           'oxml|orthoxml=s'    => \$orthoxml,
           'pxml|phyloxml=s'    => \$phyloxml,
           'cafe|cafe_phyloxml=s'    => \$cafe_phyloxml,
           'aa=s'           => \$aa,
           'dirpath=s'      => \$dirpath,
);

if ($help) {
  print "
$0 [--tree_id id | --tree_id_file file.txt] [--url mysql://ensro\@compara1:3306/kb3_ensembl_compara_59 | -reg_conf reg_file.pm -reg_alias alias ]

--tree_id         the root_id of the tree to be dumped
--tree_id_file    a file with a list of tree_ids
--url string      database url location of the form,
                  mysql://username[:password]\@host[:port]/[release_version]
--aa              dump alignment in amino acid (default is in DNA)
--dirpath         where to dump the files to (default is the directory of tree_id_file)

The following parameters define the data that should be dumped.
string is the filename extension. If string is 1, the default extension will be used

--nh_out string   tree in newick / EMF format (nh.emf)
--nhx_out string  tree in extended newick / EMF format (nhx.emf)
--aln_out string        multiple alignment in EMF format (aln.emf)
--fasta_out string      amino-acid multiple alignment in FASTA format (aa.fasta)
--fasta_cds_out string  nucleotide multiple alignment in FASTA format (cds.fasta)
--orthoxml string               tree in OrthoXML format (orthoxml.xml)
--phyloxml string               tree in PhyloXML format (phyloxml.xml)
--cafe_phyloxml string          CAFE tree in PhyloXML format (cafe_phyloxml.xml)

This scripts assumes that the compara db is linked to all the core dbs
\n";
  exit 0;
}

unless ( (defined $tree_id_file && (-r $tree_id_file)) or $one_tree_id ) {
  print "\n either --tree_id_file or --tree_id has to be defined.\nEXIT 1\n\n";
  exit 1;
}

unless ($url or ($reg_conf and $reg_alias)) {
  print "\nNeither --url nor --reg_conf and --reg_alias is not defined. The URL should be something like mysql://ensro\@compara1:3306/kb3_ensembl_compara_59\nEXIT 2\n\n";
  exit 2;
}

if($reg_conf) {
    Bio::EnsEMBL::Registry->load_all($reg_conf);    # if undefined, default reg_conf will be used
}
my $dba = $reg_alias
    ? Bio::EnsEMBL::Registry->get_DBAdaptor( $reg_alias, 'compara' )
    : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $url );

my $adaptor = $dba->get_GeneTreeAdaptor;

my @tree_ids;
if($tree_id_file and -r $tree_id_file) {
    open LIST, '<', $tree_id_file or die "couldnt open $tree_id_file: $!\n";
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

sub dump_if_wanted {
    my $param = shift;

    return unless $param;

    my $tree_id = shift;
    my $default_name = shift;

    my $filename = ($param =~ /^\// ? sprintf('%s.%s', $param, $tree_id) : sprintf('%s/%s.%s', $dirpath, $tree_id, $param eq 1 ? $default_name : $param));
    return if -s $filename;

    my $fh;
    open $fh, '>', $filename or die "couldnt open $filename:$!\n";

    my $sub = shift;
    my $root = shift;
    my $extra = shift;
    &$sub($root, $fh, @$extra);
    close $fh;
}

foreach my $tree_id (@tree_ids) {

  system("mkdir -p $dirpath") && die "Could not make directory '$dirpath: $!";

  my $tree = $adaptor->fetch_by_root_id($tree_id);
  my $root = $tree->root;
  my $cafe_tree = $dba->get_CAFEGeneFamilyAdaptor->fetch_by_GeneTree($tree);

  $tree_id = "tree.".$tree_id;
  my %fasta_names = ('protein' => 'aa.fasta', 'ncrna' => 'nt.fasta');


  if ($aln_out or $nh_out or $nhx_out) {
      Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($dba->get_DnaFragAdaptor, $tree->get_all_Members);
  }

  dump_if_wanted($aln_out, $tree_id, 'aln.emf', \&dumpTreeMultipleAlignment, $tree, []);
  dump_if_wanted($nh_out, $tree_id, 'nh.emf', \&dumpNewickTree, $root, [0]);
  dump_if_wanted($nhx_out, $tree_id, 'nhx.emf', \&dumpNewickTree, $root, [1]);
  dump_if_wanted($fasta_out, $tree_id, $fasta_names{$tree->member_type}, \&dumpTreeFasta, $root, [0]);
  dump_if_wanted($fasta_cds_out, $tree_id, 'cds.fasta', \&dumpTreeFasta, $root, [1]) if $tree->member_type eq 'protein';
  dump_if_wanted($orthoxml, $tree_id, 'orthoxml.xml', \&dumpTreeOrthoXML, $tree);
  dump_if_wanted($phyloxml, $tree_id, 'phyloxml.xml', \&dumpTreePhyloXML, $tree);
  dump_if_wanted($cafe_phyloxml, $tree_id, 'cafe_phyloxml.xml', \&dumpCafeTreePhyloXML, $cafe_tree) if $cafe_tree;

  $root->release_tree;
}

sub dumpTreeMultipleAlignment {
  my $tree = shift;
  my $fh = shift;

  Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($dba->get_SequenceAdaptor, $aa ? undef : 'cds', $tree->get_all_Members);

  my @aligned_seqs;
  foreach my $leaf (@{$tree->get_all_leaves}) {
    #SEQ organism peptide_stable_id chr sequence_start sequence_stop strand gene_stable_id display_label
    my $species = $leaf->genome_db->name;
    $species =~ s/ /_/;
    print $fh "SEQ $species ".$leaf->stable_id." ".$leaf->dnafrag->name." ".$leaf->dnafrag_start." ".$leaf->dnafrag_end." ".$leaf->dnafrag_strand." ".$leaf->gene_member->stable_id." ".($leaf->gene_member->display_label || "NULL") ."\n";

    my $alignment_string;
    if ($aa) {
      $alignment_string = $leaf->alignment_string;
    } else {
      $alignment_string = $leaf->alignment_string('cds');
    }
    for (my $i = 0; $i<length($alignment_string); $i++) {
      $aligned_seqs[$i] .= substr($alignment_string, $i, 1);
    }
  }
# will need to update the script when we will produce omega score for each column
# of the alignment.
# print "SCORE NULL\n";

  # Here come the trees
  print $fh "TREE newick ", $tree->newick_format('simple'), "\n";
  print $fh "TREE nhx ", $tree->nhx_format, "\n";

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
    print $fh "SEQ $species ".$leaf->stable_id." ".$leaf->dnafrag->name." ".$leaf->dnafrag_start." ".$leaf->dnafrag_end." ".$leaf->dnafrag_strand." ".$leaf->gene_member->stable_id." ".($leaf->gene_member->display_label || "NULL") ."\n";
  }
# will need to update the script when we will produce omega score for each column
# of the alignment.
# print "SCORE NULL\n";
  print $fh "DATA\n";
  if ($nhx) {
    print $fh $tree->nhx_format;
  } else {
    print $fh $tree->newick_format('simple');
  }
  print $fh "\n//\n\n";
}

sub dumpTreeFasta {
    my $tree = shift;
    my $fh = shift;
    my $cdna = shift;

    my @aligned_seqs;
    warn("missing tree\n") unless($tree);
    my $sa;

    $sa = $tree->get_SimpleAlign(-id_type => 'STABLE', $cdna ? (-seq_type => 'cds') : () );
    $sa->set_displayname_flat(1);
    my $alignIO = Bio::AlignIO->newFh(-fh => $fh,
                                      -format => 'fasta'
                                     );
    print $alignIO $sa;
    print $fh "\n//\n\n";
}

sub dumpTreeOrthoXML {
    my $tree = shift;
    my $fh = shift;

    my $w = Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter->new(-SOURCE => 'compara', -SOURCE_VERSION => software_version(), -HANDLE => $fh, -NO_RELEASE_TREES => 1);
    $w->write_trees($tree);
    $w->finish();
}

sub dumpTreePhyloXML {
    my $tree = shift;
    my $fh = shift;

    my $w = Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter->new(-SOURCE => 'compara', -NO_SEQUENCES => 1, -HANDLE => $fh, -NO_RELEASE_TREES => 1);
    $w->write_trees($tree);
    $w->finish();
}

sub dumpCafeTreePhyloXML {
    my $tree = shift;
    my $fh = shift;

    my $w = Bio::EnsEMBL::Compara::Graph::CAFETreePhyloXMLWriter->new(-SOURCE => 'compara', -NO_SEQUENCES => 1, -HANDLE => $fh, -NO_RELEASE_TREES => 1);
    $w->write_trees($tree);
    $w->finish();
}

