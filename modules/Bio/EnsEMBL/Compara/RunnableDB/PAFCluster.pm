#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PAFCluster

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('PAFCluster');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::PAFCluster(
                         -input_id   => "{'species_set'=>[1,2,3,14]}",
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a compara specific runnableDB, that based on an input_id
of arrayrefs of genome_db_ids, and from this species set relationship
it will search through the peptide_align_feature data and build 
SingleLinkage Clusters and store them into a NestedSet datastructure.
This is the first step in the ProteinTree analysis production system.

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

package Bio::EnsEMBL::Compara::RunnableDB::PAFCluster;

use strict;
use Switch;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Graph::ConnectedComponents;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Time::HiRes qw(time gettimeofday tv_interval);

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->{'species_set'} = undef;
  throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{gdba} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;
  $self->{'selfhit_score_hash'} = {};
  $self->{'no_filters'} = 0;
  $self->{'all_bests'} = 0;
  $self->{'include_brh'} = 1;
  $self->{'bsr_threshold'} = 0.25;
  $self->{'clusterset_id'} = undef;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  my @species_set = @{$self->{'species_set'}};
  $self->{'cluster_mlss'} = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $self->{'cluster_mlss'}->method_link_type('PROTEIN_TREES');
  my @genomeDB_set;
  foreach my $gdb_id (@species_set) {
    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
    throw("print gdb not defined for gdb_id = $gdb_id\n") unless (defined $gdb);
    push @genomeDB_set, $gdb;
  }
  $self->{'cluster_mlss'}->species_set(\@genomeDB_set);

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return if ($param_string eq "1");

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
  if (defined $params->{'all_best'}) {
    $self->{'all_bests'} = $params->{'all_best'};
  }
  if (defined $params->{'no_filters'}) {
    $self->{'no_filters'} = $params->{'no_filters'};
  }
  if (defined $params->{'bsr_threshold'}) {
    $self->{'bsr_threshold'} = $params->{'bsr_threshold'};
  }
  if (defined $params->{'brh'}) {
    $self->{'include_brh'} = $params->{'brh'};
  }
  $self->{'max_gene_count'} = 1000000;
  if (defined $params->{'max_gene_count'}) {
    $self->{'max_gene_count'} = $params->{'max_gene_count'};
  }

  print("parameters...\n");
  printf("  species_set    : (%s)\n", join(',', @{$self->{'species_set'}}));
  printf("  BRH            : %d\n", $self->{'include_brh'});
  printf("  all_blast_hits : %d\n", $self->{'no_filters'});
  printf("  all_bests      : %d\n", $self->{'all_bests'});
  printf("  bsr_threshold  : %1.3f\n", $self->{'bsr_threshold'});

  return;
}

sub run
{
  my $self = shift;

  $self->analyze_table();
  $self->build_paf_clusters();
  return 1;
}

sub write_output {
  my $self = shift;

  $self->store_clusters;

  $self->dataflow_clusters;

  # modify input_job so that it now contains the clusterset_id
  my $outputHash = {};
  $outputHash = eval($self->input_id) if(defined($self->input_id) && $self->input_id =~ /^\s*\{.*\}\s*$/);
  $outputHash->{'clusterset_id'} = $self->{'clusterset_id'};
  my $output_id = $self->encode_hash($outputHash);
  $self->input_job->input_id($output_id);

  return 1;
}

##########################################
#
# internal methods
#
##########################################

# This will make sure that the indexes for paf are fine
sub analyze_table {
  my $self = shift;

  my $starttime = time();

  foreach my $gdb_id (@{$self->{'species_set'}}) {
    my $gdb = $self->{gdba}->fetch_by_dbID($gdb_id);
    my $species_name = lc($gdb->name);
    $species_name =~ s/\ /\_/g;
    my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
    $DB::single=1;1;
    # Re-enable the keys before starting the queries
    my $sql = "ALTER TABLE $tbl_name ENABLE KEYS";

    #print("$sql\n");
    my $sth = $self->dbc->prepare($sql);
    $sth->execute();

    $sql = "ANALYZE TABLE $tbl_name";

    #print("$sql\n");
    $sth = $self->dbc->prepare($sql);
    $sth->execute();
  }
  printf("  %1.3f secs to ANALYZE TABLE\n", (time()-$starttime));
}


