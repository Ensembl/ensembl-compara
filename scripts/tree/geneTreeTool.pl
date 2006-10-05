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
use Bio::EnsEMBL::Hive::URLFactory; # only used for url
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::NCBITaxon;
use Bio::EnsEMBL::Compara::Graph::Algorithms;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::RunnableDB::OrthoTree;
use File::Basename;
use Digest::MD5  qw(md5_hex); # duploss_fraction

use Time::HiRes qw(time gettimeofday tv_interval);

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

my %compara_conf = ();
$compara_conf{'-user'} = 'ensro';
$compara_conf{'-port'} = 3306;

$self->{'cdna'} = 0;
$self->{'scale'} = 20;
$self->{'align_format'} = 'phylip';
$self->{'debug'} = 0;
$self->{'run_topo_test'} = 1;
$self->{'analyze'} = 0;
$self->{'drawtree'} = 0;
$self->{'print_leaves'} = 0;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $url;

Bio::EnsEMBL::Registry->no_version_check(1);

GetOptions('help'             => \$help,
           'url=s'            => \$url,
           'h=s'              => \$compara_conf{'-host'},
           'u=s'              => \$compara_conf{'-user'},
           'p=s'              => \$compara_conf{'-pass'},
           'port=s'           => \$compara_conf{'-port'},
           'db=s'             => \$compara_conf{'-dbname'},
           'file=s'           => \$self->{'newick_file'},
           'tree_id=i'        => \$self->{'tree_id'},
           'clusterset_id=i'  => \$self->{'clusterset_id'},
           'gene=s'           => \$self->{'gene_stable_id'},
           'reroot=i'         => \$self->{'new_root_id'},
           'parent'           => \$self->{'parent'},
           'align'            => \$self->{'print_align'},
           'cdna'             => \$self->{'cdna'},
           'fasta'            => \$self->{'output_fasta'},
           'dump'             => \$self->{'dump'},
           'align_format=s'   => \$self->{'align_format'},
           'scale=f'          => \$self->{'scale'},
           'counts'           => \$self->{'counts'},
           'newick'           => \$self->{'print_newick'},
           'nhx'              => \$self->{'print_nhx'},
           'nhx_gene_id'      => \$self->{'nhx_gene_id'},
           'nhx_protein_id'   => \$self->{'nhx_protein_id'},
           'nhx_transcript_id'=> \$self->{'nhx_transcript_id'},
           'print'            => \$self->{'print_tree'},
           'list'             => \$self->{'print_leaves'},
           'draw'             => \$self->{'drawtree'},
           'balance'          => \$self->{'balance_tree'},
           'chop'             => \$self->{'chop_tree'},
           'keep_leaves=s'    => \$self->{'keep_leaves'},
           'debug=s'          => \$self->{'debug'},
           'onlyrapdups'      => \$self->{'onlyrapdups'},
           'orthotree'        => \$self->{'orthotree'},
           'species_list=s'   => \$self->{'species_list'},
           'v|verbose=s'      => \$self->{'verbose'},
           'analyze|analyse'  => \$self->{'analyze'},
           'test|_orthotree_treefam'    => \$self->{'_orthotree_treefam'},
           '_treefam_file=s'            => \$self->{'_treefam_file'},
           '_readonly|readonly=s'       => \$self->{'_readonly'},
           '_pattern|pattern'           => \$self->{'_pattern'},
           '_list_defs|list_defs=s'     => \$self->{'_list_defs'},
           '_check_mfurc|check_mfurc'   => \$self->{'_check_mfurc'},
           '_topolmis|topolmis=s'       => \$self->{'_topolmis'},
           'duploss=s'                 => \$self->{'_duploss'},
           'duprates=s'                 => \$self->{'_duprates'},
           '_badgenes|badgenes'         => \$self->{'_badgenes'},
           '_farm|farm'                 => \$self->{'_farm'},
          );

if ($help) { usage(); }

if($url) {
  $self->{'comparaDBA'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($url, 'compara');
} else {
  eval { $self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf); }
}
unless(defined $self->{'newick_file'} || defined($self->{'comparaDBA'})) {
  print("couldn't connect to compara database or get a newick file\n\n");
  usage();
}

#
# load tree
#

# internal purposes
if($self->{'_list_defs'}) {
  my @treeids_list = split (":", $self->{'_list_defs'});
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  foreach my $tree_id (@treeids_list) {
    $self->{'tree'} = $treeDBA->fetch_node_by_node_id($tree_id);
    # leaves are Bio::EnsEMBL::Compara::AlignedMember objects
    my $leaves = $self->{'tree'}->get_all_leaves;
    #printf("fetched %d leaves\n", scalar(@$leaves));
    printf("treeid %d, %d proteins ########################################\n", $tree_id, scalar(@$leaves));
    foreach my $leaf (@$leaves) {
      #$leaf->print_node;
      my $gene = $leaf->gene_member;
      my $desc = $gene->description;
      $desc = "" unless($desc);
      $desc = "Description : " . $desc if ($desc);
      printf("%s %s : %s\n", $leaf->name,$gene->stable_id, $desc);
    }
    #printf("\n");
    $self->{'tree'}->release_tree;
  }
}

if($self->{'tree_id'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'tree'} = $treeDBA->fetch_node_by_node_id($self->{'tree_id'});
} 
elsif ($self->{'gene_stable_id'} and $self->{'clusterset_id'} and $self->{orthotree}) {
  fetch_protein_tree_with_gene($self, $self->{'gene_stable_id'});
  $self->{'clusterset_id'} = undef;
  _run_orthotree($self);
} 
elsif ($self->{'gene_stable_id'} and $self->{'clusterset_id'}) {
  fetch_protein_tree_with_gene($self, $self->{'gene_stable_id'});
  $self->{'clusterset_id'} = undef;
} 
elsif ($self->{'newick_file'}) {
  parse_newick($self);
}
elsif ($self->{'_treefam_file'}) {
  # internal purposes
  _compare_treefam($self);
  $self->{'keep_leaves'} = 0;
}

if ($self->{'keep_leaves'}) {
  keep_leaves($self);
}

#
# do tree stuff to it
#
if($self->{'tree'}) {
  if($self->{'parent'} and $self->{'tree'}->parent) {
    $self->{'tree'} = $self->{'tree'}->parent;
  }

  $self->{'tree'}->disavow_parent;
  #$self->{'tree'}->get_all_leaves;
  #printf("get_all_leaves gives %d proteins\n", scalar(@{$self->{'tree'}->get_all_leaves}));
  #$self->{'tree'}->flatten_tree;

  if($self->{'new_root_id'}) {
    reroot($self);
  }

  #test7($self);
  if($self->{'balance_tree'}) {
    balance_tree($self);
  }

  if($self->{'chop_tree'}) {
    Bio::EnsEMBL::Compara::Graph::Algorithms::chop_tree($self->{'tree'});
  }

  #
  # display and statistics routines
  #
  if($self->{'print_tree'}) {
    $self->{'tree'}->print_tree($self->{'scale'});
    printf("%d proteins\n", scalar(@{$self->{'tree'}->get_all_leaves}));
  }
  if($self->{'print_leaves'}) {
    # leaves are Bio::EnsEMBL::Compara::AlignedMember objects
    my $leaves = $self->{'tree'}->get_all_leaves;
    printf("fetched %d leaves\n", scalar(@$leaves));
    foreach my $leaf (@$leaves) {
      #$leaf->print_node;
      my $gene = $leaf->gene_member;
      my $desc = $gene->description;
      $desc = "" unless($desc);
      printf("%s %s : %s\n", $leaf->name,$gene->stable_id, $desc);
    }
    printf("%d proteins\n", scalar(@$leaves));
  }

  if($self->{'print_newick'}) {
    dumpTreeAsNewick($self, $self->{'tree'});
  }

  if($self->{'print_nhx'}) {
    dumpTreeAsNHX($self, $self->{'tree'});
  }

  if($self->{'counts'}) {
    print_cluster_counts($self);
    print_cluster_counts($self, $self->{'tree'});
  }

  if($self->{'print_align'}) {
    dumpTreeMultipleAlignment($self);
  }

  if($self->{'output_fasta'}) {
    dumpTreeFasta($self);
  }

  if($self->{'drawtree'}) {
    drawPStree($self);
  }

  #cleanup memory
  #print("ABOUT TO MANUALLY release tree\n");
  $self->{'tree'}->release_tree unless ($self->{_treefam});
  $self->{'tree'} = undef;
  #print("DONE\n");
}

#
# clusterset stuff
#

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_pattern'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _analyzePattern($self) if($self->{'_pattern'});

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_topolmis'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _topology_mismatches($self) if($self->{'_topolmis'});

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_duploss'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _get_all_duploss_fractions($self) if(defined($self->{'_duploss'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_duprates'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _get_all_duprates_for_species_tree($self) if(defined($self->{'_duprates'}));

  exit(0);
}

