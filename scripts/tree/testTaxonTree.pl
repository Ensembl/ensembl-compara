#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::DBLoader;
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::EnsEMBL::Compara::NestedSet;
use Switch;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'speciesList'} = ();
$self->{'removeXedSeqs'} = undef;
$self->{'outputFasta'} = undef;
$self->{'noSplitSeqLines'} = undef;
$self->{'cdna'} = 0;
$self->{'scale'} = 10;
$self->{'drawtree'} = 0;
$self->{'extrataxon_sequenced'} = undef;
$self->{'extrataxon_incomplete'} = undef;
$self->{'multifurcation_deletes_node'} = undef;
$self->{'multifurcation_deletes_all_subnodes'} = undef;
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
           'query_ncbi_name=s'     => \$self->{'query_ncbi_name'},
           'no_previous'             => \$self->{'no_previous'},
           'create_species_tree'     => \$self->{'create_species_tree'},
           'extrataxon_sequenced=s'  => \$self->{'extrataxon_sequenced'},
           'extrataxon_incomplete=s' => \$self->{'extrataxon_incomplete'},
           'multifurcation_deletes_node=s' => \$self->{'multifurcation_deletes_node'},
           'multifurcation_deletes_all_subnodes=s' => \$self->{'multifurcation_deletes_all_subnodes'},
           'scale=f'     => \$self->{'scale'},
           'mini'        => \$self->{'minimize_tree'},
           'count'       => \$self->{'stats'},
          );

if($self->{'newick_file'}) { $state=6; }
if($self->{'create_species_tree'}) { $state=9; }
if($self->{'query_ncbi_name'}) { $state=10; }
if($self->{'tree_id'}) { $state=1; }
if($self->{'gene_stable_id'}) { $state=5; }
if($self->{'new_root_id'}) { $state=7; }
if($self->{'print_align'}) { $state=8; }

if ($help or !$state) { usage(); }

if ($url) {
  eval { require Bio::EnsEMBL::Hive::URLFactory ;};
  if ($@) {
    $url =~ /mysql\:\/\/(\S+)\@(\S+)\/(\S+)/g;
    my ($myuserpass,$myhost,$mydbname) = ($1,$2,$3);
    my ($myuser,$mypass);
    if ($myuserpass =~ /(\S+)\:(\S+)/) {
      $myuser = $1;
      $mypass = $2;
    } else {
      $myuser = $myuserpass;
    }
    my $myport = 3306;
    if ($myhost =~ /(\S+)\:(\S+)/) {
      $myport = $2;
      $myhost = $1;
    }
    my %compara_conf;
    $compara_conf{-user} = $myuser;
    $compara_conf{-pass} = $mypass if (defined($mypass));
    $compara_conf{-host} = $myhost;
    $compara_conf{-dbname} = $mydbname;
    $compara_conf{-port} = $myport;
    eval { $self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf); }
  } else {
    $self->{'comparaDBA'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($url, 'compara');
  }
}
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
  case 9 { create_species_tree($self); }
  case 10 { query_ncbi_name($self); }
}


#cleanup memory
if($self->{'root'}) {
  print("ABOUT TO MANUALLY release tree\n") if ($self->{'debug'});
  $self->{'root'}->release_tree;
  $self->{'root'} = undef;
  print("DONE\n") if ($self->{'debug'});
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
  $root = $root->minimize_tree if($self->{'minimize_tree'});
  $root->print_tree($self->{'scale'});

  $self->{'root'} = $root;
  drawPStree($self) if ($self->{'drawtree'});
}

