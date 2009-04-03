#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::NJTREE_PHYML

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $njtree_phyml = Bio::EnsEMBL::Compara::RunnableDB::NJTREE_PHYML->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$njtree_phyml->fetch_input(); #reads from DB
$njtree_phyml->run();
$njtree_phyml->output();
$njtree_phyml->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input
This must already have a multiple alignment run on it. It uses that alignment
as input into the NJTREE PHYML program which then generates a phylogenetic tree

input_id/parameters format eg: "{'protein_tree_id'=>1234}"
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::NJTREE_PHYML;

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

  $self->{'cdna'}           = 1;
  $self->{'bootstrap'}      = 1;
  $self->{'max_gene_count'} = 200;

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
  if ($self->{'protein_tree'}->get_tagvalue('gene_count') 
      > $self->{'max_gene_count'}) {
    # 3 is QuickTreeBreak -- 2 is NJTREE_PHYML jackknife
    $self->dataflow_output_id($self->input_id, 3);
    $self->input_job->update_status('FAILED');
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
    throw("NJTREE_PHYML : cluster size over threshold and FAIL it");
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
  $self->run_njtree_phyml;
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
  $self->store_proteintree;
}


sub DESTROY {
  my $self = shift;

  if($self->{'protein_tree'}) {
    printf("NJTREE_PHYML::DESTROY  releasing tree\n") if($self->debug);
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
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

  if (defined $params->{'njtree_phyml_analysis_data_id'}) {
    my $njtree_phyml_analysis_data_id = $params->{'njtree_phyml_analysis_data_id'};
    my $ada = $self->db->get_AnalysisDataAdaptor;
    my $new_params = eval($ada->fetch_by_dbID($njtree_phyml_analysis_data_id));
    if (defined $new_params) {
      $params = $new_params;
    }
  }

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  if(defined($params->{'protein_tree_id'})) {
    $self->{'protein_tree'} =  
         $self->{'comparaDBA'}->get_ProteinTreeAdaptor->
         fetch_node_by_node_id($params->{'protein_tree_id'});
  }
  $self->{'jackknife'} = $params->{'jackknife'} if(defined($params->{'jackknife'}));
  $self->{'cdna'} = $params->{'cdna'} if(defined($params->{'cdna'}));
  $self->{'max_gene_count'} = 
    $params->{'max_gene_count'} if(defined($params->{'max_gene_count'}));

  foreach my $key (qw[cdna max_gene_count species_tree_file honeycomb_dir use_genomedb_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  return;

}


sub print_params {
  my $self = shift;

  print("params:\n");
  print("  tree_id   : ", $self->{'protein_tree'}->node_id,"\n") if($self->{'protein_tree'});
  print("  cdna      : ", $self->{'cdna'},"\n");
}


sub run_njtree_phyml
{
  my $self = shift;

  my $starttime = time()*1000;

  $self->{'cdna'} = 1; #always use cdna for njtree_phyml
  $self->{'input_aln'} = $self->dumpTreeMultipleAlignmentToWorkdir
    (
     $self->{'protein_tree'}
    );
  return unless($self->{'input_aln'});

  $self->{'newick_file'} = $self->{'input_aln'} . "_njtree_phyml_tree.txt ";
  
  my $njtree_phyml_executable = $self->analysis->program_file || '';

  unless (-e $njtree_phyml_executable) {
    if (`uname -m` =~ /ia64/) {
      $njtree_phyml_executable = "/nfs/acari/avilella/src/treesoft/trunk/treebest/ia64/treebest";
    } else {
      # it is a linux machine
      # md5sum 91a9da7ad7d38ebedd5ce363a28d509b
      # $njtree_phyml_executable = "/lustre/work1/ensembl/avilella/bin/i386/njtree_gcc";
      # $njtree_phyml_executable = "/nfs/acari/avilella/src/_treesoft/treebest/treebest";
      $njtree_phyml_executable = "/nfs/acari/avilella/src/treesoft/trunk/treebest/treebest";
    }
  }

  throw("can't find a njtree executable to run\n") 
    unless(-e $njtree_phyml_executable);
  throw("can't find species_tree_file\n") 
    unless(-e $self->{'species_tree_file'});

  # ./njtree best -f spec-v4.1.nh -p tree -o $BASENAME.best.nhx \
  # $BASENAME.nucl.mfa -b 100 2>&1/dev/null

  my $cmd = $njtree_phyml_executable;
  if (1 == $self->{'bootstrap'}) {
    $cmd .= " best ";
    if (defined($self->{'species_tree_file'})) {
      $cmd .= " -f ". $self->{'species_tree_file'};
    }
    $cmd .= " ". $self->{'input_aln'};
    $cmd .= " -p tree ";
    $cmd .= " -o " . $self->{'newick_file'};
    my $logfile = $self->worker_temp_directory. "proteintree_". $self->{'protein_tree'}->node_id . ".log";
    my $errfile = $self->worker_temp_directory. "proteintree_". $self->{'protein_tree'}->node_id . ".err";
    $cmd .= " 1>$logfile 2>$errfile";
    #     $cmd .= " 2>&1 > /dev/null" unless($self->debug);

    $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
    print("$cmd\n") if($self->debug);
    my $worker_temp_directory = $self->worker_temp_directory;

    unless(system("cd $worker_temp_directory; $cmd") == 0) {
      print("$cmd\n");
      open ERRFILE,"$errfile" or die "couldnt open logfile $errfile: $!\n";
      while (<ERRFILE>) {
        if ($_ =~ /NNI/) {
          # Do jack-knife treebest starting by the sequence with more Ns
          my $jackknife_value = $self->{'jackknife'} if (defined($self->{'jackknife'}));
          $jackknife_value++;
          my $output_id = sprintf("{'protein_tree_id'=>%d, 'clusterset_id'=>1, 'jackknife'=>$jackknife_value}", $self->{'protein_tree'}->node_id);
          $self->input_job->input_id($output_id);
          $self->dataflow_output_id($output_id, 2);
          $self->input_job->update_status('FAILED');
          $self->{'protein_tree'}->release_tree;
          $self->{'protein_tree'} = undef;
          warn("NJTREE_PHYML : NNI error, resubmitting as jackknife NJTREE_PHYML");
          return undef;
        }
      }
      $self->check_job_fail_options;
      throw("error running njtree phyml, $!\n");
    }

    $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  } elsif (0 == $self->{'bootstrap'}) {
    # first part
    # ./njtree phyml -nS -f species_tree.nh -p 0.01 -o $BASENAME.cons.nh $BASENAME.nucl.mfa
    $cmd = $njtree_phyml_executable;
    $cmd .= " phyml -nS";
    if (defined($self->{'species_tree_file'})) {
      $cmd .= " -f ". $self->{'species_tree_file'};
    }
    $cmd .= " ". $self->{'input_aln'};
    $cmd .= " -p 0.01 ";
    $self->{'intermediate_newick_file'} = $self->{'input_aln'} . "_intermediate_njtree_phyml_tree.txt ";
    $cmd .= " -o " . $self->{'intermediate_newick_file'};
    $cmd .= " 2>&1 > /dev/null" unless($self->debug);

    print("$cmd\n") if($self->debug);
    my $worker_temp_directory = $self->worker_temp_directory;
    unless(system("cd $worker_temp_directory; $cmd") == 0) {
      print("$cmd\n");
      $self->check_job_fail_options;
      throw("error running njtree phyml noboot (step 1 of 2), $!\n");
    }
    # second part
    # nice -n 19 ./njtree sdi -s species_tree.nh $BASENAME.cons.nh > $BASENAME.cons.nhx
    $cmd = $njtree_phyml_executable;
    $cmd .= " sdi ";
    if (defined($self->{'species_tree_file'})) {
      $cmd .= " -s ". $self->{'species_tree_file'};
    }
    $cmd .= " ". $self->{'intermediate_newick_file'};
    $cmd .= " 1> " . $self->{'newick_file'};
    $cmd .= " 2> /dev/null" unless($self->debug);

    $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
    print("$cmd\n") if($self->debug);
    my $worker_temp_directory = $self->worker_temp_directory;
    unless(system("cd $worker_temp_directory; $cmd") == 0) {
      print("$cmd\n");
      $self->check_job_fail_options;
      throw("error running njtree phyml noboot (step 2 of 2), $!\n");
    }
    $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  } else {
    throw("NJTREE PHYML -- wrong bootstrap option");
  }

  #parse the tree into the datastucture
  $self->parse_newick_into_proteintree;

  my $runtime = time()*1000-$starttime;

  $self->{'protein_tree'}->store_tag('NJTREE_PHYML_runtime_msec', $runtime);
}


sub check_job_fail_options
{
  my $self = shift;

  if ($self->input_job->retry_count == 1) {
    if ($self->{'protein_tree'}->get_tagvalue('gene_count') > 200 && !defined($self->worker->{HIGHMEM})) {
      $self->input_job->adaptor->reset_highmem_job_by_dbID($self->input_job->dbID);
      $self->DESTROY;
      throw("NJTREE PHYML job too big: try something else and FAIL it");
    }
  }

  # This will go to QuickTreeBreak
  if($self->input_job->retry_count >= 2 && !defined($self->{'jackknife'})) {
    $self->dataflow_output_id($self->input_id, 3);
    $self->input_job->update_status('FAILED');

    $self->DESTROY;
    throw("NJTREE PHYML job failed >=3 times: try something else and FAIL it");
  }
}


########################################################
#
# ProteinTree input/output section
#
########################################################

sub dumpTreeMultipleAlignmentToWorkdir
{
  my $self = shift;
  my $tree = shift;

  my $leafcount = scalar(@{$tree->get_all_leaves});
  if($leafcount<3) {
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
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
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
     -cdna=>$self->{'cdna'},
     -stop2x => 1,
     %sa_params
    );
  $sa->set_displayname_flat(1);
  if (defined($self->{'jackknife'})) {
    # my $coverage_hash;
    my $empty_hash;
    foreach my $seq ($sa->each_seq) {
      my $sequence = $seq->seq;
      $sequence =~ s/\-//g;
      my $full_length = length($sequence);
      $sequence =~ s/N//g;
      my $covered_length = length($sequence);
      my $coverage_proportion = $covered_length/$full_length;
      my $empty_length = $full_length - $covered_length;
      # $coverage_hash->{$coverage_proportion} = $seq->display_id if ($coverage_proportion < 1);
      $empty_hash->{$empty_length} = $seq->display_id if ($empty_length > 0);
    }
    my @lowest = sort {$b<=>$a} keys %$empty_hash;
    my $i = 0;
    while ($i < $self->{jackknife}) {
      $sa->remove_seq($sa->each_seq_with_id($empty_hash->{$lowest[$i]}));
      $sa = $sa->remove_gaps(undef,1);
      $i++;
    }
  }

  my $alignIO = Bio::AlignIO->newFh
    (
     -fh => \*OUTSEQ,
     -format => "fasta"
    );
  print $alignIO $sa;

  close OUTSEQ;

  $self->{'input_aln'} = $aln_file;
  return $aln_file;
}


sub store_proteintree
{
  my $self = shift;

  return unless($self->{'protein_tree'});

  printf("PHYML::store_proteintree\n") if($self->debug);
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $treeDBA->sync_tree_leftright_index($self->{'protein_tree'});
  $treeDBA->store($self->{'protein_tree'});
  $treeDBA->delete_nodes_not_in_tree($self->{'protein_tree'});

  if($self->debug >1) {
    print("done storing - now print\n");
    $self->{'protein_tree'}->print_tree;
  }

  $self->{'protein_tree'}->store_tag('PHYML_alignment', 'njtree_phyml');
  $self->{'protein_tree'}->store_tag('reconciliation_method', 'njtree_best');
  $self->store_tags($self->{'protein_tree'});

  $self->_store_tree_tags();

  return undef;
}

sub store_tags
{
  my $self = shift;
  my $node = shift;

  if(defined($self->{'jackknife'})) {
    my $leaf_count = $self->{protein_tree}->num_leaves;
    $self->{protein_tree}->adaptor->delete_tag($self->{protein_tree}->node_id,'gene_count');
    $self->{protein_tree}->store_tag('gene_count', $leaf_count);
  }

  if($node->get_tagvalue("Duplication") eq '1') {
    if($self->debug) { printf("store duplication : "); $node->print_node; }
    $node->store_tag('Duplication', 1);
  } else {
    $node->store_tag('Duplication', 0);
  }

  if (defined($node->get_tagvalue("B"))) {
    my $bootstrap_value = $node->get_tagvalue("B");
    if (defined($bootstrap_value) && $bootstrap_value ne '') {
      if ($self->debug) {
        printf("store bootstrap : $bootstrap_value "); $node->print_node;
      }
      $node->store_tag('Bootstrap', $bootstrap_value);
    }
  }
  if (defined($node->get_tagvalue("DD"))) {
    my $dubious_dup = $node->get_tagvalue("DD");
    if (defined($dubious_dup) && $dubious_dup ne '') {
      if ($self->debug) {
        printf("store dubious_duplication : $dubious_dup "); $node->print_node;
      }
      $node->store_tag('dubious_duplication', $dubious_dup);
    }
  }
  if (defined($node->get_tagvalue("E"))) {
    my $n_lost = $node->get_tagvalue("E");
    $n_lost =~ s/.{2}//;        # get rid of the initial $-
    my @lost_taxa = split('-',$n_lost);
    my %lost_taxa;
    foreach my $taxon (@lost_taxa) {
      $lost_taxa{$taxon} = 1;
    }
    foreach my $taxon (keys %lost_taxa) {
      if ($self->debug) {
        printf("store lost_taxon_id : $taxon "); $node->print_node;
      }
      $node->store_tag('lost_taxon_id', $taxon);
    }
  }
  if (defined($node->get_tagvalue("SISi"))) {
    my $sis_score = $node->get_tagvalue("SISi");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store SISi : $sis_score "); $node->print_node;
      }
      $node->store_tag('SISi', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SISu"))) {
    my $sis_score = $node->get_tagvalue("SISu");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store SISu : $sis_score "); $node->print_node;
      }
      $node->store_tag('SISu', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SIS"))) {
    my $sis_score = $node->get_tagvalue("SIS");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store species_intersection_score : $sis_score "); $node->print_node;
      }
      $node->store_tag('species_intersection_score', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SIS1"))) {
    my $sis_score = $node->get_tagvalue("SIS1");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store SIS1 : $sis_score "); $node->print_node;
      }
      $node->store_tag('SIS1', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SIS2"))) {
    my $sis_score = $node->get_tagvalue("SIS2");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store SIS2 : $sis_score "); $node->print_node;
      }
      $node->store_tag('SIS2', $sis_score);
    }
  }
#   if (defined($node->get_tagvalue("SIS3"))) {
#     my $sis_score = $node->get_tagvalue("SIS3");
#     if (defined($sis_score) && $sis_score ne '') {
#       if ($self->debug) {
#         printf("store SIS3 : $sis_score "); $node->print_node;
#       }
#       $node->store_tag('SIS3', $sis_score);
#     }
#  }

  foreach my $child (@{$node->children}) {
    $self->store_tags($child);
  }
  return undef;
}

sub parse_newick_into_proteintree
{
  my $self = shift;
  my $newick_file =  $self->{'newick_file'};
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
  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or throw("Couldnt open newick file [$newick_file]");
  while(<FH>) { $newick .= $_;  }
  close(FH);

  my $newtree = 
    Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
  $newtree->print_tree(20) if($self->debug > 1);
  # get rid of the taxon_id needed by njtree -- name tag
  foreach my $leaf (@{$newtree->get_all_leaves}) {
    my $njtree_phyml_name = $leaf->get_tagvalue('name');
    $njtree_phyml_name =~ /(\d+)\_\d+/;
    my $member_name = $1;
    $leaf->add_tag('name', $member_name);
  }

  # Leaves of newick tree are named with member_id of members from
  # input tree move members (leaves) of input tree into newick tree to
  # mirror the 'member_id' nodes
  foreach my $member (@{$tree->get_all_leaves}) {
    my $tmpnode = $newtree->find_node_by_name($member->member_id);
    if($tmpnode) {
      $tmpnode->add_child($member, 0.0);
      $tmpnode->minimize_node; #tmpnode is now redundant so it is removed
    } else {
      print("unable to find node in newick for member"); 
      $member->print_member;
    }
  }
  
  # Merge the trees so that the children of the newick tree are now
  # attached to the input tree's root node
  $tree->merge_children($newtree);

  # Newick tree is now empty so release it
  $newtree->release_tree;

  $tree->print_tree if($self->debug);
  # check here on the leaf to test if they all are AlignedMembers as
  # minimize_tree/minimize_node might not work properly
  foreach my $leaf (@{$self->{'protein_tree'}->get_all_leaves}) {
    unless($leaf->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
      throw("Phyml tree does not have all leaves as AlignedMember\n");
    }
  }

  return undef;
}

sub _store_tree_tags {
    my $self = shift;
    my $tree = $self->{'protein_tree'};
    my $pta = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;

    print "Storing Tree tags...\n";
    $tree->_load_tags();

    my @leaves = @{$tree->get_all_leaves};
    my @nodes = @{$tree->get_all_nodes};

    # Node is a root node (full tree).
    my $node_is_root = 0;
    my @roots = @{$pta->fetch_all_roots()};
    foreach my $root (@roots) {
	$node_is_root = 1 if ($root->node_id == $tree->parent->node_id);
    }
    $tree->store_tag("node_is_root",$node_is_root);

    # Node is leaf node.
    my $node_is_leaf = 0;
    $node_is_leaf = 1 if ($tree->is_leaf);
    $tree->store_tag("node_is_leaf",$node_is_leaf);

    # Tree number of leaves.
    my $tree_num_leaves = scalar(@leaves);
    $tree->store_tag("tree_num_leaves",$tree_num_leaves);

    # Tree number of human peptides contained.
    my $num_hum_peps = 0;
    foreach my $leaf (@leaves) {
	$num_hum_peps++ if ($leaf->taxon_id == 9606);
    }
    $tree->store_tag("tree_num_human_peps",$num_hum_peps);

    # Tree max root-to-tip distance.
    my $tree_max_length = $tree->max_distance;
    $tree->store_tag("tree_max_length",$tree_max_length);

    # Tree max single branch length.
    my $tree_max_branch = 0;
    foreach my $node (@nodes) {
	my $dist = $node->distance_to_parent;
	$tree_max_branch = $dist if ($dist > $tree_max_branch);
    }
    $tree->store_tag("tree_max_branch",$tree_max_branch);

    # Tree number of duplications and speciations.
    my $tree_num_leaves = scalar(@{$tree->get_all_leaves});
    my $num_dups = 0;
    my $num_specs = 0;
    foreach my $node (@{$tree->get_all_nodes}) {
	my $dup = $node->get_tagvalue("Duplication");
	if ($dup ne '' && $dup > 0) {
	    $num_dups++;
	} else {
	    $num_specs++;
	}
    }
    $tree->store_tag("tree_num_dup_nodes",$num_dups);
    $tree->store_tag("tree_num_spec_nodes",$num_specs);

    print "Done storing stuff!\n" if ($self->debug);
}


1;