# internal purposes
if (defined($self->{'clusterset_id'}) && $self->{'_check_mfurc'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _check_mfurc($self) if($self->{'_check_mfurc'});

  exit(0);
}

if(defined($self->{'clusterset_id'}) && !($self->{'_treefam_file'})) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
#  analyzeClusters2($self) if($self->{'analyze'});
#  analyzeClusters($self) if($self->{'analyze'});

  dumpAllTreesToNewick($self) if($self->{'print_newick'});
  dumpAllTreesToNHX($self) if($self->{'print_nhx'});

#   if($self->{'counts'}) {
#     print_cluster_counts($self);
#     foreach my $cluster (@{$self->{'clusterset'}->children}) {
#       print_cluster_counts($self, $cluster);
#     }
#   }
  $self->{'clusterset'} = undef;
}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "geneTreeTool.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -url <url>             : connect to compara at url\n";
  print "\n";
  print "  -tree_id <id>          : fetch tree with node_id\n";
  print "  -gene <stable_id>      : fetch tree which contains gene_stable_id\n";
  print "  -file <path>           : parse tree from Newick format file\n";
  print "\n";
  print "  -treefam_file <path>   : parse tree from treefam and compare to genetree db (clusterset_id req)\n";
  print "\n";
  print "  -align                 : output protein multiple alignment\n";
  print "  -cdna                  : output cdna multiple alignment\n";
  print "  -align_format          : alignment format (see perldoc Bio::AlignIO) (def:phylip)\n";
  print "\n";
  print "  -print_tree            : print ASCII formated tree\n";
  print "  -scale <num>           : scale factor for printing tree (def: 100)\n";
  print "  -newick                : output tree(s) in newick format\n";
  print "  -nhx                   : output tree(s) in newick extended (NHX) format with duplication tags\n";
  print "    -nhx_protein_id      : protein_ids in the leaf names for newick extended (NHX) format\n";
  print "    -nhx_gene_id         : gene_ids in the leaf names for newick extended (NHX) format\n";
  print "    -nhx_transcript_id   : transcript_ids in the leaf names for newick extended (NHX) format\n";
  print "  -reroot <id>           : reroot genetree on node_id\n";
  print "  -parent                : move up to the parent of the loaded node\n";
  print "  -dump                  : outputs to autonamed file, not STDOUT\n";
  print "  -draw                  : use PHYLIP drawtree to create ps output\n";
  print "  -counts                : return counts of proteins within tree nestedset\n";
  print "\n";
  print "  -clusterset_id <id>    : load all clusters\n"; 
  print "  -analyze               : perform rosette analysis on all clusters\n"; 
  print "  -newick                : combination of clusterset_id and newick dumps all\n"; 
  print "  -counts                : return counts of each cluster\n";
  print "  -keep_leaves <string>  : if you want to trim your tree and keep a list of leaves (by \$leaf->name) e.g. \"human,mouse,rat\"\n";
  print "geneTreeTool.pl v1.22\n";
  exit(1);
}



sub fetch_protein_tree_with_gene {
  my $self = shift;
  my $gene_stable_id = shift;

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;

  my $member = $self->{'comparaDBA'}->
               get_MemberAdaptor->
               fetch_by_source_stable_id('ENSEMBLGENE', $gene_stable_id);
  return 0 unless (defined $member);
  my $aligned_member = $treeDBA->
                       fetch_AlignedMember_by_member_id_root_id(
                          $member->get_longest_peptide_Member->member_id,
                          $self->{'clusterset_id'});
  return 0 unless (defined $aligned_member);
  my $node = $aligned_member->subroot;

  $self->{'tree'} = $treeDBA->fetch_node_by_node_id($node->node_id);
  $node->release_tree;
  return 1;
}


sub parse_newick {
  my $self = shift;

  my $newick = '';
  print("load from file ", $self->{'newick_file'}, "\n");
  open (FH, $self->{'newick_file'}) or throw("Could not open newick file [$self->{'newick_file'}]");
  while(<FH>) {
    $newick .= $_;
  }
  printf("newick string: $newick\n");
  $self->{'tree'} = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
}

sub keep_leaves {
  my $self = shift;

  my %leaves_names;
  foreach my $name (split(",",$self->{'keep_leaves'})) {
    $leaves_names{$name} = 1;
  }

  print join(" ",keys %leaves_names),"\n" if $self->{'$debug'};
  my $tree = $self->{'tree'};

  foreach my $leaf (@{$tree->get_all_leaves}) {
    unless (defined $leaves_names{$leaf->name}) {
      print $leaf->name," leaf disavowing parent\n" if $self->{'$debug'};
      $leaf->disavow_parent;
      $tree = $tree->minimize_tree;
    }
  }
  if ($tree->get_child_count == 1) {
    my $child = $tree->children->[0];
    $child->parent->merge_children($child);
    $child->disavow_parent;
  }
  $self->{'tree'} = $tree;
}

sub reroot {
  my $self = shift;
  my $node_id = $self->{'new_root_id'};

  #my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  #my $node = $treeDBA->fetch_node_by_node_id($node_id);  
  #printf("tree at %d\n", $node->subroot->node_id);
  #my $tree = $treeDBA->fetch_node_by_node_id($node->subroot->node_id);  
  
  my $tree = $self->{'tree'};
  $tree->get_all_leaves;  #make sure entire tree is loaded into memory
  #$tree->print_tree($self->{'scale'});

  my $reroot_node = $tree->find_node_by_node_id($node_id);
  return unless $reroot_node;

  #print("unlink tree from clusterset\n");
  my $parent = $tree->parent;
  my $dist = $tree->distance_to_parent;
  $tree->disavow_parent;
  
  $reroot_node->re_root;
  
  $parent->add_child($tree, $dist);
  
  #$treeDBA->store($tree);
  #$treeDBA->delete_node($new_root);
}



sub dumpTreeMultipleAlignment
{
  my $self = shift;
  
  warn("missing tree\n") unless($self->{'tree'});
  
  my $tree = $self->{'tree'};

  my $sa = $tree->get_SimpleAlign(-id_type => 'SEQ', -UNIQ_SEQ=>1, -cdna=>$self->{'cdna'});

  if($self->{'dump'}) {
    my $aln_file = "proteintree_". $tree->node_id;
    $aln_file =~ s/\/\//\//g;  # converts any // in path to /
    $aln_file .= ".cdna" if($self->{'cdna'});
    $aln_file .= "." . $self->{'align_format'};
    
    print("aln_file = '$aln_file'\n") if($self->{'debug'});

    open(OUTSEQ, ">$aln_file")
      or $self->throw("Error opening $aln_file for write");
  } else {
    open OUTSEQ, ">&STDOUT";
  }
  
  if($self->{'debug'}) {
    my $leafcount = scalar(@{$tree->get_all_leaves});  
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
  }

  my $alignIO = Bio::AlignIO->newFh(-fh => \*OUTSEQ,
                                    -interleaved => 0,
                                    -format => $self->{'align_format'},
                                   );
  print $alignIO $sa;
  close OUTSEQ;
}


sub dumpTreeAsNewick 
{
  my $self = shift;
  my $tree = shift;

  warn("missing tree\n") unless($tree);

  # newick_simple_format is a synonymous of newick_format method
  my $newick = $tree->newick_simple_format;

  if($self->{'dump'}) {
    my $newick_file = "proteintree_". $tree->node_id;
    $newick_file = $self->{'dump'} if (1 < length($self->{'dump'})); #wise naming
    $newick_file =~ s/\/\//\//g;  # converts any // in path to /
    $newick_file .= ".newick";

    $self->{'newick_file'} = $newick_file;

    open(OUTSEQ, ">$newick_file")
      or $self->throw("Error opening $newick_file for write");
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
  } elsif ($self->{'nhx_protein_id'}) {
    $nhx = $tree->nhx_format("protein_id");
  } elsif ($self->{'nhx_transcript_id'}) {
    $nhx = $tree->nhx_format("transcript_id");
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
    dumpTreeAsNewick($self, $self->{'tree'});
  }
  
  my $ps_file = "proteintree_". $self->{'tree'}->node_id;
  $ps_file =~ s/\/\//\//g;  # converts any // in path to /
  $ps_file .= ".ps";
  $self->{'plot_file'} = $ps_file;

  my $cmd = sprintf("drawtree -auto -charht 0.1 -intree %s -fontfile /usr/local/ensembl/bin/font5 -plotfile %s", 
                    $self->{'newick_file'}, $ps_file);
  print("$cmd\n");
  system($cmd);
  system("open $ps_file");
}


