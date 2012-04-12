=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
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
$otherparalogs->output();
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

use Bio::EnsEMBL::Compara::Graph::Link;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree');


sub param_defaults {
    return {
            'tag_split_genes'       => 0,
            'store_homologies'      => 1,
    };
}


sub write_output {
    my $self = shift @_;

    $self->store_homologies;
    if ($self->param('dataflow_subclusters')) {
        foreach my $child (@{$self->param('children')}) {
            $self->dataflow_output_id({'protein_tree_id' => $child->node_id}, 2);
        }
    }
}


=head2 run_analysis

    This function will create all the links between two genes from two different sub-trees, and from the same species

=cut
sub run_analysis {
    my $self = shift;

    my $starttime = time()*1000;
    my $gene_tree = $self->param('gene_tree');
    my $tree_node_id = $gene_tree->node_id;

    my ($child1, $child2) = @{$gene_tree->children};
    $self->param('children', $gene_tree->children);

    print "Calculating ancestor species hash\n" if ($self->debug);
    $self->get_ancestor_species_hash($gene_tree);

    my $tmp_time = time();
    print "build paralogs graph\n" if ($self->debug);
    my @genepairlinks;
    my $graphcount = 0;

    # All the homologies will share this information
    my $ancestor = $gene_tree;
    my $taxon_name = $self->get_ancestor_taxon_level($ancestor)->name;

    # The node_type of the root
    unless ($self->param('_readonly')) {
        my $original_node_type = $gene_tree->get_tagvalue('node_type');
        if ($gene_tree->get_tagvalue('is_dup', 0)) {
            $gene_tree->store_tag('node_type', 'duplication');
            $self->duplication_confidence_score($gene_tree);
        } elsif (($child1->get_tagvalue('taxon_name') eq $taxon_name) or ($child2->get_tagvalue('taxon_name') eq $taxon_name)) {
            $gene_tree->store_tag('node_type', 'dubious');
            $gene_tree->store_tag('duplication_confidence_score', 0);
        } else {
            $gene_tree->store_tag('node_type', 'speciation');
        }
        print "setting node_type of the root to ", $gene_tree->get_tagvalue('node_type'), "\n";
    }

    # Each species
    foreach my $genome_db_id (keys %{$child1->get_tagvalue('gene_hash')}) {
        # Each gene from the sub-tree 1
        foreach my $gene1 (@{$child1->get_tagvalue('gene_hash')->{$genome_db_id}}) {
            # Each gene from the sub-tree 2
            foreach my $gene2 (@{$child2->get_tagvalue('gene_hash')->{$genome_db_id}}) {
                my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link($gene1, $gene2, 0);
                $genepairlink->add_tag("ancestor", $ancestor);
                $genepairlink->add_tag("taxon_name", $taxon_name);
                $genepairlink->add_tag("tree_node_id", $tree_node_id);
                $genepairlink->add_tag("orthotree_type", 'other_paralog');
                push @genepairlinks, $genepairlink;
                print "build links $graphcount\n" if ($graphcount++ % 10 == 0 and $self->debug);
            }
        }
    }
    printf("%1.3f secs build links and features\n", time()-$tmp_time) if($self->debug>1);
    
    $self->param('orthotree_homology_counts', {'other_paralog' => $graphcount});

    print scalar(@genepairlinks), " pairings\n" if ($self->debug);
    $self->param('homology_links', \@genepairlinks);

    #display summary stats of analysis 
    my $runtime = time()*1000-$starttime;  
    $gene_tree->tree->store_tag('OtherParalogs_runtime_msec', $runtime) unless ($self->param('_readonly'));

}


=head2 get_ancestor_species_hash

    This function is optimized for super-trees:
     - It fetches all the gene tree leaves in one go (with left/right_index)
     - It is able to jump from a super-tree to the sub-trees
     - It stores the list of all the leaves to save DB queries

=cut
sub get_ancestor_species_hash
{
    my $self = shift;
    my $node = shift;

    my $species_hash = $node->get_tagvalue('species_hash');
    return $species_hash if($species_hash);

    my $gene_hash = {};
    if ($node->tree->tree_type eq 'tree') {
        foreach my $leaf (@{$self->param('treeDBA')->fetch_all_leaves_indexed($node)}) {
            $species_hash->{$leaf->genome_db_id} = 1 + ($species_hash->{$leaf->genome_db_id} || 0);
            push @{$gene_hash->{$leaf->genome_db_id}}, $leaf;
        }
    
    } else {

        delete $node->{'_children_loaded'} unless $node->get_child_count;
        my $is_dup = 0;
        
        foreach my $child (@{$node->children}) {
            my $t_species_hash = $self->get_ancestor_species_hash($child);
            foreach my $genome_db_id (keys(%$t_species_hash)) {
                $is_dup ||= (exists $species_hash->{$genome_db_id});
                $species_hash->{$genome_db_id} = $t_species_hash->{$genome_db_id} + ($species_hash->{$genome_db_id} || 0);
                push @{$gene_hash->{$genome_db_id}}, @{$child->get_tagvalue('gene_hash')->{$genome_db_id}};
            }
        }

        $node->add_tag("is_dup", $is_dup);
    }

    $node->add_tag("species_hash", $species_hash);
    $node->add_tag("gene_hash", $gene_hash);

    return $species_hash;
}

1;
