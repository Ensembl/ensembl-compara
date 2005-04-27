#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Hive::URLFactory;
use Bio::SimpleAlign;
use Bio::EnsEMBL::Compara::NestedSet;
use Switch;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_conf'} = {};
$self->{'compara_conf'}->{'-user'} = 'ensro';
$self->{'compara_conf'}->{'-port'} = 3306;

$self->{'speciesList'} = ();
$self->{'removeXedSeqs'} = undef;
$self->{'outputFasta'} = undef;
$self->{'noSplitSeqLines'} = undef;
my $state = 0;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $url;

GetOptions('help'        => \$help,
           'url=s'       => \$url,
           'tre=s'       => \$self->{'newick_file'},
           'tree_id=i'   => \$self->{'tree_id'},
           'gene=s'      => \$self->{'gene_stable_id'},
          );

if($self->{'newick_file'}) { $state=6; }
if($self->{'tree_id'}) { $state=1; }
if($self->{'gene_stable_id'}) { $state=5; }

if ($help or !$state) { usage(); }


$self->{'comparaDBA'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($url, 'compara') if($url);
unless(defined($self->{'comparaDBA'})) {
  print("no url URL\n\n");
  usage();
} 

switch($state) {
  case 1 { fetch_protein_tree($self, $self->{'tree_id'}); }
  case 2 { create_taxon_tree($self); }
  case 3 { fetch_primate_ncbi_taxa($self); }
  case 4 { fetch_compara_ncbi_taxa($self); }
  case 5 { fetch_protein_tree_with_gene($self, $self->{'gene_stable_id'}); }
  case 6 { parse_newick($self); }
  case 7 { reroot($self); }
}


#cleanup memory
if($self->{'root'}) {
  print("ABOUT TO MANUALLY release tree\n");
  $self->{'root'}->release;
  $self->{'root'} = undef;
  print("DONE\n");
}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "testTaxonTree.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -url <url>             : connect to compara at url\n";
  print "testTaxonTree.pl v1.1\n";
  
  exit(1);  
}


sub fetch_primate_ncbi_taxa {
  my $self = shift;

  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;

  my $marmoset = $taxonDBA->fetch_node_by_taxon_id(9483);
  my $root = $marmoset->root->retain;
  $root->merge_node_via_shared_ancestor($taxonDBA->fetch_node_by_taxon_id(9544));
  $root->merge_node_via_shared_ancestor($taxonDBA->fetch_node_by_taxon_id(9490));
  $root->merge_node_via_shared_ancestor($taxonDBA->fetch_node_by_taxon_id(9516));
  $root->merge_node_via_shared_ancestor($taxonDBA->fetch_node_by_taxon_id(9500));
  $root->merge_node_via_shared_ancestor($taxonDBA->fetch_node_by_taxon_id(9511));
  $root->merge_node_via_shared_ancestor($taxonDBA->fetch_node_by_taxon_id(9606));
  $root->merge_node_via_shared_ancestor($taxonDBA->fetch_node_by_taxon_id(9598));
  $root->merge_node_via_shared_ancestor($taxonDBA->fetch_node_by_taxon_id(9600));
  $root->merge_node_via_shared_ancestor($taxonDBA->fetch_node_by_taxon_id(9581));
  $root->print_tree;

  $root->flatten_tree->print_tree;

  $self->{'root'} = $root;
}


sub fetch_compara_ncbi_taxa {
  my $self = shift;

  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $root = $self->{'root'};

  my $gdb_list = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
  foreach my $gdb (@$gdb_list) {
    my $taxon = $taxonDBA->fetch_node_by_taxon_id($gdb->taxon_id);
    $taxon->release_children;

    $root = $taxon->root unless($root);
    $root->merge_node_via_shared_ancestor($taxon);
  }  
  $root->print_tree;

  $self->{'root'} = $root;
}


sub fetch_protein_tree {
  my $self = shift;
  my $node_id = shift;

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $tree;

  switch(1) {
    case 1 {
      $tree = $treeDBA->fetch_node_by_node_id($node_id);
      $tree = $tree->root;
    }

    case 2 {
      my $member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLPEP', 'ENSP00000264731');
      my $aligned_member = $treeDBA->fetch_AlignedMember_by_member_id_root_id($member->member_id, 68537);
      print $aligned_member, "\n";
      $aligned_member->print_member;
      $aligned_member->gene_member->print_member;
      $tree = $aligned_member->subroot;
      $treeDBA->fetch_all_children_for_node($tree);
    }
  }

  $tree->print_tree;
  printf("%d proteins\n", scalar(@{$tree->get_all_leaves}));
  $tree->release;
  return;

  $tree->flatten_tree->print_tree;

  my $leaves = $tree->get_all_leaves;
  foreach my $node (@{$leaves}) {
    $node->print_member;
  }
  $tree->release;
}


sub fetch_protein_tree_with_gene {
  my $self = shift;
  my $gene_stable_id = shift;

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $tree;

  my $member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', $gene_stable_id);
  $member->print_member;
  $member->get_longest_peptide_Member->print_member;
  my $aligned_member = $treeDBA->fetch_AlignedMember_by_member_id_root_id($member->get_longest_peptide_Member->member_id);
  print $aligned_member, "\n";
  $aligned_member->print_member;
  $aligned_member->gene_member->print_member;
  $tree = $aligned_member->root;
  $treeDBA->fetch_all_children_for_node($tree);

  $tree->print_tree;
  $tree->release;
  return;

  $tree->flatten_tree->print_tree;

  my $leaves = $tree->get_all_leaves;
  foreach my $node (@{$leaves}) {
    $node->print_member;
  }
  $tree->release;
}


