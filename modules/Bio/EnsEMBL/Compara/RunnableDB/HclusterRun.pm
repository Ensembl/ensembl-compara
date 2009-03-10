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

  Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
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
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->parameters);

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

  #  $self->{gdba} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;
  #   my $input_gdb_id = $self->input_id;
  #   my $gdb = $self->{gdba}->fetch_by_dbID($input_gdb_id);
  #   throw("no genome_db for $input_gdb_id") unless(defined($gdb));
  #   $self->{gdb} = $gdb;

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
  if (defined $params->{'fasta_dir'}) {
    $self->{'fasta_dir'} = $params->{'fasta_dir'};
  }
  if (defined $params->{'outgroups'}) {
    foreach my $outgroup (@{$params->{'outgroups'}}) {
      $self->{outgroups}{$outgroup} = 1;
    }
  }
  if (defined $params->{'max_gene_count'}) {
    $self->{'max_gene_count'} = $params->{'max_gene_count'};
  }

  print("parameters...\n");
  printf("  fasta_dir      : %d\n", $self->{'fasta_dir'});
  printf("  species_set    : (%s)\n", join(',', @{$self->{'species_set'}}));
  printf("  outgroups      : (%s)\n", join(',', keys %{$self->{'outgroups'}}));
  printf("  max_gene_count : %d\n", $self->{'max_gene_count'});

  return;
}

sub run
{
  my $self = shift;

  $self->gather_input();
  $self->run_hcluster();
  return 1;
}

sub write_output {
  my $self = shift;

  $self->store_clusters();
  $self->dataflow_clusters;

  # modify input_job so that it now contains the clusterset_id
  my $outputHash = {};
  $outputHash = eval($self->input_id) if(defined($self->input_id) && $self->input_id =~ /^\s*\{.*\}\s*$/);
  $outputHash->{'clusterset_id'} = $self->{'clusterset_id'};
  my $output_id = $self->encode_hash($outputHash);

  return 1;

}

sub store_clusters {
  my $self = shift;

  my $mlssDBA = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $starttime = time();

  $self->{'ccEngine'} = new Bio::EnsEMBL::Compara::Graph::ConnectedComponents;
  my $clusterset = $self->{'ccEngine'}->clusterset;
  throw("no clusters generated") unless($clusterset);

  $clusterset->name("PROTEIN_TREES");
  $treeDBA->store_node($clusterset);
  printf("root_id %d\n", $clusterset->node_id);
  $self->{'clusterset_id'} = $clusterset->node_id;

  $mlssDBA->store($self->{'cluster_mlss'});
  printf("MLSS %d\n", $self->{'cluster_mlss'}->dbID);
  my $mlss_id = $self->{'cluster_mlss'}->dbID;

  my $filename = $self->worker_temp_directory . "/" . "hcluster.out";
  open FILE, "$filename" or die $!;
  my $counter=1;
  while (<FILE>) {
    # 0       0       0       1.000   2       1       697136_68,
    # 1       0       39      1.000   3       5       1213317_31,1135561_22,288182_42,426893_62,941130_38,
    chomp $_;

    my ($cluster_id, $dummy1, $dummy2, $dummy3, $dummy4, $dummy5, $cluster_list) = split("\t",$_);
    $cluster_list =~ s/\,^//;
    my @cluster_list = split(",",$cluster_list);

    # If it's a singleton, we don't store it as a protein tree
    next if (2 > scalar(@cluster_list));

    my $cluster = new Bio::EnsEMBL::Compara::NestedSet;
    $clusterset->add_child($cluster);

    foreach my $member_hcluster_id (@cluster_list) {
      my ($node_id,$genome_db_id) = split("_",$member_hcluster_id);
      my $node = new Bio::EnsEMBL::Compara::NestedSet;
      $node->node_id($node_id);
      $cluster->add_child($node);
      #leaves are NestedSet objects, bless to make into AlignedMember objects
      bless $node, "Bio::EnsEMBL::Compara::AlignedMember";

      #the building method uses member_id's to reference unique nodes
      #which are stored in the node_id value, copy to member_id
      $node->member_id($node->node_id);
      $node->method_link_species_set_id($mlss_id);
    }

    # Store the cluster
    $treeDBA->store($cluster);
    #calc residue count total
    my $leafcount = scalar(@{$cluster->get_all_leaves});
    $cluster->store_tag('gene_count', $leafcount);
    # $cluster->store_tag('include_brh', $self->{'include_brh'});
    # $cluster->store_tag('bsr_threshold', $self->{'bsr_threshold'});

    if($counter % 20 == 0) { printf("%10d clusters stored\n", $counter); }
    $counter++;
  }

  return 1;
}

##########################################
#
# internal methods
#
##########################################

sub gather_input {
  my $self = shift;

  my $starttime = time();
  my $fasta_dir = $self->{fasta_dir};
  my $output_dir = $self->worker_temp_directory;
  my $cmd;
  print "gathering input in $output_dir\n" if ($self->debug);

  $cmd ="cat $fasta_dir/*.hcluster.cat > $output_dir/hcluster.cat";
  unless(system($cmd) == 0) {
    $self->check_job_fail_options;
    throw("error gathering category files for Hcluster, $!\n");
  }
  printf("%1.3f secs to gather category entries\n", (time()-$starttime));
  $cmd ="cat $fasta_dir/*.hcluster.txt > $output_dir/hcluster.txt";
  unless(system($cmd) == 0) {
    $self->check_job_fail_options;
    throw("error gathering distance files for Hcluster, $!\n");
  }
  printf("%1.3f secs to gather distance entries\n", (time()-$starttime));
}

