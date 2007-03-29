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
# use Bio::SimpleAlign;
# use Bio::AlignIO;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::NCBITaxon;
use Bio::EnsEMBL::Compara::Graph::Algorithms;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::RunnableDB::OrthoTree;
use Bio::EnsEMBL::Compara::Homology;
use File::Basename;
use Digest::MD5 qw(md5_hex); # duploss_fraction

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
           'species=s'        => \$self->{'_species'},
           'sp1=s'            => \$self->{'_species1'},
           'sp2=s'            => \$self->{'_species2'},
           'v|verbose=s'      => \$self->{'verbose'},
           'analyze|analyse'           => \$self->{'analyze'},
           'analyze_homologies'        => \$self->{'_analyze_homologies'},
           'append_taxon_id'           => \$self->{'append_taxon_id'},
           'test|_orthotree_treefam'   => \$self->{'_orthotree_treefam'},
           '_treefam_file=s'           => \$self->{'_treefam_file'},
           '_readonly|readonly=s'      => \$self->{'_readonly'},
           '_pattern|pattern'          => \$self->{'_pattern'},
           '_list_defs|list_defs=s'    => \$self->{'_list_defs'},
           '_check_mfurc|check_mfurc'  => \$self->{'_check_mfurc'},
           '_topolmis|topolmis=s'      => \$self->{'_topolmis'},
           'duploss=s'                 => \$self->{'_duploss'},
           'gap_contribution=s'        => \$self->{'_gap_contribution'},
           'gap_proportion=s'          => \$self->{'_gap_proportion'},
           'per_residue_g_contribution=s'   => \$self->{'_per_residue_g_contribution'},
           'distances_taxon_level=s'   => \$self->{'_distances_taxon_level'},
           'homologs_and_paf_scores=s' => \$self->{'_homologs_and_paf_scores'},
           'homologs_and_dnaaln=s'     => \$self->{'_homologs_and_dnaaln'},
           'consistency_orthotree_mlss=s'      => \$self->{'_consistency_orthotree_mlss'},
           'consistency_orthotree_member_id=s' => \$self->{'_consistency_orthotree_member_id'},
           'pafs=s'                    => \$self->{'_pafs'},
           'duprates=s'                => \$self->{'_duprates'},
           'duphop=s'                  => \$self->{'_duphop'},
           'dnds_pairs=s'              => \$self->{'_dnds_pairs'},
           'sisrates=s'                => \$self->{'_sisrates'},
           'print_as_species_ids=s'    => \$self->{'_print_as_species_ids'},
           'taxon_name_genes=s'        => \$self->{'_taxon_name_genes'},
           '_badgenes|badgenes'        => \$self->{'_badgenes'},
           '_farm|farm=s'              => \$self->{'_farm'},
           '_modula|modula=s'          => \$self->{'_modula'},
          );

