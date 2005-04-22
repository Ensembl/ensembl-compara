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
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Homology;
use Time::HiRes qw(time gettimeofday tv_interval);

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->{'species_set'} = undef;
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
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
  
  return unless($self->{'species_set'});
  my @species_set = @{$self->{'species_set'}};
  return unless @species_set;

  my $mlssDBA = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $homologyDBA = $self->{'comparaDBA'}->get_HomologyAdaptor;
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $starttime = time();
   
  my $root = new Bio::EnsEMBL::Compara::NestedSet;
  $root->name("ORTHO_CLUSTERS");
  $treeDBA->store($root);
    
  #
  # create Cluster MLSS
  #
  $self->{'cluster_mlss'} = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $self->{'cluster_mlss'}->method_link_type('ORTHO_CLUSTERS'); 
  my @genomeDB_set;
  foreach my $gdb_id (@species_set) {
    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
    push @genomeDB_set, $gdb;
  }
  $self->{'cluster_mlss'}->species_set(\@genomeDB_set);
  $mlssDBA->store($self->{'cluster_mlss'});
  
  #  
  #get all MLSS for each homology pair in this species set
  #get all homologies for each MLSS
  #
  my $ug = new Data::UUID;
  
  while (my $gdb_id1 = shift @species_set) {
    foreach my $gdb_id2 (@species_set) {
      printf("find MLSS for genome pair %d/%d\n", $gdb_id1, $gdb_id2);
      my $mlss = $mlssDBA->fetch_by_method_link_type_genome_db_ids
            ("ENSEMBL_ORTHOLOGUES",[$gdb_id1, $gdb_id2]);
      next unless(defined($mlss));

      printf("fetch all homologies for mlss_id=%d\n", $mlss->dbID);
      $starttime = time();
      my $homology_list = $homologyDBA->fetch_all_by_MethodLinkSpeciesSet($mlss);
      printf("  %d secs to fetch homologies\n", (time()-$starttime));
      printf("  %d homologies\n", scalar(@{$homology_list}));

      $starttime = time();
      my $counter=0;
      while(@{$homology_list}) {
        my $homology = shift @{$homology_list};
        $counter++;
        if($counter % 200 == 0) { printf("%10d homologies done\n", $counter); }
        
        $self->grow_clusters_with_homology($root, $homology);
      }
      printf("  %d secs to load/process homologies\n", (time()-$starttime));
    }
  }  
}


sub grow_clusters_with_homology {
  my $self = shift;
  my $root = shift;
  my $homology = shift;
  

  my ($alignedMember1, $alignedMember2) = $homology->get_AlignedMember_pair;
  
  my $proteinTreeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $treeMember1 = $proteinTreeDBA->fetch_AlignedMember_by_member_id_root_id(
              $alignedMember1->member_id, $root->node_id);
  my $treeMember2 = $proteinTreeDBA->fetch_AlignedMember_by_member_id_root_id(
              $alignedMember2->member_id, $root->node_id);

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

  $treeMember1->parent->release if($treeMember1);
  $treeMember2->parent->release if($treeMember2);

}


##################################################
#
# single cluster build : gene start, recursive search
#
##################################################


sub build_cluster_around_gene_stable_id {
  my $self = shift;
  my $gene_stable_id = shift;

  my $root = new Bio::EnsEMBL::Compara::NestedSet;
  $root->name("ORTHO_CLUSTERS");
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

1;