sub create_species_tree {
  my $self = shift;

  printf("create_species_tree\n");

  my @extrataxon_sequenced;
  if($self->{'extrataxon_sequenced'}) { 
    my $temp = $self->{'extrataxon_sequenced'};
    @extrataxon_sequenced = split ('_',$temp);
  }
  my @extrataxon_incomplete;
  if($self->{'extrataxon_incomplete'}) { 
    my $temp = $self->{'extrataxon_incomplete'};
    @extrataxon_incomplete = split ('_',$temp);
  }
  my @multifurcation_deletes_node;
  if($self->{'multifurcation_deletes_node'}) { 
    my $temp = $self->{'multifurcation_deletes_node'};
    @multifurcation_deletes_node = split ('_',$temp);
  }
  my @multifurcation_deletes_all_subnodes;
  if($self->{'multifurcation_deletes_all_subnodes'}) { 
    my $temp = $self->{'multifurcation_deletes_all_subnodes'};
    @multifurcation_deletes_all_subnodes = split ('_',$temp);
  }

  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $root = $self->{'root'};

  my $gdb_list = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
  unless (defined($self->{no_previous})) {
    print STDERR "Loading taxa from gdbs in $url...\n";
    foreach my $gdb (@$gdb_list) {
      my $taxon_name = $gdb->name;
      next if ($taxon_name =~ /ncestral/);
      my $taxon_id = $gdb->taxon_id;
      my $taxon = $taxonDBA->fetch_node_by_taxon_id($taxon_id);
      print STDERR "  $taxon_name [$taxon_id]\n";
      $taxon->release_children;

      $root = $taxon->root unless($root);
      $root->merge_node_via_shared_ancestor($taxon);
    }
  }
  print STDERR "Loading taxa from extrataxon_sequenced...\n" if (0 != scalar(@extrataxon_sequenced));
  foreach my $extra_taxon (@extrataxon_sequenced) {
    my $taxon = $taxonDBA->fetch_node_by_taxon_id($extra_taxon);
    my $taxon_name = $taxon->name;
    my $taxon_id = $taxon->taxon_id;
    print STDERR "  $taxon_name [$taxon_id]\n";
    $taxon->release_children;

    $root = $taxon->root unless($root);
    $root->merge_node_via_shared_ancestor($taxon);
  }
  print STDERR "Loading taxa from extrataxon_incomplete...\n" if (0 != scalar(@extrataxon_incomplete));
  foreach my $extra_taxon (@extrataxon_incomplete) {
    my $taxon = $taxonDBA->fetch_node_by_taxon_id($extra_taxon);
    my $taxon_name = $taxon->name;
    my $taxon_id = $taxon->taxon_id;
    print STDERR "  $taxon_name [$taxon_id]\n";
    $taxon->release_children;

    $root = $taxon->root unless($root);
    $root->merge_node_via_shared_ancestor($taxon);
    $taxon->add_tag("is_incomplete", '1');
  }

  #$root = $root->minimize_tree if($self->{'minimize_tree'});
  $root = $root->minimize_tree;

#   print STDERR "# Before multifurcation_deletes_node\n\n";
#   $root->print_tree($self->{'scale'});

  # Deleting nodes to further multifurcate
  my @subnodes = $root->get_all_subnodes;
  print STDERR "Multifurcating nodes...\n" if (0 != scalar(@multifurcation_deletes_node));
  foreach my $extra_taxon (@multifurcation_deletes_node) {
    my $taxon = $taxonDBA->fetch_node_by_taxon_id($extra_taxon);
    my $taxon_name = $taxon->name;
    my $taxon_id = $taxon->taxon_id;
    print STDERR "* $taxon_name [$taxon_id]\n";
    foreach my $node (@subnodes) {
      next unless ($node->node_id == $extra_taxon);
      my $node_children = $node->children;
      foreach my $child (@$node_children) {
        $node->parent->add_child($child);
      }
      $node->disavow_parent;
    }
  }

  # Deleting subnodes down to a given node
  @subnodes = $root->get_all_subnodes;
  print STDERR "Multifurcating subnodes...\n" if (0 != scalar(@multifurcation_deletes_all_subnodes));
  foreach my $extra_taxon (@multifurcation_deletes_all_subnodes) {
    my $taxon = $taxonDBA->fetch_node_by_taxon_id($extra_taxon);
    my $taxon_name = $taxon->name;
    my $taxon_id = $taxon->taxon_id;
    print STDERR "* $taxon_name [$taxon_id]\n";
    $DB::single=1;1;
    my $node_in_root = $root->find_node_by_node_id($taxon_id);
    foreach my $node ($node_in_root->get_all_subnodes) {
      next if ($node->is_leaf);
      my $node_children = $node->children;
      foreach my $child (@$node_children) {
        $node->parent->add_child($child);
      }
      $node->disavow_parent;
    }
  }


#   print STDERR "#\n After multifurcation_deletes_node\n\n";
  $root->print_tree($self->{'scale'});

  my $outname = $self->{'comparaDBA'}->dbc->dbname;
  my $num_leaves = scalar(@{$root->get_all_leaves});
  $outname = $num_leaves . "." . $outname;
  my $newick_common;
  eval {$newick_common = $root->newick_format("full_common");};
  unless ($@) {
    print("\n\n$newick_common\n\n");

    open T,">newick_common.$outname.nh" or die "$!";
    print T $newick_common;
    close T;
  }
  my $newick = $root->newick_format;
  print("\n\n$newick\n\n");

  open T,">newick.$outname.nh" or die "$!";
  print T $newick;
  close T;

  my $newick_simple = $newick;
  $newick_simple =~ s/\:\d\.\d+//g;
  $newick_simple =~ s/\ /\_/g;

  print "$newick_simple\n\n";

  open T,">newick_simple.$outname.nh" or die "$!";
  print T $newick_simple;
  close T;

  my $species_short_name = $root->newick_format('species_short_name');
  print("$species_short_name\n\n");

  open T,">species_short_name.$outname.nh" or die "$!";
  print T $species_short_name;
  close T;

  my $njtree_tree = $root->newick_format('njtree');
  print STDERR "==== Your njtree file njtree.$outname.nh ====\n";
  print("$njtree_tree\n\n");

  open T,">njtree.$outname.nh" or die "$!";
  print T $njtree_tree;
  close T;


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

sub query_ncbi_name {
  my $self = shift;
  my $name = $self->{query_ncbi_name};
  $name =~ s/\_/\ /g;

  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $taxon = $taxonDBA->fetch_node_by_name($name);
  print "taxon_name -- ", $taxon->name, "\n";
  print "taxon_id -- ", $taxon->taxon_id, "\n\n";
  foreach my $tag ($taxon->get_all_tags) {
    my $value = $taxon->get_tagvalue($tag);
    print "$tag -- $value\n";
  }
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


sub min_taxon_id {
  my $node = shift;

  return $node->taxon_id if($node->is_leaf);
  return $node->{'_leaves_min_taxon_id'} 
    if (defined($node->{'_leaves_min_taxon_id'}));

  my $minID = undef;
  foreach my $child (@{$node->children}) {
    my $taxon_id = min_taxon_id($child);
    $minID = $taxon_id unless(defined($minID) and $taxon_id>$minID);
  }
  $node->{'_leaves_min_taxon_id'} = $minID;
  return $minID;
}


