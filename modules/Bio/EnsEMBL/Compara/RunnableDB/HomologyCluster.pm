#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HomologyCluster

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HomologyCluster');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::HomologyCluster(
                         -input_id   => "{'species_set'=>[1,2,3,14]}",
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a compara specific runnableDB, that based on an input_id
of arrayrefs of genome_db_ids, and from this species set realtionship
it will search through the homology data and build SingleLinkage Clusters
and store them into a NestedSet datastructure.  This is the first step in
the Tree analysis production system.

=cut

=head1 CONTACT

  Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyCluster;

use strict;
use Switch;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Homology;
use Data::UUID;
use Time::HiRes qw(time gettimeofday tv_interval);

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->{'species_set'} = undef;
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->input_id);
  return 1;
}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");
  
  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  if (defined $params->{'species_set'}) {
    $self->{'species_set'} = $params->{'species_set'};
  }
  if (defined $params->{'gene_stable_id'}) {
    $self->{'gene_stable_id'} = $params->{'gene_stable_id'};
  }
  
  return;
}

sub run
{
  my $self = shift;  
  return 1;
}

sub write_output {
  my $self = shift;
  
  if($self->{'gene_stable_id'}) {
    $self->build_cluster_around_gene_stable_id($self->{'gene_stable_id'});
  } else {
    $self->build_homology_clusters();
  }
  
  return 1;
}

##########################################
#
# internal methods
#
##########################################


sub build_homology_clusters {
  my $self = shift;
  
  my $build_mode = 'direct';
  
  return unless($self->{'species_set'});
  my @species_set = @{$self->{'species_set'}};
  return unless @species_set;

  my $mlssDBA = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $homologyDBA = $self->{'comparaDBA'}->get_HomologyAdaptor;
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $starttime = time();
   
  my $root = new Bio::EnsEMBL::Compara::NestedSet;
  $root->name("PROTEIN_TREES");
  $treeDBA->store($root);
  printf("root_id %d\n", $root->node_id);
    
  #
  # create Cluster MLSS
  #
  $self->{'cluster_mlss'} = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $self->{'cluster_mlss'}->method_link_type('PROTEIN_TREES'); 
  my @genomeDB_set;
  foreach my $gdb_id (@species_set) {
    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
    push @genomeDB_set, $gdb;
  }
  $self->{'cluster_mlss'}->species_set(\@genomeDB_set);
  $mlssDBA->store($self->{'cluster_mlss'});
  printf("MLSS %d\n", $self->{'cluster_mlss'}->dbID);
  
  $self->{'member_leaves'} = {};
  
  my $ug = new Data::UUID;

  #  
  # load all the Paralogue pairs, building clusters as we load
  # get all homologies for each MLSS
  #
  
  foreach my $gdb_id1 (@species_set) {
    printf("\nfind MLSS for genome  %d\n", $gdb_id1);
    my $mlss = $mlssDBA->fetch_by_method_link_type_genome_db_ids
          ("ENSEMBL_PARALOGUES",[$gdb_id1]);
    next unless(defined($mlss));

    printf("fetch all paralogues for mlss_id=%d\n", $mlss->dbID);
    $starttime = time();
    my $homology_list = $self->fetch_homology_peptide_pairs_by_mlss($mlss);
    printf("  %1.3f secs to fetch paralogues\n", (time()-$starttime));
    printf("  %d paralogue pairs\n", scalar(@{$homology_list}));

    $starttime = time();
    while(@{$homology_list}) {
      my $pep_pair = shift @{$homology_list};
      $self->grow_memclusters_with_peppair($root, $pep_pair);
    }
    printf("  %1.3f secs to load/process homologies\n", (time()-$starttime));
  }

  #  
  #get all MLSS for each homology pair in this species set
  #get all homologies for each MLSS
  #  
  
  while (my $gdb_id1 = shift @species_set) {
    foreach my $gdb_id2 (@species_set) {
      printf("\nfind MLSS for genome pair %d/%d\n", $gdb_id1, $gdb_id2);
      my $mlss = $mlssDBA->fetch_by_method_link_type_genome_db_ids
            ("ENSEMBL_ORTHOLOGUES",[$gdb_id1, $gdb_id2]);
      next unless(defined($mlss));

      printf("fetch all homologies for mlss_id=%d\n", $mlss->dbID);
      $starttime = time();
      my $homology_list = undef;
      switch ($build_mode) {
        case 'API' { $homology_list = $homologyDBA->fetch_all_by_MethodLinkSpeciesSet($mlss); }
        case 'direct' { $homology_list = $self->fetch_homology_peptide_pairs_by_mlss($mlss); }
      }
      printf("  %1.3f secs to fetch homologies\n", (time()-$starttime));
      printf("  %d homologies\n", scalar(@{$homology_list}));

      $starttime = time();
      my $counter=0;
      while(@{$homology_list}) {
        $counter++;
        #if($counter % 200 == 0) { printf("%10d homologies done\n", $counter); }
        
        switch($build_mode) {
          case 'API' {
            my $homology = shift @{$homology_list};        
            $self->grow_clusters_with_homology($root, $homology);
          }
          case 'direct' {
            my $pep_pair = shift @{$homology_list};
            $self->grow_memclusters_with_peppair($root, $pep_pair);
          }
        }
        
      }
      printf("  %1.3f secs to load/process homologies\n", (time()-$starttime));
    }
  }
  
  if($build_mode eq 'direct') {
    $self->store_clusters($root);
  }
  
  $self->dataflow_clusters($root);
}