sub dumpTreeFasta
{
  my $self = shift;
  
  if($self->{'dump'}) {
    my $fastafile = "proteintree_". $self->{'tree'}->node_id. ".fasta";
    $fastafile =~ s/\/\//\//g;  # converts any // in path to /
    
    open(OUTSEQ, ">$fastafile")
      or $self->throw("Error opening $fastafile for write");
  } else {
    open OUTSEQ, ">&STDOUT";
  }

  my $seq_id_hash = {};
  my $member_list = $self->{'tree'}->get_all_leaves;  
  foreach my $member (@{$member_list}) {
    next if($seq_id_hash->{$member->sequence_id});
    $seq_id_hash->{$member->sequence_id} = 1;
    
    my $seq = $member->sequence;
    $seq =~ s/(.{72})/$1\n/g;
    chomp $seq;

    printf OUTSEQ ">%d %s\n$seq\n", $member->sequence_id, $member->stable_id
  }
  close OUTSEQ;
  
}


sub print_cluster_counts
{
  my $self = shift;
  my $tree = shift;
  
  unless($tree) {
    printf("%10s %10s %20s %20s\n", 'tree_id', 'proteins', 'residues', 'PHYML msecs');
    return;
  }
  
  my $proteins = $tree->get_all_leaves;
  my $count = 0;
  foreach my $member (@$proteins) {
    if(!($member->isa("Bio::EnsEMBL::Compara::Member"))) {
      printf("FOUND NOT MEMBER LEAF\n");
      $member->print_node;
      $member->print_tree;
      $member->parent->print_tree;
      next;
    }
    $count += $member->seq_length;
  }

  my $phyml_msec =  $tree->has_tag('PHYML_runtime_msec');
  $phyml_msec ='' unless(defined($phyml_msec));

  printf("%10d %10d %20d %20d\n",
    $tree->node_id, 
    scalar(@$proteins),
    $count, $phyml_msec
    );
}


##################################################
#
# tree analysis
#
##################################################

sub dumpAllTreesToNewick
{
  my $self = shift;

  foreach my $cluster (@{$self->{'clusterset'}->children}) {
    dumpTreeAsNewick($self, $cluster);
  }
}

sub dumpAllTreesToNHX
{
  my $self = shift;

  foreach my $cluster (@{$self->{'clusterset'}->children}) {
    dumpTreeAsNHX($self, $cluster);
  }
}

sub _topology_mismatches
{
  my $self = shift;
  my $species_list_as_in_tree = $self->{species_list} || "22,10,21,23,3,14,15,19,11,16,9,13,4,18,5,24,12,7,17";
  my $species_list = [22,10,21,25,3,14,15,28,11,16,26,13,4,27,18,5,24,7,17];
  my @species_list_as_in_tree = split("\,",$species_list_as_in_tree);
  my @query_species = split("\,",$self->{'_topolmis'});
  
  printf("topolmis root_id: %d\n", $self->{'clusterset_id'});
  
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

  #  my $outfile = "topolmis.". $self->{'clusterset_id'} . ".txt";
  my $outfile = "topolmis.". $self->{'clusterset_id'}. "." . "sp." . join (".",@query_species) . ".txt";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE "topo_match,tree_id,node_id,duptag,ottag\n";
  my $cluster_count;
  foreach my $cluster (@{$clusterset->children}) {
    my %member_totals;
    $cluster_count++;
    my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
    print STDERR $verbose_string if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
    $treeDBA->fetch_subtree_under_node($cluster);

    my $member_list = $cluster->get_all_leaves;
    my %member_gdbs;

    foreach my $member (@{$member_list}) {
      $member_gdbs{$member->genome_db_id} = 1;
      $member_totals{$member->genome_db_id}++;
    }
    my @genetree_species = keys %member_gdbs;
    #print the patterns
    my @isect = my @diff = my @union = ();
    my %count;
    foreach my $e (@genetree_species, @query_species) { $count{$e}++ }
    foreach my $e (keys %count) {
      push(@union, $e);
      push @{ $count{$e} == 2 ? \@isect : \@diff }, $e;
    }

    next if (scalar(@isect) < 3);
    #trim tree and look at topology
    my $keep_leaves_string;
    my %query_species;
    foreach my $mis (@query_species) {$query_species{$mis}=1;}
    foreach my $member (@{$member_list}) {
      next unless ($query_species{$member->genome_db_id});
      #mark to keep
      $keep_leaves_string .= $member->name;
      $keep_leaves_string .= ",";
    }
    $keep_leaves_string =~ s/\,$//;
    $self->{'tree'} = $cluster;
    $self->{'keep_leaves'} = $keep_leaves_string;
    keep_leaves($self);
    $cluster = $self->{'tree'};
    # For each internal node in the tree
    ## no intersection of sps btw both child
    my $nodes_to_inspect = _mark_for_topology_inspection($cluster);
    foreach my $subnode ($cluster->get_all_subnodes) {
      next if ($subnode->is_leaf);
      if ('1' eq $subnode->get_tagvalue('_inspect_topology')) {
        my $copy = $subnode->copy;
        my $leaves = $copy->get_all_leaves;
        foreach my $member (@$leaves) {
          my $gene_taxon = new Bio::EnsEMBL::Compara::NCBITaxon;
          $gene_taxon->ncbi_taxid($member->taxon_id);
          $gene_taxon->distance_to_parent($member->distance_to_parent);
          $member->parent->add_child($gene_taxon);
          $member->disavow_parent;
        }
        #$copy->print_tree;  
        #build real taxon tree from NCBI taxon database
        my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
        my $species_tree = undef;
        foreach my $member (@$leaves) {
          my $ncbi_taxon = $taxonDBA->fetch_node_by_taxon_id($member->taxon_id);
          $ncbi_taxon->no_autoload_children;
          $species_tree = $ncbi_taxon->root unless($species_tree);
          $species_tree->merge_node_via_shared_ancestor($ncbi_taxon);
        }
        $species_tree = $species_tree->minimize_tree;
        my $topology_matches = _compare_topology($copy, $species_tree);
        my $refetched_cluster = $treeDBA->fetch_node_by_node_id($subnode->node_id);
        my $duptag = $refetched_cluster->find_node_by_node_id($subnode->node_id)->get_tagvalue('Duplication');
        my $ottag = $refetched_cluster->find_node_by_node_id($subnode->node_id)->get_tagvalue('Duplication_alg');
        $ottag = 1 if ($ottag =~ /species_count/);
        $ottag = 0 if ($ottag eq '');
        print OUTFILE $topology_matches, ",", 
          $subnode->subroot->node_id,",", 
            $subnode->node_id,",", 
              $duptag, "," ,
                $ottag, "\n";
      }
    }
  }
}
#topolmis end


sub _get_all_duprates_for_species_tree
{
  my $self = shift;
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  printf("dbname: %s\n", $self->{'_mydbname'});
  printf("duprates_for_species_tree_root_id: %d\n", $self->{'clusterset_id'});

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

  my $outfile = "duprates.". $self->{_mydbname} . "." . $self->{'clusterset_id'};
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE "node_subtype,dupcount,passedcount\n";
  print "node_subtype,dupcount,passedcount\n";
  my $cluster_count;

  # Load species tree
  $self->{_myspecies_tree} = $self->{'root'};
  $self->{gdb_list} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
  foreach my $gdb (@{$self->{gdb_list}}) {
    my $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($gdb->taxon_id);
    $taxon->release_children;
    $self->{_myspecies_tree} = $taxon->root unless($self->{_myspecies_tree});
    $self->{_myspecies_tree}->merge_node_via_shared_ancestor($taxon);
  }
  $self->{_myspecies_tree} = $self->{_myspecies_tree}->minimize_tree;

  my @clusters = @{$clusterset->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);
  foreach my $cluster (@clusters) {
    my %member_totals;
    $cluster_count++;
    my $verbose_string = sprintf "[%5d / %5d trees done]\n", $cluster_count, $totalnum_clusters;
    print STDERR $verbose_string if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
    $treeDBA->fetch_subtree_under_node($cluster);

    my $member_list = $cluster->get_all_leaves;
    #     my %member_gdbs;
    #     foreach my $member (@{$member_list}) {
    #       $member_gdbs{$member->genome_db_id} = 1;
    #       $member_totals{$member->genome_db_id}++;
    #     }
    #     my @genetree_species = keys %member_gdbs;
    # Store the duprates for every cluster
    $self->_count_dups($cluster);
  }
  foreach my $sp_node ($self->{_myspecies_tree}->get_all_subnodes) {
    my $sp_node_name = $sp_node->get_tagvalue('name');
    my $sp_node_dupcount = $sp_node->get_tagvalue('dupcount') || 0;
    my $sp_node_passedcount = $sp_node->get_tagvalue('passedcount') || 0;
    print OUTFILE $sp_node_name, ", ", $sp_node_dupcount, ", ", $sp_node_passedcount, "\n";
    print $sp_node_name, ", ", $sp_node_dupcount, ", ", $sp_node_passedcount, "\n";
  }
}
#

