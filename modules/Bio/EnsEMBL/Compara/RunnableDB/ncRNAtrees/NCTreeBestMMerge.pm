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
$treebest_mmerge->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

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


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'cdna'  => 0,
        'filt_cmdline'          => undef,
        'remove_columns'        => undef,
        'check_split_genes'     => 0,
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

  my $gene_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param('gene_tree_id'));

  $self->param('gene_tree', $gene_tree);
  unless ($gene_tree->gene_align_id) {
      my $alignment_id = $self->param('gene_tree')->get_value_for_tag('genomic_alignment_gene_align_id');
      my $aln = $self->compara_dba->get_GeneAlignAdaptor->fetch_by_dbID($alignment_id);
      $gene_tree->alignment($aln);
  }

  $self->param('inputtrees_unrooted', {});
  $self->param('inputtrees_rooted', {});
  
  $self->_load_species_tree_string_from_db();
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

  ## Remove the tree if there are no contributions
  unless (scalar(keys %{$self->param('inputtrees_unrooted')} )) {
      $self->compara_dba->get_GeneTreeAdaptor->delete_tree( $self->param('gene_tree') );
      $self->input_job->autoflow(0);
      $self->complete_early($self->param('gene_tree_id')." tree has no contributions from genomic_tree / fast_trees / sec_struct_model_tree. Deleting this family !\n");
  }

  my $merged_tree;

  my $leafcount = scalar(@{$self->param('gene_tree')->get_all_leaves});
  if ($leafcount == 2) {

    warn "2 leaves only, we only need sdi\n";
    my $gdbid2stn = $self->param('species_tree')->get_genome_db_id_2_node_hash();
    my @goodgenes = map { sprintf('%d_%d', $_->seq_member_id, $gdbid2stn->{$_->genome_db_id}->node_id) } @{$self->param('gene_tree')->get_all_leaves};
    $merged_tree = $self->run_treebest_sdi_genepair(@goodgenes);

  } else {

    $self->reroot_inputtrees;
    $self->param('ref_support', [keys %{$self->param('inputtrees_rooted')}]);
    my $input_trees = [map {$self->param('inputtrees_rooted')->{$_}} @{$self->param('ref_support')}];
    $merged_tree = $self->run_treebest_mmerge($input_trees);

    my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir($self->param('gene_tree'), 'fasta', {-APPEND_SPECIES_TREE_NODE_ID => $self->param('species_tree')->get_genome_db_id_2_node_hash});
    $merged_tree = $self->run_treebest_branchlength_nj($input_aln, $merged_tree);

  }
    
    $self->parse_newick_into_tree($merged_tree, $self->param('gene_tree'), $self->param('ref_support'));
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

    $self->store_genetree($self->param('gene_tree')) if defined $self->param('inputtrees_unrooted');
    $self->call_one_hc('alignment');
    $self->call_one_hc('tree_content');
    $self->call_one_hc('tree_attributes');
    $self->call_one_hc('tree_structure');
}

sub post_cleanup {
  my $self = shift;

  if($self->param('gene_tree')) {
    printf("NctreeBestMMerge::post_cleanup  releasing tree\n") if($self->debug);
    $self->param('gene_tree')->release_tree;
    $self->param('gene_tree', undef);
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
  my $tree = $self->param('gene_tree');

  my $gdbid2stn = $self->param('species_tree')->get_genome_db_id_2_node_hash();
  for my $other_tree (values %{$tree->alternative_trees}) {
    my $tag = $other_tree->clusterset_id;
    $self->param('inputtrees_unrooted')->{$tag} = $other_tree->newick_format('ryo','%{-m}%{"_"-X}:%{d}');
    print STDERR $self->param('inputtrees_unrooted')->{$tag} if ($self->debug);
  }
}


1;
