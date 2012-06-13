#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $treebest_mmerge = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$treebest_mmerge->fetch_input(); #reads from DB
$treebest_mmerge->run();
$treebest_mmerge->output();
$treebest_mmerge->write_output(); #writes to DB

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


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge;

use strict;
use Bio::AlignIO;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');



=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param('nc_tree_id'));
  if (scalar @{$nc_tree->get_all_leaves()} < 4) {
      # We don't have enough data to create the trees
      my $msg = sprintf "Tree cluster %d has <4 genes\n", $self->param('nc_tree_id');
      print STDERR $msg if ($self->debug());
      $self->input_job->incomplete(0);
      die $msg;
  }

      # Fetch sequences:
  $self->param('nc_tree', $nc_tree);

  $self->load_input_trees;

  my $treebest_exe = $self->param('treebest_exe')
          or die "'treebest_exe' is an obligatory parameter";
                  
  die "Cannot execute '$treebest_exe'" unless(-x $treebest_exe);
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

  if (defined($self->param('inputtrees_unrooted'))) {
    $self->reroot_inputtrees;
    $self->run_treebest_mmerge;
    $self->calculate_branch_lengths;
  }
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

  $self->store_genetree($self->param('nc_tree')) if (defined($self->param('inputtrees_unrooted')));
  $self->dataflow_output_id (
                             $self->input_id, 2
                            );
}

sub DESTROY {
  my $self = shift;

  if($self->param('nc_tree')) {
    printf("NctreeBestMMerge::DESTROY  releasing tree\n") if($self->debug);
    $self->param('nc_tree')->release_tree;
    $self->param('nc_tree', undef);
  }

  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


##########################################
#
# internal methods
#
##########################################

sub run_treebest_mmerge {
  my $self = shift;

  my $root_id = $self->param('nc_tree')->root_id;
  my $species_tree_file = $self->get_species_tree_file();
  my $treebest_exe = $self->param('treebest_exe');
  my $temp_directory = $self->worker_temp_directory;

  my $mmergefilename = $temp_directory . $root_id . ".mmerge";
  my $mmerge_output_filename = $mmergefilename . ".output";
  open FILE,">$mmergefilename" or die $!;
  foreach my $method (keys %{$self->param('inputtrees_rooted')}) {
    my $inputtree = $self->param('inputtrees_rooted')->{$method};
    print FILE "$inputtree\n";
  }
  close FILE;

  my $cmd = "$treebest_exe mmerge -s $species_tree_file $mmergefilename > $mmerge_output_filename";
  print("$cmd\n") if($self->debug);
  $DB::single=1;1;#??
  unless(system("$cmd") == 0) {
    print("$cmd\n");
    $self->throw("error running treebest mmerge, $!\n");
  }

  $self->param('mmerge_output', $mmerge_output_filename);

  return 1;
}

sub calculate_branch_lengths {
  my $self = shift;

  $self->param('input_aln', $self->dumpTreeMultipleAlignmentToWorkdir($self->param('nc_tree')->root) );

  my $leafcount = scalar(@{$self->param('nc_tree')->get_all_leaves});
  if($leafcount<3) {
    printf(STDERR "tree cluster %d has <3 genes - can not build a tree\n", 
           $self->param('nc_tree')->root_id);
    $self->param('mmerge_blengths_output', $self->param('mmerge_output'));
    $self->parse_newick_into_tree($self->param('mmerge_blengths_output'), $self->param('nc_tree'));
    return;
  }

  my $treebest_exe = $self->param('treebest_exe');
  my $constrained_tree = $self->param('mmerge_output');
  my $tree_with_blengths = $self->param('mmerge_output') . ".blengths.nh";
  my $input_aln = $self->param('input_aln');
  my $species_tree_file = $self->get_species_tree_file();
  my $cmd = $treebest_exe;
  $cmd .= " nj";
  if ($treebest_exe =~ /tracking/) {
      $cmd .= " -I";
  }
  $cmd .= " -c $constrained_tree";
  $cmd .= " -s $species_tree_file";
  $cmd .= " $input_aln";
  $cmd .= " > $tree_with_blengths";
#  my $cmd = "$treebest_exe nj -c $constrained_tree -s $species_tree_file $input_aln > $tree_with_blengths";
  print STDERR +("$cmd\n") if($self->debug);

  unless(system("$cmd") == 0) {
    print("$cmd\n");
    $self->throw("error running treebest nj, $!\n");
  }

  $self->param('mmerge_blengths_output', $tree_with_blengths);

  #parse the tree into the datastucture
  $self->parse_newick_into_tree($self->param('mmerge_blengths_output'), $self->param('nc_tree'));
  return 1;
}

sub reroot_inputtrees {
  my $self = shift;

  my $root_id = $self->param('nc_tree')->root_id;
  my $species_tree_file = $self->get_species_tree_file;
  my $treebest_exe = $self->param('treebest_exe');

  my $temp_directory = $self->worker_temp_directory;
  my $template_cmd = "$treebest_exe sdi -rs $species_tree_file";

  foreach my $method (keys %{$self->param('inputtrees_unrooted')}) {
    my $cmd = $template_cmd;
    my $unrootedfilename = $temp_directory . $root_id . "." . $method . ".unrooted";
    my $rootedfilename = $temp_directory . $root_id . "." . $method . ".rooted";
    my $inputtree = $self->param('inputtrees_unrooted')->{$method};
    open FILE,">$unrootedfilename" or die $!;
    print FILE $inputtree;
    close FILE;

    $cmd .= " $unrootedfilename";
    $cmd .= " > $rootedfilename";

    print("$cmd\n") if($self->debug);
    $DB::single=1;1;
    unless(system("$cmd") == 0) {
      print("$cmd\n");
      $self->throw("error running treebest sdi, $!\n");
    }

    # Parse the rooted tree string
    my $rootedstring;
    open (FH, $rootedfilename) or $self->throw("Couldnt open rooted file [$rootedfilename]");
    while(<FH>) {
      chomp $_;
      $rootedstring .= $_;
    }
    close(FH);

      # manual vivification needed:
    unless($self->param('inputtrees_rooted')) {
        $self->param('inputtrees_rooted', {});
    }
    $self->param('inputtrees_rooted')->{$method} = $rootedstring;
  }

  return 1;
}

sub load_input_trees {
  my $self = shift;
  my $tree = $self->param('nc_tree');

  foreach my $tag ($tree->get_all_tags) {
    next unless $tag =~ m/_it_/;
    my $inputtree_string = $tree->get_value_for_tag($tag);

    my $eval_inputtree;
    eval {
      $eval_inputtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($inputtree_string);
      my @leaves = @{$eval_inputtree->get_all_leaves};
    };
    unless ($@) {
        # manual vivification needed:
      unless($self->param('inputtrees_unrooted')) {
          $self->param('inputtrees_unrooted', {});
      }

      $self->param('inputtrees_unrooted')->{$tag} = $inputtree_string;
    }
  }

  return 1;
}


1;