sub _count_dups {
  my $self = shift;
  my $cluster = shift;
  #Assumes $self->{_myspecies_tree} exists
  foreach my $node ($cluster->get_all_subnodes) {
    next if ($node->is_leaf);
    my $taxon_name = '';
    my $taxon;
    $taxon_name = $node->get_tagvalue('name');
    unless (defined($taxon_name)) {
      $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($node->taxon_id);
      $taxon_name = $taxon->name;
    }
    my $taxon_node = $self->{_myspecies_tree}->find_node_by_name($taxon_name);
    my $dups = $node->get_tagvalue("Duplication") || 0;
    my $dupcount = $taxon_node->get_tagvalue('dupcount') || 0;
    $taxon_node->add_tag('dupcount',($dupcount+1)) if ($dups);
    my $passedcount = $taxon_node->get_tagvalue('passedcount') || 0;
    $taxon_node->add_tag('passedcount',($passedcount+1));
  }
}

sub _get_all_duploss_fractions
{
  my $self = shift;
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  printf("dbname: %s\n", $self->{'_mydbname'});
  printf("duploss_fractions_root_id: %d\n", $self->{'clusterset_id'});

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

  #  my $outfile = "topolmis.". $self->{'clusterset_id'} . ".txt";
  my $outfile = "duploss_fraction.". $self->{_mydbname} . "." . $self->{'clusterset_id'};
  $outfile .= ".md5" if (2 == $self->{debug});
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE "tree_id,node_id,node_subtype,duploss_fraction,num,denom,stable_id\n" unless (2==$self->{debug});
  print OUTFILE "tree_id,node_id,node_subtype,duploss_fraction,num,denom,stable_id,md5_stable_ids\n" if (2==$self->{debug});
  my $cluster_count;
  my @clusters = @{$clusterset->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);
  foreach my $cluster (@clusters) {
    my %member_totals;
    $cluster_count++;
    my $verbose_string = sprintf "[%5d / %5d trees done]\n", $cluster_count, $totalnum_clusters;
    print STDERR $verbose_string if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
    $treeDBA->fetch_subtree_under_node($cluster);

    my $member_list = $cluster->get_all_leaves;
    my %member_gdbs;

    foreach my $member (@{$member_list}) {
      $member_gdbs{$member->genome_db_id} = 1;
      $member_totals{$member->genome_db_id}++;
    }
    my @genetree_species = keys %member_gdbs;
    # Do we want 1-species trees?
    next if (scalar(@genetree_species) < 2);
    # For each internal node in the tree
    # no intersection of sps btw both child
    my $ret = _duploss_fraction($cluster);
  }
}


# internal purposes
sub _duploss_fraction {
  my $node = shift;
  my ($child_a, $child_b) = @{$node->children};
  # Look at the childs
  # FIXME assumes binary tree
  my $child_a_dups = _count_dups_in_subtree($child_a);
  my $child_b_dups = _count_dups_in_subtree($child_b);
  # Look at the node
  my $dups = 0;
  $dups = $node->get_tagvalue("Duplication") || 0;
  return 0 if (0 == $dups && 0 == $child_a_dups && 0 == $child_b_dups);
  my @gdb_a_tmp = map {$_->genome_db_id} @{$child_a->get_all_leaves};
  my @gdb_b_tmp = map {$_->genome_db_id} @{$child_b->get_all_leaves};

  my $using_genes = 0;
  my @gdb_a_stable_ids = map {$_->stable_id} @{$child_a->get_all_leaves};
  my @gdb_b_stable_ids = map {$_->stable_id} @{$child_b->get_all_leaves};
  # my @gdb_a_stable_ids = map {$_->gene->stable_id} @{$child_a->get_all_leaves};
  # my @gdb_b_stable_ids = map {$_->gene->stable_id} @{$child_b->get_all_leaves};
  my $stable_ids_pattern = '';
  my $repr_stable_id_chosen = 0;
  foreach my $stable_id (sort(@gdb_a_stable_ids,@gdb_b_stable_ids)) {
    $stable_ids_pattern .= "$stable_id"."#";
    # FIXME - put in a generic function
    if (1 == $using_genes) {
      if (0 == $repr_stable_id_chosen) {
        if ($stable_id =~ /^ENSG0/) {
          $repr_stable_id_chosen = 1;
        } elsif ($stable_id =~ /^ENSMUSG0/) {
          $repr_stable_id_chosen = 1;
        } elsif ($stable_id =~ /^ENSDARG0/) {
          $repr_stable_id_chosen = 1;
        } elsif ($stable_id =~ /^ENSCING0/) {
          $repr_stable_id_chosen = 1;
        } else {
          $repr_stable_id_chosen = 0;
        }
        $node->{_repr_stable_id} = $stable_id if (1 == $repr_stable_id_chosen);
      }
    } else {
      if (0 == $repr_stable_id_chosen) {
        if ($stable_id =~ /^ENSP0/) {
          $repr_stable_id_chosen = 1;
        } elsif ($stable_id =~ /^ENSMUSP0/) {
          $repr_stable_id_chosen = 1;
        } elsif ($stable_id =~ /^ENSDARP0/) {
          $repr_stable_id_chosen = 1;
        } elsif ($stable_id =~ /^ENSCINP0/) {
          $repr_stable_id_chosen = 1;
        } else {
          $repr_stable_id_chosen = 0;
        }
        $node->{_repr_stable_id} = $stable_id if (1 == $repr_stable_id_chosen);
      }
    }
  }
  unless(defined($node->{_repr_stable_id})) {
    $node->{_repr_stable_id} = $gdb_a_stable_ids[0];
  }
  $node->{_stable_ids_md5sum} = md5_hex($stable_ids_pattern);

  my %seen = ();  my @gdb_a = grep { ! $seen{$_} ++ } @gdb_a_tmp;
     %seen = ();  my @gdb_b = grep { ! $seen{$_} ++ } @gdb_b_tmp;
  my @isect = my @diff = my @union = (); my %count;
  foreach my $e (@gdb_a, @gdb_b) { $count{$e}++ }
  foreach my $e (keys %count) { push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e; }
  1;
  my $taxon_id = $node->get_tagvalue("taxon_id");
  my $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($taxon_id);
  my $taxon_name = $taxon->name;
  my $scalar_isect = scalar(@isect);
  my $scalar_union = scalar(@union);
  my $duploss_frac = $scalar_isect/$scalar_union;
  unless (0 == $dups) { # we want to check for dupl nodes onlly
    unless (1 == $scalar_isect && 1 == $scalar_union) { # we dont want leaf-level 1/1 within_species_paralogs
      $taxon_name =~ s/\//\_/g;
      $taxon_name =~ s/\ /\_/g;
      my $results = 
        $node->subroot->node_id . 
          ", " . 
        $node->node_id . 
          ", " . 
        $taxon_name . 
          ", " . 
        $duploss_frac . 
         ", " . 
        $scalar_isect . 
         ", " . 
        $scalar_union . 
         ", " . 
        $node->{_repr_stable_id};
      $results .= ", " . $node->{_stable_ids_md5sum} if (2==$self->{debug});
      $results .= "\n";
      print OUTFILE $results;
    }
  }
  # Recurse
  my $dummy = _duploss_fraction($child_a) if (0 < $child_a_dups);
  $dummy = _duploss_fraction($child_b) if (0 < $child_b_dups);

  return $dups;
}


sub _count_dups_in_subtree {
  my $node = shift;

  my (@duptags) = map {$_->get_tagvalue("Duplication")} $node->get_all_subnodes;
  my $duptags = 0; foreach my $duptag (@duptags) { $duptags++ if (0 != $duptag); }

  return $duptags;
}


