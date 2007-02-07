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
use Bio::AlignIO;
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
$self->{'cdna'} = 0;
$self->{'scale'} = 100;
$self->{'drawtree'} = 0;
$self->{'extrataxon'} = undef;
my $state = 4;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $url;

GetOptions('help'        => \$help,
           'url=s'       => \$url,
           'tre=s'       => \$self->{'newick_file'},
           'tree_id=i'   => \$self->{'tree_id'},
           'gene=s'      => \$self->{'gene_stable_id'},
           'reroot=i'    => \$self->{'new_root_id'},
           'align'       => \$self->{'print_align'},
           'cdna'        => \$self->{'cdna'},
           'draw'        => \$self->{'drawtree'},
           'extra_taxon=s'=> \$self->{'extrataxon'},
           'scale=f'     => \$self->{'scale'},
           'mini'        => \$self->{'minimize_tree'},
           'count'       => \$self->{'stats'},
          );

my @extrataxon;
if($self->{'extrataxon'}) { 
  my $temp = $self->{'extrataxon'};
  @extrataxon = split ('_',$temp);
}
if($self->{'newick_file'}) { $state=6; }
if($self->{'tree_id'}) { $state=1; }
if($self->{'gene_stable_id'}) { $state=5; }
if($self->{'new_root_id'}) { $state=7; }
if($self->{'print_align'}) { $state=8; }

if ($help or !$state) { usage(); }