sub grow_clusters_with_homology {
  my $self = shift;
  my $root = shift;
  my $homology = shift;
  

  my ($alignedMember1, $alignedMember2) = $homology->get_AlignedMember_pair;
  $alignedMember1->method_link_species_set_id($self->{'cluster_mlss'}->dbID);
  $alignedMember2->method_link_species_set_id($self->{'cluster_mlss'}->dbID);  
  
  my $proteinTreeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $treeMember1 = $proteinTreeDBA->fetch_AlignedMember_by_member_id_mlssID(
              $alignedMember1->member_id, $self->{'cluster_mlss'}->dbID);
  my $treeMember2 = $proteinTreeDBA->fetch_AlignedMember_by_member_id_mlssID(
              $alignedMember2->member_id, $self->{'cluster_mlss'}->dbID);

  if(!defined($treeMember1) and !defined($treeMember2)) {
    #neither member is in a cluster so create new cluster with just these 2 members
    # printf("create new cluster\n");
    my $cluster = new Bio::EnsEMBL::Compara::NestedSet;
    $root->store_child($cluster);

    $cluster->store_child($alignedMember1);
    $cluster->store_child($alignedMember2);
  }
  elsif(defined($treeMember1) and !defined($treeMember2)) {
    # printf("add member to cluster %d\n", $treeMember1->parent->node_id);
    # $alignedMember2->print_member; 
    $treeMember1->parent->store_child($alignedMember2);
  }
  elsif(!defined($treeMember1) and defined($treeMember2)) {
    # printf("add member to cluster %d\n", $treeMember2->parent->node_id);
    # $alignedMember1->print_member; 
    $treeMember2->parent->store_child($alignedMember1);
  }
  elsif(defined($treeMember1) and defined($treeMember2)) {
    if($treeMember1->parent->equals($treeMember2->parent)) {
      # printf("both members already in same cluster %d\n", $treeMember1->parent->node_id);
    } else {
      #this member already belongs to a different cluster -> need to merge clusters
      # print("MERGE clusters\n");
      $proteinTreeDBA->merge_nodes($treeMember1->parent, $treeMember2->parent);
    }
  }
}


##################################################
#
# single cluster build : gene start, recursive search
#   Mainly used for debugging and testing.  
#   Too slow to be used as a primary production algorithm.
#
##################################################


sub build_cluster_around_gene_stable_id {
  my $self = shift;
  my $gene_stable_id = shift;

  my $root = new Bio::EnsEMBL::Compara::NestedSet;
  $root->name("PROTEIN_TREES");
  $self->{'comparaDBA'}->get_ProteinTreeAdaptor->store($root);

  my $MA = $self->{'comparaDBA'}->get_MemberAdaptor;
  my $gene_member = $MA->fetch_by_source_stable_id("ENSEMBLGENE", $gene_stable_id);

  throw("couldn't find gene member $gene_stable_id") unless($gene_member);
  
  my $start = time();
  my $ortho_set = {};
  my $member_set = {};
  $self->get_orthologue_cluster($gene_member, $ortho_set, $member_set, 0);

  printf("cluster has %d links\n", scalar(keys(%{$ortho_set})));
  printf("cluster has %d genes\n", scalar(keys(%{$member_set})));
  printf("%1.3f msec\n", 1000.0*(time() - $start));

  foreach my $homology (values(%{$ortho_set})) {
    $self->grow_clusters_with_homology($root, $homology);
  }

  printf("cluster has %d genes\n", scalar(keys(%{$member_set})));
  foreach my $member (values(%{$member_set})) {
    $member->print_member;
  }
  $root->print_tree;
}


