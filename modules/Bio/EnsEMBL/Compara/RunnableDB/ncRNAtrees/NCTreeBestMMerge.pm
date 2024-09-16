=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::Cigars qw(cigar_from_alignment_string);

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
  if (!$gene_tree->gene_align_id && $gene_tree->has_tag('genomic_alignment_gene_align_id')) {
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

    if (defined $self->param('inputtrees_unrooted')) {
        my $gene_tree = $self->param('gene_tree');

        if ($gene_tree->gene_align_id
                && $gene_tree->has_tag('genomic_alignment_gene_align_id')) {
            my $genomic_alignment_gene_align_id = $gene_tree->get_value_for_tag('genomic_alignment_gene_align_id');
            if ($gene_tree->gene_align_id == $genomic_alignment_gene_align_id) {
                my $gene_align_adaptor = $self->compara_dba->get_GeneAlignAdaptor();

                if ($gene_tree->has_tag('unflanked_alignment_gene_align_id')) {
                    # If a flanked genomic alignment is the primary alignment of
                    # this tree, replace it with an unflanked genomic alignment.

                    my %tag_mapping = (
                        'unflanked_alignment_percent_identity' => 'aln_percent_identity',
                        'unflanked_alignment_num_residues' => 'aln_num_residues',
                        'unflanked_alignment_length' => 'aln_length',
                    );

                    while (my ($old_tag, $new_tag) = each %tag_mapping) {
                        if ($gene_tree->has_tag($old_tag)) {
                            my $value = $gene_tree->get_value_for_tag($old_tag);
                            $gene_tree->store_tag($new_tag, $value);
                            $gene_tree->delete_tag($old_tag);
                        }
                    }

                    # Leave the gene-tree alignment as the one identified by 'genomic_alignment_gene_align_id'
                    # until the last possible moment. That way, errors do not prevent us from trying again.
                    $gene_tree->gene_align_id( $gene_tree->get_value_for_tag('unflanked_alignment_gene_align_id') );

                } else {
                    # If an unflanked genomic alignment is unavailable for
                    # any reason, try a trivial alignment if appropriate.
                    my @tree_leaves = @{$gene_tree->get_all_leaves()};
                    my $num_members = scalar(@tree_leaves);
                    my %tree_seq_id_set = map { $_->sequence_id => 1 } @tree_leaves;
                    my $num_distinct_sequences = scalar keys %tree_seq_id_set;
                    if ($num_distinct_sequences == 1) {

                        my $trivial_aln = $self->generate_trivial_alignment($gene_tree);
                        $trivial_aln->dbID( $gene_tree->get_value_for_tag('trivial_alignment_gene_align_id') );
                        $gene_align_adaptor->store($trivial_aln);

                        $gene_tree->store_tag('trivial_alignment_gene_align_id', $trivial_aln->dbID);
                        $gene_tree->store_tag('aln_num_residues', $trivial_aln->aln_length * $num_members);
                        $gene_tree->store_tag('aln_length', $trivial_aln->aln_length);
                        $gene_tree->store_tag('aln_percent_identity', 100.0);


                        # Leave the gene-tree alignment as the one identified by 'genomic_alignment_gene_align_id'
                        # until the last possible moment. That way, errors do not prevent us from trying again.
                        $gene_tree->alignment($trivial_aln);
                    }
                }
            }
        }

        $self->store_genetree($gene_tree);
    }

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

# Generate a trivial alignment for a gene tree in
# which all the member sequences are identical.
sub generate_trivial_alignment {
    my ($self, $gene_tree) = @_;
    my $aligned_member_adaptor = $self->compara_dba->get_AlignedMemberAdaptor();

    my $trivial_alignment = $gene_tree->deep_copy();
    bless $trivial_alignment, 'Bio::EnsEMBL::Compara::AlignedMemberSet';
    $trivial_alignment->aln_method('identical_seq');
    $trivial_alignment->seq_type(undef);

    my $aln_length;
    my $trivial_cigar;
    foreach my $member (@{$trivial_alignment->get_all_Members()}) {
        bless $member, 'Bio::EnsEMBL::Compara::AlignedMember';
        $member->adaptor($aligned_member_adaptor);

        if (!defined $trivial_cigar) {
            $trivial_cigar = Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string($member->sequence);
            $aln_length = $member->seq_length;
        }

        $member->cigar_line($trivial_cigar);
    }

    $trivial_alignment->aln_length($aln_length);

    return $trivial_alignment;
}

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
    # Should not happen because of other healthchecks, but it never hurts
    # to check again (and TreeBest segfaults without printing any
    # meaningful messages)
    foreach my $n (@{$other_tree->get_all_nodes}) {
        if (scalar(@{$n->children}) == 1) {
            die sprintf("node_id=%d in root_id=%d (%s) is unary", $n->node_id, $other_tree->root_id, $other_tree->clusterset_id);
        }
    }

    my $tag = $other_tree->clusterset_id;
    $self->param('inputtrees_unrooted')->{$tag} = $other_tree->newick_format('ryo','%{-m}%{"_"-X}:%{d}');
    print STDERR $self->param('inputtrees_unrooted')->{$tag}, "\n" if ($self->debug);
  }
}


1;