# internal purposes
sub _compare_topology {
  my $gene_tree = shift;
  my $species_tree = shift;
  my $topology_matches = 0;

  my ($g_child_a, $g_child_b) = @{$gene_tree->children};
  my @g_gdb_a_tmp = map {$_->node_id} @{$g_child_a->get_all_leaves};
  my @g_gdb_b_tmp = map {$_->node_id} @{$g_child_b->get_all_leaves};
  my %g_seen = ();  my @g_gdb_a = grep { ! $g_seen{$_} ++ } @g_gdb_a_tmp;
     %g_seen = ();  my @g_gdb_b = grep { ! $g_seen{$_} ++ } @g_gdb_b_tmp;
  my ($s_child_a, $s_child_b) = @{$species_tree->children};
  my @s_gdb_a_tmp = map {$_->node_id} @{$s_child_a->get_all_leaves};
  my @s_gdb_b_tmp = map {$_->node_id} @{$s_child_b->get_all_leaves};
  my %s_seen = ();  my @s_gdb_a = grep { ! $s_seen{$_} ++ } @s_gdb_a_tmp;
     %s_seen = ();  my @s_gdb_b = grep { ! $s_seen{$_} ++ } @s_gdb_b_tmp;

  # straight
  my @isect_a = my @diff_a = my @union_a = (); my %count_a;
  foreach my $e (@g_gdb_a, @s_gdb_a) { $count_a{$e}++ }
  foreach my $e (keys %count_a) { push(@union_a, $e); push @{ $count_a{$e} == 2 ? \@isect_a : \@diff_a }, $e; }
  my @isect_b = my @diff_b = my @union_b = (); my %count_b;
  foreach my $e (@g_gdb_b, @s_gdb_b) { $count_b{$e}++ }
  foreach my $e (keys %count_b) { push(@union_b, $e); push @{ $count_b{$e} == 2 ? \@isect_b : \@diff_b }, $e; }
  # crossed
  my @isect_ax = my @diff_ax = my @union_ax = (); my %count_ax;
  foreach my $e (@g_gdb_a, @s_gdb_b) { $count_ax{$e}++ }
  foreach my $e (keys %count_ax) { push(@union_ax, $e); push @{ $count_ax{$e} == 2 ? \@isect_ax : \@diff_ax }, $e; }
  my @isect_bx = my @diff_bx = my @union_bx = (); my %count_bx;
  foreach my $e (@g_gdb_b, @s_gdb_a) { $count_bx{$e}++ }
  foreach my $e (keys %count_bx) { push(@union_bx, $e); push @{ $count_bx{$e} == 2 ? \@isect_bx : \@diff_bx }, $e; }

  if ((0==scalar(@diff_a) && 0==scalar(@diff_b)) || (0==scalar(@diff_ax) && 0==scalar(@diff_bx))) {
    $topology_matches = 1;
  }
  return $topology_matches;
}


# internal purposes
sub _mark_for_topology_inspection {
  my $node = shift;
  my $nodes_to_inspect = 0;
  my ($child_a, $child_b) = @{$node->children};
  my @gdb_a_tmp = map {$_->genome_db_id} @{$child_a->get_all_leaves};
  my @gdb_b_tmp = map {$_->genome_db_id} @{$child_b->get_all_leaves};
  my %seen = ();  my @gdb_a = grep { ! $seen{$_} ++ } @gdb_a_tmp;
     %seen = ();  my @gdb_b = grep { ! $seen{$_} ++ } @gdb_b_tmp;
  my @isect = my @diff = my @union = (); my %count;
  foreach my $e (@gdb_a, @gdb_b) { $count{$e}++ }
  foreach my $e (keys %count) { push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e; }
  if (0 == scalar(@isect)) {
    $node->add_tag('_inspect_topology','1'); $nodes_to_inspect++;
  }
  $nodes_to_inspect += _mark_for_topology_inspection($child_a) if (scalar(@gdb_a)>2);
  $nodes_to_inspect += _mark_for_topology_inspection($child_b) if (scalar(@gdb_b)>2);
  return $nodes_to_inspect;
}


# internal purposes
sub _check_mfurc {
  my $self = shift;
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $cluster_count;
  foreach my $cluster (@{$clusterset->children}) {
    $cluster_count++;
    foreach my $subnode ($cluster->get_all_subnodes) {
      my $child_count = scalar(@{$subnode->children});
      print "multifurcation node_id\n", $cluster->node_id, if ($child_count > 2);
      my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
      print STDERR $verbose_string if ($self->{'verbose'} && ($cluster_count % $self->{'verbose'} == 0));
    }
  }
}


# internal purposes
sub _analyzePattern
{
  my $self = shift;
  my $species_list_as_in_tree = $self->{species_list} || "22,10,21,23,3,14,15,19,11,16,9,13,4,18,5,24,12,7,17";
  my @species_list_as_in_tree = split("\,",$species_list_as_in_tree);
  #        my $species_list = [3,4,5,7,9,10,11,12,13,14,15,16,17,18,19,21,22,23,24];

  printf("analyzePattern root_id: %d\n", $self->{'clusterset_id'});

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

  #printf("%d clusters\n", $clusterset->get_child_count);

  my $pretty_cluster_count=0;
  my $outfile = "analyzePattern.". $self->{'clusterset_id'} . ".txt";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  my $badgenes = "analyzePattern.". $self->{'clusterset_id'} . ".strangepatterns" . ".txt";
  open BADGENES, ">$badgenes" or die "error opening outfile: $!\n" if ($self->{'_badgenes'});
  #  printf(OUTFILE "%7s, %10s, %10s, %7s", "node_id", "members", "has_gdb_dups", "time");
  printf(OUTFILE "%7s, %7s, %7s, %7s, %10s, %8s, %9s", "node_id", "members", "nodes", "species", "has_gdb_dups", "duptags", "time");
  foreach my $species (@species_list_as_in_tree) {
    printf(OUTFILE ", %2d", $species);
  }
  printf(OUTFILE "\n");
  my $cluster_count;
  foreach my $cluster (@{$clusterset->children}) {
    my %member_totals;
    $cluster_count++;
    my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
    print STDERR $verbose_string if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
    my $starttime = time();
    $treeDBA->fetch_subtree_under_node($cluster);

    my $member_list = $cluster->get_all_leaves;
    my %member_gdbs;
    my $has_gdb_dups=0;

    my (@duptags) = map {$_->get_tagvalue("Duplication")} $cluster->get_all_subnodes;
    push @duptags, $cluster->get_tagvalue("Duplication");
    my $duptags;
    foreach my $duptag (@duptags) {
      $duptags++ if (0 != $duptag);
    }

    foreach my $member (@{$member_list}) {
      $has_gdb_dups=1 if($member_gdbs{$member->genome_db_id});
      $member_gdbs{$member->genome_db_id} = 1;
      #$member_totals{$member->genome_db_id}{$member->node_id} = scalar(@{$member_list});
      $member_totals{$member->genome_db_id}++;
    }
    my $species_count = (scalar(keys %member_gdbs));
    #     printf("%7d, %10d, %10d, %10.3f\n", $cluster->node_id, scalar(@{$member_list}), $has_gdb_dups, (time()-$starttime));
    printf(
           OUTFILE "%7d, %7d, %7d, %7d, %10d, %10d, %10.3f", 
           $cluster->node_id, scalar(@{$member_list}), 
           scalar(@duptags), 
           $species_count, 
           $has_gdb_dups, 
           $duptags, 
           (time()-$starttime)
          );
    #print the patterns
    foreach my $species (@species_list_as_in_tree) {
      my $value = 0;
      $value = $member_totals{$species} if ($member_totals{$species});
      printf(OUTFILE ", %2d", $value);
    }
    print OUTFILE "\n";

    $pretty_cluster_count++ unless($has_gdb_dups);
    #badgenes
    if ($self->{'_badgenes'}) {
      my $max = 0; my $min = 999; my $mean_num;
      foreach my $species (keys %member_totals) {
        $max = $member_totals{$species} if ($member_totals{$species}>$max);
        $min = $member_totals{$species} if ($member_totals{$species}<$min);
        $mean_num += $member_totals{$species};
      }
      my $mean = $mean_num/$species_count;
      next unless ($max >= 10);
      next unless ($max > (3*$mean));
      # get number of "Un" genes
      printf(BADGENES "%7d, %7d, %7d, %10d, %10.3f", 
             $cluster->node_id, 
             scalar(@{$member_list}), 
             $species_count, 
             $has_gdb_dups, 
             (time()-$starttime));
      print BADGENES "\n";
    }
    ### badgenes

  }
  printf("%d clusters without duplicates (%d total)\n", 
         $pretty_cluster_count, 
         $cluster_count);
  close OUTFILE;
}

sub analyzeClusters
{
  my $self = shift;
  my $species_list = [3,4,5,7,9,10,11,12,13,14,15,16,17,18,19,21,22,23,24];

  printf("analyzeClusters root_id: %d\n", $self->{'clusterset_id'});

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

  printf("%d clusters\n", $clusterset->get_child_count);

  my $pretty_cluster_count=0;
  my $outfile = "analyzeClusters.". $self->{'clusterset_id'} . ".txt";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  printf(OUTFILE "%7s, %10s, %10s, %7s", 
         "node_id", 
         "members", 
         "has_gdb_dups", 
         "time");
  foreach my $species (sort {$a <=> $b} @{$species_list}) {
    printf(OUTFILE ", %2d", $species);
  }
  printf(OUTFILE "\n");
#   my %member_totals;
  foreach my $cluster (@{$clusterset->children}) {
    my $starttime = time();
    $treeDBA->fetch_subtree_under_node($cluster);

    my $member_list = $cluster->get_all_leaves;
    my %member_gdbs;
    my $has_gdb_dups=0;
    foreach my $member (@{$member_list}) {
      $has_gdb_dups=1 if($member_gdbs{$member->genome_db_id});
      $member_gdbs{$member->genome_db_id} = 1;
    }
    printf(OUTFILE "%7d, %10d, %10d, %10.3f", 
           $cluster->node_id, 
           scalar(@{$member_list}), 
           $has_gdb_dups, 
           (time()-$starttime));
    foreach my $species (sort {$a <=> $b} @{$species_list}) {
      my $value = 0;
      $value = 1 if $member_gdbs{$species};
      printf(OUTFILE ", %2d", $value);
    }
    print OUTFILE "\n";
    $pretty_cluster_count++ unless($has_gdb_dups);
  }
  printf("%d clusters without duplicates (%d total)\n", 
         $pretty_cluster_count, 
         $clusterset->get_child_count);
  close OUTFILE;
}


