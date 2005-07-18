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
use Bio::EnsEMBL::Compara::NCBITaxon;
use Switch;
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
$self->{'scale'} = 100;
$self->{'align_format'} = 'phylip';
$self->{'debug'}=0;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $url;

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
           'dump'             => \$self->{'dump'},           
           'align_format=s'   => \$self->{'align_format'},
           'scale=f'          => \$self->{'scale'},
           'count'            => \$self->{'counts'},
           'newick'           => \$self->{'print_newick'},
           'print'            => \$self->{'print_tree'},
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

if($self->{'parent'} and $self->{'tree'} and $self->{'tree'}->parent) {
  $self->{'tree'} = $self->{'tree'}->parent;
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

if($self->{'clusterset_id'}) {
  analyzeClusters2($self);
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
  print "  -parent                : move up to the parent of the loaded node\n";
  print "  -dump                  : outputs to autonamed file, not STDOUT\n";
  print "\n";  
  print "  -clusertset_id <id>    : analyze clusters :)\n"; 
  print "geneTreeTool.pl v1.2\n";
  
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


sub analyzeClusters
{
  my $self = shift;
  
  printf("analyzeClusters root_id: %d\n", $self->{'clusterset_id'});
  
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});  

  printf("%d clusters\n", $clusterset->get_child_count);  
  
  my $pretty_cluster_count=0;
  foreach my $cluster (@{$clusterset->children}) {
    my $starttime = time();
    $treeDBA->fetch_subtree_under_node($cluster);
    
    my $member_list = $cluster->get_all_leaves;
    my %member_gdb_hash;
    my $has_gdb_dups=0;
    foreach my $member (@{$member_list}) {
      $has_gdb_dups=1 if($member_gdb_hash{$member->genome_db_id});
      $member_gdb_hash{$member->genome_db_id} = 1;
    }
    printf("%7d, %10d, %10d, %10.3f\n", $cluster->node_id, scalar(@{$member_list}), $has_gdb_dups, (time()-$starttime));
    $pretty_cluster_count++ unless($has_gdb_dups);
  }
  print("%d clusters without duplciates (%d total)\n", $pretty_cluster_count, $clusterset->get_child_count);
    
  $clusterset->release;
}


sub analyzeClusters2
{
  my $self = shift;
  #my $species_list = [1,2,3,4,9,11,13,14,16];
  my $species_list = [1,2,3,14];
  
  $self->{'member_LSD_hash'} = {};
  $self->{'gdb_member_hash'} = {};

  my $ingroup = {};
  foreach my $gdb (@{$species_list}) {
    $ingroup->{$gdb} = 1;
    $self->{'gdb_member_hash'}->{$gdb} = []
  }
  
  printf("analyzeClusters root_id: %d\n", $self->{'clusterset_id'});
  
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});  

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
    $cluster->retain->disavow_parent;

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
        
        push @{$self->{'gdb_member_hash'}->{$member->genome_db_id}}, $member->member_id;
      
        next if(defined($self->{'member_LSD_hash'}->{$member->member_id})); #already analyzed
        next unless($ingroup->{$member->genome_db_id});
        
        #print("\nFIND INGROUP from\n   ");
        #$member->print_node;
        
        my $rosette = find_ingroup_ancestor($self, $ingroup, $member);
        #$rosette->print_tree;
        $rosette_count++;
        if($self->{'debug'}) {
          printf("    rosette: %10d, %10d, %10d, %10d\n",
                 $rosette->node_id, scalar(@{$rosette->get_all_leaves}), 
                 $cluster->node_id, scalar(@{$member_list}));
        }
        
        #generate a taxon_id string
        my @all_leaves = @{$rosette->get_all_leaves};
        $total_members += scalar(@all_leaves);
        my @taxon_list;
        foreach my $leaf (@all_leaves) { push @taxon_list, $leaf->taxon_id;}
        my $taxon_id_string = join("_", sort {$a <=> $b} @taxon_list);
        $rosette_taxon_hash{$taxon_id_string} = 0 unless(defined($rosette_taxon_hash{$taxon_id_string}));
        $rosette_taxon_hash{$taxon_id_string}++;

        my $has_LSD = test_rosette_for_LSD($self,$rosette);
              
        if($has_LSD) {
          print("    LinearSpecificDuplication\n") if($self->{'debug'});
          #$rosette->print_tree;
          $lsd_rosette_count++;
          $rosette->add_tag('rosette_LSDup');
        } else {
          if(test_rosette_matches_species_tree($self, $rosette)) {
            $match_species_tree_count++;
            $rosette->add_tag('rosette_species_topo_match');        
          }
        }
        
        if(test_rosette_for_gene_loss($self, $rosette, $species_list)) {
          $geneLoss_rosette_count++;
          $rosette->add_tag('rosette_geneLoss');        
        }
        
        printf("rosette, %d, %d, %d, %d",
           $rosette->node_id, scalar(@{$rosette->get_all_leaves}), 
           $cluster->node_id, scalar(@{$member_list}));
        if($rosette->has_tag("rosette_LSDup")) {print(", LSDup");} else{print(", OK");}
        if($rosette->has_tag("rosette_geneLoss")) {print(", GeneLoss");} else{print(", OK");}
        unless($rosette->has_tag("rosette_species_topo_match")) {print(", TopoFail");} else{print(", OK");}
        print(", $taxon_id_string");
        print("\n");

      }
    }
    
    #printf("    %10.3f secs\n", '', (time()-$starttime));
    
    $cluster->release;
    
    #last if($cluster_count >= 100);
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
  foreach my $key (keys %rosette_taxon_hash) {
    printf("   %7d : %s\n", $rosette_taxon_hash{$key}, $key);
  }
  
              
  $clusterset->release;
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
    $gdb_hash{$member->genome_db_id}=0 unless(defined($gdb_hash{$member->genome_db_id}));
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
    $gdb_hash{$member->genome_db_id}=0 unless(defined($gdb_hash{$member->genome_db_id}));
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

  #copy the rosette and replace the peptide_member leaves with taxon leaves 
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
    $topo_set->release;
  }
  
  #print("BUILD TAXON topology sets\n");
  my $taxon_topo_sets = new Bio::EnsEMBL::Compara::NestedSet;
  foreach my $node ($species_tree->get_all_subnodes) {
    next if($node->is_leaf);
    my $topo_set = $node->copy->flatten_tree;
    #$topo_set->print_tree;
    $taxon_topo_sets->add_child($topo_set);
    $topo_set->release;
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
  $rosette->release;  
  $gene_topo_sets->release;
  $taxon_topo_sets->release;
  
  #printf("\n\n");
  return $topology_matches;
}