sub create_taxon_tree {
  my $self = shift;

  my $count = 1;
  my $root = Bio::EnsEMBL::Compara::NestedSet->new->retain;
  $root->node_id($count++);
  $root->name('ROOT');
  
  my $taxonDBA = $self->{'comparaDBA'}->get_TaxonAdaptor;
  my $gdb_list = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
  foreach my $gdb (@$gdb_list) {
    my $taxon = $taxonDBA->fetch_by_dbID($gdb->taxon_id);
    my @levels = reverse($taxon->classification);
    my $taxon_info = join(":", @levels);
    print("$taxon_info\n");

    my $prev_level = '';
    my $parent = undef;
    foreach my $level_name (@levels) {
      #print("  $level_name\n");
      my $taxon_level = $root->find_node_by_name($level_name);
      unless($taxon_level) {
        if($prev_level) {
          $parent = $root->find_node_by_name($prev_level);
        } else { $parent=$root; }

        my $new_node = Bio::EnsEMBL::Compara::NestedSet->new->retain;
        $new_node->node_id($count++);
        $new_node->name($level_name);
        
        $parent->add_child($new_node);
	$new_node->distance_to_parent(0.01);
        $new_node->release;
      }
      $prev_level = $level_name;
    }
    $root->find_node_by_name($taxon->species)->node_id($taxon->ncbi_taxid);
  }
  
  $root->print_tree;

#  $self->{'comparaDBA'}->get_TreeNodeAdaptor->store($root);
#  printf("store as node_id=%d\n", $root->node_id);
  
#   my $fetchTree = $self->{'comparaDBA'}->get_TreeNodeAdaptor->fetch_tree_rooted_at_node_id($root->node_id);
#   $fetchTree->print_tree;

  #cleanup memory
  print("ABOUT TO MANUALLY release tree\n");
  $root->release;
  print("DONE\n");
}

sub parse_newick {
  my $self = shift;
  
  my $newick = '';
  print("load from file ", $self->{'newick_file'}, "\n");
  open (FH, $self->{'newick_file'}) or throw("Could not open newick file [$self->{'newick_file'}]");
  while(<FH>) {
    $newick .= $_;
  }

  my $newick1 = "(Mouse:0.76985,
                  ((((Human:0.11449,Chimp:0.15471):0.03695,
                   Gorilla:0.15680):0.02121,
                    Orang:0.29209)Hominidae:0.04986,
                        Gibbon:0.35537)Hominoidea:0.41983,
                    Bovine:0.91675);";
  my $newick2 = "((((((((((((((Pop_1:0.208139,Pop_16:0.131324)93:0.0233931,(Pop_17:0.119827,Pop_18:0.119014)86:0.0173544)81:0.0377892,Pop_19:0.126574)62:0.0201278,Pop_13:0.160825)33:0.00990783,Pop_22:0.137184)30:0.0128798,Pop_12:0.11605)43:0.0240093,((Pop_15:0.131205,((Pop_20:0.0849643,((Pop_21:0.0738889,Pop_28:0.158885)92:0.0244895,Pop_23:0.0927553)92:0.0729137)100:0.0710662,(Pop_25:0.297196,(Pop_26:0.155785,Pop_27:0.104557)100:0.23343)95:0.0755565)94:0.0552113)44:0.0121811,Pop_24:0.159212)23:0.0167188)36:0.0373877,(((Pop_2:0.0868662,Pop_3:0.0929943)100:0.0480943,Pop_4:0.11667)60:0.0103432,Pop_5:0.13734)60:0.0538027)25:0.00400269,Pop_14:0.142894)18:0.0136829,Pop_10:0.120408)11:0.0065733,Pop_8:0.0925163)6:0.00601288,(Pop_6:0.0827322,Pop_7:0.0881702)99:0.0305853)5:0.00478419,Pop_9:0.13834)40,Pop_11:0.0954593);";
  my $kitsch="((((((Human:0.13460,Chimp:0.13460):0.02836,Gorilla:0.16296):0.07638,
  Orang:0.23933):0.06639,Gibbon:0.30572):0.42923,Mouse:0.73495):0.07790,
  Bovine:0.81285);";

  my $tree = $self->{'comparaDBA'}->get_ProteinTreeAdaptor->parse_newick_into_tree($newick);
  $tree->print_tree;
  my $node = $tree->find_node_by_node_id(4);
  $node->retain->re_root;
  $node->print_tree;
  $node->release;

}

sub reroot {
  my $self = shift;
  my $node_id = shift;

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $tree = $treeDBA->fetch_node_by_node_id(68703);  
  $tree->disavow_parent;
  
  $tree->root->print_tree;

  
  my $new_root = $tree->find_node_by_node_id(174957);
  return unless $new_root;
  
  $new_root->retain->re_root;
  $treeDBA->store($new_root);
  $new_root->print_tree;
  $new_root->release;
}


