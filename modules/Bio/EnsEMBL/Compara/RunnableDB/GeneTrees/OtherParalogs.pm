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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs

=head1 DESCRIPTION

This analysis will load a super gene tree and insert the
extra paralogs into the homology tables.

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $otherparalogs = Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$otherparalogs->fetch_input(); #reads from DB
$otherparalogs->run();
$otherparalogs->write_output(); #writes to DB

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs;

use strict;
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Graph::Link;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree');


sub fetch_input {
    my $self = shift;
    $self->SUPER::fetch_input;

    my $alignment_id = $self->param('gene_tree')->tree->gene_align_id;
    my $aln = $self->compara_dba->get_GeneAlignAdaptor->fetch_by_dbID($alignment_id);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $aln);

    my %super_align;
    foreach my $member (@{$aln->get_all_Members}) {
        bless $member, 'Bio::EnsEMBL::Compara::GeneTreeMember';
        $super_align{$member->seq_member_id} = $member;
    }
    $self->param('super_align', \%super_align);
    $self->param('homology_consistency', {});
    $self->param('homology_links', []);
    $self->delete_old_homologies;

    my %gdb_id2stn = ();
    foreach my $taxon (@{$self->param('gene_tree')->tree->species_tree->root->get_all_leaves}) {
        $gdb_id2stn{$taxon->genome_db_id} = $taxon;
    }
    $self->param('gdb_id2stn', \%gdb_id2stn);
}

sub write_output {
    my $self = shift @_;
    $self->run_analysis;
}


=head2 run_analysis

    This function will create all the links between two genes from two different sub-trees, and from the same species

=cut

sub run_analysis {
    my $self = shift;

    my $starttime = time()*1000;
    my $gene_tree = $self->param('gene_tree');

    my $tmp_time = time();
    print "build paralogs graph\n" if ($self->debug);
    my $ngenepairlinks = $self->rec_add_paralogs($gene_tree);
    print "$ngenepairlinks pairings\n" if ($self->debug);

    printf("%1.3f secs build links and features\n", time()-$tmp_time) if($self->debug>1);
    #display summary stats of analysis 
    my $runtime = time()*1000-$starttime;  
    $gene_tree->tree->store_tag('OtherParalogs_runtime_msec', $runtime) unless ($self->param('_readonly'));
    $self->param('orthotree_homology_counts', {'other_paralog' => $ngenepairlinks});

}

sub rec_add_paralogs {
    my $self = shift;
    my $ancestor = shift;

    $ancestor->print_node if ($self->debug);
    return unless $ancestor->get_child_count;
    my ($child1, $child2) = @{$ancestor->children};
    $child1->print_node if ($self->debug);
    $child2->print_node if ($self->debug);

    # All the homologies will share this information
    my $this_taxon = $ancestor->get_value_for_tag('species_tree_node_id');

    # The node_type of the root
    unless ($self->param('_readonly')) {
        my $original_node_type = $ancestor->get_value_for_tag('node_type');
        print "original_node_type: $original_node_type\n" if ($self->debug);
        if ($ancestor->get_value_for_tag('is_dup', 0)) {
            $ancestor->store_tag('node_type', 'duplication');
            $self->duplication_confidence_score($ancestor);
        } elsif (($child1->get_value_for_tag('species_tree_node_id') == $this_taxon) or ($child2->get_value_for_tag('species_tree_node_id') == $this_taxon)) {
            $ancestor->store_tag('node_type', 'dubious');
            $ancestor->store_tag('duplication_confidence_score', 0);
        } else {
            $ancestor->store_tag('node_type', 'speciation');
            $ancestor->delete_tag('duplication_confidence_score');
        }
        print "setting node_type to ", $ancestor->get_value_for_tag('node_type'), "\n" if ($self->debug);
    }

    # Each species
    my $ngenepairlinks = 0;
    foreach my $genome_db_id (keys %{$ancestor->get_value_for_tag('gene_hash')}) {
        # Each gene from the sub-tree 1
        foreach my $gene1 (@{$child1->get_value_for_tag('gene_hash')->{$genome_db_id}}) {
            # Each gene from the sub-tree 2
            foreach my $gene2 (@{$child2->get_value_for_tag('gene_hash')->{$genome_db_id}}) {
                my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link($gene1, $gene2, 0);
                $genepairlink->add_tag("ancestor", $ancestor);
                $genepairlink->add_tag("orthotree_type", 'other_paralog');
                $genepairlink->add_tag("is_tree_compliant", 1);
                $ngenepairlinks++;
                $self->store_gene_link_as_homology($genepairlink) if $self->param('store_homologies');
                $genepairlink->dealloc;
            }
        }
    }
    $ngenepairlinks += $self->rec_add_paralogs($child1);
    $ngenepairlinks += $self->rec_add_paralogs($child2);
    return $ngenepairlinks;
}