sub analyzeClusters2
{
  my $self = shift;
  # this list should be ok for ensembl_38
  # use mysql> select genome_db_id,name from genome_db order by genome_db_id;
  # to check gdb ids
  my $species_list = [3,4,5,7,9,10,11,12,13,14,15,16,17,18,19,21,22,23,24];
  #my $species_list = [1,2,3,14];
  
  $self->{'member_LSD_hash'} = {};
  $self->{'gdb_member_hash'} = {};

  my $ingroup = {};
  foreach my $gdb (@{$species_list}) {
    $ingroup->{$gdb} = 1;
    $self->{'gdb_member_hash'}->{$gdb} = []
  }
  
  printf("analyzeClusters root_id: %d\n", $self->{'clusterset_id'});

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $clusterset = $self->{'clusterset'};  

  printf("%d clusters\n", $clusterset->get_child_count);
  
  my $total_members=0;
  my $cluster_count=0;
  my $rosette_count=0;
  my $lsd_rosette_count=0;
  my $geneLoss_rosette_count=0;
  my $match_species_tree_count=0;
  my %rosette_taxon_hash;
  my %rosette_newick_hash;
  foreach my $cluster (@{$clusterset->children}) {

    $cluster_count++;
    printf("clustercount $cluster_count\n") if($cluster_count % 100 == 0);
    my $starttime = time();
    $treeDBA->fetch_subtree_under_node($cluster);
    $cluster->disavow_parent;

    my $member_list = $cluster->get_all_leaves;

    #test for flat tree
    my $max_depth = $cluster->max_depth;

    my $cluster_has_lsd=0;

    if($self->{'debug'}) {
      printf("%s\t%10d, %10d, %7d\n", 'cluster',
         $cluster->node_id, scalar(@{$member_list}), $max_depth);
    }

    if($max_depth > 1) {
      foreach my $member (@{$member_list}) {

        push @{$self->{'gdb_member_hash'}->{$member->genome_db_id}},
          $member->member_id;

        # If already analyzed
        next if(defined($self->{'member_LSD_hash'}->{$member->member_id}));
        next unless($ingroup->{$member->genome_db_id});

        my $rosette = find_ingroup_ancestor($self, $ingroup, $member);
        #$rosette->print_tree;
        $rosette_count++;
        if($self->{'debug'}) {
          printf("    rosette: %10d, %10d, %10d, %10d\n",
                 $rosette->node_id, scalar(@{$rosette->get_all_leaves}), 
                 $cluster->node_id, scalar(@{$member_list}));
        }

        my $has_LSDup = test_rosette_for_LSD($self,$rosette);

        if($has_LSDup) {
          print("    LinearSpecificDuplication\n") if($self->{'debug'});
          #$rosette->print_tree;
          $lsd_rosette_count++;
          $rosette->add_tag('rosette_LSDup');
        }

        if(!$has_LSDup and $self->{'run_topo_test'}) {
          if(test_rosette_matches_species_tree($self, $rosette)) {
            $match_species_tree_count++;
            $rosette->add_tag('rosette_species_topo_match');
          } else {
            $rosette->add_tag('rosette_species_topo_failed');
          }

        }

        if(test_rosette_for_gene_loss($self, $rosette, $species_list)) {
          $geneLoss_rosette_count++;
          $rosette->add_tag('rosette_geneLoss');
        }

        #generate a taxon_id string
        my @all_leaves = @{$rosette->get_all_leaves};
        $total_members += scalar(@all_leaves);
        my @taxon_list;
        foreach my $leaf (@all_leaves) { push @taxon_list, $leaf->taxon_id;}
        my $taxon_id_string = join("_", sort {$a <=> $b} @taxon_list);

        #generate taxon unique newick string
        my $taxon_newick_string = taxon_ordered_newick($rosette);

        if(!$rosette->has_tag('rosette_LSDup')) {
          $rosette_taxon_hash{$taxon_id_string} = 0 
            unless(defined($rosette_taxon_hash{$taxon_id_string}));
          $rosette_taxon_hash{$taxon_id_string}++;

          $rosette_newick_hash{$taxon_newick_string} = 0 
            unless(defined($rosette_newick_hash{$taxon_newick_string}));
          $rosette_newick_hash{$taxon_newick_string}++;
        }

        printf("rosette, %d, %d, %d, %d",
           $rosette->node_id, scalar(@{$rosette->get_all_leaves}), 
           $cluster->node_id, scalar(@{$member_list}));
        if($rosette->has_tag("rosette_LSDup")) 
          {print(", LSDup");} else{print(", OK");}
        if($rosette->has_tag("rosette_geneLoss")) 
          {print(", GeneLoss");} else{print(", OK");}

        if($rosette->has_tag("rosette_species_topo_match")) 
          {print(", TopoMatch");} 
        elsif($rosette->has_tag("rosette_species_topo_fail")) 
          {print(", TopoFail");} 
        else{print(", -");}

        print(", $taxon_id_string");
        print(",$taxon_newick_string");
        print("\n");

      }
    }
  }
  printf("\n%d clusters analyzed\n", $cluster_count);
  printf("%d ingroup rosettes found\n", $rosette_count);
  printf("   %d rosettes w/o LSD\n", $rosette_count - $lsd_rosette_count);
  printf("   %d rosettes with LSDups\n", $lsd_rosette_count);
  printf("   %d rosettes with geneLoss\n", $geneLoss_rosette_count);
  printf("   %d rosettes no_dups & match species tree\n", $match_species_tree_count);
  printf("%d ingroup members\n", $total_members);
  printf("%d members in hash\n", scalar(keys(%{$self->{'member_LSD_hash'}})));

  foreach my $gdbid (@$species_list) {
    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdbid);
    my $member_id_list = $self->{'gdb_member_hash'}->{$gdbid}; 

    my $lsd_members=0;
    foreach my $member_id (@{$member_id_list}) { 
      $lsd_members++ if($self->{'member_LSD_hash'}->{$member_id});
    }
    my $mem_count = scalar(@$member_id_list);
    printf("%30s(%2d), %7d members, %7d no_dup, %7d LSD,\n", 
       $gdb->name, $gdbid, $mem_count, $mem_count-$lsd_members, $lsd_members);
  }
  
  printf("\nrosette member dists\n");
  print_hash_bins(\%rosette_taxon_hash);
  
  printf("\n\n\nrosette newick dists\n");
  print_hash_bins(\%rosette_newick_hash);
}


sub print_hash_bins
{
  my $hash_ref = shift;
  
  my @bins;
  foreach my $key (keys %$hash_ref) {
    my $bin = {};
    $bin->{'count'} = $hash_ref->{$key};
    $bin->{'name'} = $key; 
    push @bins, $bin;
  }
  @bins = sort {$b->{'count'} <=> $a->{'count'}} @bins; 
  foreach my $bin (@bins) {
    printf("   %7d : %s\n", $bin->{'count'}, $bin->{'name'});
  }
}

sub find_ingroup_ancestor
{
  my $self = shift;
  my $ingroup = shift;
  my $node = shift;
  
  my $ancestor = $node->parent;
  return $node unless($ancestor); #reached root, so all members are 'ingroup'
  
  my $has_outgroup=0;
  foreach my $member (@{$ancestor->get_all_leaves}) {
    if(!($ingroup->{$member->genome_db_id})) {
      $has_outgroup=1;
      last;
    }
  }
  return $node if($has_outgroup);
  return find_ingroup_ancestor($self, $ingroup, $ancestor);
}


sub test_rosette_for_LSD
{
  my $self = shift;
  my $rosette = shift;
  
  my $member_list = $rosette->get_all_leaves;
  my %gdb_hash;
  my $rosette_has_LSD = 0;
  foreach my $member (@{$member_list}) {
    $gdb_hash{$member->genome_db_id} = 0 
      unless(defined($gdb_hash{$member->genome_db_id}));
    $gdb_hash{$member->genome_db_id} += 1;
  }
  foreach my $member (@{$member_list}) {
    my $gdb_has_LSD = $gdb_hash{$member->genome_db_id} - 1;
    $rosette_has_LSD=1 if($gdb_has_LSD > 0);
    $self->{'member_LSD_hash'}->{$member->member_id} = $gdb_has_LSD;
  }
  
  return $rosette_has_LSD;
}


