#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Ktreedist

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ktreedist = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Ktreedist->new
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


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Ktreedist;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

    # Fetch sequences:
  $self->param('nc_tree', $self->compara_dba->get_NCTreeAdaptor->fetch_node_by_node_id($self->param('nc_tree_id')) );

  $self->load_input_trees;

  my $ktreedist_exe = $self->param('ktreedist_exe')
      or die "'ktreedist_exe' is an obligatory parameter";

  die "Cannot execute '$ktreedist_exe'" unless(-x $ktreedist_exe);
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

sub get_species_tree_file {
    my $self = shift @_;

    unless( $self->param('species_tree_file') ) {

        unless( $self->param('species_tree_string') ) {

            my $tag_table_name = 'nc_tree_tag';

            my $sth = $self->dbc->prepare( "select value from $tag_table_name where tag='species_tree_string'" );
            $sth->execute;
            my ($species_tree_string) = $sth->fetchrow_array;
            $sth->finish;

            $self->param('species_tree_string', $species_tree_string)
                or die "Could not fetch 'species_tree_string' from $tag_table_name";
        }

        my $species_tree_string = $self->param('species_tree_string');
        eval {
            my $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string);
            my @leaves = @{$eval_species_tree->get_all_leaves};
        };
        if($@) {
            die "Error parsing species tree from the string '$species_tree_string'";
        }

            # store the string in a local file:
        my $species_tree_file = $self->worker_temp_directory . "spec_tax.nh";
        open SPECIESTREE, ">$species_tree_file" or die "Could not open '$species_tree_file' for writing : $!";
        print SPECIESTREE $species_tree_string;
        close SPECIESTREE;
        $self->param('species_tree_file', $species_tree_file);
    }
    return $self->param('species_tree_file');
}

sub run_ktreedist {
  my $self = shift;

  my $root_id = $self->param('nc_tree')->node_id;
#  my $species_tree_file = $self->param('species_tree_file');
  my $ktreedist_exe = $self->param('ktreedist_exe');
  my $temp_directory = $self->worker_temp_directory;

  my $comparisonfilename = $temp_directory . $root_id . ".ct";
  my $referencefilename = $temp_directory . $root_id . ".rt";
  open CTFILE,">$comparisonfilename" or die $!;
  print CTFILE "#NEXUS\n\n";
  print CTFILE "Begin TREES;\n\n";
  foreach my $method (keys %{$self->param('inputtrees_rooted')}) {
    my $inputtree = $self->param('inputtrees_rooted')->{$method};
    die ($method." is not defined in inputtrees_rooted")  unless (defined $inputtree);
    my $comparison_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($inputtree);
    my $newick_string = $comparison_tree->newick_simple_format;
    $self->throw("error with newick tree") unless (defined($newick_string));
    print CTFILE "TREE    $method = $newick_string\n";
  }
  print CTFILE "End;\n\n";
  close CTFILE;

  open RTFILE,">$referencefilename" or die $!;
  print RTFILE "#NEXUS\n\n";
  print RTFILE "Begin TREES;\n\n";
  my $reference_string = $self->param('nc_tree')->newick_format('member_id_taxon_id');
  $self->throw("error with newick tree") unless (defined($reference_string));
  print RTFILE "TREE    treebest = $reference_string\n";
  print CTFILE "End;\n\n";
  close RTFILE;

  my $cmd = "$ktreedist_exe -a -rt $referencefilename -ct $comparisonfilename";
  print("$cmd\n") if($self->debug);
  my $run; my $exit_status;
  open($run, "$cmd |") or $self->throw("Cannot run ktreedist with: $cmd");
  my @output = <$run>;
  $exit_status = close($run);
  $self->throw("Error exit status running Ktreedist") if (!$exit_status);
  my $ktreedist_score = $self->param('ktreedist_score', {});
  foreach my $line (@output) {
    if ($line =~ /\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)/) {
      my ($tag,$k_score,$scale_factor,$symm_difference,$n_partitions) = ($1,$2,$3,$4,$5);
      print "Parsing: $root_id,$tag,$k_score,$scale_factor,$symm_difference,$n_partitions\n" if ($self->debug);
      $ktreedist_score->{$root_id}{$k_score}{_tag}{$tag}{k_score} = $k_score;
      $ktreedist_score->{$root_id}{$k_score}{_tag}{$tag}{scale_factor} = $scale_factor;
      $ktreedist_score->{$root_id}{$k_score}{_tag}{$tag}{symm_difference} = $symm_difference;
      $ktreedist_score->{$root_id}{$k_score}{_tag}{$tag}{n_partitions} = $n_partitions;
    }
  }

  return 1;
}