# FIXME - this may break other peoples scripts or assumptions
$self->{'clusterset_id'} ||= 1;

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
      printf("%25s %25s : %s\n", $leaf->name,$gene->stable_id, $desc);
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
if ($self->{'clusterset_id'} && $self->{'_gap_contribution'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  my $species = $self->{_species} || "Homo sapiens";
  _gap_contribution($self,$species) if(defined($self->{'_gap_contribution'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_per_residue_g_contribution'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  my $species = $self->{_species} || "Homo sapiens";
  my $gap_proportion = $self->{_gap_proportion} || 0.5;
  my $modula = $self->{_modula} or throw("need a modula number for dividing the jobs");
  my $farm = $self->{_farm} or throw("need a farm number for dividing the jobs");
  _per_residue_g_contribution($self,$species,$gap_proportion,$modula,$farm) if(defined($self->{'_per_residue_g_contribution'}));

  exit(0);
}


# internal purposes
if ($self->{'clusterset_id'} && $self->{'_distances_taxon_level'}) {
  my $species = $self->{_species} || "Homo sapiens";
  $species =~ s/\_/\ /g;
  _distances_taxon_level($self, $species) if(defined($self->{'_distances_taxon_level'}));

  exit(0);
}


# internal purposes
if ($self->{'clusterset_id'} && $self->{'_duphop'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $species = $self->{_species} || "Homo sapiens";
  $species =~ s/\_/\ /g;
  _duphop($self, $species) if(defined($self->{'_duphop'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_dnds_pairs'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $species1 = $self->{_species1} || "Homo sapiens";
  my $species2 = $self->{_species2} || "Mus musculus";
  $species1 =~ s/\_/\ /g;
  $species2 =~ s/\_/\ /g;
  _dnds_pairs($self, $species1, $species2) if(defined($self->{'_dnds_pairs'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_homologs_and_paf_scores'}) {
  my $species = $self->{_species} || "Homo sapiens";
  $species =~ s/\_/\ /g;
  _homologs_and_paf_scores($self, $species) if(defined($self->{'_homologs_and_paf_scores'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_homologs_and_dnaaln'}) {
  my $species1 = $self->{_species1} || "Homo sapiens";
  my $species2 = $self->{_species2} || "Mus musculus";
  $species1 =~ s/\_/\ /g;
  $species2 =~ s/\_/\ /g;
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _homologs_and_dnaaln($self, $species1, $species2) if(defined($self->{'_homologs_and_dnaaln'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_consistency_orthotree_member_id'} && $self->{'_consistency_orthotree_mlss'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $aligned_member = $treeDBA->
    fetch_AlignedMember_by_member_id_root_id
      (
       $self->{_consistency_orthotree_member_id},
       $self->{'clusterset_id'});
  return 0 unless (defined $aligned_member);
  my $node = $aligned_member->subroot;

  $self->{'tree'} = $treeDBA->fetch_node_by_node_id($node->node_id);
  $node->release_tree;
  _consistency_orthotree($self) if($self->{'_consistency_orthotree_member_id'} && $self->{'_consistency_orthotree_mlss'});

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_pafs'}) {
  my $gdb = $self->{_species} || "22";
  _pafs($self, $gdb) if(defined($self->{'_pafs'}));

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
if ($self->{'clusterset_id'} && $self->{'_print_as_species_ids'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _print_as_species_ids($self) if(defined($self->{'_print_as_species_ids'}));

  exit(0);
}



# internal purposes
if ($self->{'clusterset_id'} && $self->{'_sisrates'}) {
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _get_all_duprates_for_species_tree_sis($self) if(defined($self->{'_sisrates'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_taxon_name_genes'}) {
  _get_all_genes_for_taxon_name($self) if(defined($self->{'_taxon_name_genes'}));

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

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_analyze_homologies'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _analyzeHomologies($self) if(defined($self->{'_analyze_homologies'}));

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
  my $provided_tree = shift;

  my %leaves_names;
  foreach my $name (split(",",$self->{'keep_leaves'})) {
    $leaves_names{$name} = 1;
  }

  print join(" ",keys %leaves_names),"\n" if $self->{'$debug'};
  my $tree = $provided_tree || $self->{'tree'};

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
  unless (defined($provided_tree)) {
    $self->{'tree'} = $tree;
  } else {
    return $tree;
  }
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

  my $sa;

  if ($self->{append_taxon_id}) {
    $sa = $tree->get_SimpleAlign
      (
       -id_type => 'MEMBER',
       -cdna=>$self->{'cdna'},
       -stop2x => 1,
       -append_taxon_id => 1
      );
  } else {
    $sa = $tree->get_SimpleAlign(-id_type => 'STABLE', -UNIQ_SEQ=>1, -cdna=>$self->{'cdna'});
  }
  $sa->set_displayname_flat(1);

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
  my $species_list_as_in_tree = $self->{species_list} 
    || "22,10,21,23,3,14,15,19,11,16,9,13,4,18,5,24,12,7,17";
  my $species_list = [22,10,21,25,3,14,15,28,11,16,26,13,4,27,18,5,24,7,17];
  my @species_list_as_in_tree = split("\,",$species_list_as_in_tree);
  my @query_species = split("\,",$self->{'_topolmis'});
  
  printf("topolmis root_id: %d\n", $self->{'clusterset_id'});
  
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

  #  my $outfile = "topolmis.". $self->{'clusterset_id'} . ".txt";
  my $outfile = "topolmis.". $self->{'clusterset_id'}. "." . "sp." 
    . join (".",@query_species) . ".txt";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE "topo_match,tree_id,node_id,duptag,ottag\n";
  my $cluster_count;
  foreach my $cluster (@{$clusterset->children}) {
    my %member_totals;
    $cluster_count++;
    my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
    print STDERR $verbose_string 
      if ($self->{'verbose'} && ($cluster_count % $self->{'verbose'} == 0));
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
          my $ncbi_taxon = 
            $taxonDBA->fetch_node_by_taxon_id($member->taxon_id);
          $ncbi_taxon->no_autoload_children;
          $species_tree = $ncbi_taxon->root unless($species_tree);
          $species_tree->merge_node_via_shared_ancestor($ncbi_taxon);
        }
        $species_tree = $species_tree->minimize_tree;
        my $topology_matches = _compare_topology($copy, $species_tree);
        my $refetched_cluster = 
          $treeDBA->fetch_node_by_node_id($subnode->node_id);
        my $duptag = 
          $refetched_cluster->find_node_by_node_id($subnode->node_id)->get_tagvalue('Duplication');
        my $ottag = 
          $refetched_cluster->find_node_by_node_id
            ($subnode->node_id)->get_tagvalue('Duplication_alg');
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


sub _get_all_duprates_for_species_tree_sis {
  my $self = shift;
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  my $sql = 
    "SELECT ptt1.node_id, ptt1.value, ptt2.value FROM protein_tree_tag ptt1, protein_tree_tag ptt2 ".
      "WHERE ptt1.tag='taxon_name' AND ptt1.node_id=ptt2.node_id ".
        "AND ptt2.tag='Duplication'";
  my $sth = $self->{comparaDBA}->dbc->prepare($sql);
  $sth->execute();
  my ($node_id, $taxon_name, $duplication);
  my $count;
  while (($node_id, $taxon_name, $duplication) = $sth->fetchrow_array()) {
    my $sql = 
      "SELECT ptt3.value FROM protein_tree_tag ptt1, protein_tree_tag ptt2, protein_tree_tag ptt3 ".
        "WHERE ptt1.node_id=$node_id ".
          "AND ptt1.tag='taxon_name' AND ptt1.node_id=ptt2.node_id ".
            "AND ptt2.tag='Duplication' AND ptt2.node_id=ptt3.node_id ".
              "AND ptt3.tag='species_intersection_score'";
    my $sth = $self->{comparaDBA}->dbc->prepare($sql);
    $sth->execute();
    my $sis = $sth->fetchrow_array() || 0;
    if (0 != $duplication && 0 != $sis) {
      $self->{sisrates}{$taxon_name}{dupcount}++;
    } else {
      $self->{sisrates}{$taxon_name}{spccount}++;
    }
    if (0 != $duplication && 40 <= $sis) {
      $self->{sisrates}{$taxon_name}{dupcount04}++;
    } else {
      $self->{sisrates}{$taxon_name}{spccount04}++;
    }
    if (0 != $duplication && 60 <= $sis) {
      $self->{sisrates}{$taxon_name}{dupcount06}++;
    } else {
      $self->{sisrates}{$taxon_name}{spccount06}++;
    }
    $count++;
    my $verbose_string = sprintf "[%5d nodes done]\n", 
      $count;
    print STDERR $verbose_string 
      if ($self->{'verbose'} &&  ($count % $self->{'verbose'} == 0));
  }

  my $outfile = "sisrates.". $self->{_mydbname} . "." . 
    $self->{'clusterset_id'};
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE "node_subtype,is_leaf,dupcount,passedcount,coef,dupcount04,passedcount04,coef04,dupcount06,passedcount06,coef06\n";
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{taxonDBA} =    $self->{comparaDBA}->get_NCBITaxonAdaptor;
  my $is_leaf;
  foreach my $taxon_name (keys %{$self->{sisrates}}) {
    my $taxon = $self->{taxonDBA}->fetch_node_by_name($taxon_name);
    my $taxon_id = $taxon->taxon_id;
    my $sp_pep_count = $self->{memberDBA}->get_source_taxon_count
      (
       'ENSEMBLGENE',
       $taxon_id);
    my $dupcount = $self->{sisrates}{$taxon_name}{dupcount} || 0;
    my $spccount = $self->{sisrates}{$taxon_name}{spccount} || 0;
    my $dupcount04 = $self->{sisrates}{$taxon_name}{dupcount04} || 0;
    my $spccount04 = $self->{sisrates}{$taxon_name}{spccount04} || 0;
    my $dupcount06 = $self->{sisrates}{$taxon_name}{dupcount06} || 0;
    my $spccount06 = $self->{sisrates}{$taxon_name}{spccount06} || 0;
    my $coef = 1; my $coef04 = 1; my $coef06 = 1;
    if (0 != $sp_pep_count) {
      $coef = $coef04 = $coef06 = $dupcount/$sp_pep_count;
      $is_leaf = 1;
    } else {
      $coef = $dupcount/($dupcount+$spccount) if ($spccount!=0);
      $coef04 = $dupcount04/($dupcount+$spccount04) if ($spccount04!=0);
      $coef06 = $dupcount06/($dupcount+$spccount06) if ($spccount06!=0);
      $is_leaf = 0;
    }
    $taxon_name =~ s/\//\_/g; $taxon_name =~ s/\ /\_/g;
    print OUTFILE "$taxon_name,$is_leaf,$dupcount,$spccount,$coef,$dupcount04,$spccount04,$coef04,$dupcount06,$spccount06,$coef06\n" unless ($is_leaf);
    print OUTFILE "$taxon_name,$is_leaf,$dupcount,$sp_pep_count,$coef,$dupcount,$sp_pep_count,$coef04,$dupcount,$sp_pep_count,$coef06\n" if ($is_leaf);
  }
}

sub _get_all_duprates_for_species_tree
{
  my $self = shift;
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  printf("dbname: %s\n", $self->{'_mydbname'});
  printf("duprates_for_species_tree_root_id: %d\n", $self->{'clusterset_id'});

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

  my $outfile = "duprates.". $self->{_mydbname} . "." . 
    $self->{'clusterset_id'};
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE "node_subtype,dupcount,";
  print OUTFILE "dupcount0.0,dupcount0.1,dupcount0.2,dupcount0.3,";
  print OUTFILE "dupcount0.4,dupcount0.5,dupcount0.6,dupcount0.7,";
  print OUTFILE "dupcount0.8,dupcount0.9,dupcount1.0,";
  print OUTFILE "passedcount,coef,numgenes\n";
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
    my $verbose_string = sprintf "[%5d / %5d trees done]\n", 
      $cluster_count, $totalnum_clusters;
    print STDERR $verbose_string 
      if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    $treeDBA->fetch_subtree_under_node($cluster);

    my $member_list = $cluster->get_all_leaves;
    # Store the duprates for every cluster
    # next if (3000 < scalar(@$member_list));
    $self->_count_dups($cluster);
  }

  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  foreach my $sp_node ($self->{_myspecies_tree}->get_all_subnodes) {
    next if ($sp_node->is_leaf);
    my $sp_node_name = $sp_node->get_tagvalue('name');
    # For internal nodes
    my @taxon_ids = map {$_->taxon_id } @{$sp_node->get_all_leaves};
    # and for leaves
    if (0 == scalar(@taxon_ids)) {
      1;
      $taxon_ids[0] = $sp_node->taxon_id;
    }

    my $pep_totals;
    foreach my $taxon_id (@taxon_ids) {
      my $sp_pep_count = $self->{memberDBA}->get_source_taxon_count
        (
         'ENSEMBLGENE',
         $taxon_id);
      $pep_totals += $sp_pep_count;
      $sp_node->{_peps}{$taxon_id} = $sp_pep_count;
    }
    if (0 == $pep_totals) {
      1;
    }
    $sp_node->add_tag('pep_totals', $pep_totals);
  }
  # Get the list of ENSEMBLPEP for each of the species in a given
  # internal node
  # TODO: do the same but only with homology_members

  foreach my $sp_node ($self->{_myspecies_tree}->get_all_subnodes) {
    my $sp_node_name = $sp_node->get_tagvalue('name');
    my $sp_node_dupcount = $sp_node->get_tagvalue('dupcount') || 0;
    my $sp_node_dupcount00 = $sp_node->get_tagvalue('dupcount0.0') || 0;
    my $sp_node_dupcount01 = $sp_node->get_tagvalue('dupcount0.1') || 0;
    my $sp_node_dupcount02 = $sp_node->get_tagvalue('dupcount0.2') || 0;
    my $sp_node_dupcount03 = $sp_node->get_tagvalue('dupcount0.3') || 0;
    my $sp_node_dupcount04 = $sp_node->get_tagvalue('dupcount0.4') || 0;
    my $sp_node_dupcount05 = $sp_node->get_tagvalue('dupcount0.5') || 0;
    my $sp_node_dupcount06 = $sp_node->get_tagvalue('dupcount0.6') || 0;
    my $sp_node_dupcount07 = $sp_node->get_tagvalue('dupcount0.7') || 0;
    my $sp_node_dupcount08 = $sp_node->get_tagvalue('dupcount0.8') || 0;
    my $sp_node_dupcount09 = $sp_node->get_tagvalue('dupcount0.9') || 0;
    my $sp_node_dupcount10 = $sp_node->get_tagvalue('dupcount1.0') || 0;
    my $sp_node_passedcount = $sp_node->get_tagvalue('passedcount') || 0;
    my $sp_node_pep_totals = $sp_node->get_tagvalue('pep_totals') || 0;
    my $results = 
      $sp_node_name. ",". 
      $sp_node_dupcount. ",". 
      $sp_node_dupcount00. ",". 
      $sp_node_dupcount01. ",". 
      $sp_node_dupcount02. ",". 
      $sp_node_dupcount03. ",". 
      $sp_node_dupcount04. ",". 
      $sp_node_dupcount05. ",". 
      $sp_node_dupcount06. ",". 
      $sp_node_dupcount07. ",". 
      $sp_node_dupcount08. ",". 
      $sp_node_dupcount09. ",". 
      $sp_node_dupcount10. ",". 
      $sp_node_passedcount. ",",
      $sp_node_dupcount/$sp_node_passedcount. ",". 
      $sp_node_pep_totals. 
      "\n";
    print $results;
    print OUTFILE $results;
  }
}
#

sub _get_all_genes_for_taxon_name {
  my $self = shift;

  my $species = $self->{_species};
  my $taxon_name = $self->{_taxon_name_genes};
  print "dups\n" if($self->{verbose});
  my $dup_gene_stable_ids;
  $dup_gene_stable_ids = $self->_get_all_genes_for_taxon_name_dup_tag_hm(1) if (2==$self->{verbose});
  $dup_gene_stable_ids = $self->_get_all_genes_for_taxon_name_dup_tag(1) if (2!=$self->{verbose});
  open DUPS, ">dups_genes_".$species."_for_taxon_name_".$taxon_name.".txt" or die "$!";
  foreach my $gene_stable_id (keys %$dup_gene_stable_ids) {
    if ($gene_stable_id =~ /$species/) {
      print DUPS "$gene_stable_id\n";
    }
  }
  close DUPS;
  print "specs\n" if($self->{verbose});
  my $spc_gene_stable_ids;
  $spc_gene_stable_ids = $self->_get_all_genes_for_taxon_name_dup_tag_hm(0) if (2==$self->{verbose});
  $spc_gene_stable_ids = $self->_get_all_genes_for_taxon_name_dup_tag(0) if (2!=$self->{verbose});
  open SPECS, ">specs_genes_".$species."_for_taxon_name_".$taxon_name.".txt" or die "$!";
  foreach my $gene_stable_id (keys %$spc_gene_stable_ids) {
    if ($gene_stable_id =~ /$species/) {
      print SPECS "$gene_stable_id\n";
    }
  }
  close SPECS;
}

sub _get_all_genes_for_taxon_name_dup_tag {
  my $self = shift;
  my $dup_tag = shift;

  # get all nodes that have the taxon_name tag and have duplications
  # 1 - nodes that have the adequate taxon_name and adequate Duplication tag
  my $sql = 
    "select ptt1.node_id from protein_tree_tag ptt1, protein_tree_tag ptt2 where ptt1.tag='taxon_name' and ptt1.value='" .
      $self->{_taxon_name_genes} 
        . "' and ptt1.node_id=ptt2.node_id and ptt2.tag='Duplication' and ptt2.value";
  $sql .= "=0" if (0 == $dup_tag);
  $sql .= "!=0" if (0 != $dup_tag);
  my $sth = $self->{comparaDBA}->dbc->prepare($sql);
  $sth->execute();
  my $node_id;
  my @nodes;
  my %gene_stable_ids;
  while ($node_id = $sth->fetchrow_array()) {
    # 2 - left and right index of the previous nodes
    my $sql = 
      "select node_id, left_index, right_index from protein_tree_node where node_id=$node_id";
    my $sth = $self->{comparaDBA}->dbc->prepare($sql);
    $sth->execute();
    my ($node_id,$left_index,$right_index);
    while (($node_id,$left_index,$right_index) = $sth->fetchrow_array()) {
      # 3 - all the leaves for those nodes
      my $sql = 
        "select node_id from protein_tree_node where left_index > $left_index and right_index < $right_index and (right_index-left_index)=1";
      my $sth = $self->{comparaDBA}->dbc->prepare($sql);
      $sth->execute();
      my $leaf_node_ids;
      my $leaf_node_id;
      while ($leaf_node_id = $sth->fetchrow_array()) {
        $leaf_node_ids .= $leaf_node_id . ",";
      }
      $leaf_node_ids =~ s/\,$//;
      # 4 - Get only those leaves that actually have the ancestral node_id in homology
      my $sql2 = "SELECT distinct(m1.stable_id) FROM member m1, member m2, protein_tree_member ptm, homology_member hm, homology h WHERE ptm.node_id in ($leaf_node_ids) AND ptm.member_id=m2.member_id AND hm.member_id=m2.gene_member_id AND h.node_id=$node_id AND h.homology_id=hm.homology_id AND m2.gene_member_id=m1.member_id";
      # my $sql = "select m.stable_id from member m, protein_tree_member ptm where ptm.node_id=$leaf_node_id and ptm.member_id=m.member_id";
      my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
      $sth2->execute();
      my $gene_stable_id;
      while ($gene_stable_id = $sth2->fetchrow_array()) {
        $gene_stable_ids{$gene_stable_id} = 1;
      }
      print scalar(keys %gene_stable_ids), " ids\n" if(((scalar( keys %gene_stable_ids)) % 1000 < 25) && $self->{verbose});
    }
  }
  $sth->finish();
  return \%gene_stable_ids;
}

sub _get_all_genes_for_taxon_name_dup_tag_hm {
  my $self = shift;
  my $dup_tag = shift;

  # get all nodes that have the taxon_name tag and have duplications
  # 1 - nodes that have the adequate taxon_name and adequate Duplication tag
  print "query 1/4\n" if $self->{verbose};
  my $sql = 
    "select ptt1.node_id from protein_tree_tag ptt1, protein_tree_tag ptt2 where ptt1.tag='taxon_name' and ptt1.value='" .
      $self->{_taxon_name_genes} 
        . "' and ptt1.node_id=ptt2.node_id and ptt2.tag='Duplication' and ptt2.value";
  $sql .= "=0" if (0 == $dup_tag);
  $sql .= "!=0" if (0 != $dup_tag);
  my $sth = $self->{comparaDBA}->dbc->prepare($sql);
  $sth->execute();
  my $node_id;
  my @nodes;
  my %gene_stable_ids;
  my $in_node_ids;
  while ($node_id = $sth->fetchrow_array()) {
    $in_node_ids .= $node_id . ",";
  }
  $in_node_ids =~ s/\,$//;
  print "query 2/4\n" if $self->{verbose};
  my $sql2 = "SELECT homology_id FROM homology WHERE node_id in ($in_node_ids)";
  my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
  $sth2->execute();
  my $homology_id;
  my $in_homology_ids;
  while ($homology_id = $sth2->fetchrow_array()) {
    $in_homology_ids .= $homology_id . ",";
  }
  $in_homology_ids =~ s/\,$//;
  print "query 3/4\n" if $self->{verbose};
  my $sql3 = "SELECT member_id FROM homology_member WHERE homology_id in ($in_homology_ids)";
  my $sth3 = $self->{comparaDBA}->dbc->prepare($sql3);
  $sth3->execute();
  my $member_id;
  print "query 4/4\n" if $self->{verbose};
  while ($member_id = $sth3->fetchrow_array()) {
    my $sql4 = "SELECT stable_id FROM member WHERE member_id=$member_id";
    my $sth4 = $self->{comparaDBA}->dbc->prepare($sql4);
    $sth4->execute();
    my $gene_stable_id;
    while ($gene_stable_id = $sth4->fetchrow_array()) {
      $gene_stable_ids{$gene_stable_id} = 1;
    }
  }
  $sth->finish();
  return \%gene_stable_ids;
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
    $taxon_name = $node->get_tagvalue('taxon_name'); # this was name instead of taxon_name in v41
    unless (defined($taxon_name)) {
      $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($node->taxon_id);
      $taxon_name = $taxon->name;
    }
    my $taxon_node = $self->{_myspecies_tree}->find_node_by_name($taxon_name);
    my $dups = $node->get_tagvalue('Duplication') || 0;
    my $dupcount = $taxon_node->get_tagvalue('dupcount') || 0;
    if ($dups) {
      my $dup_confidence_score = 
        $node->get_tagvalue('duplication_confidence_score');
      unless ('' eq $dup_confidence_score) {
        $dup_confidence_score = sprintf ("%.1f", $dup_confidence_score);
        my $decr_score = $dup_confidence_score;
        while (0.0 <= $decr_score) {
          $decr_score = sprintf ("%.1f", $decr_score);
          print "  $decr_score\n" if ($self->{debug});
          my $decr_tag = 'dupcount' . $decr_score;
          my $tagcount = $taxon_node->get_tagvalue($decr_tag) || 0;
          $taxon_node->add_tag($decr_tag,($tagcount+1));
          $decr_score = $decr_score - 0.1;
        }
      }
      $taxon_node->add_tag('dupcount',($dupcount+1));
    }
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

  my $outfile = "duploss_fraction.". 
    $self->{_mydbname} . "." . $self->{'clusterset_id'};
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE 
    "tree_id,node_id,parent_id,node_subtype,duploss_fraction,num,denom," . 
    "child_a_avg_dist,child_a_leaves,child_b_avg_dist,child_b_leaves," . 
    "aln_overlap_coef,aln_overlap_prod_coef,repr_stable_id,stable_ids_md5sum\n";

  my $outfile_human = "duploss_fraction_human_heterotachy."
    . $self->{_mydbname} . "." . $self->{'clusterset_id'};
  $outfile_human .= ".csv";
  open OUTFILE_HUMAN, ">$outfile_human" or die "error opening outfile: $!\n";
  print OUTFILE_HUMAN 
    "tree_id,node_id,parent_id,node_subtype,duploss_fraction,num,denom," . 
    "child_a_human_dist,child_a_leaves,child_b_human_dist,child_b_leaves," . 
    "child_a_human_stable_id,child_b_human_stable_id,stable_ids_md5sum\n";

  my $cluster_count;
  my @clusters = @{$clusterset->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);
  foreach my $cluster (@clusters) {
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    my %member_totals;
    $cluster_count++;
    my $verbose_string = sprintf "[%5d / %5d trees done]\n", 
      $cluster_count, $totalnum_clusters;
    print STDERR $verbose_string 
      if ($self->{'verbose'} && ($cluster_count % $self->{'verbose'} == 0));
    #$treeDBA->fetch_subtree_under_node($cluster);

    my $member_list = $cluster->get_all_leaves;
    my %member_gdbs;

    foreach my $member (@{$member_list}) {
      $member_gdbs{$member->genome_db_id} = 1;
      $member_totals{$member->genome_db_id}++;
    }
    my @genetree_species = keys %member_gdbs;
    # Do we want 1-species trees?
    $cluster->{duploss_number_of_species} = scalar(@genetree_species);
    # For each internal node in the tree
    # no intersection of sps btw both child
    _duploss_fraction($cluster);
  }
}


# internal purposes
sub _duploss_fraction {
  my $cluster = shift;
  my $taxon_id = $cluster->get_tagvalue('taxon_id') || 0;
  my ($child_a, $child_b, $dummy) = @{$cluster->children};
  warn "multifurcated tree! check code!\n" if (defined($dummy));
  print STDERR "multifurcated tree - ", $cluster->node_id, "\n" 
    if (defined($dummy));
  # Look at the childs
  my $child_a_dups = _count_dups_in_subtree($child_a);
  my $child_b_dups = _count_dups_in_subtree($child_b);
  # Look at the node
  my $dups = $cluster->get_tagvalue('Duplication') || 0;

  # Only look at duplications
  return 0 if (0 == $dups && 0 == $child_a_dups && 0 == $child_b_dups);

  # Representative gene name
  my @child_a_leaves = @{$child_a->get_all_leaves};
  my @child_b_leaves = @{$child_b->get_all_leaves};

  my @taxon_a_tmp = map {$_->taxon_id} @child_a_leaves;
  my %taxon_a_tmp;
  foreach my $taxon_tmp (@taxon_a_tmp) {$taxon_a_tmp{$taxon_tmp}=1;}
  $child_a->{duploss_number_of_species} = scalar(keys %taxon_a_tmp);
  my @taxon_b_tmp = map {$_->taxon_id} @child_b_leaves;
  my %taxon_b_tmp;
  foreach my $taxon_tmp (@taxon_b_tmp) {$taxon_b_tmp{$taxon_tmp}=1;}
  $child_b->{duploss_number_of_species} = scalar(keys %taxon_b_tmp);

  my $using_genes = 0;
  my @child_a_stable_ids; my @child_b_stable_ids;
  @child_a_stable_ids = map {$_->stable_id} @child_a_leaves;
  @child_b_stable_ids = map {$_->stable_id} @child_b_leaves;
  my $stable_ids_pattern = '';
  my $r_chosen = 0;
  my %child_a_stable_ids; my %child_b_stable_ids;
  foreach my $stable_id (@child_a_stable_ids) {
    $child_a_stable_ids{$stable_id} = 1; }
  foreach my $stable_id (@child_b_stable_ids) {
    $child_b_stable_ids{$stable_id} = 1; }
  foreach my $stable_id (sort(@child_a_stable_ids,@child_b_stable_ids)) {
    $stable_ids_pattern .= "$stable_id"."#";
    # FIXME - put in a generic function
    if (0 == $r_chosen) {
      if ($stable_id =~ /^ENSP0/)       { $r_chosen = 1; }
      elsif ($stable_id =~ /^ENSMUSP0/) { $r_chosen = 1; }
      elsif ($stable_id =~ /^ENSDARP0/) { $r_chosen = 1; }
      elsif ($stable_id =~ /^ENSCINP0/) { $r_chosen = 1; }
      else { $r_chosen = 0; }
      $cluster->{_repr_stable_id} = $stable_id if (1 == $r_chosen);
    }
  }
  unless(defined($cluster->{_repr_stable_id})) {
    $cluster->{_repr_stable_id} = $child_a_stable_ids[0];
  }
  # Generate a md5sum string to compare among databases
  $cluster->{_stable_ids_md5sum} = md5_hex($stable_ids_pattern);

  ##########
  my %seen = ();  my @gdb_a = grep { ! $seen{$_} ++ } @taxon_a_tmp;
     %seen = ();  my @gdb_b = grep { ! $seen{$_} ++ } @taxon_b_tmp;
  my @isect = my @diff = my @union = (); my %count;
  foreach my $e (@gdb_a, @gdb_b) { $count{$e}++ }
  foreach my $e (keys %count) 
    { push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e; }
  my %isect;
  foreach my $elem (@isect) {$isect{$elem} = 1;}
  ##########

  if (0 == $taxon_id) {
    my $root_id = $cluster->node_id;
    warn "no taxon_id found for this cluster's root: $root_id\n";
  }
  my $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($taxon_id);
  my $taxon_name = $taxon->name;
  my $scalar_isect = scalar(@isect); my $scalar_union = scalar(@union);
  my $duploss_frac = $scalar_isect/$scalar_union;
  # we want to check for dupl nodes only
  unless (0 == $dups) {
    $taxon_name =~ s/\//\_/g; $taxon_name =~ s/\ /\_/g;
    # Heterotachy
    my $child_a_avg_dist; my $child_b_avg_dist;
    foreach my $leaf (@child_a_leaves) {
      $child_a_avg_dist += $leaf->distance_to_ancestor($child_a);
    }
    foreach my $leaf (@child_b_leaves) {
      $child_b_avg_dist += $leaf->distance_to_ancestor($child_b);
    }
    $cluster->add_tag
      ('child_a_avg_dist', ($child_a_avg_dist/scalar(@child_a_leaves)));
    $cluster->add_tag
      ('child_a_leaves', (scalar(@child_a_leaves)));
    $cluster->add_tag
      ('child_b_avg_dist', ($child_b_avg_dist/scalar(@child_b_leaves)));
    $cluster->add_tag
      ('child_b_leaves', (scalar(@child_b_leaves)));

    # We get the msa from the cluster, but then remove_seq to convert
    # to child_a and child_b respectively
    my $parent_aln = $cluster->get_SimpleAlign
      (
       -id_type => 'STABLE',
       -cdna => 0,
       -stop2x => 1
      );
    my $ungapped; my $ungapped_len;
    # FIXME: this depends on the latest SimpleAlign.pm
    eval { $ungapped = $parent_aln->remove_gaps; };
      if ($@) { $ungapped_len = 0; } else {
        $ungapped_len = $ungapped->length;
      }
    my $total_len = $parent_aln->length;
    my $parent_aln_gap_coef = $ungapped_len/$total_len;
    $cluster->add_tag('parent_aln_gap_coef',$parent_aln_gap_coef);

    # Purge seqs not in child_a (i.e. in child_b)
    my $child_a_aln = $cluster->get_SimpleAlign
      (
       -id_type => 'STABLE',
       -cdna => 0,
       -stop2x => 1
      );
    my $child_a_aln_gap_coef;
    if (2 <= scalar(keys %child_a_stable_ids)) {
      foreach my $seq ($child_a_aln->each_seq) {
        my $display_id = $seq->display_id;
        $child_a_aln->remove_seq($seq) 
          unless (defined($child_a_stable_ids{$display_id}));
      }
      # FIXME: this depends on the latest SimpleAlign.pm
      eval { $ungapped = $child_a_aln->remove_gaps; };
        if ($@) { $ungapped_len = 0; } else {
          $ungapped_len = $ungapped->length;
        }
      $total_len = $child_a_aln->length;
      $child_a_aln_gap_coef = $ungapped_len/$total_len;
    } else {
      my @key = keys %child_a_stable_ids;
      my @seq = $child_a_aln->each_seq_with_id($key[0]);
      $child_a_aln_gap_coef = 
        ((($seq[0]->length)-($seq[0]->no_gaps))/$seq[0]->length);
    }
    $cluster->add_tag('child_a_aln_gap_coef',$child_a_aln_gap_coef);

    # Purge seqs not in child_b (i.e. in child_a)
    my $child_b_aln = $cluster->get_SimpleAlign
      (
       -id_type => 'STABLE',
       -cdna => 0,
       -stop2x => 1
      );
    my $child_b_aln_gap_coef;
    if (2 <= scalar(keys %child_b_stable_ids)) {
      foreach my $seq ($child_b_aln->each_seq) {
        my $display_id = $seq->display_id;
        $child_b_aln->remove_seq($seq) 
          unless (defined($child_b_stable_ids{$display_id}));
      }
      # FIXME: this depends on the latest SimpleAlign.pm
      eval { $ungapped = $child_b_aln->remove_gaps; };
        if ($@) { $ungapped_len = 0; } else {
          $ungapped_len = $ungapped->length;
        }
      $total_len = $child_b_aln->length;
      $child_b_aln_gap_coef = $ungapped_len/$total_len;
    } else {
      my @key = keys %child_b_stable_ids;
      my @seq = $child_b_aln->each_seq_with_id($key[0]);
      $child_b_aln_gap_coef = 
        ((($seq[0]->length)-($seq[0]->no_gaps))/$seq[0]->length);
    }
    $cluster->add_tag('child_b_aln_gap_coef',$child_b_aln_gap_coef);

    # human - human heterotachy --- taxon_id = 9606
    my $human_taxon_id = "9606";
    if (defined($isect{$human_taxon_id})) {
      foreach my $leaf (@child_a_leaves) {
        if ($leaf->taxon_id eq $human_taxon_id) {
          my $human_dist = $leaf->distance_to_ancestor($child_a);
          $cluster->add_tag('child_a_human_stable_id', $leaf->stable_id);
          $cluster->add_tag('child_a_human_dist', $human_dist);
        }
      }
      foreach my $leaf (@child_b_leaves) {
        if ($leaf->taxon_id eq $human_taxon_id) {
          my $human_dist = $leaf->distance_to_ancestor($child_b);
          $cluster->add_tag('child_b_human_stable_id', $leaf->stable_id);
          $cluster->add_tag('child_b_human_dist', $human_dist);
        }
      }
      my $results_human = 
        $cluster->subroot->node_id . 
          "," . 
        $cluster->node_id . 
          "," . 
        $cluster->parent->node_id . 
          "," . 
        $taxon_name . 
          "," . 
        $duploss_frac . 
         "," . 
        $scalar_isect . 
         "," . 
        $scalar_union . 
         "," . 
        $cluster->get_tagvalue('child_a_human_dist') . 
         "," . 
        $cluster->get_tagvalue('child_a_leaves') . 
         "," . 
        $cluster->get_tagvalue('child_b_human_dist') . 
         "," . 
        $cluster->get_tagvalue('child_b_leaves') . 
         "," . 
        $cluster->get_tagvalue('child_a_human_stable_id') . 
        "," . 
        $cluster->get_tagvalue('child_b_human_stable_id') . 
        "," . 
        $cluster->{_stable_ids_md5sum} . 
        "\n";
      print OUTFILE_HUMAN $results_human;
    }
    # we dont want leaf-level 1/1 within_species_paralogs
    my $number_of_species = $cluster->{duploss_number_of_species};
    if (1 < $number_of_species) {
      unless (1 == $scalar_isect && 1 == $scalar_union) {
        my $aln_overlap_coef;
        eval {$aln_overlap_coef = 
          ($cluster->get_tagvalue('parent_aln_gap_coef')/
           ($cluster->get_tagvalue('child_a_aln_gap_coef')+
            $cluster->get_tagvalue('child_b_aln_gap_coef')/2));};
        $aln_overlap_coef = 0 if ($@);
        $aln_overlap_coef = -1 
          if ($@ && 0 < $cluster->get_tagvalue('parent_aln_gap_coef'));
        my $aln_overlap_prod_coef = 
          (($cluster->get_tagvalue('parent_aln_gap_coef'))*
           (
           ($cluster->get_tagvalue('child_a_aln_gap_coef')+
            $cluster->get_tagvalue('child_b_aln_gap_coef')/2)
           ));
        my $results = 
          $cluster->subroot->node_id . 
            "," . 
          $cluster->node_id . 
            "," . 
          $cluster->parent->node_id . 
            "," . 
          $taxon_name . 
            "," . 
          $duploss_frac . 
           "," . 
          $scalar_isect . 
           "," . 
          $scalar_union . 
           "," . 
          $cluster->get_tagvalue('child_a_avg_dist') . 
           "," . 
          $cluster->get_tagvalue('child_a_leaves') . 
           "," . 
          $cluster->get_tagvalue('child_b_avg_dist') . 
           "," . 
          $cluster->get_tagvalue('child_b_leaves') . 
           "," . 
          $aln_overlap_coef . 
           "," . 
          $aln_overlap_prod_coef . 
           "," . 
          $cluster->{_repr_stable_id} . 
          "," . 
          $cluster->{_stable_ids_md5sum} . 
          "\n";
        print OUTFILE $results;
        print $results if ($self->{debug});
      }
    }
  }

  # Recurse
  _duploss_fraction($child_a) if (0 < $child_a_dups);
  _duploss_fraction($child_b) if (0 < $child_b_dups);
}

sub _dnds_pairs {
  my $self = shift;
  my $species1 = shift;
  my $species2 = shift;

  $species1 =~ s/\_/\ /g;
  $species2 =~ s/\_/\ /g;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
  my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
  my $sp1_short_name = $sp1_gdb->get_short_name;
  my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
  my $sp2_short_name = $sp2_gdb->get_short_name;
  my $sp1_pair_short_name_list = 
    join ("_", sort ($sp2_short_name,$sp2_short_name));
  my $sp2_pair_short_name_list = 
    join ("_", sort ($sp2_short_name,$sp2_short_name));

  my @clusters = @{$self->{'clusterset'}->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  my $outfile = "dnds_pairs.". $sp1_short_name ."." . $sp2_short_name ."." . 
    $self->{_mydbname} . "." . $self->{'clusterset_id'};
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE 
    "tree_id,subtree_id,root_taxon,peptide1_stable_id,gene1_stable_id,sp1_name,peptide2_stable_id,gene2_stable_id,sp2_name,dn,ds,lnl\n";
  foreach my $cluster (@clusters) {
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    # next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
    my %member;
    my %species;
    my %species1_is_present;
    my %species2_is_present;
    my $member_copy;
    foreach my $member (@{$cluster->get_all_leaves}) {
      my $member_species_short_name = $member->genome_db->get_short_name;
      my $member_stable_id = $member->stable_id;
      $member{$member_stable_id}{gdb_short_name} = $member_species_short_name;
      $member{$member_stable_id}{gene_stable_id} = $member->gene_member->stable_id;
      if ($sp1_short_name eq $member_species_short_name) {
        $species1_is_present{$member_stable_id} = 1;
      } elsif ($sp2_short_name eq $member_species_short_name) {
        $species2_is_present{$member_stable_id} = 1;
      }
      if (2 == scalar(keys(%species1_is_present)) && 2 == scalar(keys(%species2_is_present))) {
        $member_copy = $member;
        last;
      }
    }
    my $tetrad_node;
    if (2 == scalar(keys(%species1_is_present)) && 2 == scalar(keys(%species2_is_present))) {
      $tetrad_node = $member_copy->parent; # should never fail
      my $found_pair1 = 0;
      my $found_pair2 = 0;
      do {
        eval { $tetrad_node = $tetrad_node->parent;} ;
        last if ($@);
        my $this_cluster_short_name_sps_list = join ("_", sort map { $_->genome_db->get_short_name } @{$tetrad_node->get_all_leaves});
        $found_pair1 = 1 if ($this_cluster_short_name_sps_list =~ /$sp1_pair_short_name_list/);
        $found_pair2 = 1 if ($this_cluster_short_name_sps_list =~ /$sp2_pair_short_name_list/);
      } while (1 != $found_pair1 || 1!= $found_pair2);
      if (1 == $found_pair1 && 1 == $found_pair2) {
        $self->{'keep_leaves'} = (join ",", (keys %species2_is_present, keys %species1_is_present));
        my $tetrad_minimized_tree = $self->keep_leaves($tetrad_node);
        my @leaves = @{$tetrad_minimized_tree->get_all_leaves};
        my $results = '';
        my $tree_id = $cluster->node_id;
        my $subtree_id = $tetrad_minimized_tree->node_id;
        foreach my $leaf1 (shift @leaves) {
          foreach my $leaf2 (@leaves) {
            next if ($leaf1->genome_db_id == $leaf2->genome_db_id);
            my $leaf1_gene_member = $leaf1->gene_member;
            my $leaf2_gene_member = $leaf2->gene_member;
            my @homologies = @{$self->{ha}->fetch_by_Member_Member_method_link_type
                                 ($leaf1_gene_member, $leaf2_gene_member, 'ENSEMBL_ORTHOLOGUES')};
            push @homologies, @{$self->{ha}->fetch_by_Member_Member_method_link_type
                                  ($leaf1_gene_member, $leaf2_gene_member, 'ENSEMBL_PARALOGUES')};
            foreach my $homology (@homologies) {
              my $dn = $homology->dn;
              my $ds = $homology->ds;
              my $lnl = $homology->lnl;
              if (defined($dn) && defined($ds) && defined($lnl)) {
                my $peptide1_stable_id = $leaf1->stable_id;
                my $peptide2_stable_id = $leaf2->stable_id;
                my $gene1_stable_id = $leaf1_gene_member->stable_id;
                my $gene2_stable_id = $leaf2_gene_member->stable_id;
                my $taxonomy_level = $homology->subtype;
                print OUTFILE "$tree_id,$subtree_id,$taxonomy_level,", 
                  "$peptide1_stable_id,$gene1_stable_id,$sp1_short_name,",
                    "$peptide2_stable_id,$gene2_stable_id,$sp2_short_name,",
                      "$dn,$ds,$lnl\n";
                print "$tree_id,$subtree_id,$taxonomy_level,", 
                  "$peptide1_stable_id,$gene1_stable_id,$sp1_short_name,",
                    "$peptide2_stable_id,$gene2_stable_id,$sp2_short_name,",
                      "$dn,$ds,$lnl\n" if ($self->{verbose});
              }
            }
          }
        }
      }
    }
  }
}

sub _duphop {
  my $self = shift;
  my $species = shift;

  $species =~ s/\_/\ /g;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
  my $sp_short_name = $sp_gdb->get_short_name;

  my @clusters = @{$self->{'clusterset'}->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  my $outfile = "duphop.". $sp_short_name ."." . 
    $self->{_mydbname} . "." . $self->{'clusterset_id'};
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE 
    "tree_id,root_taxon,peptide_stable_id,gene_stable_id,sp_name,duphop,totalhop,consecdup\n";
  print "tree_id,peptide_stable_id,gene_stable_id,sp_name,duphop,totalhop\n" if ($self->{verbose});
  foreach my $cluster (@clusters) {
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    # next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
    my %member;
    my %species;
    my $species_is_present = 0;
    foreach my $member (@{$cluster->get_all_leaves}) {
      my $member_species_short_name = $member->genome_db->get_short_name;
      my $member_stable_id = $member->stable_id;
      $member{$member_stable_id}{gdb_short_name} = $member_species_short_name;
      $member{$member_stable_id}{gene_stable_id} = $member->gene_member->stable_id;
      if($sp_short_name eq $member_species_short_name) {
        $species_is_present = 1;
        my $duphop = 0;
        my $totalhop = 0;
        my $consecutive_duphops = 0;
        my $max_consecdups = 0;
        my $parent = $member;
        do {
          $parent = $parent->parent;
          my $duplication = $parent->get_tagvalue("Duplication");
          if (1 == $duplication || 2 == $duplication) {
            $duphop++;
            $consecutive_duphops++;
          } else {
            $max_consecdups = $consecutive_duphops if ($consecutive_duphops > $max_consecdups);
            $consecutive_duphops = 0;
          }
          $totalhop++;
          $member{$member_stable_id}{duphop} = $duphop;
          $member{$member_stable_id}{totalhop} = $totalhop;
        } while ($parent->parent->node_id != $self->{'clusterset_id'});
        my $root_taxon = $cluster->get_tagvalue("taxon_name");
        $root_taxon =~ s/\//\_/g;$root_taxon =~ s/\ /\_/g;
        my $results = $cluster->node_id . 
          "," . 
            $root_taxon . 
              "," . 
                $member_stable_id . 
                  "," . 
                    $member{$member_stable_id}{gene_stable_id} . 
                      "," . 
                        $member{$member_stable_id}{gdb_short_name} . 
                          "," . 
                            $member{$member_stable_id}{duphop} . 
                              "," . 
                                $member{$member_stable_id}{totalhop} . 
                                  "," . 
                                    $max_consecdups;
        $duphop = 0;
        $totalhop = 0;
        print OUTFILE "$results\n";
        print "$results\n" if ($self->{verbose});
      }
    }
  }
}

# internal purposes
sub _gap_contribution {
  my $self = shift;
  my $species = shift;

  $species =~ s/\_/\ /g;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
  my $sp_short_name = $sp_gdb->get_short_name;

  my @clusters = @{$self->{'clusterset'}->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  my $outfile = "gap_contribution.". $sp_short_name ."." . 
    $self->{_mydbname} . "." . $self->{'clusterset_id'};
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE 
    "tree_id,peptide_stable_id,gene_stable_id,genome_db_id,gap_contribution,total_length\n";
  foreach my $cluster (@clusters) {
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    next if ('2' eq $cluster->get_tagvalue('gene_count'));
    next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
    my %member;
    my $species_is_present = 0;
    foreach my $member (@{$cluster->get_all_leaves}) {
      my $member_species_short_name = $member->genome_db->get_short_name;
      $member{$member->stable_id}{gdb_short_name} = $member_species_short_name;
      $member{$member->stable_id}{gene_stable_id} = $member->gene_member->stable_id;
      $species_is_present = 1 if($sp_short_name eq $member_species_short_name);
    }
    next unless (1 == $species_is_present);
    my $dummy_aln = $cluster->get_SimpleAlign
      (
       -id_type => 'STABLE',
       -cdna => 0,
       -stop2x => 1
      );

    # Purge seqs one by one
    my $before_length; my $after_length;
    foreach my $dummy_seq ($dummy_aln->each_seq) {
      next unless ($member{$dummy_seq->display_id}{gdb_short_name} eq $sp_short_name);
      my $aln = $cluster->get_SimpleAlign
        (
         -id_type => 'STABLE',
         -cdna => 0,
         -stop2x => 1
        );
      my %seqs;
      foreach my $seq ($aln->each_seq) {
        $seqs{$seq->display_id} = $seq;
      }
      $before_length = $aln->length;
      $aln->remove_seq($seqs{$dummy_seq->display_id});
      $aln = $aln->remove_gaps('', 1);
      $after_length = $aln->length;
      my $display_id = $dummy_seq->display_id;
      my $simple_seq_gap_contrib = 1 - ($after_length/$before_length);
      my $results = 
        $cluster->subroot->node_id . 
          "," . 
            $display_id . 
              "," . 
                $member{$dummy_seq->display_id}{gene_stable_id} . 
                  "," . 
                    $member{$dummy_seq->display_id}{gdb_short_name} . 
                          "," . 
                            sprintf("%03f",$simple_seq_gap_contrib) . 
                              "," . 
                                $before_length . 
                                  "\n";
      print OUTFILE $results;
      print $results if ($self->{verbose});
    }
    1;
  }
}

# internal purposes
sub _per_residue_g_contribution {
  my $self = shift;
  my $species = shift;
  my $gap_proportion = shift;
  my $modula = shift;
  my $farm = shift;

  $species =~ s/\_/\ /g;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
  my $sp_short_name = $sp_gdb->get_short_name;

  my @clusters = @{$self->{'clusterset'}->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  my $pmodula = sprintf("%04d",$modula);
  my $outfile = "rgap_contribution." . $sp_short_name . "." . $pmodula . ".". 
    $self->{_mydbname} . "." . $self->{'clusterset_id'};
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE 
    "tree_id,peptide_stable_id,gene_stable_id,sp_name,aln_rgap_contribution,rgap_contribution,total_length\n";
  my $tree_id;
  foreach my $cluster (@clusters) {
    $tree_id = $cluster->subroot->node_id;
    next unless ($tree_id % $farm == ($modula-1)); # this divides the jobs by tree_id
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    next if ('2' eq $cluster->get_tagvalue('gene_count'));
    next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
    next if ();
    my %member;
    my $species_is_present = 0;
    foreach my $member (@{$cluster->get_all_leaves}) {
      my $member_species_short_name = $member->genome_db->get_short_name;
      $member{$member->stable_id}{gdb_short_name} = $member_species_short_name;
      $member{$member->stable_id}{gene_stable_id} = $member->gene_member->stable_id;
      $species_is_present = 1 if($sp_short_name eq $member_species_short_name);
    }
    next unless (1 == $species_is_present);

    my $dummy_aln = $cluster->get_SimpleAlign
      (
       -id_type => 'STABLE',
       -cdna => 0,
       -stop2x => 1
      );
    # Purge seqs one by one
    my $before_length; my $after_length;
    foreach my $dummy_seq ($dummy_aln->each_seq) {
      next unless ($member{$dummy_seq->display_id}{gdb_short_name} eq $sp_short_name);
      my $aln = $cluster->get_SimpleAlign
        (
         -id_type => 'STABLE',
         -cdna => 0,
         -stop2x => 1
        );
      my %seqs;
      foreach my $seq ($aln->each_seq) {
        $seqs{$seq->display_id} = $seq;
      }

      my $display_id = $dummy_seq->display_id;
      my $seq_string = $dummy_seq->seq;
      $seq_string =~ s/\-//g;
      my $gap_count = 0;
      my $aln_no_sequences = $aln->no_sequences;
      my $aln_no_residues = $aln->no_residues;
      $aln->verbose(-1);
      for my $seq_coord (1..length($seq_string)) {
        my $aln_coord = $aln->column_from_residue_number($display_id, $seq_coord);
        my $column_aln = $aln->slice($aln_coord,$aln_coord);
        my $column_no_gaps = $aln_no_sequences - $column_aln->no_residues;
        my $column_aln_no_residues = $column_aln->no_residues;
        my $residue_proportion = $column_aln_no_residues/$aln_no_sequences if (0 != $column_aln_no_residues);
        $residue_proportion = 0 if (0 == $column_aln_no_residues);
        if ($gap_proportion < (1-$residue_proportion)) {
          $gap_count += $column_no_gaps;
        }
      }
      my $aln_length = $aln->length;
      my $per_residue_aln_gap_contrib = $gap_count/(($aln_length)*$aln_no_sequences) if (0 != $gap_count);
      $per_residue_aln_gap_contrib = 0 if (0 == $gap_count);
      my $per_residue_gap_contrib = $gap_count/(($aln_length*$aln_no_sequences)-$aln_no_residues) if (0 != $gap_count);
      $per_residue_gap_contrib = 0 if (0 == $gap_count);
      my $results = 
        $tree_id .
          "," . 
            $display_id . 
              "," . 
                $member{$dummy_seq->display_id}{gene_stable_id} . 
                  "," . 
                    $member{$dummy_seq->display_id}{gdb_short_name} . 
                          "," . 
                            sprintf("%03f",$per_residue_aln_gap_contrib) . 
                              "," . 
                            sprintf("%03f",$per_residue_gap_contrib) . 
                              "," . 
                                $aln_length . 
                                  "\n";
      print OUTFILE $results;
      print $results if ($self->{verbose});
    }
    1;
  }
}


# internal purposes
sub _count_dups_in_subtree {
  my $node = shift;

  my (@duptags) = 
    map {$_->get_tagvalue('Duplication')} $node->get_all_subnodes;
  my $duptags = 0; 
  foreach my $duptag (@duptags) { $duptags++ if (0 != $duptag); }

  return $duptags;
}

# internal purposes
sub _distances_taxon_level {
  my $self = shift;
  my $species = shift;
  $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
  $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;

  my $sp_db = $self->{gdba}->fetch_by_name_assembly($species);
  my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs("ENSEMBL_PARALOGUES",[$sp_db]);
  my $homologies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss);
  print "root_tree_id,peptide_a,distance_a,peptide_b,distance_b,taxonomy_level\n";
  foreach my $homology (@{$homologies}) {
    my $hom_subtype = $homology->description;
    next unless ($hom_subtype =~ /^within_species_paralog/);
    my @two_ids = map { $_->get_longest_peptide_Member->member_id } @{$homology->gene_list};
    my $leaf_node_id = $homology->node_id;
    my $tree = $self->{treeDBA}->fetch_node_by_node_id($leaf_node_id);
    my $node_a = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($two_ids[0],$self->{'clusterset_id'});
    my $node_b = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($two_ids[1],$self->{'clusterset_id'});
    my $root = $node_a->subroot;
    $root->merge_node_via_shared_ancestor($node_b);
    my $ancestor = $node_a->find_first_shared_ancestor($node_b);
    my $distance_a = $node_a->distance_to_ancestor($ancestor);
    my $distance_b = $node_b->distance_to_ancestor($ancestor);
    my $sorted_node_id_a = $node_a->stable_id;
    my $sorted_node_id_b = $node_b->stable_id;
    if ($distance_b < $distance_a) {
      $distance_a = $distance_b;
      my $temp;
      $temp = $sorted_node_id_a;
      $sorted_node_id_a = $sorted_node_id_b;
      $sorted_node_id_b = $temp;
    }
    my $subtype = $homology->subtype;
    $subtype =~ s/\///g; $subtype =~ s/\ /\_/g;
    print $root->node_id, ",$sorted_node_id_a,$distance_a,$sorted_node_id_b,$distance_b,", $subtype, "\n";
    $root->release_tree;
  }
}

sub _consistency_orthotree {
  my $self = shift;
  $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $self->{mlssa}->fetch_by_dbID($self->{_consistency_orthotree_mlss});
  my @species_set_ids = map {$_->dbID} @{$mlss->species_set};
  foreach my $leaf (@{$self->{tree}->get_all_leaves}) {
    next unless ($leaf->genome_db->dbID == $species_set_ids[0] || $leaf->genome_db->dbID == $species_set_ids[1]);
    my $leaf_name = $leaf->name;
    $self->{'keep_leaves'} .= $leaf_name . ",";
  }
  $self->{keep_leaves} =~ s/\,$//;
  keep_leaves($self);
  $self->{tree}->print_tree(20) if ($self->{debug});
  _run_orthotree($self);
  1; #??
}

sub _homologs_and_dnaaln {
  my $self = shift;
  my $species1 = shift;
  my $species2 = shift;

  $species1 =~ s/\_/\ /g;
  $species2 =~ s/\_/\ /g;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
  my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
  my $sp1_short_name = $sp1_gdb->get_short_name;
  my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
  my $sp2_short_name = $sp2_gdb->get_short_name;
  my $sp1_pair_short_name_list = 
    join ("_", sort ($sp2_short_name,$sp2_short_name));
  my $sp2_pair_short_name_list = 
    join ("_", sort ($sp2_short_name,$sp2_short_name));

  my @clusters = @{$self->{'clusterset'}->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  my $outfile = "h_dnaaln.". $sp1_short_name ."." . $sp2_short_name ."." . 
    $self->{_mydbname} . "." . $self->{'clusterset_id'};
  $outfile .= ".csv";
  open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
  print OUTFILE 
    "tree_id,subtree_id,root_taxon,peptide1_stable_id,gene1_stable_id,sp1_name,peptide2_stable_id,gene2_stable_id,sp2_name,present_in_aln,in_frame\n";
  foreach my $cluster (@clusters) {
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    # next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
    my %member;
    my %species;
    my %species1_is_present;
    my %species2_is_present;
    foreach my $member (@{$cluster->get_all_leaves}) {
      my $member_species_short_name = $member->genome_db->get_short_name;
      my $member_stable_id = $member->stable_id;
      $member{$member_stable_id}{gdb_short_name} = $member_species_short_name;
      $member{$member_stable_id}{gene_stable_id} = $member->gene_member->stable_id;
      if ($sp1_short_name eq $member_species_short_name) {
        $species1_is_present{$member_stable_id} = 1;
      } elsif ($sp2_short_name eq $member_species_short_name) {
        $species2_is_present{$member_stable_id} = 1;
      }
    }

    if (1 <= scalar(keys(%species1_is_present)) && 1 <= scalar(keys(%species2_is_present))) {
      foreach my $member (@{$cluster->get_all_leaves}) {
        1;
      }
#       my $peptide1_stable_id = $leaf1->stable_id;
#       my $peptide2_stable_id = $leaf2->stable_id;
#       my $gene1_stable_id = $leaf1_gene_member->stable_id;
#       my $gene2_stable_id = $leaf2_gene_member->stable_id;
#       my $taxonomy_level = $homology->subtype;
#       print OUTFILE "$tree_id,$subtree_id,$taxonomy_level,", 
#         "$peptide1_stable_id,$gene1_stable_id,$sp1_short_name,",
#           "$peptide2_stable_id,$gene2_stable_id,$sp2_short_name,",
#             "$dn,$ds,$lnl\n";
#       print "$tree_id,$subtree_id,$taxonomy_level,", 
#         "$peptide1_stable_id,$gene1_stable_id,$sp1_short_name,",
#           "$peptide2_stable_id,$gene2_stable_id,$sp2_short_name,",
#             "$dn,$ds,$lnl\n" if ($self->{verbose});
    }
  }
}

# internal purposes
sub _homologs_and_paf_scores {
  my $self = shift;
  my $species = shift;
  $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
  $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;

  my $sp_db = $self->{gdba}->fetch_by_name_assembly($species);
  my $all_dbs = $self->{gdba}->fetch_all;
  my $orthologies;
  print "query_peptide_stable_id\thit_peptide_stable_id\thomology_type\ttaxonomy_level\tscore\n";
  foreach my $db (@$all_dbs) {
    unless ($db->name eq $species) {
      my $mlss_1 = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs("ENSEMBL_ORTHOLOGUES",[$sp_db,$db]);
      $orthologies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss_1);
      $self->print_homology_paf_scores(@$orthologies);
    }
  }
  my $mlss_2 = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs("ENSEMBL_PARALOGUES",[$sp_db]);
  my $paralogies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss_2);
  $self->print_homology_paf_scores(@$paralogies);
}

sub print_homology_paf_scores {
  my $self = shift;
  my @homologies = @_;
  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;

  foreach my $homology (@homologies) {
    my $homology_description = $homology->description;
    my @two_ids = map { $_->get_longest_peptide_Member->member_id } @{$homology->gene_list};
    my $subtype = $homology->subtype;
    my $pafs = $pafDBA->fetch_all_by_qmember_id_hmember_id($two_ids[0],$two_ids[1]);
    $subtype =~ s/\///g; $subtype =~ s/\ /\_/g;
    foreach my $self_paf (@$pafs) {
      my $hit_peptide_stable_id = $self_paf->hit_member->stable_id;
      my $query_peptide_stable_id = $self_paf->query_member->stable_id;
      print "$query_peptide_stable_id\t$hit_peptide_stable_id\t$homology_description\t$subtype\t", $self_paf->score, "\n";
    }
  }
}


sub _pafs {
  my $self = shift;
  my $gdb = shift;
  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  my $pafs = $pafDBA->fetch_all_by_hgenome_db_id($gdb);
  foreach my $self_paf (@$pafs) {
    my $hit_peptide_stable_id = $self_paf->hit_member->stable_id;
    my $query_peptide_stable_id = $self_paf->query_member->stable_id;
    print "$hit_peptide_stable_id\t$query_peptide_stable_id\t", $self_paf->score, "\n";
  }
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
  foreach my $e (keys %count) { 
    push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e; }
  if (0 == scalar(@isect)) {
    $node->add_tag('_inspect_topology','1'); $nodes_to_inspect++;
  }
  $nodes_to_inspect += _mark_for_topology_inspection($child_a) 
    if (scalar(@gdb_a)>2);
  $nodes_to_inspect += _mark_for_topology_inspection($child_b) 
    if (scalar(@gdb_b)>2);
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
      print "multifurcation node_id\n", 
        $cluster->node_id, if ($child_count > 2);
      my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
      print STDERR $verbose_string 
        if ($self->{'verbose'} && ($cluster_count % $self->{'verbose'} == 0));
    }
  }
}


# internal purposes
sub _analyzePattern
{
  my $self = shift;
  my $species_list_as_in_tree = $self->{species_list} || 
    "22,10,21,23,3,14,15,19,11,16,9,13,4,18,5,24,12,7,17";
  my @species_list_as_in_tree = split("\,",$species_list_as_in_tree);

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

    my (@duptags) = map {$_->get_tagvalue('Duplication')} $cluster->get_all_subnodes;
    push @duptags, $cluster->get_tagvalue('Duplication');
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

sub _analyzeHomologies {
  my $self = shift;
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  printf("dbname: %s\n", $self->{'_mydbname'});
  printf("analyzeHomologies_: %d\n", $self->{'clusterset_id'});
  $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my @clusters = @{$clusterset->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);
  foreach my $cluster (@clusters) {
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    # my $string = $cluster->get_tagvalue("OrthoTree_types_hashstr");
    my $cluster_node_id = $cluster->node_id;
    foreach my $member (@{$cluster->get_all_leaves}) {
      # my $homologies = $self->{ha}->fetch_by_Member($member->gene_member);
        # Generate a md5sum string to compare among databases
      1;#ONGOING
      my $gene_stable_id = $member->gene_member->stable_id;
      my $transcript_stable_id = $member->transcript->stable_id;
      my $transcript_analysis_logic_name = $member->transcript->analysis->logic_name;
      my $peptide_stable_id = $member->stable_id;
      my $seq = $member->sequence;
      my $md5sum = md5_hex($seq);
      $self->{results_string} .= 
        sprintf "$md5sum,$cluster_node_id,$transcript_analysis_logic_name,$peptide_stable_id,$transcript_stable_id,$gene_stable_id\n";
    }
    print $self->{results_string}; $self->{results_string} = '';
  }
}

sub _print_as_species_ids {
  my $self = shift;
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#  printf("dbname: %s\n", $self->{'_mydbname'});
#  printf("as_species_ids_: %d\n", $self->{'clusterset_id'});
  $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my @clusters = @{$clusterset->children};
  my $totalnum_clusters = scalar(@clusters);
#  printf("totalnum_trees: %d\n", $totalnum_clusters);
  foreach my $cluster (@clusters) {
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    # my $string = $cluster->get_tagvalue("OrthoTree_types_hashstr");
    my $cluster_node_id = $cluster->node_id;
    print "# $cluster_node_id\n";
    my $newick = $cluster->newick_format('species');
    $newick =~ s/\;//;
    print "$newick\n";
  }
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

    my $starttime = time();

    # recalling a genetree for each leaf of treefam tree
    my @leaves = @{$tf->get_all_leaves};
    foreach my $leaf (@leaves) {
      my $genename = $leaf->get_tagvalue('G');
      push @tf_genenames, $genename unless (0 == length($genename));
      my $genename_speciesname = $genename . ", " . $leaf->get_tagvalue('S');
      push @tf_genename_speciesname, $genename_speciesname;
    }

    printf( STDERR "- end of loading foreach -- %10.3f\n", time()-$starttime) if ($self->{'debug'});
    $starttime = time();

    foreach my $leaf (@leaves) {
      my $leaf_name = $leaf->name;
      # treefam uses G NHX tag for genename
      my $genename = $leaf->get_tagvalue('G');
      next if (0==length($genename)); # for weird pseudoleaf tags with no gene name
      $leaf->name($genename);
      # Asking for a genetree given the genename of a treefam tree
      if (fetch_protein_tree_with_gene($self, $genename)) {
        next if ('1' eq $self->{'tree'}->get_tagvalue('cluster_had_to_be_broken_down'));
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

    printf( STDERR "- end of first foreach -- %10.3f\n", time()-$starttime) if ($self->{'debug'});
    $starttime = time();

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

    printf( STDERR "- end of second foreach -- %10.3f\n", time()-$starttime) if ($self->{'debug'});
    $starttime = time();

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
  unless(system("lsrcp $tmpoutfile bc-9-1-03:$outfile") == 0) {
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
  unless(system("lsrcp bc-9-1-03:$infile $tmpinfile") == 0) {
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