sub test_rosette_for_gene_loss
{
  my $self = shift;
  my $rosette = shift;
  my $species_list = shift;

  my $member_list = $rosette->get_all_leaves;
  my %gdb_hash;
  my $rosette_has_geneLoss = 0;
  foreach my $member (@{$member_list}) {
    $gdb_hash{$member->genome_db_id} = 0 
      unless(defined($gdb_hash{$member->genome_db_id}));
    $gdb_hash{$member->genome_db_id} += 1;
  }

  foreach my $gdb (@{$species_list}) {
    unless($gdb_hash{$gdb}) { $rosette_has_geneLoss=1;}
  }

  return $rosette_has_geneLoss;
}


sub test_rosette_matches_species_tree
{
  my $self = shift;
  my $rosette = shift;

  return 0 unless($rosette);
  return 0 unless($rosette->get_child_count > 0);

  #$rosette->print_tree;

  #copy the rosette and replace the peptide_member leaves with taxon
  #leaves
  $rosette = $rosette->copy;
  my $leaves = $rosette->get_all_leaves;
  foreach my $member (@$leaves) {
    my $gene_taxon = new Bio::EnsEMBL::Compara::NCBITaxon;
    $gene_taxon->ncbi_taxid($member->taxon_id);
    $gene_taxon->distance_to_parent($member->distance_to_parent);
    $member->parent->add_child($gene_taxon);
    $member->disavow_parent;
  }
  #$rosette->print_tree;

  #build real taxon tree from NCBI taxon database
  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $species_tree = undef;
  foreach my $member (@$leaves) {
    my $ncbi_taxon = $taxonDBA->fetch_node_by_taxon_id($member->taxon_id);
    $ncbi_taxon->no_autoload_children;
    $species_tree = $ncbi_taxon->root unless($species_tree);
    $species_tree->merge_node_via_shared_ancestor($ncbi_taxon);
  }
  $species_tree = $species_tree->minimize_tree;
  #$species_tree->print_tree;

  #use set theory to test tree topology
  #foreach internal node of the tree, flatten all the leaves into sets.
  #if two trees have the same topology, then all these internal flattened sets
  #will be present.
  #print("BUILD GENE topology sets\n");
  my $gene_topo_sets = new Bio::EnsEMBL::Compara::NestedSet;
  foreach my $node ($rosette->get_all_subnodes) {
    next if($node->is_leaf);
    my $topo_set = $node->copy->flatten_tree;
    #$topo_set->print_tree;
    $gene_topo_sets->add_child($topo_set);
  }

  #print("BUILD TAXON topology sets\n");
  my $taxon_topo_sets = new Bio::EnsEMBL::Compara::NestedSet;
  foreach my $node ($species_tree->get_all_subnodes) {
    next if($node->is_leaf);
#    my $topo_set = $node->copy->flatten_tree;
    my $topo_set = $node->flatten_tree;
    #$topo_set->print_tree;
    $taxon_topo_sets->add_child($topo_set);
  }

  #printf("TEST TOPOLOGY\n");
  my $topology_matches = 0;
  foreach my $taxon_set (@{$taxon_topo_sets->children}) {
    #$taxon_set->print_tree;
    #print("test\n");
    $topology_matches=0;
    foreach my $gene_set (@{$gene_topo_sets->children}) {
      #$gene_set->print_tree;
      if($taxon_set->equals($gene_set)) {
        #print "  MATCH\n";
        $topology_matches=1;
        $gene_set->disavow_parent;
        last;
      }
    }
    unless($topology_matches) {
      #printf("FAILED to find a match -> topology doesn't match\n");
      last;
    }
  }
  if($topology_matches) {
    #print("TREES MATCH!!!!");
  }

  #cleanup copies

  #printf("\n\n");
  return $topology_matches;
}


###############################
# taxon ordered newick
###############################


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


sub taxon_ordered_newick {
  my $node = shift;
  my $newick = "";

  if($node->get_child_count() > 0) {
    $newick .= "(";

    my @sorted_children = 
      sort {min_taxon_id($a) <=> min_taxon_id($b)} @{$node->children};

    my $first_child=1;
    foreach my $child (@sorted_children) {
      $newick .= "," unless($first_child);
      $newick .= taxon_ordered_newick($child);
      $first_child = 0;
    }
    $newick .= ")";
  }

  $newick .= sprintf("%d", $node->taxon_id) if($node->is_leaf);
  return $newick;
}


#################################################
#
# tree manipulation algorithms
#
#################################################


sub balance_tree
{
  my $self = shift;

  #$self->{'tree'}->print_tree($self->{'scale'});

  my $node = new Bio::EnsEMBL::Compara::NestedSet;
  $node->merge_children($self->{'tree'});
  $node->node_id($self->{'tree'}->node_id);

  # get a link
  my ($link) = @{$node->links};
  $link = Bio::EnsEMBL::Compara::Graph::Algorithms::find_balanced_link($link);
#  print("balanced link is\n    ");
#  $link->print_link;
  my $root = 
    Bio::EnsEMBL::Compara::Graph::Algorithms::root_tree_on_link($link);
  #$root->print_tree($self->{'scale'});

  #remove old root if it has become a redundant internal node
  $node->minimize_node;
  #$root->print_tree($self->{'scale'});

  #move tree back to original root node
  $self->{'tree'}->merge_children($root);
}

