=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
$ktreedist->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

=cut


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');

sub param_defaults {
    return {
        'ref_tree_clusterset'   => undef,
        'alternative_trees'     => undef,
        'reroot_with_sdi'       => 1,
    };
}

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
  $self->param('gene_tree', $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param('gene_tree_id')) );

  if ($self->check_members) {
      $self->complete_early("Ktreedist.pm: All members have the same sequence.");
  }

  $self->load_input_trees;

  unless (scalar(keys %{$self->param('inputtrees_unrooted')})) {
    $self->complete_early("No trees with non-0 distances. Nothing to compute");
  }

  $self->require_executable('ktreedist_exe');
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

  #If re-root we run the method otherwise we just copy over from the unrooted hash
  if ($self->param('reroot_with_sdi') ) {
    $self->reroot_inputtrees;
  }else{
    $self->param('inputtrees_rooted', $self->param('inputtrees_unrooted'));
  }

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
  $self->call_within_transaction( sub {
    $self->store_ktreedist_score;
  });
}

sub post_cleanup {
  my $self = shift;

  if(my $gene_tree = $self->param('gene_tree')) {
    $gene_tree->release_tree;
    $self->param('gene_tree', undef);
  }

  $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
}


##########################################
#
# internal methods
#
##########################################

## We want to make sure that all the members don't have the same sequence,
## otherwise, ktreedist will fail
sub check_members {
    my ($self) = @_;
    my $tree = $self->param('gene_tree');
    my %seqs;
    my %ref_tree_seq_member_ids;
    for my $leaf (@{$tree->get_all_leaves}) {
        $seqs{$leaf->sequence_id}++;
        $ref_tree_seq_member_ids{$leaf->seq_member_id} = $leaf;
    }
    $self->param('ref_tree_seq_member_ids', \%ref_tree_seq_member_ids);

    if (scalar(keys %seqs) == 1) {
        return 1
    }
    return 0;
}

sub run_ktreedist {
  my $self = shift;

  my $root_id = $self->param('gene_tree')->root_id;
  my $ktreedist_exe = $self->param('ktreedist_exe');
  my $temp_directory = $self->worker_temp_directory;

  my $comparisonfilename = $temp_directory . "/" . $root_id . ".ct";
  my $referencefilename = $temp_directory .  "/" .$root_id . ".rt";
  open(my $ct_fh, '>', $comparisonfilename) or die $!;
  print $ct_fh "#NEXUS\n\n";
  print $ct_fh "Begin TREES;\n\n";
  foreach my $method (keys %{$self->param('inputtrees_rooted')}) {
    my $inputtree = $self->param('inputtrees_rooted')->{$method};
    die ($method." is not defined in inputtrees_rooted")  unless (defined $inputtree);
    # KtreeDist doesn't understand NHX tags, and needs each tree on a single line
    my $newick_string = $inputtree;
    $newick_string =~ s/\[[^\]]*\]//g;
    $newick_string =~ s/\n//g;

    $self->throw("error with newick tree") unless (defined($newick_string));
    print $ct_fh "TREE    $method = $newick_string\n";
  }
  print $ct_fh "End;\n\n";
  close $ct_fh;

  my $reference_tree = $self->param('ref_tree_clusterset') ? $self->param('gene_tree')->alternative_trees->{$self->param('ref_tree_clusterset')} : $self->param('gene_tree');
  my $reference_string = $reference_tree->newick_format('ryo', '%{-m}%{"_"-X}:%{d}');
  my $ref_label = $self->param('gene_tree')->clusterset_id;
  
  $self->throw("error with newick tree") unless (defined($reference_string));

  $self->_spurt($referencefilename, join("\n",
          "#NEXUS\n",
          "Begin TREES;\n",
          "TREE    $ref_label = $reference_string",
          "End;\n",
      ));

  my $cmd = [$ktreedist_exe, '-a', '-rt', $referencefilename, '-ct', $comparisonfilename];
  my $runCmd = $self->run_command($cmd);
  if ($runCmd->exit_code) {
      if ($runCmd->err =~ /Substitution loop at.*ktreedist line 1777/) {
          # The tree is too big for ktreedist
          $self->complete_early('Ktreedist is not able to compute distances');
      }
      $self->throw("Error exit status running Ktreedist: " .$runCmd->err . "\n");
  }
  my @output = split/\n/, $runCmd->out;

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
    my ($self) = @_;
    my $tree = $self->param('gene_tree');
    $self->param('inputtrees_unrooted', {});

    my %alternative_trees;
    if ($self->param('ref_tree_clusterset')){
        %alternative_trees = map { $_ => 1 } @{$self->param('alternative_trees')};
    }

    # Although the reference tree for KTreeDist is "ref_tree_clusterset", the
    # tree in which the members are removed is the "default" clusterset, i.e.
    # $self->param('gene_tree_id') because KTreeDist can deal with alternative
    # references
    my %removed_members = map { $_ => 1 } @{$self->compara_dba->get_GeneTreeAdaptor->fetch_all_removed_seq_member_ids_by_root_id($self->param('gene_tree_id'))};

    for my $other_tree (values %{$tree->alternative_trees}) {

        #If we have a different set of alternative trees and the tags are not specified, it will skip the current tree
        next if ($self->param('ref_tree_clusterset') && (!$alternative_trees{$other_tree->clusterset_id}));

        print "tree:" . $other_tree->clusterset_id . "\n" if ($self->debug);

        # ktreedist will crash if the trees being compared have different number of leaves.
        # This may be caused by a member being deleted from one tree only but the other
        # jobs running on the same family are still unaware that the gene has been
        # dropped and keep it.

        for my $leaf ( @{ $other_tree->get_all_leaves } ) {
            if ( !exists( $self->param('ref_tree_seq_member_ids')->{ $leaf->dbID } ) && ( exists( $removed_members{ $leaf->dbID } ) ) ) {
                print "\tremoving:" . $leaf->dbID . "\n" if ( $self->debug );
                $leaf->disavow_parent;
                $other_tree->minimize_tree;
            }
        }
        print "ref_tree_leaves:" . scalar( keys( %{ $self->param('ref_tree_seq_member_ids') } ) ) . "\tcomp_tree_leaves:" . scalar(@{ $other_tree->get_all_leaves }) . "\tafter removing:" . scalar(@{ $other_tree->get_all_leaves }) . "\n" if ( $self->debug );

        # We set all the branch lengths to 1 in trees that are missing branch lengths
        # (e.g raxml_parsimony), so that KtreeDist runs without crashing
        my $ryo_format = $self->check_distances_to_parent($other_tree) ? '%{-m}%{"_"-X}:%{d}' : '%{-m}%{"_"-X}:1';
        $self->param('inputtrees_unrooted')->{$other_tree->clusterset_id} = $other_tree->newick_format('ryo', $ryo_format);
    }
    return 1;
}


