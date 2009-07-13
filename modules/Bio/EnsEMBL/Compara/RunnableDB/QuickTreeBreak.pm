#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::QuickTreeBreak

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $quicktreebreak = Bio::EnsEMBL::Compara::RunnableDB::QuickTreeBreak->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$quicktreebreak->fetch_input(); #reads from DB
$quicktreebreak->run();
$quicktreebreak->output();
$quicktreebreak->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input.

This must already have a multiple alignment run on it. It uses that
alignment as input into the QuickTree program which then generates a
simple phylogenetic tree to be broken down into 2 pieces.

Google QuickTree to get the latest tar.gz from the Sanger.
Google sreformat to get the sequence reformatter that switches from fasta to stockholm.

input_id/parameters format eg: "{'protein_tree_id'=>1234,'clusterset_id'=>1}"
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Javier Herrero on EnsEMBL/Compara: jherrero@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::QuickTreeBreak;

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::SimpleAlign;
use Bio::AlignIO;

use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'max_gene_count'} = 1500; # Can be overriden later

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  $self->print_params if($self->debug);
  $self->check_job_fail_options;
  $self->check_if_exit_cleanly;

  unless($self->{'protein_tree'}) {
    throw("undefined ProteinTree as input\n");
  }

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs NJTREE PHYML
    Returns :   none
    Args    :   none

=cut


sub run {
  my $self = shift;
  $self->check_if_exit_cleanly;
  $self->run_quicktreebreak;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores proteintree
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

  $self->check_if_exit_cleanly;
  $self->store_proteintrees;
}


sub DESTROY {
  my $self = shift;

  if($self->{'protein_tree'}) {
    printf("QuickTreeBreak::DESTROY releasing tree\n") if($self->debug);

    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;

    $self->{'max_subtree'}->release_tree;
    $self->{'new_subtree'}->release_tree;
    $self->{'remaining_subtree'}->release_tree;

    $self->{'max_subtree'} = undef;
    $self->{'new_subtree'} = undef;
    $self->{'remaining_subtree'} = undef;
  }

  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  if(defined($params->{'protein_tree_id'})) {
    $self->{'protein_tree'} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor->fetch_node_by_node_id($params->{'protein_tree_id'});
  }
  
  foreach my $key (qw[max_gene_count use_genomedb_id clusterset_id sreformat_exe]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  return;
}


sub print_params {
  my $self = shift;

  print("params:\n");
  print("  tree_id   : ", $self->{'protein_tree'}->node_id,"\n") if($self->{'protein_tree'});
}


sub run_quicktreebreak {
  my $self = shift;

  my $starttime = time()*1000;

  $self->{'input_aln'} = $self->dumpTreeMultipleAlignmentToWorkdir
    (
     $self->{'protein_tree'}
    );
  return unless($self->{'input_aln'});

  $self->{'newick_file'} = $self->{'input_aln'} . "_quicktreebreak_tree.txt ";

  my $quicktreebreak_executable = $self->analysis->program_file || '';

  unless (-e $quicktreebreak_executable) {
    $quicktreebreak_executable = "/nfs/acari/avilella/src/quicktree/quicktree_1.1/bin/quicktree";
  }

  throw("can't find a quicktree executable to run. Tried $quicktreebreak_executable \n") 
    unless(-e $quicktreebreak_executable);

  my $cmd = $quicktreebreak_executable;
  $cmd .= " -out t -in a";
  $cmd .= " ". $self->{'input_aln'};

  #/nfs/acari/avilella/src/quicktree/quicktree_1.1/bin/quicktree -out t
  # -in a /tmp/worker.12270/proteintree_517373.stk

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  open(RUN, "$cmd |") or $self->throw("error running quicktree, $!\n");
  my @output = <RUN>;
  my $exit_status = close(RUN);
  if (!$exit_status) {
    $self->throw("error running quicktree, $!\n");
  }
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  foreach my $line (@output) {
    $line =~ s/\n//;
    $self->{quicktree_newick_string} .= $line;
  }

  #parse the tree into the datastucture
  $self->generate_subtrees;

  my $runtime = time()*1000-$starttime;
  $self->{'protein_tree'}->store_tag('QuickTreeBreak_runtime_msec', $runtime);
}


sub check_job_fail_options {
  my $self = shift;

  if ($self->input_job->retry_count > 8) {
    # $self->input_job->adaptor->reset_highmem_job_by_dbID($self->input_job->dbID);
    $self->input_job->update_status('FAILED');
    $self->DESTROY;
    throw("QuickTree job failed");
  }
}


########################################################
#
# ProteinTree input/output section
#
########################################################

sub dumpTreeMultipleAlignmentToWorkdir {
  my $self = shift;
  my $tree = shift;

  $self->{original_leafcount} = scalar(@{$tree->get_all_leaves});
  if($self->{original_leafcount}<3) {
    printf(STDERR "tree cluster %d has <3 proteins - can not build a tree\n", 
           $tree->node_id);
    return undef;
  }

  $self->{'file_root'} = 
    $self->worker_temp_directory. "proteintree_". $tree->node_id;
  $self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $self->{'file_root'} . ".aln";
  return $aln_file if(-e $aln_file);
  if($self->debug) {
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $self->{original_leafcount});
    print("aln_file = '$aln_file'\n");
  }

  open(OUTSEQ, ">$aln_file")
    or $self->throw("Error opening $aln_file for write");

  # Using append_taxon_id will give nice seqnames_taxonids needed for
  # njtree species_tree matching
  my %sa_params = ($self->{use_genomedb_id}) ?	('-APPEND_GENOMEDB_ID', 1) :
    ('-APPEND_TAXON_ID', 1);

  my $sa = $tree->get_SimpleAlign
    (
     -id_type => 'MEMBER',
     %sa_params
    );
  $sa->set_displayname_flat(1);
  my $alignIO = Bio::AlignIO->newFh
    (
     -fh => \*OUTSEQ,
     -format => "fasta"
    );
  print $alignIO $sa;

  close OUTSEQ;

  print STDERR "Using sreformat to change to stockholm format\n" if ($self->debug);
  my $stk_file = $self->{'file_root'} . ".stk";
  
  my $sreformat_exe = $self->{sreformat_exe};
  $sreformat_exe = '/usr/local/ensembl/bin/sreformat' unless -e $sreformat_exe;
  
  my $cmd = "$sreformat_exe stockholm $aln_file > $stk_file";

  unless( system("$cmd") == 0) {
    print("$cmd\n");
    $self->check_job_fail_options;
    throw("error running sreformat with cmd $cmd: $!\n");
  }

  $self->{'input_aln'} = $stk_file;
  return $stk_file;
}


