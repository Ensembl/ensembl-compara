#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Ktreedist

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ktreedist = Bio::EnsEMBL::Compara::RunnableDB::Ktreedist->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$ktreedist->fetch_input(); #reads from DB
$ktreedist->run();
$ktreedist->output();
$ktreedist->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::Ktreedist;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;

use Bio::EnsEMBL::Compara::Graph::NewickParser;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'clusterset_id'} = 1;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  # Get the needed adaptors here
  # $self->{silly_adaptor} = $self->{'comparaDBA'}->get_SillyAdaptor;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

# For long parameters, look at analysis_data
  if($self->{ktreedist_data_id}) {
    my $analysis_data_id = $self->{ktreedist_data_id};
    my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
    $self->get_params($analysis_data_params);
  }

  $self->load_input_trees;
  $self->load_species_tree;

  # Define executable
  my $ktreedist_executable = $self->analysis->program_file || '';
  unless (-e $ktreedist_executable) {
    $ktreedist_executable = "/software/ensembl/compara/ktreedist/Ktreedist.pl";
  }
  throw("can't find a ktreedist executable to run\n") unless(-e $ktreedist_executable);
  $self->{ktreedist_executable} = $ktreedist_executable;

  return 1;
}


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

  foreach my $key (qw[param1 param2 param3 ktreedist_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  if(defined($params->{'nc_tree_id'})) {
    $self->{'nc_tree'} =  
         $self->{'comparaDBA'}->get_NCTreeAdaptor->
         fetch_node_by_node_id($params->{'nc_tree_id'});
  }
  if(defined($params->{'clusterset_id'})) {
    $self->{'clusterset_id'} = $params->{'clusterset_id'};
  }


  return;
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  $self->reroot_inputtrees;
  $self->run_ktreedist;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;
  $self->store_ktreedist_score;
}


##########################################
#
# internal methods
#
##########################################


sub run_ktreedist {
  my $self = shift;

  my $root_id = $self->{nc_tree}->node_id;
  my $species_tree_file = $self->{'species_tree_file'};
  my $ktreedist_executable = $self->{ktreedist_executable};
  my $temp_directory = $self->worker_temp_directory;

  my $comparisonfilename = $temp_directory . $root_id . ".ct";
  my $referencefilename = $temp_directory . $root_id . ".rt";
  open CTFILE,">$comparisonfilename" or die $!;
  print CTFILE "#NEXUS\n\n";
  print CTFILE "Begin TREES;\n\n";
  foreach my $method (keys %{$self->{inputtrees_rooted}}) {
    my $inputtree = $self->{inputtrees_rooted}{$method};
    my $comparison_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($inputtree);
    my $newick_string = $comparison_tree->newick_simple_format;
    throw("error with newick tree") unless (defined($newick_string));
    print CTFILE "TREE    $method = $newick_string\n";
  }
  print CTFILE "End;\n\n";
  close CTFILE;

  open RTFILE,">$referencefilename" or die $!;
  print RTFILE "#NEXUS\n\n";
  print RTFILE "Begin TREES;\n\n";
  my $reference_string = $self->{nc_tree}->newick_format('member_id_taxon_id');
  throw("error with newick tree") unless (defined($reference_string));
  print RTFILE "TREE    treebest = $reference_string\n";
  print CTFILE "End;\n\n";
  close RTFILE;

  my $cmd = "$ktreedist_executable -a -rt $referencefilename -ct $comparisonfilename";
  print("$cmd\n") if($self->debug);
  my $run; my $exit_status;
  open($run, "$cmd |") or throw("Cannot run ktreedist with: $cmd");
  my @output = <$run>;
  $exit_status = close($run);
  throw("Error exit status running Ktreedist") if (!$exit_status);
  foreach my $line (@output) {
    if ($line =~ /\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)/) {
      my ($tag,$k_score,$scale_factor,$symm_difference,$n_partitions) = ($1,$2,$3,$4,$5);
      print "Parsing: $root_id,$tag,$k_score,$scale_factor,$symm_difference,$n_partitions\n" if ($self->debug);
      $self->{ktreedist_score}{$root_id}{$k_score}{_tag}{$tag}{k_score} = $k_score;
      $self->{ktreedist_score}{$root_id}{$k_score}{_tag}{$tag}{scale_factor} = $scale_factor;
      $self->{ktreedist_score}{$root_id}{$k_score}{_tag}{$tag}{symm_difference} = $symm_difference;
      $self->{ktreedist_score}{$root_id}{$k_score}{_tag}{$tag}{n_partitions} = $n_partitions;
    }
  }

  return 1;
}

sub load_input_trees {
  my $self = shift;

  my $root_id = $self->{nc_tree}->node_id;

  my $sql1 = "select tag,value from nc_tree_tag where node_id=$root_id and tag like '%\\\_IT%'";
  my $sth1 = $self->dbc->prepare($sql1);
  $sth1->execute;
  while (  my $inputtree_string = $sth1->fetchrow_hashref ) {
    my $eval_inputtree;
    eval {
      $eval_inputtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($inputtree_string->{value});
      my @leaves = @{$eval_inputtree->get_all_leaves};
    };
    unless ($@) {
      $self->{inputtrees_unrooted}{$inputtree_string->{tag}} = $inputtree_string->{value};
    }
  }
  $sth1->finish;

  return 1;
}