# internal purposes
sub _compare_treefam
{
  my $self = shift;
  my ($treefam_entry, $treefam_nhx) = '';
  #my $oneTonebigtrees = 0;
  my $infile = $self->{'_treefam_file'};
  my $outfile = $self->{'_treefam_file'};
  my ($infilebase,$path,$type) = fileparse($infile);
  $outfile .= ".gp.txt";
  my $io = new Bio::Root::IO();my ($tmpfilefh,$tempfile) = $io->tempfile(-dir => "/tmp"); #internal purposes
  #  open OUTFILE, ">$outfile" or die "couldnt open outfile: $!\n" if ($self->{'_orthotree_treefam'});
  print $tmpfilefh "tree_type,tree_id,gpair_link,type,sub_type\n" if ($self->{'_orthotree_treefam'});
  print("load from file ", $infile, "\n") if $self->{'debug'};
  _transfer_input_to_tmp($infile, "/tmp/$infilebase") if $self->{'_farm'};
  open (FH, "/tmp/$infilebase") 
    or die("Could not open treefam_nhx file [/tmp/$infile]") if $self->{'_farm'};
  open (FH, $infile) 
    or die("Could not open treefam_nhx file [$infile]") unless $self->{'_farm'};
  my $cluster_count = 0;
  while(<FH>) {
    $treefam_entry .= $_;
    next unless $treefam_entry =~ /;/;
    my ($treefamid, $treefam_nhx) = split ("\t",$treefam_entry);
    $treefam_entry = '';
    my $tf = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($treefam_nhx);
    $cluster_count++;
    my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
    print STDERR $verbose_string if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
    next unless (defined $tf);
    my %gsid_names;
    my %differ_leaves;
    my (@shared, @differ);
    my ($gt, $gt_node_id);
    my (%treeid_shared, %tf_gt_map, %tf_gt_keepleaves);
    my (@gt_genenames, @tf_genenames, @tf_genename_speciesname);

    # recalling a genetree for each leaf of treefam tree
    my @leaves = @{$tf->get_all_leaves};
    foreach my $leaf (@leaves) {
      my $genename = $leaf->get_tagvalue('G');
      push @tf_genenames, $genename unless (0 == length($genename));
      my $genename_speciesname = $genename . ", " . $leaf->get_tagvalue('S');
      push @tf_genename_speciesname, $genename_speciesname;
    }
    foreach my $leaf (@leaves) {
      my $leaf_name = $leaf->name;
      # treefam uses G NHX tag for genename
      my $genename = $leaf->get_tagvalue('G');
      next if (0==length($genename)); # for weird pseudoleaf tags with no gene name
      $leaf->name($genename);
      # Asking for a genetree given the genename of a treefam tree
      if (fetch_protein_tree_with_gene($self, $genename)) {
        $gt = $self->{'tree'};
        @gt_genenames = ();
        foreach my $leaf (@{$self->{'tree'}->get_all_leaves}) {
          my $description = $leaf->description;
          $description =~ /Gene\:(\S+)/;
          push @gt_genenames, $1;
        }
        $gt_node_id = $self->{'tree'}->node_id;
        $treeid_shared{$self->{'tree'}->node_id} += 1;
        push @shared, $genename;
        $tf_gt_map{$treefamid}{$gt_node_id} = 1;
        ##
        my @isect = my @diff = my @union = ();
        my %count;
        foreach my $e (@tf_genenames, @gt_genenames) { $count{$e}++ }
        foreach my $e (keys %count) {
          push(@union, $e);
          push @{ $count{$e} == 2 ? \@isect : \@diff }, $e;
        }
        ##
        my $to_keep = join(",", @isect);
        $tf_gt_keepleaves{$treefamid}{$gt_node_id} = $to_keep;
        $gsid_names{$gt_node_id}{$leaf_name} = $genename;
      } else {
        $differ_leaves{$leaf_name} = 1;
      }
    }

    unless (defined($gt)) {
      # this treefam tree doesnt overlap any of the genetrees
      $self->{'_tf_nomatch'}{$treefamid} = 1;
      foreach my $id (@tf_genename_speciesname) {
        $self->{'_tf_nomatch_genes'}{$treefamid}{$id} = 1;
      }
    }

    # Do this for every gt that has a match to our tf tree genesx
    foreach my $treeid (keys %{$tf_gt_map{$treefamid}}) {
      my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
      $self->{'tree'} = $treeDBA->fetch_node_by_node_id($treeid);
      $gt = $self->{'tree'};

      my $incomparison_tf = 
        Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($treefam_nhx);
      # Only the shared leaves of the tree are kept. Renamed to gsids
      #$oneTonebigtrees++ if (2000 < scalar(@{$self->{'tree'}->get_all_leaves}));
      next if (2000 < scalar(@{$self->{'tree'}->get_all_leaves})); #avoid huge trees
      foreach my $leaf (@{$self->{'tree'}->get_all_leaves}) {
        # This is to map the genename to the main identifier
        my $description = $leaf->description;
        $description =~ /Gene\:(\S+)/;
        my $desc_gsid = $1;
        $leaf->name($desc_gsid) unless (0 == length($desc_gsid));
      }
      $self->{'keep_leaves'} = $tf_gt_keepleaves{$treefamid}{$treeid};
      keep_leaves($self);
      $self->{_treefam} = 0;
      my %leaf_to_member;
      my %leaf_to_genome_db_id;
      foreach my $leaf (@{$self->{'tree'}->get_all_leaves}) {
        $leaf_to_member{$leaf->name} = $leaf->member_id;
        $leaf_to_genome_db_id{$leaf->name} = $leaf->genome_db_id;
      }
      $self->{_gpresults} = '';
      _run_orthotree($self) if ($self->{'_orthotree_treefam'});

      my $gt_lc = scalar(@{$self->{'tree'}->get_all_leaves}) unless $self->{'_orthotree_treefam'};
      $incomparison_tf->node_id($self->{'tree'}->node_id);
      dumpTreeAsNewick($self, $self->{'tree'}) unless ($self->{'_orthotree_treefam'});

      # stuffing treefam tree into $self->{'tree'} -- caution
      $gt = $self->{'tree'};
      @leaves = @{$incomparison_tf->get_all_leaves};
      foreach my $leaf (@leaves) {
        my $genename = $leaf->get_tagvalue('G');
        next if (0==length($genename)); #for weird pseudoleaf tags with no gene name
        $leaf->name($genename);
      }
      $self->{'tree'} = $incomparison_tf;
      $self->{'keep_leaves'} = $tf_gt_keepleaves{$treefamid}{$treeid};
      # first round
      # With the rooting it should be ok
      my $tf_root = new Bio::EnsEMBL::Compara::NestedSet;
      $tf_root->add_child($tf->root, 0.0);
      keep_leaves($self);
      foreach my $leaf (@{$self->{'tree'}->get_all_leaves}) {
        my $name = $leaf->name;
        bless $leaf, "Bio::EnsEMBL::Compara::AlignedMember";
        $leaf->name($name);
        $leaf->{'_dbID'} = $leaf_to_member{$name};
        $leaf->{'_genome_db_id'} = $leaf_to_genome_db_id{$name};
      }
      $tf = $self->{'tree'};
      $self->{_treefam} = $treefamid;
      _run_orthotree($self) if ($self->{'_orthotree_treefam'});
      print $tmpfilefh $self->{_gpresults}; $self->{_gpresults} = '';
      my $tf_lc = scalar(@{$self->{'tree'}->get_all_leaves});
      # second round may be necessary for cleaning extra anonymous close-to-root leaves in tf
      print STDERR "gt leaves ", $gt_lc,"\n" unless $self->{'_orthotree_treefam'};
      print STDERR "tf leaves ", $tf_lc,"\n" unless $self->{'_orthotree_treefam'};
      dumpTreeAsNewick($self, $self->{'tree'}) unless ($self->{'_orthotree_treefam'});

      #$self->{'tree'} = 0;
      #$self->{'tree'}->release_tree;
    }
    1;
  }
  _delete_input_from_tmp("/tmp/$infilebase") if $self->{'_farm'};
  #print STDERR "bigtrees (2000 limit) with one-one gt-tf = $oneTonebigtrees\n";
  _close_and_transfer($tmpfilefh,$outfile,$tempfile);

  # tf_nomatch results
  my $tf_nomatch_results_string = "";
  foreach my $treefamid (keys %{$self->{'_tf_nomatch'}}) {
    $tf_nomatch_results_string .= sprintf("$treefamid, null\n");
    foreach my $genename (keys %{$self->{'_tf_nomatch_genes'}{$treefamid}}) {
      $tf_nomatch_results_string .= sprintf("$genename\n");
    }
  }
  $outfile = $self->{'_treefam_file'};
  $outfile .= "_tf_nomatch.gp.txt";
  open (TFNOMATCH, ">$outfile") or die "couldnt open outfile: $!\n";
  print TFNOMATCH "$tf_nomatch_results_string";
  close TFNOMATCH;
}


sub _run_orthotree {
  my $self = shift;
  # nasty nasty reblessing hack
  bless $self, "Bio::EnsEMBL::Compara::RunnableDB::OrthoTree";
  $self->{'protein_tree'} = $self->{'tree'};
  if (defined($self->{'_readonly'})) {
    if ($self->{'_readonly'} == 0) {1;}
  } else { $self->{'_readonly'} = 1;  }
  $self->load_species_tree() unless($self->{_treefam}); #load only once
  $self->Bio::EnsEMBL::Compara::RunnableDB::OrthoTree::_treefam_genepairlink_stats;
}


sub test7
{
  my $self = shift;
  
  my $newick ="((1:0.110302,(3:0.104867,2:0.078911):0.265676):0.019461, 14:0.205267);";
  printf("newick string: $newick\n");
  my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
  print "tree_string1: ",$tree->newick_simple_format,"\n";
  $tree->print_tree;

  $tree->print_tree;
  my $node = $tree->find_node_by_name('3');
  $node->print_node;
  $node->disavow_parent;
  $tree->print_tree;
  
  $tree = $tree->minimize_tree;
  $tree->print_tree;
  
  $tree->release_tree;
  exit(1);
}


sub chop_tree
{
  my $self = shift;
  
  $self->{'tree'}->print_tree($self->{'scale'});
  
  my $node = new Bio::EnsEMBL::Compara::NestedSet;
  $node->merge_children($self->{'tree'});

  my ($link) = @{$node->links};
  $link->print_link;
  
  $link = Bio::EnsEMBL::Compara::Graph::Algorithms::find_balanced_link($link);
  my $root = Bio::EnsEMBL::Compara::Graph::Algorithms::root_tree_on_link($link);

  $root->print_tree($self->{'scale'});
  bless $node, "Bio::EnsEMBL::Compara::Graph::Node";
  $node->minimize_node;
  Bio::EnsEMBL::Compara::Graph::Algorithms::parent_graph($root);
  $root->print_tree($self->{'scale'});
  
  $self->{'tree'}->merge_children($root);
  $node->minimize_node;
}

# this is really really only for internal purposes - kitten-killer
sub _close_and_transfer {
  my $tmpfilefh = shift;
  my $outfile = shift;
  my $tmpoutfile = shift;
  close $tmpfilefh;
  unless(system("lsrcp $tmpoutfile ecs2a:$outfile") == 0) {
    warn ("warn lsrcp tempfile, $!\n");
    unless(system("cp $tmpoutfile $outfile") == 0) {
      warn ("warn cp tempfile, $!\n");
    }
  }
  unless(system("rm -f $tmpoutfile") == 0) {
    warn ("error deleting tempfile, $!\n");
  }
}

# this is really really only for internal purposes - kitten-killer
sub _transfer_input_to_tmp {
  my $infile = shift;
  my $tmpinfile = shift;
  unless(system("lsrcp ecs2a:$infile $tmpinfile") == 0) {
    warn ("warn lsrcp tempfile, $!\n");
    unless(system("cp $infile $tmpinfile") == 0) {
      warn ("warn cp tempfile, $!\n");
    }
  }
}

sub _delete_input_from_tmp {
  my $tmpinfile = shift;
  unless(system("rm -f $tmpinfile") == 0) {
    warn ("error deleting tempfile, $!\n");
  }
}

1;
