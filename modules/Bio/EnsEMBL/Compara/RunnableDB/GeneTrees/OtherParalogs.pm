=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

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

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs;

use strict;

use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Graph::Link;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree');


sub param_defaults {
    return {
            'tag_split_genes'       => 0,
            'store_homologies'      => 1,
    };
}

sub fetch_input {
    my $self = shift;
    $self->SUPER::fetch_input;

    my $alignment_id = $self->param('gene_tree')->tree->gene_align_id;
    my $aln = $self->compara_dba->get_GeneAlignAdaptor->fetch_by_dbID($alignment_id);

    my %super_align;
    foreach my $member (@{$aln->get_all_Members}) {
        bless $member, 'Bio::EnsEMBL::Compara::GeneTreeMember';
        $super_align{$member->member_id} = $member;
    }
    $self->param('super_align', \%super_align);
    $self->param('homology_consistency', {});
    $self->param('homology_links', []);
    $self->delete_old_homologies;
}

sub write_output {
    my $self = shift @_;

}


=head2 run_analysis

    This function will create all the links between two genes from two different sub-trees, and from the same species

=cut
sub run_analysis {
    my $self = shift;

    my $starttime = time()*1000;
    my $gene_tree = $self->param('gene_tree');

    print "Calculating ancestor species hash\n" if ($self->debug);
    $self->get_ancestor_species_hash($gene_tree);

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
    $self->get_ancestor_taxon_level($ancestor);
    my $taxon_name = $ancestor->get_tagvalue('taxon_name');
    print "taxon_name: $taxon_name\n" if ($self->debug);

    # The node_type of the root
    unless ($self->param('_readonly')) {
        my $original_node_type = $ancestor->get_tagvalue('node_type');
        print "original_node_type: $original_node_type\n" if ($self->debug);
        if ($ancestor->get_tagvalue('is_dup', 0)) {
            $ancestor->store_tag('node_type', 'duplication');
            $self->duplication_confidence_score($ancestor);
        } elsif (($child1->get_tagvalue('taxon_name') eq $taxon_name) or ($child2->get_tagvalue('taxon_name') eq $taxon_name)) {
            $ancestor->store_tag('node_type', 'dubious');
            $ancestor->store_tag('duplication_confidence_score', 0);
        } else {
            $ancestor->store_tag('node_type', 'speciation');
        }
        print "setting node_type to ", $ancestor->get_tagvalue('node_type'), "\n" if ($self->debug);
    }

    # Each species
    my $ngenepairlinks = 0;
    foreach my $genome_db_id (keys %{$ancestor->get_tagvalue('gene_hash')}) {
        # Each gene from the sub-tree 1
        foreach my $gene1 (@{$child1->get_tagvalue('gene_hash')->{$genome_db_id}}) {
            # Each gene from the sub-tree 2
            foreach my $gene2 (@{$child2->get_tagvalue('gene_hash')->{$genome_db_id}}) {
                my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link($gene1, $gene2, 0);
                $genepairlink->add_tag("ancestor", $ancestor);
                $genepairlink->add_tag("taxon_name", $taxon_name);
                $genepairlink->add_tag("tree_node_id", $ancestor->tree->root_id);
                $genepairlink->add_tag("orthotree_type", 'other_paralog');
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

    my $species_hash = $node->get_tagvalue('species_hash');
    return $species_hash if($species_hash);

    print $node->node_id, " is a ", $node->tree->tree_type, "\n" if ($self->debug);
    my $gene_hash = {};

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
            $leaf->print_member if ($self->debug);
            $species_hash->{$leaf->genome_db_id} = 1 + ($species_hash->{$leaf->genome_db_id} || 0);
            push @{$gene_hash->{$leaf->genome_db_id}}, $self->param('super_align')->{$leaf->member_id};
        }
   
    } else {

        # Super-tree root
        print "super-tree root=", $node->node_id, " children=", $node->get_child_count, "\n";
        my $is_dup = 0;
        foreach my $child (@{$node->children}) {
            print "child: ", $child->node_id, "\n" if ($self->debug);
            my $t_species_hash = $self->get_ancestor_species_hash($child);
            foreach my $genome_db_id (keys(%$t_species_hash)) {
                $is_dup ||= (exists $species_hash->{$genome_db_id});
                $species_hash->{$genome_db_id} = $t_species_hash->{$genome_db_id} + ($species_hash->{$genome_db_id} || 0);
                push @{$gene_hash->{$genome_db_id}}, @{$child->get_tagvalue('gene_hash')->{$genome_db_id}};
            }
        }

        $node->add_tag("is_dup", $is_dup);
 
    }

    print $node->node_id, " contains ", scalar(keys %$species_hash), " species\n" if ($self->debug);
    $node->add_tag("species_hash", $species_hash);
    $node->add_tag("gene_hash", $gene_hash);

    return $species_hash;
}

1;
