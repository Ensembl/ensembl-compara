#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HclusterRun

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HclusterRun');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::HclusterRun(
                         -input_id   => "{'species_set'=>[1,2,3,14]}",
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a compara specific runnableDB, that based on an input_id
of arrayrefs of genome_db_ids, and from this species set relationship
it will search through the peptide_align_feature data and build 
Hclusters and store them into a NestedSet datastructure.
This is the first step in the ProteinTree analysis production system.

=cut

=head1 CONTACT

  Contact Albert Vilella on module implemetation/design detail: avilella@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HclusterRun;

use strict;
use Switch;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Graph::ConnectedComponents;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'clusterset_id'         => 1,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $species_set = $self->param('species_set') or die "'species_set' is an obligatory list parameter";

    my $cluster_mlss = $self->param('cluster_mlss', Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new() );
    $cluster_mlss->method_link_type('PROTEIN_TREES');
    my @genomedb_array = ();
    foreach my $gdb_id (@$species_set) {
        my $gdb = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
        $self->throw("print gdb not defined for gdb_id = $gdb_id\n") unless (defined $gdb);
        push @genomedb_array, $gdb;
    }
    $cluster_mlss->species_set(\@genomedb_array);
}


sub run {
    my $self = shift @_;

    $self->gather_input();
    $self->run_hcluster();
}

sub write_output {
    my $self = shift @_;

    $self->store_clusters();
    $self->dataflow_clusters;
}

##########################################
#
# internal methods
#
##########################################

sub gather_input {
  my $self = shift;

  my $starttime = time();
  return if ($self->input_job->retry_count > 10);

  my $cluster_dir = $self->param('cluster_dir');
  my $output_dir = $self->worker_temp_directory;
  my $cmd;
  print "gathering input in $output_dir\n" if ($self->debug);

  $cmd ="cat $cluster_dir/*.hcluster.cat > $output_dir/hcluster.cat";
  unless(system($cmd) == 0) {
    $self->throw("error gathering category files for Hcluster, $!\n");
  }
  printf("%1.3f secs to gather category entries\n", (time()-$starttime));
  $cmd ="cat $cluster_dir/*.hcluster.txt > $output_dir/hcluster.txt";
  unless(system($cmd) == 0) {
    $self->throw("error gathering distance files for Hcluster, $!\n");
  }
  printf("%1.3f secs to gather distance entries\n", (time()-$starttime));
}

sub run_hcluster {
  my $self = shift;

  my $starttime = time();
  return if ($self->input_job->retry_count > 10);

  my $hcluster_executable = $self->analysis->program_file;
  unless (-e $hcluster_executable) {
    if (`uname -m` =~ /ia64/) {
      $hcluster_executable
        = "/nfs/users/nfs_a/avilella/src/treesoft/trunk/ia64/hcluster/hcluster_sg";
    } else {
      $hcluster_executable
        = "/nfs/users/nfs_a/avilella/src/treesoft/trunk/hcluster/hcluster_sg";
    }
  }

  $self->compara_dba->dbc->disconnect_when_inactive(1);

  my $cmd = $hcluster_executable;
  my $max_count = int($self->param('max_gene_count')/2); # hcluster can joint up to (max_count+(max_count-1))
  $cmd .= " ". "-m $max_count -w 0 -s 0.34 -O ";
  $cmd .= "-C " . $self->worker_temp_directory . "hcluster.cat ";
  $cmd .= "-o " . $self->worker_temp_directory . "hcluster.out ";
  $cmd .= " " . $self->worker_temp_directory . "hcluster.txt";
  print("Ready to execute:\n") if($self->debug);
  print("$cmd\n") if($self->debug);
  unless(system($cmd) == 0) {
    $self->throw("error running hcluster command ' $cmd ': $!\n");
  }
  $self->compara_dba->dbc->disconnect_when_inactive(0);
  printf("%1.3f secs to execute\n", (time()-$starttime));

  return 1;
}