=head2 duplication_confidence_score

    Super-trees lack the duplication confidence scores, and we have to compute them here

=cut

sub duplication_confidence_score {
  my $self = shift;
  my $ancestor = shift;

  # This assumes bifurcation!!! No multifurcations allowed
  my ($child_a, $child_b, $dummy) = @{$ancestor->children};
  $self->throw("tree is multifurcated in duplication_confidence_score\n") if (defined($dummy));
  my @child_a_gdbs = keys %{$self->get_ancestor_species_hash($child_a)};
  my @child_b_gdbs = keys %{$self->get_ancestor_species_hash($child_b)};
  my %seen = ();  my @gdb_a = grep { ! $seen{$_} ++ } @child_a_gdbs;
     %seen = ();  my @gdb_b = grep { ! $seen{$_} ++ } @child_b_gdbs;
  my @isect = my @diff = my @union = (); my %count;
  foreach my $e (@gdb_a, @gdb_b) { $count{$e}++ }
  foreach my $e (keys %count) {
    push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e;
  }

  my $duplication_confidence_score = 0;
  my $scalar_isect = scalar(@isect);
  my $scalar_union = scalar(@union);
  $duplication_confidence_score = (($scalar_isect)/$scalar_union) unless (0 == $scalar_isect);

  $ancestor->store_tag("duplication_confidence_score", $duplication_confidence_score) unless ($self->param('_readonly'));
}



=head2 get_ancestor_species_hash

    This function is optimized for super-trees:
     - It fetches all the gene tree leaves
     - It is able to jump from a super-tree to the sub-trees
     - It stores the list of all the leaves to save DB queries

=cut

sub get_ancestor_species_hash
{
    my $self = shift;
    my $node = shift;

    my $species_hash = $node->get_value_for_tag('species_hash');
    return $species_hash if($species_hash);

    print $node->node_id, " is a ", $node->tree->tree_type, "\n" if ($self->debug);
    my $gene_hash = {};
    my @sub_taxa = ();

    if ($node->is_leaf) {
  
        # Super-tree leaf
        $node->adaptor->fetch_all_children_for_node($node);
        print "super-tree leaf=", $node->node_id, " children=", $node->get_child_count, "\n";
        my $child = $node->children->[0];
        my $leaves = $self->compara_dba->get_GeneTreeNodeAdaptor->fetch_all_AlignedMember_by_root_id($child->node_id);
        eval {
            $self->dataflow_output_id({'gene_tree_id' => $child->node_id}, 2) if ($self->param('dataflow_subclusters'));
        };
        $child->disavow_parent;

        foreach my $leaf (@$leaves) {
            print $leaf->toString if ($self->debug);
            $species_hash->{$leaf->genome_db_id} = 1 + ($species_hash->{$leaf->genome_db_id} || 0);
            push @sub_taxa, $self->param('gdb_id2stn')->{$leaf->genome_db_id};
            push @{$gene_hash->{$leaf->genome_db_id}}, $self->param('super_align')->{$leaf->seq_member_id};
        }
   
    } else {

        # Super-tree root
        print "super-tree root=", $node->node_id, " children=", $node->get_child_count, "\n";
        my $is_dup = 0;
        foreach my $child (@{$node->children}) {
            print "child: ", $child->node_id, "\n" if ($self->debug);
            my $t_species_hash = $self->get_ancestor_species_hash($child);
            push @sub_taxa, $child->get_value_for_tag('lca_taxon');
            foreach my $genome_db_id (keys(%$t_species_hash)) {
                $is_dup ||= (exists $species_hash->{$genome_db_id});
                $species_hash->{$genome_db_id} = $t_species_hash->{$genome_db_id} + ($species_hash->{$genome_db_id} || 0);
                push @{$gene_hash->{$genome_db_id}}, @{$child->get_value_for_tag('gene_hash')->{$genome_db_id}};
            }
        }

        $node->add_tag("is_dup", $is_dup);
 
    }

    my $lca_taxon = shift @sub_taxa;
    foreach my $this_taxon (@sub_taxa) {
        $lca_taxon = $lca_taxon->find_first_shared_ancestor($this_taxon);
    }

    printf("%s is a '%s' and contains %d species\n", $node->node_id, $lca_taxon->node_name, scalar(keys %$species_hash)) if ($self->debug);
    $node->add_tag("species_hash", $species_hash);
    $node->add_tag("gene_hash", $gene_hash);
    $node->add_tag('lca_taxon', $lca_taxon);
    $node->store_tag('species_tree_node_id', $lca_taxon->node_id);

    return $species_hash;
}

1;
