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

my %compara_conf = ();
$compara_conf{'-user'} = 'ensro';
$compara_conf{'-port'} = 3306;

$self->{'cdna'} = 0;
$self->{'scale'} = 100;
$self->{'align_format'} = 'phylip';

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $url;

GetOptions('help'           => \$help,
           'url=s'          => \$url,
           'h=s'            => \$compara_conf{'-host'},
           'u=s'            => \$compara_conf{'-user'},
           'p=s'            => \$compara_conf{'-pass'},
           'port=s'         => \$compara_conf{'-port'},
           'db=s'           => \$compara_conf{'-dbname'},
           'file=s'         => \$self->{'newick_file'},
           'tree_id=i'      => \$self->{'tree_id'},
           'gene=s'         => \$self->{'gene_stable_id'},
           'reroot=i'       => \$self->{'new_root_id'},
           'align'          => \$self->{'print_align'},
           'cdna'           => \$self->{'cdna'},
           'dump'           => \$self->{'dump'},           
           'align_format=s' => \$self->{'align_format'},
           'scale=f'        => \$self->{'scale'},
           'count'          => \$self->{'counts'},
           'newick'         => \$self->{'print_newick'},
           'print'          => \$self->{'print_tree'},
          );

if ($help) { usage(); }

if($url) {
  $self->{'comparaDBA'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($url, 'compara');
} else {
  eval { $self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf); }
}
unless(defined($self->{'comparaDBA'})) {
  print("couldn't connect to compara database\n\n");
  usage();
} 

if($self->{'tree_id'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'tree'} = $treeDBA->fetch_node_by_node_id($self->{'tree_id'});
} 
elsif ($self->{'gene_stable_id'}) {
  fetch_protein_tree_with_gene($self, $self->{'gene_stable_id'});
} 
elsif ($self->{'newick_file'}) { 
  parse_newick($self); 
}

if($self->{'print_tree'}) {
  $self->{'tree'}->print_tree($self->{'scale'});
  printf("%d proteins\n", scalar(@{$self->{'tree'}->get_all_leaves}));
}

if($self->{'print_newick'}) {
  dumpTreeAsNewick($self);
}

if($self->{'counts'}) {
  printf("%d proteins\n", scalar(@{$self->{'tree'}->get_all_leaves}));
}

if($self->{'print_align'} or $self->{'cdna'}) {
  dumpTreeMultipleAlignment($self);
}


#cleanup memory
if($self->{'tree'}) {
  #print("ABOUT TO MANUALLY release tree\n");
  $self->{'tree'}->release;
  $self->{'tree'} = undef;
  #print("DONE\n");
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
  print "  -align                 : output protein multiple alignment\n";
  print "  -cdna                  : output cdna multiple alignment\n";
  print "  -align_format          : alignment format (see perldoc Bio::AlignIO) (def:phylip)\n";
  print "\n";  
  print "  -print_tree            : print ASCII formated tree\n";
  print "  -scale <num>           : scale factor for printing tree (def: 100)\n";
  print "  -newick                : output tree in newick format\n";
  print "  -reroot <id>           : reroot genetree on node_id\n";
  print "  -dump                  : outputs to autonamed file, not STDOUT\n";
  print "geneTreeTool.pl v1.1\n";
  
  exit(1);  
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

  my $member = $self->{'comparaDBA'}->
               get_MemberAdaptor->
               fetch_by_source_stable_id('ENSEMBLGENE', $gene_stable_id);
  my $aligned_member = $treeDBA->
                       fetch_AlignedMember_by_member_id_root_id(
                          $member->get_longest_peptide_Member->member_id);
  $self->{'tree'} = $aligned_member->root;
}


sub parse_newick {
  my $self = shift;
  
  my $newick = '';
  print("load from file ", $self->{'newick_file'}, "\n");
  open (FH, $self->{'newick_file'}) or throw("Could not open newick file [$self->{'newick_file'}]");
  while(<FH>) {
    $newick .= $_;
  }
  $self->{'tree'} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor->parse_newick_into_tree($newick);
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
  
  warn("missing tree\n") unless($self->{'tree'});
  
  my $tree = $self->{'tree'};

  my $sa = $tree->get_SimpleAlign(-id_type => 'MEMBER', -cdna=>$self->{'cdna'});

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
                                    -interleaved => 1,
                                    -format => $self->{'align_format'},
                                   );
  print $alignIO $sa;

  close OUTSEQ;
}


sub dumpTreeAsNewick 
{
  my $self = shift;
  
  warn("missing tree\n") unless($self->{'tree'});

  my $newick = $self->{'tree'}->newick_simple_format;

  if($self->{'dump'}) {
    my $aln_file = "proteintree_". $self->{'tree'}->node_id;
    $aln_file =~ s/\/\//\//g;  # converts any // in path to /
    $aln_file .= ".newick";
    
    open(OUTSEQ, ">$aln_file")
      or $self->throw("Error opening $aln_file for write");
  } else {
    open OUTSEQ, ">&STDOUT";
  }

  print OUTSEQ "$newick\n";
  close OUTSEQ;
}