sub build_paf_clusters {
  my $self = shift;

  return unless($self->{'species_set'});
  my @species_set = @{$self->{'species_set'}};
  return unless @species_set;

  my $starttime = time();

  # create ConnectedComponents cluster building engine
  $self->{'ccEngine'} = new Bio::EnsEMBL::Compara::Graph::ConnectedComponents;

  #
  # load all the self equal hits for each genome so we have our reference score
  #

  $self->fetch_selfhit_score;

  #
  # for each species pair, get all 'high scoring' hits and build clusters
  #

  while (my $gdb_id1 = shift @species_set) {
    #first get paralogues
    $self->threshold_grow_for_species($gdb_id1);

    foreach my $gdb_id2 (@species_set) {
      $starttime = time();
      $self->BRH_grow_for_species($gdb_id1, $gdb_id2);
      $self->threshold_grow_for_species($gdb_id1, $gdb_id2);
    }
  }
}


#########################################################################
#
# new fast algorithm idea:
#  1) use light weight query to get 'homologies' as a peptide_pair
#     array reference of two member_ids
#  2) use NestedSet/AlignedMember objects in light-weight mode
#     by only storing member_ids
#  3) build clusters in memory (uses very little now)
#  4) store
#
#########################################################################


sub fetch_selfhit_score {
  my $self= shift;

  return undef unless(($self->{'bsr_threshold'} >0.0) and ($self->{'bsr_threshold'} < 1.0));

  my $starttime = time();
  foreach my $gdb_id (@{$self->{'species_set'}}) {
    my $gdb = $self->{gdba}->fetch_by_dbID($gdb_id);
    my $species_name = lc($gdb->name);
    $species_name =~ s/\ /\_/g;
    my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
    my $sql = "SELECT qmember_id, score ".
      "FROM $tbl_name paf ".
        "WHERE qmember_id=hmember_id ".
          "AND qgenome_db_id=$gdb_id";
    print("$sql\n");
    my $sth = $self->dbc->prepare($sql);
    $sth->execute();
    print("  done with fetch\n");
    while ( my $ref  = $sth->fetchrow_arrayref() ) {
      my ($member_id, $score) = @$ref;
      $self->{'selfhit_score_hash'}->{$member_id} = $score;
    }
    $sth->finish;
  }
  printf("%1.3f secs to process\n", (time()-$starttime));
}


sub BRH_grow_for_species
{
  my $self = shift;
  my ($gdb_id1, $gdb_id2) = @_;

  return unless($self->{'include_brh'});

  my $starttime = time();

  my $gdb1 = $self->{gdba}->fetch_by_dbID($gdb_id1);
  my $species_name1 = lc($gdb1->name);
  $species_name1 =~ s/\ /\_/g;
  my $tbl_name1 = "peptide_align_feature"."_"."$species_name1"."_"."$gdb_id1";
  my $gdb2 = $self->{gdba}->fetch_by_dbID($gdb_id2);
  my $species_name2 = lc($gdb2->name);
  $species_name2 =~ s/\ /\_/g;
  my $tbl_name2 = "peptide_align_feature"."_"."$species_name2"."_"."$gdb_id2";

  my $sql = "SELECT paf1.qmember_id, paf1.hmember_id, paf1.score, paf1.hit_rank ".
            "FROM $tbl_name1 paf1 ".
            "JOIN $tbl_name2 paf2 ".
            "  ON( paf1.qmember_id = paf2.hmember_id and paf1.hmember_id = paf2.qmember_id)  ".
            "WHERE paf1.qgenome_db_id = $gdb_id1 AND paf1.hgenome_db_id = $gdb_id2 ".
            "AND   paf2.qgenome_db_id = $gdb_id2 AND paf2.hgenome_db_id = $gdb_id1 ".
            "AND paf1.hit_rank=1 and paf2.hit_rank =1";

  print("$sql\n");
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  printf("  %1.3f secs to fetch BRHs via PAF\n", (time()-$starttime));

  my $midtime = time();
  my $paf_counter=0;
  while( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($pep1_id, $pep2_id, $score, $hit_rank) = @$ref;
    $paf_counter++;
    #my $pep_pair = [$pep1_id, $pep2_id];
    #$self->grow_memclusters_with_peppair($pep_pair);
    $self->{'ccEngine'}->add_connection($pep1_id, $pep2_id);
  }

  printf("  %d clusters so far\n", $self->{'ccEngine'}->get_cluster_count);
  printf("  %d members in hash\n", $self->{'ccEngine'}->get_component_count);
  printf("  %1.3f secs to process %d BRH PAFs\n", time()-$midtime, $paf_counter);
  printf("  %1.3f secs to load/process\n", (time()-$starttime));
}