sub run_hcluster {
  my $self = shift;

  my $starttime = time();

  my $hcluster_executable = $self->analysis->program_file;
  unless (-e $hcluster_executable) {
    if (`uname -m` =~ /ia64/) {
      $hcluster_executable
        = "/nfs/acari/avilella/src/treesoft/trunk/ia64/hcluster/hcluster_sg";
    } else {
      $hcluster_executable
        = "/nfs/acari/avilella/src/treesoft/trunk/hcluster/hcluster_sg";
    }
  }

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);

  my $cmd = $hcluster_executable;
  my $max_count = int($self->{'max_gene_count'}/2); # hcluster can joint up to (max_count+(max_count-1))
  $cmd .= " ". "-m $max_count -w 0 -s 0.34 -O ";
  $cmd .= "-C " . $self->worker_temp_directory . "hcluster.cat ";
  $cmd .= "-o " . $self->worker_temp_directory . "hcluster.out ";
  $cmd .= " " . $self->worker_temp_directory . "hcluster.txt";
  print("Ready to execute:\n") if($self->debug);
  print("$cmd\n") if($self->debug);
  unless(system($cmd) == 0) {
    $self->check_job_fail_options;
    throw("error running hcluster, $!\n");
  }
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  printf("%1.3f secs to execute\n", (time()-$starttime));

  # printf("%1.3f secs to process\n", (time()-$starttime));
  return 1;
}

# sub store_clusters {
#   my $self = shift;

#   return unless($self->{'species_set'});
# #  my @species_set = @{$self->{'species_set'}};
# #  return unless @species_set;
#   return unless ($self->{'cluster_mlss'});

#   my $mlssDBA = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
#   my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
#   my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $starttime = time();

#   my $clusterset = $self->{'ccEngine'}->clusterset;
#   throw("no clusters generated") unless($clusterset);

#   $clusterset->name("PROTEIN_TREES");
#   $treeDBA->store_node($clusterset);
#   printf("root_id %d\n", $clusterset->node_id);
#   $self->{'clusterset_id'} = $clusterset->node_id;

#   #
#   # create Cluster MLSS
#   #
# #  $self->{'cluster_mlss'} = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
# #  $self->{'cluster_mlss'}->method_link_type('PROTEIN_TREES');
# #  my @genomeDB_set;
# #  foreach my $gdb_id (@species_set) {
# #    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
# #
# #    push @genomeDB_set, $gdb;
# #  }
# #  $self->{'cluster_mlss'}->species_set(\@genomeDB_set);
#   $mlssDBA->store($self->{'cluster_mlss'});
#   printf("MLSS %d\n", $self->{'cluster_mlss'}->dbID);

#   #
#   # Go through all the leaves which were generated by ConnectedComponents
#   # and convert them into AlignedMember objects with additional data
#   # to allow them to be stored correctly
#   #
#   my $mlss_id = $self->{'cluster_mlss'}->dbID;
#   my $leaves = $clusterset->get_all_leaves;
#   foreach my $leaf (@$leaves) {
#     #leaves are NestedSet objects, bless to make into AlignedMember objects
#     bless $leaf, "Bio::EnsEMBL::Compara::AlignedMember";

#     #the building method uses member_id's to reference unique nodes
#     #which are stored in the node_id value, copy to member_id
#     $leaf->member_id($leaf->node_id);
#     $leaf->method_link_species_set_id($mlss_id);
#   }


#   printf("storing the clusters\n");
#   printf("    loaded %d leaves\n", scalar(@$leaves));
#   my $count=0;
#   foreach my $mem (@$leaves) { $count++ if($mem->isa('Bio::EnsEMBL::Compara::AlignedMember'));}
#   printf("    loaded %d leaves which are members\n", $count);
#   printf("    loaded %d members in hash\n", $self->{'ccEngine'}->get_component_count);
#   printf("    %d clusters generated\n", $self->{'ccEngine'}->get_cluster_count);

#   my $clusters = $clusterset->children;
#   my $counter=1;
#   foreach my $cluster (@{$clusters}) {
#     $treeDBA->store($cluster);

#     #calc residue count total
#     my $leafcount = scalar(@{$cluster->get_all_leaves});
#     $cluster->store_tag('gene_count', $leafcount);
#     $cluster->store_tag('include_brh', $self->{'include_brh'});
#     $cluster->store_tag('bsr_threshold', $self->{'bsr_threshold'});

#     if($counter++ % 200 == 0) { printf("%10d clusters stored\n", $counter); }
#   }
#   printf("  %1.3f secs to store clusters\n", (time()-$starttime));
#   printf("tree_root : %d\n", $clusterset->node_id);
# }


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

sub check_job_fail_options
{
  my $self = shift;

  if($self->input_job->retry_count >= 5) {
    $self->input_job->update_status('FAILED');

    throw("HclusterRun job failed >=5 times: try something else and FAIL it");
  }
}

1;