$self->{'comparaDBA'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($url, 'compara') if($url);
unless(defined($self->{'comparaDBA'})) {
  print("no url URL\n\n");
  usage();
} 

if($self->{'tree_id'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'root'} = $treeDBA->fetch_node_by_node_id($self->{'tree_id'});
}

if($self->{'stats'}) {
  $state=0;
  printf("%d proteins\n", scalar(@{$self->{'root'}->get_all_leaves}));
}


switch($state) {
  case 1 { fetch_protein_tree($self, $self->{'tree_id'}); }
  case 2 { create_taxon_tree($self); }
  case 3 { fetch_primate_ncbi_taxa($self); }
  case 4 { fetch_compara_ncbi_taxa($self); }
  case 5 { fetch_protein_tree_with_gene($self, $self->{'gene_stable_id'}); }
  case 6 { parse_newick($self); }
  case 7 { reroot($self); }
  case 8 { dumpTreeMultipleAlignment($self); }
}


#cleanup memory
if($self->{'root'}) {
  print("ABOUT TO MANUALLY release tree\n");
  $self->{'root'}->release_tree;
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
  print "  -tree_id <id>          : print tree with node_id\n";
  print "  -name <string>         : search for <name> and print tree from that node\n";
  print "  -align                 : print multiple alignment\n";
  print "  -scale <num>           : scale factor for printing tree (def: 100)\n";
  print "  -mini                  : minimize tree\n";
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
  $root->print_tree($self->{'scale'});

  $root->flatten_tree->print_tree($self->{'scale'});

  $self->{'root'} = $root;
}


sub fetch_compara_ncbi_taxa {
  my $self = shift;
  
  printf("fetch_compara_ncbi_taxa\n");
  
  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $root = $self->{'root'};

  my $gdb_list = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
  foreach my $gdb (@$gdb_list) {
    my $taxon = $taxonDBA->fetch_node_by_taxon_id($gdb->taxon_id);
    $taxon->release_children;

    $root = $taxon->root unless($root);
    $root->merge_node_via_shared_ancestor($taxon);
  }
  foreach my $extra_taxon (@extrataxon) {
    my $taxon = $taxonDBA->fetch_node_by_taxon_id($extra_taxon);
    $taxon->release_children;

    $root = $taxon->root unless($root);
    $root->merge_node_via_shared_ancestor($taxon);
  }

  #$root = $root->find_node_by_name('Mammalia');

  $root = $root->minimize_tree if($self->{'minimize_tree'});
  $root->print_tree($self->{'scale'});

  my $newick = $root->newick_format;
  print("$newick\n");
  my $nhx = $root->nhx_format;
  print("$nhx\n");

  $self->{'root'} = $root;
  drawPStree($self) if ($self->{'drawtree'});
}

sub fetch_protein_tree {
  my $self = shift;
  my $node_id = shift;

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $tree;

  switch(1) {
    case 1 {
      $tree = $treeDBA->fetch_node_by_node_id($node_id);
      #$tree = $tree->parent if($tree->parent);
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

  $tree->print_tree($self->{'scale'});
  printf("%d proteins\n", scalar(@{$tree->get_all_leaves}));
  
  my $newick = $tree->newick_simple_format;
  print("$newick\n");

  $tree->release;
  return;

  $tree->flatten_tree->print_tree($self->{'scale'});

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

  $tree->print_tree($self->{'scale'});
  $tree->release;
  return;

  $tree->flatten_tree->print_tree($self->{'scale'});

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
  
  $root->print_tree($self->{'scale'});

#  $self->{'comparaDBA'}->get_TreeNodeAdaptor->store($root);
#  printf("store as node_id=%d\n", $root->node_id);
  
#   my $fetchTree = $self->{'comparaDBA'}->get_TreeNodeAdaptor->fetch_tree_rooted_at_node_id($root->node_id);
#   $fetchTree->print_tree($self->{'scale'});

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

  my $tree = $self->{'comparaDBA'}->get_ProteinTreeAdaptor->parse_newick_into_tree($newick);
  $tree->print_tree($self->{'scale'});
  $tree->release;

}

sub reroot {
  my $self = shift;
  my $node_id = $self->{'new_root_id'}; 

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $node = $treeDBA->fetch_node_by_node_id($node_id);  
  printf("tree at %d\n", $node->subroot->node_id);
  my $tree = $treeDBA->fetch_node_by_node_id($node->subroot->node_id);  
  $tree->print_tree($self->{'scale'});
  
  my $new_root = $tree->find_node_by_node_id($node_id);
  return unless $new_root;

  my $tmp_root = Bio::EnsEMBL::Compara::NestedSet->new->retain;
  $tmp_root->merge_children($tree);

  $new_root->retain->re_root;
  $tmp_root->release;
  $tree->merge_children($new_root);

  $tree->build_leftright_indexing;
  $tree->print_tree($self->{'scale'});

  $treeDBA->store($tree);
  $treeDBA->delete_node($new_root);

  $tree->release;
  $new_root->release;
}



sub dumpTreeMultipleAlignment
{
  my $self = shift;
  
  warn("missing tree\n") unless($self->{'root'});
  
  my $tree = $self->{'root'};
    
  $self->{'file_root'} = "proteintree_". $tree->node_id;
  $self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $clw_file = $self->{'file_root'} . ".aln";

  if($self->{'debug'}) {
    my $leafcount = scalar(@{$tree->get_all_leaves});  
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    print("clw_file = '$clw_file'\n");
  }

  open(OUTSEQ, ">$clw_file")
    or $self->throw("Error opening $clw_file for write");

  my $sa = $tree->get_SimpleAlign(-id_type => 'MEMBER', -cdna=>$self->{'cdna'});
  
  my $alignIO = Bio::AlignIO->newFh(-fh => \*OUTSEQ,
                                    -interleaved => 1,
                                    -format => "phylip"
                                   );
  print $alignIO $sa;

  close OUTSEQ;
}


sub dumpTreeAsNewick 
{
  my $self = shift;
  my $tree = shift;
  
  warn("missing tree\n") unless($tree);

  my $newick = $tree->newick_simple_format;

  if($self->{'dump'}) {
    my $aln_file = "proteintree_". $tree->node_id;
    $aln_file =~ s/\/\//\//g;  # converts any // in path to /
    $aln_file .= ".newick";
    
    $self->{'newick_file'} = $aln_file;
    
    open(OUTSEQ, ">$aln_file")
      or $self->throw("Error opening $aln_file for write");
  } else {
    open OUTSEQ, ">&STDOUT";
  }

  print OUTSEQ "$newick\n\n";
  close OUTSEQ;
}


sub dumpTreeAsNHX 
{
  my $self = shift;
  my $tree = shift;
  
  warn("missing tree\n") unless($tree);

  # newick_simple_format is a synonymous of newick_format method
  my $nhx;
  if ($self->{'nhx_gene_id'}) {
    $nhx = $tree->nhx_format("gene_id");
  } else {
    $nhx = $tree->nhx_format;
  }

  if($self->{'dump'}) {
    my $aln_file = "proteintree_". $tree->node_id;
    $aln_file =~ s/\/\//\//g;  # converts any // in path to /
    $aln_file .= ".nhx";
    
    # we still call this newick_file as we dont need it for much else
    $self->{'newick_file'} = $aln_file;
    
    open(OUTSEQ, ">$aln_file")
      or $self->throw("Error opening $aln_file for write");
  } else {
    open OUTSEQ, ">&STDOUT";
  }

  print OUTSEQ "$nhx\n\n";
  close OUTSEQ;
}


sub drawPStree
{
  my $self = shift;
  
  unless($self->{'newick_file'}) {
    $self->{'dump'} = 1;
    dumpTreeAsNewick($self, $self->{'root'});
    dumpTreeAsNHX($self, $self->{'root'});
  }
  
  my $ps_file = "proteintree_". $self->{'root'}->taxon_id;
  $ps_file =~ s/\/\//\//g;  # converts any // in path to /
  $ps_file .= ".ps";
  $self->{'plot_file'} = $ps_file;

  my $cmd = sprintf("drawtree -auto -charht 0.1 -intree %s -fontfile /usr/local/ensembl/bin/font5 -plotfile %s", 
                    $self->{'newick_file'}, $ps_file);
  print("$cmd\n");
  system($cmd);
  system("open $ps_file");
}