sub threshold_grow_for_species
{
  my $self = shift;
  my @species_set = @_;

  return undef unless
    ($self->{'all_bests'} or 
     (($self->{'bsr_threshold'} >0.0) and ($self->{'bsr_threshold'} < 1.0)));

  my $starttime = time();
  my $species_string = "(" . join(',', @species_set) . ")";

  my $midtime;
  my $paf_counter;
  my $included_pair_count;
  my $included_bests_count;
  foreach my $gdb_id (@species_set) {
    my $gdb = $self->{gdba}->fetch_by_dbID($gdb_id);
    my $species_name = lc($gdb->name);
    $species_name =~ s/\ /\_/g;
    my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
    my $sql = "SELECT paf.qmember_id, paf.hmember_id, paf.score, paf.hit_rank ".
      "FROM $tbl_name paf ".
        "WHERE paf.qmember_id != paf.hmember_id ".
          "AND paf.hgenome_db_id in $species_string ";
    # !! why do we have that here? Surely adding this constraint we may loose within_species_paralogues...
    if(scalar(@species_set) > 1) {
      $sql .= "AND paf.qgenome_db_id != paf.hgenome_db_id ";
    }
    print("$sql\n");
    my $sth = $self->dbc->prepare($sql);
    $sth->execute();
    printf("  %1.3f secs to fetch PAFs\n", (time()-$starttime));

    $midtime = time();
    $paf_counter=0;
    $included_pair_count=0;
    $included_bests_count=0;
    while( my $ref  = $sth->fetchrow_arrayref() ) {
      my ($pep1_id, $pep2_id, $score, $hit_rank) = @$ref;

      $paf_counter++;

      my $include_pair = 0;
      if($self->{'no_filters'}) {
        $include_pair = 1;
    }

      if(!$include_pair and $self->{'all_bests'} and $hit_rank==1) {
        $included_bests_count++;
        $include_pair = 1;
    }

      if(!$include_pair and ($self->{'bsr_threshold'} < 1.0)) {
        unless(defined($self->{'selfhit_score_hash'}->{$pep1_id})) {
          printf("member_pep %d missing self_hit\n", $pep1_id);
        }
        unless(defined($self->{'selfhit_score_hash'}->{$pep2_id})) {
          printf("member_pep %d missing self_hit\n", $pep2_id);
        }

      #find largest self hit blast score to use as reference
        my $ref_score = $self->{'selfhit_score_hash'}->{$pep1_id};
        my $ref2_score = $self->{'selfhit_score_hash'}->{$pep2_id};
        if (!defined($ref_score) or 
            (defined($ref2_score) and ($ref2_score > $ref_score))) {
          $ref_score = $ref2_score;
        }

        #do blast score ratio (BSR) filter (
        if (defined($ref_score) and ($score / $ref_score > $self->{'bsr_threshold'})) {
          $include_pair=1;
        }
      }

      if ($include_pair) {
        $included_pair_count++;
        $self->{'ccEngine'}->add_connection($pep1_id, $pep2_id);
      }
    }
  }

  printf("  %d clusters so far\n", $self->{'ccEngine'}->get_cluster_count);
  printf("  %d members in hash\n", $self->{'ccEngine'}->get_component_count);
  printf("  %1.3f secs to process %d PAFs => %d picked (%d best + %d threshold)\n", 
         time()-$midtime, $paf_counter, $included_pair_count, $included_bests_count, 
         $included_pair_count - $included_bests_count);
  printf("  %1.3f secs to load/process\n", (time()-$starttime));
}