sub store_clusters {
  my $self = shift;

  my $retry = $self->param('retry', ($self->input_job->retry_count > 10) ? $self->input_job->retry_count : undef );

  my $mlss_adaptor          = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $protein_tree_adaptor  = $self->compara_dba->get_ProteinTreeAdaptor;
  my $starttime = time();

  my $filename;
  my $cluster_dir = $self->param('cluster_dir');
  if (defined($retry)) {
    $filename = $cluster_dir . "/" . "hcluster.out";
  } else {
    $filename = $self->worker_temp_directory . "/" . "hcluster.out";
    my $copy_filename = $cluster_dir . "/" . "hcluster.out";
    my $cpcmd = "cp $filename $copy_filename";
    unless(system($cpcmd) == 0) {
      warn "failed to copy $filename to $copy_filename\n";
    }
  }

  # FIXME: load the entire file in a hash and store in decreasing
  # order by cluster size this will make big clusters go first in the
  # alignment process, which makes sense since they are going to take
  # longer to process anyway
  my $clusterset;
  $clusterset = $protein_tree_adaptor->fetch_node_by_node_id($self->param('clusterset_id'));
  if (!defined($clusterset)) {
    $self->param('ccEngine', Bio::EnsEMBL::Compara::Graph::ConnectedComponents->new() );
    $clusterset = $self->param('ccEngine')->clusterset;
    $self->throw("no clusters generated") unless($clusterset);

    $clusterset->name("PROTEIN_TREES");
    $protein_tree_adaptor->store_node($clusterset);
    printf("clusterset_id %d\n", $clusterset->node_id);
    $self->param('clusterset_id', $clusterset->node_id);
    $mlss_adaptor->store($self->param('cluster_mlss'));
    printf("MLSS %d\n", $self->param('cluster_mlss')->dbID);
  }

    my $mlss_id = $self->param('cluster_mlss')->dbID;
    unless(defined($mlss_id)) {
        $mlss_id = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs(
            $self->param('cluster_mlss')->method_link_type,
            $self->param('cluster_mlss')->species_set
        )->dbID;
    }

  my $member_adaptor       = $self->compara_dba->get_MemberAdaptor;
  my $protein_tree_adaptor = $self->compara_dba->get_ProteinTreeAdaptor;

  open FILE, "$filename" or die $!;
  my $counter=1;
  while (<FILE>) {
    # 0       0       0       1.000   2       1       697136_68,
    # 1       0       39      1.000   3       5       1213317_31,1135561_22,288182_42,426893_62,941130_38,
    chomp $_;

    my ($cluster_id, $dummy1, $dummy2, $dummy3, $dummy4, $dummy5, $cluster_list) = split("\t",$_);

    next if ($dummy5 < 2);
    $cluster_list =~ s/\,^//;
    my @cluster_list = split(",",$cluster_list);

    # If it's a singleton, we don't store it as a protein tree
    next if (2 > scalar(@cluster_list));

    if($counter % 20 == 0) { 
      printf("%10d clusters\n", $counter); 
    }
    $counter++;

    my $cluster = new Bio::EnsEMBL::Compara::NestedSet;
    $clusterset->add_child($cluster);

    my $already_present;
    my $number_raw_cluster = scalar(@cluster_list);
    my $number_filtered_cluster = 0;
    if (defined($retry) && $retry >= 20) {
      foreach my $member_hcluster_id (@cluster_list) {
        my ($pmember_id,$genome_db_id) = split("_",$member_hcluster_id);
        my $aligned_member = $protein_tree_adaptor->fetch_AlignedMember_by_member_id_root_id($pmember_id, 1);
        if (defined($aligned_member)) {
          $already_present->{$aligned_member->member_id} = 1;
        }
      }
      next if ($number_raw_cluster == (scalar keys %$already_present));
    }

    foreach my $member_hcluster_id (@cluster_list) {
      my ($pmember_id,$genome_db_id) = split("_",$member_hcluster_id);
      if (defined($retry) && $retry >= 20) {
        my $member = $member_adaptor->fetch_by_dbID($pmember_id);
        my $longest_member = $member->gene_member->get_canonical_peptide_Member;
        next unless ($longest_member->member_id eq $member->member_id);
        next if (defined($already_present->{$member->member_id}));
      }
      my $node = new Bio::EnsEMBL::Compara::NestedSet;
      $node->node_id($pmember_id);
      $cluster->add_child($node);
      $cluster->clusterset_id($self->param('clusterset_id'));
      #leaves are NestedSet objects, bless to make into GeneTreeMember objects
      bless $node, "Bio::EnsEMBL::Compara::GeneTreeMember";

      #the building method uses member_id's to reference unique nodes
      #which are stored in the node_id value, copy to member_id
      $node->member_id($node->node_id);
      $node->method_link_species_set_id($mlss_id);
    }

    # Store the cluster
    $protein_tree_adaptor->store($cluster);
    #calc residue count total
    my $leafcount = scalar(@{$cluster->get_all_leaves});
    $cluster->store_tag('gene_count', $leafcount);
    if (defined($retry) && $retry >= 20) {
      $cluster->store_tag('readded_cluster', 1);
      print STDERR "Re-adding cluster ", $cluster->node_id, "with $leafcount members\n";
    }
  }
  close FILE;
  return 1;
}

sub dataflow_clusters {
  my $self = shift;

  my $retry = $self->param('retry');
  my $protein_tree_adaptor = $self->compara_dba->get_ProteinTreeAdaptor;
  my $starttime = time();

  my $clusterset;
  $clusterset = $protein_tree_adaptor->fetch_node_by_node_id($self->param('clusterset_id'));
  if (!defined($clusterset)) {
    $clusterset = $self->param('ccEngine')->clusterset;
  }
  my $clusters = $clusterset->children;
  my $counter = 0;
  foreach my $cluster (@{$clusters}) {
    my $output_id = sprintf("{'protein_tree_id'=>%d, 'clusterset_id'=>%d}", 
                            $cluster->node_id, $clusterset->node_id);
    if (defined($retry) and $retry==11 and $cluster->get_tagvalue("readded_cluster")!=1 ) {
      next; # Will skip flow unless is one of the readded
    }
    $self->dataflow_output_id($output_id, 2);
    printf("%10d clusters flowed\n", $counter) if($counter % 20 == 0);
    $counter++;
  }
}

1;