sub store_proteintrees {
  my $self = shift;

  $self->delete_original_cluster;
  $self->store_clusters;

  if($self->debug >1) {
    print("done storing\n");
  }

  return undef;
}

sub store_clusters {
  my $self = shift;

  my $mlssDBA = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $starttime = time();

  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  throw("no clusterset found: $!\n") unless($clusterset);

  $clusterset->no_autoload_children; # Important so that only the two below are used
  $clusterset->add_child($self->{new_subtree});
  $clusterset->add_child($self->{remaining_subtree});

  my $clusters = $clusterset->children;
  foreach my $cluster (@{$clusters}) {
    my $node_id = $treeDBA->store($cluster);
    # Although the leaves wont have the right root_id pointing to the $cluster->node_id,
    # this will be solved when we store back the results after the new MSA job.

    #calc residue count total
    my $leafcount = scalar(@{$cluster->get_all_leaves});
    $cluster->store_tag('gene_count', $leafcount);
    $cluster->store_tag('original_cluster', $self->{'original_cluster'}->node_id);
    print STDERR "Stored $node_id with $leafcount leaves\n" if ($self->debug);

    # Dataflow clusters
    # This will create a new MSA alignment job for each of the newly generated clusters
    my $output_id = sprintf("{'protein_tree_id'=>%d, 'clusterset_id'=>%d}", 
                            $node_id, $clusterset->node_id);
    $DB::single=1;1;
    $self->dataflow_output_id($output_id, 2); # FIXME? should it be 1 or 2?
    print STDERR "Created new cluster $node_id\n";
  }
}

sub delete_original_cluster {
  my $self = shift;

  my $delete_time = time();
  my $original_cluster = $self->{'original_cluster'}->node_id;
 #   $original_cluster->store_tag('cluster_had_to_be_broken_down',1);
  $self->delete_old_orthotree_tags;

  my $tree_node_id = $original_cluster;
  my $sql1 = "delete h.*, hm.* from homology h, homology_member hm where h.homology_id=hm.homology_id and h.tree_node_id=$tree_node_id";
  my $sth1 = $self->dbc->prepare($sql1);
  $sth1->execute;
  $sth1->finish;

  $self->{original_cluster}->adaptor->store_supertree_node_and_under($self->{original_cluster});
  printf("%1.3f secs to copy old cluster $original_cluster into supertree tables\n", time()-$delete_time);
  $self->{original_cluster}->adaptor->delete_node_and_under($self->{original_cluster});
  printf("%1.3f secs to delete old cluster $original_cluster\n", time()-$delete_time);

  return 1;

}