sub load_input_trees {
  my $self = shift;

  my $root_id = $self->param('nc_tree')->node_id;

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
        # manual vivification needed:
      unless($self->param('inputtrees_unrooted')) {
          $self->param('inputtrees_unrooted', {});
      }
      $self->param('inputtrees_unrooted')->{$inputtree_string->{tag}} = $inputtree_string->{value};
    }
  }
  $sth1->finish;
#  print STDERR Dumper $self->param('inputtrees_unrooted') if ($self->{'verbose'});

  return 1;
}

sub reroot_inputtrees {
  my $self = shift;

  my $root_id = $self->param('nc_tree')->node_id;
  my $species_tree_file = $self->get_species_tree_file();

  my $treebest_exe = $self->param('treebest_exe')
    or die "'treebest_exe' is an obligatory parameter";

  die "Cannot execute '$treebest_exe'" unless(-x $treebest_exe);

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

sub parse_newick_into_nctree
{
  my $self = shift;
  my $newick_file =  $self->param('mmerge_blengths_output');
  my $nc_tree = $self->param('nc_tree');
  
  #cleanup old tree structure- 
  #  flatten and reduce to only GeneTreeMember leaves
  $nc_tree->flatten_tree;
  $nc_tree->print_tree(20) if($self->debug);
  foreach my $node (@{$nc_tree->get_all_leaves}) {
    next if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    $node->disavow_parent;
  }

  #parse newick into a new tree object structure
  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
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
  foreach my $member (@{$nc_tree->get_all_leaves}) {
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
  $nc_tree->merge_children($newtree);

  # Newick tree is now empty so release it
  $newtree->release_tree;

  $nc_tree->print_tree if($self->debug);
  # check here on the leaf to test if they all are GeneTreeMember as
  # minimize_tree/minimize_node might not work properly
  foreach my $leaf (@{$self->param('nc_tree')->get_all_leaves}) {
    unless($leaf->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
      $self->throw("TreeBestMMerge tree does not have all leaves as GeneTreeMembers\n");
    }
  }

  return undef;
}

sub store_ktreedist_score {
  my $self = shift;
  my $root_id = $self->param('nc_tree')->node_id;

  my $sth = $self->compara_dba->dbc->prepare
    ("INSERT IGNORE INTO ktreedist_score 
                           (node_id,
                            tag,
                            k_score,
                            scale_factor,
                            symm_difference,
                            n_partitions,
                            k_score_rank) VALUES (?,?,?,?,?,?,?)");
  my $count = 1;
  my $ktreedist_score_root_id = $self->param('ktreedist_score')->{$root_id};
  foreach my $k_score_as_rank (sort {$a <=> $b} keys %$ktreedist_score_root_id) {
    foreach my $tag (keys %{$ktreedist_score_root_id->{$k_score_as_rank}{_tag}}) {
      my $k_score         = $ktreedist_score_root_id->{$k_score_as_rank}{_tag}{$tag}{k_score};
      my $scale_factor    = $ktreedist_score_root_id->{$k_score_as_rank}{_tag}{$tag}{scale_factor};
      my $symm_difference = $ktreedist_score_root_id->{$k_score_as_rank}{_tag}{$tag}{symm_difference};
      my $n_partitions    = $ktreedist_score_root_id->{$k_score_as_rank}{_tag}{$tag}{n_partitions};
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