## We filter out all the trees with all the distance to parent equals to 0
## ktreedist will fail on them
sub check_distances_to_parent {
    my ($self, $tree) = @_;
    my $tot_dtp = 0;
    for my $node(@{$tree->get_all_nodes}) {
        $tot_dtp += $node->distance_to_parent;
    }
    print STDERR "TOT_DTP: $tot_dtp\n";

    return $tot_dtp;
}

sub reroot_inputtrees {
  my $self = shift;

  $self->param('inputtrees_rooted', {});
  foreach my $method (keys %{$self->param('inputtrees_unrooted')}) {
    my $inputtree = $self->param('inputtrees_unrooted')->{$method};

    # Parse the rooted tree string
    my $rootedstring = $self->run_treebest_sdi($inputtree, 1);

    # The string may be empty if the bison parser couldn't parse the tree
    # due to memory exhaustion
    if (not $rootedstring) {
        $self->warning(sprintf("Treebest could not root the '%s' tree due probably to memory exhaustion\n", $method));
        next;
    }

    $self->param('inputtrees_rooted')->{$method} = $rootedstring;
  }
}

sub store_ktreedist_score {
    my ($self) = @_;
    my $root_id = $self->param('gene_tree')->root_id;
    my $other_trees = $self->param('gene_tree')->alternative_trees;

    my $sth = $self->compara_dba->dbc->prepare
        ("REPLACE INTO ktreedist_score
                                            (node_id,
                                             tag,
                                             k_score,
                                             scale_factor,
                                             symm_difference,
                                             n_partitions,
                                             k_score_rank) VALUES (?,?,?,?,?,?,?)");

    my $count = 1;
    my $ktreedist_score_root_id = $self->param('ktreedist_score')->{$root_id};
    for my $k_score_as_rank (sort {$a <=> $b} keys %$ktreedist_score_root_id) {
        for my $tag (keys %{$ktreedist_score_root_id->{$k_score_as_rank}{_tag}}) {
            print STDERR "TAG: $tag\n" if ($self->debug);
            $other_trees->{$tag}->store_tag('k_score', $ktreedist_score_root_id->{$k_score_as_rank}{_tag}{$tag}{k_score});
            $other_trees->{$tag}->store_tag('k_score_rank', $count);

            my $k_score         = $ktreedist_score_root_id->{$k_score_as_rank}{_tag}{$tag}{k_score};
            my $scale_factor    = $ktreedist_score_root_id->{$k_score_as_rank}{_tag}{$tag}{scale_factor};
            my $symm_difference = $ktreedist_score_root_id->{$k_score_as_rank}{_tag}{$tag}{symm_difference};
            my $n_partitions    = $ktreedist_score_root_id->{$k_score_as_rank}{_tag}{$tag}{n_partitions};
            my $k_score_rank    = $count++;
            ## Hack e92 ##
            $scale_factor = '99999.99999' if $scale_factor >= 100_000;
            $k_score = '99999.99999' if $k_score >= 100_000;
            ## Hack e92 ##
            $sth->execute($root_id,
                          $tag,
                          $k_score,
                          $scale_factor,
                          $symm_difference,
                          $n_partitions,
                          $k_score_rank);
        }
    }
    $sth->finish;

}


1;
