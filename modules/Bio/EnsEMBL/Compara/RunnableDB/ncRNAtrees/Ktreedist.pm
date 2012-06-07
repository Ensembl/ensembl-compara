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

sub run_ktreedist {
  my $self = shift;

  my $root_id = $self->param('nc_tree')->node_id;
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
  my $tree = $self->param('nc_tree')->tree;

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
