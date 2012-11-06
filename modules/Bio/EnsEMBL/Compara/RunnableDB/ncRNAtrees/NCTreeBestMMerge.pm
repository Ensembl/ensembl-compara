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

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');


sub param_defaults {
    return {
            'store_tree_support'    => 1,
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

  my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param('gene_tree_id'));

  # We now have genomic_trees for them
#   if (scalar @{$nc_tree->get_all_leaves()} < 4) {
#       # We don't have enough data to create the trees
#       my $msg = sprintf "Tree cluster %d has <4 genes\n", $self->param('gene_tree_id');
#       print STDERR $msg if ($self->debug());
#       $self->input_job->incomplete(0);
#       die $msg;
#   }

      # Fetch sequences:
  $self->param('nc_tree', $nc_tree);

  $self->param('inputtrees_unrooted', {});
  $self->param('inputtrees_rooted', {});
  
  $self->load_input_trees;

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
    $self->param('ref_support', [keys %{$self->param('inputtrees_rooted')}]);
    my $input_trees = [map {$self->param('inputtrees_rooted')->{$_}} @{$self->param('ref_support')}];
    my $merged_tree = $self->run_treebest_mmerge($input_trees);

    my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir($self->param('nc_tree')->root);
    my $leafcount = scalar(@{$self->param('nc_tree')->get_all_leaves});
    $merged_tree = $self->run_treebest_branchlength_nj($input_aln, $merged_tree) if ($leafcount >= 3);
    
    $self->parse_newick_into_tree($merged_tree, $self->param('nc_tree'));
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my ($self) = @_;

  $self->store_genetree($self->param('nc_tree'), $self->param('ref_support')) if (defined($self->param('inputtrees_unrooted')));

  if ($self->param('store_intermediate_trees')) {
       foreach my $clusterset_id (keys %{$self->param('inputtrees_rooted')}) {
          my $newtree = $self->store_alternative_tree($self->param('inputtrees_rooted')->{$clusterset_id}, $clusterset_id, $self->param('nc_tree');
          $self->dataflow_output_id({'gene_tree_id' => $newtree->root_id}, 2);
      }
   }
}

sub post_cleanup {
  my $self = shift;

  if($self->param('nc_tree')) {
    printf("NctreeBestMMerge::post_cleanup  releasing tree\n") if($self->debug);
    $self->param('nc_tree')->release_tree;
    $self->param('nc_tree', undef);
  }

  $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
}


##########################################
#
# internal methods
#
##########################################


sub reroot_inputtrees {
  my $self = shift;

  foreach my $method (keys %{$self->param('inputtrees_unrooted')}) {
    my $inputtree = $self->param('inputtrees_unrooted')->{$method};

    # Parse the rooted tree string
    my $rootedstring = $self->run_treebest_sdi($inputtree, 1);

    $self->param('inputtrees_rooted')->{$method} = $rootedstring;
  }
}

sub load_input_trees {
  my $self = shift;
  my $tree = $self->param('nc_tree');

  foreach my $tag ($tree->get_all_tags) {
    next unless $tag =~ m/_it_/;
    my $inputtree_string = $tree->get_value_for_tag($tag);

    # Checks that the tree can be parsed
    eval {
      my $eval_inputtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($inputtree_string);
      my @leaves = @{$eval_inputtree->get_all_leaves};
    };
    unless ($@) {
        $self->param('inputtrees_unrooted')->{$tag} = $inputtree_string;
    }
  }
}


1;