sub delete_old_orthotree_tags {
  my $self = shift;

  print "deleting old orthotree tags\n" if ($self->debug);
  my @node_ids;
  my $left_index  = $self->{'protein_tree'}->left_index;
  my $right_index = $self->{'protein_tree'}->right_index;
  my $tree_root_node_id = $self->{'protein_tree'}->node_id;
  # Include the root_id as well as the rest of the nodes within the tree
  push @node_ids, $tree_root_node_id;
  my $sql = "select ptn.node_id from protein_tree_node ptn where ptn.left_index>$left_index and ptn.right_index<$right_index";
  my $sth = $self->dbc->prepare($sql);
  $sth->execute;
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($node_id) = @$aref;
    push @node_ids, $node_id;
  }

  my @list_ids;
  foreach my $id (@node_ids) {
    push @list_ids, $id;
    if (scalar @list_ids == 2000) {
      my $sql = "delete from protein_tree_tag where node_id in (".join(",",@list_ids).") and tag in ('duplication_confidence_score','taxon_id','taxon_name','OrthoTree_runtime_msec','OrthoTree_types_hashstr')";
      my $sth = $self->dbc->prepare($sql);
      $sth->execute;
      $sth->finish;
      @list_ids = ();
    }
  }
  
  if (scalar @list_ids) {
    my $sql = "delete from protein_tree_tag where node_id in (".join(",",@list_ids).") and tag in ('duplication_confidence_score','taxon_id','taxon_name','OrthoTree_runtime_msec','OrthoTree_types_hashstr')";
    my $sth = $self->dbc->prepare($sql);
    $sth->execute;
    $sth->finish;
    @list_ids = ();
  }

  return undef;
}

sub generate_subtrees {
  my $self = shift;
  my $newick =  $self->{'quicktree_newick_string'};
  my $tree = $self->{'protein_tree'};

  #cleanup old tree structure- 
  #  flatten and reduce to only AlignedMember leaves
  $tree->flatten_tree;
  $tree->print_tree(20) if($self->debug);
  foreach my $node (@{$tree->get_all_leaves}) {
    next if($node->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    $node->disavow_parent;
  }

  #parse newick into a new tree object structure
  my $newtree = 
    Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
  $newtree->print_tree(20) if($self->debug > 1);
  # get rid of the taxon_id needed by njtree -- name tag
  foreach my $leaf (@{$newtree->get_all_leaves}) {
    my $quicktreebreak_name = $leaf->get_tagvalue('name');
    $quicktreebreak_name =~ /(\d+)\_\d+/;
    my $member_name = $1;
    $leaf->add_tag('name', $member_name);
    bless $leaf, "Bio::EnsEMBL::Compara::AlignedMember";
    $leaf->member_id($member_name);
  }

  # Break the tree by immediate children recursively
  my @children;
  my $keep_braking = 1;
  $self->{max_subtree} = $newtree;
  while ($keep_braking) {
    @children = @{$self->{max_subtree}->children};
    my $max_num_leaves = 0;
    foreach my $child (@children) {
      my $num_leaves = scalar(@{$child->get_all_leaves});
      if ($num_leaves > $max_num_leaves) {
        $max_num_leaves = $num_leaves;
        $self->{max_subtree} = $child;
      }
    }
    # Broke down to half, happy with it
    my $proportion = ($max_num_leaves*100/$self->{original_leafcount});
    print STDERR "QuickTreeBreak iterate -- $max_num_leaves ($proportion)\n" if ($self->debug);
    if ($proportion <= 50) {
      $keep_braking = 0;
    }
  }

  # Create a copy of what is not max_subtree
  $self->{remaining_subtree} = $self->{protein_tree}->copy;
  $self->{new_subtree}       = $self->{protein_tree}->copy;
  $self->{new_subtree}->flatten_tree;
  $self->{remaining_subtree}->flatten_tree;
  my $subtree_leaves;
  foreach my $leaf (@{$self->{max_subtree}->get_all_leaves}) {
    $subtree_leaves->{$leaf->member_id} = 1;
  }
  foreach my $leaf (@{$self->{new_subtree}->get_all_leaves}) {
    unless (defined $subtree_leaves->{$leaf->member_id}) {
      print $leaf->name," leaf disavowing parent\n" if $self->debug;
      $leaf->disavow_parent;
    }
  }
  foreach my $leaf (@{$self->{remaining_subtree}->get_all_leaves}) {
    if (defined $subtree_leaves->{$leaf->member_id}) {
      print $leaf->name," leaf disavowing parent\n" if $self->debug;
      $leaf->disavow_parent;
    }
  }
  $self->{remaining_subtree} = $self->{remaining_subtree}->minimize_tree;
  $self->{new_subtree} = $self->{new_subtree}->minimize_tree;

  # Some checks
  $self->throw("QuickTreeBreak: Failed to generate subtrees: $!\n")  unless(defined($self->{'new_subtree'}) && defined($self->{'remaining_subtree'}));
  my  $final_original_num = scalar @{$self->{protein_tree}->get_all_leaves};
  my       $final_max_num = scalar @{$self->{new_subtree}->get_all_leaves};
  my $final_remaining_num = scalar @{$self->{remaining_subtree}->get_all_leaves};

  if(($final_max_num + $final_remaining_num) != $final_original_num) {
    $self->throw("QuickTreeBreak: Incorrect sum of leaves [$final_max_num + $final_remaining_num != $final_original_num]: $!\n");
  }

  $self->{'original_cluster'} = $self->{protein_tree};
  return undef;
}

1;