sub reroot_inputtrees {
  my $self = shift;

  my $root_id = $self->{nc_tree}->node_id;
  my $species_tree_file = $self->{'species_tree_file'};
  my $treebest_mmerge_executable = '/nfs/users/nfs_a/avilella/src/treesoft/trunk/treebest_ncrna/treebest';

  my $temp_directory = $self->worker_temp_directory;
  my $template_cmd = "$treebest_mmerge_executable sdi -rs $species_tree_file";

  foreach my $method (keys %{$self->{inputtrees_unrooted}}) {
    my $cmd = $template_cmd;
    my $unrootedfilename = $temp_directory . $root_id . "." . $method . ".unrooted";
    my $rootedfilename = $temp_directory . $root_id . "." . $method . ".rooted";
    my $inputtree = $self->{inputtrees_unrooted}{$method};
    open FILE,">$unrootedfilename" or die $!;
    print FILE $inputtree;
    close FILE;

    $cmd .= " $unrootedfilename";
    $cmd .= " > $rootedfilename";

    print("$cmd\n") if($self->debug);

    unless(system("$cmd") == 0) {
      print("$cmd\n");
      throw("error running treebest sdi, $!\n");
    }

    # Parse the rooted tree string
    my $rootedstring;
    open (FH, $rootedfilename) or throw("Couldnt open rooted file [$rootedfilename]");
    while(<FH>) {
      chomp $_;
      $rootedstring .= $_;
    }
    close(FH);

    $self->{inputtrees_rooted}{$method} = $rootedstring;
  }

  return 1;
}

sub load_species_tree {
  my $self = shift;

  # Defining a species_tree
  # Option 1 is species_tree_string in nc_tree_tag, which then doesn't require tracking files around
  # Option 2 is species_tree_file which should still work for compatibility
  my $sql1 = "select value from nc_tree_tag where tag='species_tree_string'";
  my $sth1 = $self->dbc->prepare($sql1);
  $sth1->execute;
  my $species_tree_string = $sth1->fetchrow_hashref;
  $sth1->finish;
  my $eval_species_tree;
  eval {
    $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string->{value});
    my @leaves = @{$eval_species_tree->get_all_leaves};
  };

  if($@) {
    unless(-e $self->{'species_tree_file'}) {
      throw("can't find species_tree\n");
    }
  } else {
    $self->{species_tree_string} = $species_tree_string->{value};
    my $spfilename = $self->worker_temp_directory . "spec_tax.nh";
    open SPECIESTREE, ">$spfilename" or die "$!";
    print SPECIESTREE $self->{species_tree_string};
    close SPECIESTREE;
    $self->{'species_tree_file'} = $spfilename;
  }

}

sub parse_newick_into_nctree
{
  my $self = shift;
  my $newick_file =  $self->{'mmerge_blengths_output'};
  my $tree = $self->{'nc_tree'};
  
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

  my $newtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
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
  foreach my $leaf (@{$self->{'nc_tree'}->get_all_leaves}) {
    unless($leaf->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
      throw("TreeBestMMerge tree does not have all leaves as AlignedMember\n");
    }
  }

  return undef;
}

sub store_ktreedist_score {
  my $self = shift;
  my $root_id = $self->{nc_tree}->node_id;

  my $sth = $self->{'comparaDBA'}->dbc->prepare
    ("INSERT IGNORE INTO ktreedist_score 
                           (node_id,
                            tag,
                            k_score,
                            scale_factor,
                            symm_difference,
                            n_partitions,
                            k_score_rank) VALUES (?,?,?,?,?,?,?)");
  my $count = 1;
  foreach my $k_score_as_rank (sort {$a <=> $b} keys %{$self->{ktreedist_score}{$root_id}}) {
    foreach my $tag (keys %{$self->{ktreedist_score}{$root_id}{$k_score_as_rank}{_tag}}) {
      my $k_score         = $self->{ktreedist_score}{$root_id}{$k_score_as_rank}{_tag}{$tag}{k_score};
      my $scale_factor    = $self->{ktreedist_score}{$root_id}{$k_score_as_rank}{_tag}{$tag}{scale_factor};
      my $symm_difference = $self->{ktreedist_score}{$root_id}{$k_score_as_rank}{_tag}{$tag}{symm_difference};
      my $n_partitions    = $self->{ktreedist_score}{$root_id}{$k_score_as_rank}{_tag}{$tag}{n_partitions};
      my $k_score_rank = $count;
      $DB::single=1;1;
      $sth->execute($root_id,
                    $tag,
                    $k_score,
                    $scale_factor,
                    $symm_difference,
                    $n_partitions,
                    $k_score_rank);
      $count++;
    }
  }
  $sth->finish;


}

1;
