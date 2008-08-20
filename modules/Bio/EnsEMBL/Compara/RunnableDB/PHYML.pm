#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PHYML

=cut

=head1 SYNOPSIS

my $db    = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $phyml = Bio::EnsEMBL::Compara::RunnableDB::PHYML->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$phyml->fetch_input(); #reads from DB
$phyml->run();
$phyml->output();
$phyml->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input
This must already have a multiple alignment run on it.  It uses that alignment
as input into the PHYML program which then generates a phylogenetic tree

input_id/parameters format eg: "{'protein_tree_id'=>1234}"
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree

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

package Bio::EnsEMBL::Compara::RunnableDB::PHYML;

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

  $self->{'transition_transversion_ratio'}           = 0.0;
  $self->{'number_of_substitution_rate_categories'}  = 4;
  $self->{'gamma_distribution_parameter'}            = 1;
  $self->{'cdna'}                                    = 1;
  $self->{'max_gene_count'} = 1000000;

  $self->check_job_fail_options;

#  if($self->input_job->retry_count >= 3) {
#    $self->dataflow_output_id($self->input_id, 2);
#    $self->input_job->update_status('FAILED');
#    throw("PHYML job failed >3 times: try something else and FAIL it");
#  }

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  $self->print_params if($self->debug);

  unless($self->{'protein_tree'}) {
    throw("undefined ProteinTree as input\n");
  }
  if ($self->{'protein_tree'}->get_tagvalue('gene_count') > $self->{'max_gene_count'}) {
    $self->dataflow_output_id($self->input_id, 2);
    $self->input_job->update_status('FAILED');
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
    throw("PHYML : cluster size over threshold and FAIL it");
  }
  
  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs PHYML
    Returns :   none
    Args    :   none
    
=cut

sub run
{
  my $self = shift;
  $self->run_phyml;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   parse clustalw output and update family and family_member tables
    Returns :   none
    Args    :   none
    
=cut

sub write_output {
  my $self = shift;

  $self->store_proteintree;
}
 
 
sub DESTROY {
  my $self = shift;

  if($self->{'protein_tree'}) {
    printf("PHYML::DESTROY  releasing tree\n") if($self->debug);
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
  $self->{'cdna'} = $params->{'cdna'} if(defined($params->{'cdna'}));
  $self->{'max_gene_count'} = $params->{'max_gene_count'} if(defined($params->{'max_gene_count'}));
  
  return;

}


sub print_params {
  my $self = shift;

  print("params:\n");
  print("  tree_id   : ", $self->{'protein_tree'}->node_id,"\n") if($self->{'protein_tree'});
  print("  cdna      : ", $self->{'cdna'},"\n");
}


sub run_phyml
{
  my $self = shift;

  my $starttime = time()*1000;

  $self->{'input_aln'} = $self->dumpTreeMultipleAlignmentToWorkdir($self->{'protein_tree'});
  return unless($self->{'input_aln'});
  
  $self->{'newick_file'} = $self->{'input_aln'} . "_phyml_tree.txt ";

  my $phyml_executable = $self->analysis->program_file;
  unless (-e $phyml_executable) {
    $phyml_executable = "/nfs/acari/jessica/bin/alpha-dec-osf4.0/phyml";
    if (-e "/proc/version") {
      # it is a linux machine
      $phyml_executable = "/nfs/acari/jessica/bin/i386/phyml";
    }
  }
  unless (-e $phyml_executable) {
    $phyml_executable = "/usr/local/ensembl/bin/phyml";
  }

  throw("can't find a phyml executable to run\n") unless(-e $phyml_executable);

  #./phyml seqs2 1 i 1 0 JTT 0.0 4 1.0 BIONJ n n 
  my $cmd = $phyml_executable;
  $cmd .= " ". $self->{'input_aln'};  
  if($self->{'cdna'}) {
    $cmd .= " 0 i 1 0 HKY e 0.0 4 e BIONJ y y";
  } else {
    $cmd .= " 1 i 1 0 WAG 0.0 4 e BIONJ y y "; #AA, interleaved, 1 dataset, no bootstrap
  }
  $cmd .= " 2>&1 > /dev/null" unless($self->debug);

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  unless(system($cmd) == 0) {
    print("$cmd\n");
    $self->check_job_fail_options;
    throw("error running phyml, $!\n");
  }
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  
  #parse the tree into the datastucture
  $self->parse_newick_into_proteintree;
  
  my $runtime = time()*1000-$starttime;
  
  $self->{'protein_tree'}->store_tag('PHYML_runtime_msec', $runtime);
  
}


sub check_job_fail_options
{
  my $self = shift;

  if($self->input_job->retry_count >= 2) {
    $self->dataflow_output_id($self->input_id, 2);
    $self->input_job->update_status('FAILED');
  
    if($self->{'protein_tree'}) {
      $self->{'protein_tree'}->release_tree;
      $self->{'protein_tree'} = undef;
    }
    throw("PHYML job failed >=3 times: try something else and FAIL it");
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
    printf(STDERR "tree cluster %d has <3 proteins - can not build a tree\n", $tree->node_id);
    return undef;
  }
  
  $self->{'file_root'} = $self->worker_temp_directory. "proteintree_". $tree->node_id;
  $self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $clw_file = $self->{'file_root'} . ".aln";
  return $clw_file if(-e $clw_file);
  if($self->debug) {
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    print("clw_file = '$clw_file'\n");
  }

  open(OUTSEQ, ">$clw_file")
    or $self->throw("Error opening $clw_file for write");

  my $sa = $tree->get_SimpleAlign(-id_type => 'MEMBER', -cdna=>$self->{'cdna'}, -stop2x => 1);
  
  my $alignIO = Bio::AlignIO->newFh(-fh => \*OUTSEQ,
                                    -interleaved => 1,
                                    -format => "phylip"
                                   );
  print $alignIO $sa;

  close OUTSEQ;
  
  $self->{'input_aln'} = $clw_file;
  return $clw_file;
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
  
  if($self->{'cdna'}) {
    $self->{'protein_tree'}->store_tag('PHYML_alignment', 'cdna');
  } else {
    $self->{'protein_tree'}->store_tag('PHYML_alignment', 'aa');
  }
  $self->{'protein_tree'}->store_tag('tree_method', 'PHYML');
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
  $tree->print_tree if($self->debug);
  foreach my $node (@{$tree->get_all_leaves}) {
    next if($node->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    $node->disavow_parent;
  }

  #parse newick into a new tree object structure
  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or throw("Could not open newick file [$newick_file]");
  while(<FH>) { $newick .= $_;  }
  close(FH);
  my $newtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
  $newtree->print_tree if($self->debug > 1);
  
  #leaves of newick tree are named with member_id of members from input tree
  #move members (leaves) of input tree into newick tree to mirror the 'member_id' nodes
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
  
  # merge the trees so that the children of the newick tree are now attached to the 
  # input tree's root node
  $tree->merge_children($newtree);

  #newick tree is now empty so release it
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



1;