sub get_orthologue_cluster {
  my $self = shift;
  my $gene = shift;
  my $ortho_set = shift;
  my $member_set = shift;

  return if($member_set->{$gene->dbID});

  $gene->print_member("query gene\n") if($self->debug);
  $member_set->{$gene->dbID} = $gene;

  my $homologies = $self->{'comparaDBA'}->get_HomologyAdaptor->fetch_by_Member($gene);
  printf("fetched %d homologies\n", scalar(@$homologies)) if($self->debug);

  foreach my $homology (@{$homologies}) {
    next if($ortho_set->{$homology->dbID});
    next if($homology->method_link_type ne 'ENSEMBL_ORTHOLOGUES');

    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @{$member_attribute};
      next if($member->dbID == $gene->dbID); #skip query gene
      $member->print_member if($self->debug);

      printf("adding homology_id %d to cluster\n", $homology->dbID) if($self->debug);
      $ortho_set->{$homology->dbID} = $homology;
      $self->get_orthologue_cluster($member, $ortho_set, $member_set, $self->debug);
    }
  }
  printf("done with search query %s\n", $gene->stable_id) if($self->debug);
}


#########################################################################
#
# new fast algorithm idea:
#  AVOIDS most of the API :(
#  1) preload all members from all genomes into MLSS linked group
#     a) create 1 'un parented' node and member for each peptide  
#  2) load 'homologies' as simple peptide_member_id pair SQL query
#  3) loop through peptide_pair, use root_id,parent_id to grow clusters
#
#
#########################################################################

sub fetch_homology_peptide_pairs_by_mlss {
  my $self = shift;
  my $mlss = shift;
  
  my $starttime = time();

  my $sql = "SELECT hm.homology_id, peptide_member_id ".
            "FROM homology_member hm join homology using (homology_id ) ".
            "WHERE method_link_species_set_id = ? order by hm.homology_id";
  #print("$sql\n");
  my $sth = $self->dbc->prepare($sql);
  $sth->execute($mlss->dbID);
  #print("  done with fetch\n");
  my $homology_hash = {};
  while( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($homology_id, $peptide_member_id) = @$ref;
    push @{$homology_hash->{$homology_id}}, $peptide_member_id;
  }
  $sth->finish;
  #printf("loaded %d homologies pep_pairs in %1.3f secs\n", scalar(keys(%$homology_hash)), (time()-$starttime));

  my @pairs = values(%$homology_hash);
  return \@pairs;
}


sub grow_dbclusters_with_peppair {
  my $self = shift;
  my $root = shift;
  my $pep_pair = shift;

  #printf("homology peptide pair : %d - %d\n", $pep_pair->[0], $pep_pair->[1]); 
  my $mlss_id = $self->{'cluster_mlss'}->dbID;
  
  my $proteinTreeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $starttime = time();
  my $treeMember1 = $proteinTreeDBA->fetch_AlignedMember_by_member_id_mlssID($pep_pair->[0], $mlss_id);
  my $treeMember2 = $proteinTreeDBA->fetch_AlignedMember_by_member_id_mlssID($pep_pair->[1], $mlss_id);
  printf("  %1.3f secs to fetch AlignedMember\n", (time()-$starttime));

  my $alignedMember1 = undef;
  if(!defined($treeMember1)) {
    $alignedMember1 = new Bio::EnsEMBL::Compara::AlignedMember;
    $alignedMember1->method_link_species_set_id($mlss_id);
    $alignedMember1->member_id($pep_pair->[0]);
  }
  my $alignedMember2 = undef;
  if(!defined($treeMember2)) {
    $alignedMember2 = new Bio::EnsEMBL::Compara::AlignedMember;
    $alignedMember2->method_link_species_set_id($mlss_id);
    $alignedMember2->member_id($pep_pair->[1]);
  }
  
  if(!defined($treeMember1) and !defined($treeMember2)) {
    #neither member is in a cluster so create new cluster with just these 2 members
    # printf("create new cluster\n");
    my $cluster = new Bio::EnsEMBL::Compara::NestedSet;
    $root->store_child($cluster);

    my $starttime = time();
    $cluster->store_child($alignedMember1);
    printf("  %1.3f secs to store member in new cluster\n", (time()-$starttime));
    $cluster->store_child($alignedMember2);
  }
  elsif(defined($treeMember1) and !defined($treeMember2)) {
    # printf("add member to cluster %d\n", $treeMember1->parent->node_id);
    # $alignedMember2->print_member; 
    my $starttime = time();
    $treeMember1->parent->store_child($alignedMember2);
    printf("  %1.3f secs to store member in exisiting cluster\n", (time()-$starttime));
  }
  elsif(!defined($treeMember1) and defined($treeMember2)) {
    # printf("add member to cluster %d\n", $treeMember2->parent->node_id);
    # $alignedMember1->print_member; 
    $treeMember2->parent->store_child($alignedMember1);
  }
  elsif(defined($treeMember1) and defined($treeMember2)) {
    if($treeMember1->parent->equals($treeMember2->parent)) {
      # printf("both members already in same cluster %d\n", $treeMember1->parent->node_id);
    } else {
      #this member already belongs to a different cluster -> need to merge clusters
      # print("MERGE clusters\n");
      $proteinTreeDBA->merge_nodes($treeMember1->parent, $treeMember2->parent);
    }
  }
}