sub store_clusters {
  my $self = shift;

  return unless($self->{'species_set'});
#  my @species_set = @{$self->{'species_set'}};
#  return unless @species_set;
  return unless ($self->{'cluster_mlss'});

  my $mlssDBA = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $starttime = time();

  my $clusterset = $self->{'ccEngine'}->clusterset;
  throw("no clusters generated") unless($clusterset);

  $clusterset->name("PROTEIN_TREES");
  $treeDBA->store_node($clusterset);
  printf("root_id %d\n", $clusterset->node_id);
  $self->{'clusterset_id'} = $clusterset->node_id;

  #
  # create Cluster MLSS
  #
#  $self->{'cluster_mlss'} = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
#  $self->{'cluster_mlss'}->method_link_type('PROTEIN_TREES');
#  my @genomeDB_set;
#  foreach my $gdb_id (@species_set) {
#    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
#
#    push @genomeDB_set, $gdb;
#  }
#  $self->{'cluster_mlss'}->species_set(\@genomeDB_set);
  $mlssDBA->store($self->{'cluster_mlss'});
  printf("MLSS %d\n", $self->{'cluster_mlss'}->dbID);

  #
  # Go through all the leaves which were generated by ConnectedComponents
  # and convert them into AlignedMember objects with additional data
  # to allow them to be stored correctly
  #
  my $mlss_id = $self->{'cluster_mlss'}->dbID;
  my $leaves = $clusterset->get_all_leaves;
  foreach my $leaf (@$leaves) {
    #leaves are NestedSet objects, bless to make into AlignedMember objects
    bless $leaf, "Bio::EnsEMBL::Compara::AlignedMember";

    #the building method uses member_id's to reference unique nodes
    #which are stored in the node_id value, copy to member_id
    $leaf->member_id($leaf->node_id);
    $leaf->method_link_species_set_id($mlss_id);
  }


  printf("storing the clusters\n");
  printf("    loaded %d leaves\n", scalar(@$leaves));
  my $count=0;
  foreach my $mem (@$leaves) { $count++ if($mem->isa('Bio::EnsEMBL::Compara::AlignedMember'));}
  printf("    loaded %d leaves which are members\n", $count);
  printf("    loaded %d members in hash\n", $self->{'ccEngine'}->get_component_count);
  printf("    %d clusters generated\n", $self->{'ccEngine'}->get_cluster_count);

  my $clusters = $clusterset->children;
  my $counter=1;
  foreach my $cluster (@{$clusters}) {
    $treeDBA->store($cluster);

    #calc residue count total
    my $leafcount = scalar(@{$cluster->get_all_leaves});
    $cluster->store_tag('gene_count', $leafcount);
    $cluster->store_tag('include_brh', $self->{'include_brh'});
    $cluster->store_tag('bsr_threshold', $self->{'bsr_threshold'});

    if($counter++ % 200 == 0) { printf("%10d clusters stored\n", $counter); }
  }
  printf("  %1.3f secs to store clusters\n", (time()-$starttime));
  printf("tree_root : %d\n", $clusterset->node_id);
}


sub dataflow_clusters {
  my $self = shift;

  my $clusterset = $self->{'ccEngine'}->clusterset;
  my $clusters = $clusterset->children;
  foreach my $cluster (@{$clusters}) {
    my $output_id = sprintf("{'protein_tree_id'=>%d, 'clusterset_id'=>%d}", 
                            $cluster->node_id, $clusterset->node_id);
    if ($cluster->get_tagvalue('gene_count') > $self->{'max_gene_count'}) {
      $self->dataflow_output_id($output_id, 3);
    } else {
      $self->dataflow_output_id($output_id, 2);
    }
  }
}


1;
