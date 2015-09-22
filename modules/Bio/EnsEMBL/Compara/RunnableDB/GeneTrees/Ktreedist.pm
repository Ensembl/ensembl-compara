=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  $self->param('gene_tree')->preload();

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
    for my $leaf (@{$tree->get_all_leaves}) {
        $seqs{$leaf->sequence_id}++;
    }
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

  my $comparisonfilename = $temp_directory . $root_id . ".ct";
  my $referencefilename = $temp_directory . $root_id . ".rt";
  open CTFILE,">$comparisonfilename" or die $!;
  print CTFILE "#NEXUS\n\n";
  print CTFILE "Begin TREES;\n\n";
  foreach my $method (keys %{$self->param('inputtrees_rooted')}) {
    my $inputtree = $self->param('inputtrees_rooted')->{$method};
    die ($method." is not defined in inputtrees_rooted")  unless (defined $inputtree);
    my $comparison_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($inputtree);
    my $newick_string = $comparison_tree->newick_format("simple");

    #We replace all the zero branch lengths (added by the parser, since parsimony trees have no BLs) with 1s.
    #This allows KtreeDist to run without crashing.

    #!!!!!! IMPORTANT !!!!!!!!
    # Should ONLY look into RF distances for raxml_parsimony trees. Other distances should be ignored.
    #!!!!!!!!!!!!!!!!!!!!!!!!!

    if ($method eq "raxml_parsimony"){
        $newick_string =~ s/:0/:1/g;
    }

    $self->throw("error with newick tree") unless (defined($newick_string));
    print CTFILE "TREE    $method = $newick_string\n";
  }
  print CTFILE "End;\n\n";
  close CTFILE;

  open RTFILE,">$referencefilename" or die $!;
  print RTFILE "#NEXUS\n\n";
  print RTFILE "Begin TREES;\n\n";
  my $reference_string;
  my $ref_label;
 
  if ($self->param('ref_tree_clusterset')){
    $reference_string = $self->param('gene_tree')->alternative_trees->{$self->param('ref_tree_clusterset')}->newick_format('member_id_taxon_id');
    $ref_label = $self->param('ref_tree_clusterset');
  }else{
    $reference_string = $self->param('gene_tree')->newick_format('member_id_taxon_id');
    $ref_label = 'treebest';
  }
  
  $self->throw("error with newick tree") unless (defined($reference_string));
  print RTFILE "TREE    $ref_label = $reference_string\n";
  print CTFILE "End;\n\n";
  close RTFILE;

  my $cmd = "$ktreedist_exe -a -rt $referencefilename -ct $comparisonfilename";
  my $runCmd = $self->run_command($cmd);
  if ($runCmd->exit_code) {
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

    my %alternative_trees = undef;
    if ($self->param('ref_tree_clusterset')){
        %alternative_trees = map { $_ => 1 } @{$self->param('alternative_trees')};
    }

    for my $other_tree (values %{$tree->alternative_trees}) {

        #If we have a different set of alternative trees and the tags are not specified, it will skip the current tree
        next if ($self->param('ref_tree_clusterset') && (!$alternative_trees{$other_tree->clusterset_id}));

        $other_tree->preload();
        #print STDERR $other_tree->newick_format('ryo','%{-m}%{"_"-x}:%{d}') if ($self->debug);
        print "tree:" . $other_tree->clusterset_id . "\n" if ($self->debug);

        #Parsimony trees dont have branch lengths.
        if ($other_tree->clusterset_id eq "raxml_parsimony"){
            $self->param('inputtrees_unrooted')->{$other_tree->clusterset_id} = $other_tree->newick_format('ryo','%{-m}%{"_"-x}');
        }else{
            $self->param('inputtrees_unrooted')->{$other_tree->clusterset_id} = $other_tree->newick_format('ryo','%{-m}%{"_"-x}:%{d}') if ($self->check_distances_to_parent($other_tree));
        }

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
            $DB::single=1;1;
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