=head2 grow_memclusters_with_peppair

  Description: Takes a pair of peptide_member_id and uses the NestedSet objects
     to build a 3 layer tree in memory.  There is a single root for the entire build
     process, and each cluster is a child of this root.  The members are children of
     the clusters. During the build process the member leaves are assigned a node_id
     equal to the peptide_member_id so they can be found via 'find_node_by_node_id'.
     After the process is completed, each cluster can then be stored in a faster 
     bulk insert process.
    
=cut


sub grow_memclusters_with_peppair {
  my $self = shift;
  my $root = shift;
  my $pep_pair = shift;

  #printf("homology peptide pair : %d - %d\n", $pep_pair->[0], $pep_pair->[1]); 
  my $mlss_id = $self->{'cluster_mlss'}->dbID;
  
  my ($treeMember1, $treeMember2);
  $treeMember1 = $self->{'member_leaves'}->{$pep_pair->[0]};
  $treeMember2 = $self->{'member_leaves'}->{$pep_pair->[1]};

  if(!defined($treeMember1)) {
    $treeMember1 = new Bio::EnsEMBL::Compara::AlignedMember;
    $treeMember1->method_link_species_set_id($mlss_id);
    $treeMember1->member_id($pep_pair->[0]);
    $treeMember1->node_id($pep_pair->[0]);
    $self->{'member_leaves'}->{$pep_pair->[0]} = $treeMember1;
  }
  if(!defined($treeMember2)) {
    $treeMember2 = new Bio::EnsEMBL::Compara::AlignedMember;
    $treeMember2->method_link_species_set_id($mlss_id);
    $treeMember2->member_id($pep_pair->[1]);
    $treeMember2->node_id($pep_pair->[1]);
    $self->{'member_leaves'}->{$pep_pair->[1]} = $treeMember2;
  }
  
  if(!defined($treeMember1->parent) and !defined($treeMember2->parent)) {
    #neither member is in a cluster so create new cluster with just these 2 members
    # printf("create new cluster\n");
    my $cluster = new Bio::EnsEMBL::Compara::NestedSet;
    $root->add_child($cluster);
    $cluster->add_child($treeMember1);
    $cluster->add_child($treeMember2);
  }
  elsif(defined($treeMember1->parent) and !defined($treeMember2->parent)) {
    # printf("add member to cluster %d\n", $treeMember1->parent->node_id);
    # $treeMember2->print_member; 
    $treeMember1->parent->add_child($treeMember2);
  }
  elsif(!defined($treeMember1->parent) and defined($treeMember2->parent)) {
    # printf("add member to cluster %d\n", $treeMember2->parent->node_id);
    # $treeMember1->print_member; 
    $treeMember2->parent->add_child($treeMember1);
  }
  elsif(defined($treeMember1->parent) and defined($treeMember2->parent)) {
    if($treeMember1->parent->equals($treeMember2->parent)) {
      # printf("both members already in same cluster %d\n", $treeMember1->parent->node_id);
    } else {
      #this member already belongs to a different cluster -> need to merge clusters
      # print("MERGE clusters\n");
      my $parent2 = $treeMember2->parent;
      $treeMember1->parent->merge_children($treeMember2->parent);
      $parent2->disavow_parent; #releases from root
    }
  }

}


sub store_clusters {
  my $self = shift;
  my $root = shift;
  
  my $starttime = time();

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;

  my $leaves = $root->get_all_leaves;
  printf("loaded %d leaves\n", scalar(@$leaves));
  my $count=0;
  foreach my $mem (@$leaves) { $count++ if($mem->isa('Bio::EnsEMBL::Compara::AlignedMember'));}
  printf("loaded %d leaves which are members\n", $count);
  printf("loaded %d members in hash\n", scalar(keys(%{$self->{'member_leaves'}})));
  printf("%d clusters generated\n", $root->get_child_count);  
  
  my $clusters = $root->children;
  my $counter=0;
  foreach my $cluster (@{$clusters}) {
    $cluster->build_leftright_indexing;
    
    $treeDBA->store($cluster);
    if($counter++ % 200 == 0) { printf("%10d clusters stored\n", $counter); }
  }
  printf("  %1.3f secs to store clusters\n", (time()-$starttime));
}


sub dataflow_clusters {
  my $self = shift;
  my $root = shift;
  
  my $clusters = $root->children;
  foreach my $cluster (@{$clusters}) {
    my $output_id = sprintf("{'protein_tree_id'=>%d}", $cluster->node_id);
    $self->dataflow_output_id($output_id, 2);
  }
}


1;
