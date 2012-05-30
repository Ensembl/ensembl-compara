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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes

=head1 DESCRIPTION

This Runnable will build the list of contiguous split genes and store
them in the 'split_genes' table. One of the following conditions must
be true:
 - The two sequences do not overlap at all, and the genes are next to
   each other (less than 1 Mb), with at most 1 gene in between
 - The two sequences slightly overlap, and the genes are consecutive
   in the genome and less than 500 kb apart

=head1 SYNOPSIS

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes \
 -compara_db mysql://server/mm14_compara_homology_67 -protein_tree_id 267568

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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes;

use strict;

use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Graph::ConnectedComponentGraphs;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree');

sub param_defaults {
    return {
            'max_dist_no_overlap'           => 1000000, # Max distance between genes that do not overlap
            'max_nb_genes_no_overlap'       => 1,       # Number of genes between two genes that do not overlap
            'max_dist_small_overlap'        => 500000,  # Max distance between genes that slightly overlap
            'small_overlap_percentage'      => 10,      # Max %ID and %pos to define a 'small' overlap
            'max_nb_genes_small_overlap'    => 0,       # Number of genes between two genes that slightly overlap
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->check_if_exit_cleanly;

    my $protein_tree_id = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";
    my $protein_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($protein_tree_id) or die "Could not fetch protein_tree with protein_tree_id='$protein_tree_id'";
    $protein_tree->print_tree(0.0001) if($self->debug);

    $self->param('protein_tree', $protein_tree);
    $self->param('member_adaptor', $self->compara_dba->get_MemberAdaptor);
}


sub run {
    my $self = shift;

    $self->check_if_exit_cleanly;
    $self->check_for_split_genes
}


sub write_output {
    my $self = shift;

    $self->check_if_exit_cleanly;
    $self->store_split_genes;
}


sub DESTROY {
    my $self = shift;

    if(my $protein_tree = $self->param('protein_tree')) {
        printf("FindContiguousSplitGenes::DESTROY  releasing tree\n") if($self->debug);
        $protein_tree->release_tree;
        $self->param('protein_tree', undef);
    }

    $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}



sub check_for_split_genes {
    my $self = shift;
    my $protein_tree = $self->param('protein_tree');

    my $connected_split_genes = $self->param('connected_split_genes', new Bio::EnsEMBL::Compara::Graph::ConnectedComponentGraphs);

    my $tmp_time = time();

    my @all_protein_leaves = @{$protein_tree->get_all_leaves};
    printf("%1.3f secs to fetch all leaves\n", time()-$tmp_time) if ($self->debug);

    if($self->debug) {
        printf("%d proteins in tree\n", scalar(@all_protein_leaves));
    }
    printf("build paralogs graph\n") if($self->debug);
    my @genepairlinks;
    my $graphcount = 0;
    my $tree_node_id = $protein_tree->node_id;
    while (my $protein1 = shift @all_protein_leaves) {
        foreach my $protein2 (@all_protein_leaves) {
            next unless ($protein1->genome_db_id == $protein2->genome_db_id);
            push @genepairlinks, [$protein1, $protein2];
            print "build graph $graphcount\n" if ($self->debug and ($graphcount++ % 10 == 0));
        }
    }
    printf("%1.3f secs build links and features\n", time()-$tmp_time) if($self->debug>1);

    # We sort the pairings by seq_region (chr) name, then by distance between
    # the start of link_node pairs.
    # This is to try to do the joining up of cdnas in the best order in
    # cases of e.g. 2 cases of 3-way split genes in same species.
    my @sorted_genepairlinks = sort { 
        $a->[0]->chr_name <=> $b->[0]->chr_name 
            || $a->[1]->chr_name <=> $b->[1]->chr_name 
            || abs($a->[0]->chr_start - $a->[1]->chr_start) <=> abs($b->[0]->chr_start - $b->[1]->chr_start) } @genepairlinks;

    foreach my $genepairlink (@sorted_genepairlinks) {
        my ($protein1, $protein2) = @$genepairlink;
        my ($cigar_line1, $perc_id1, $perc_pos1, $cigar_line2, $perc_id2, $perc_pos2) = 
            $self->generate_attribute_arguments($protein1, $protein2, 'within_species_paralog');
        print "Pair: ", $protein1->stable_id, " - ", $protein2->stable_id, "\n" if ($self->debug);

        # Checking for gene_split cases
        if (0 == $perc_id1 && 0 == $perc_id2 && 0 == $perc_pos1 && 0 == $perc_pos2) {

            # Condition A1: If same seq region and less than 1MB distance
            my $gene_member1 = $protein1->gene_member; my $gene_member2 = $protein2->gene_member;
            if ($gene_member1->chr_name eq $gene_member2->chr_name 
                    && ($self->param('max_dist_no_overlap') > abs($gene_member1->chr_start - $gene_member2->chr_start)) 
                    && $gene_member1->chr_strand eq $gene_member2->chr_strand ) {

                # Condition A2: there have to be the only 2 or 3 protein coding
                # genes in the range defined by the gene pair. This should
                # strictly be 2, only the pair in question, but in clean perc_id
                # = 0 cases, we allow for 2+1: the rare case where one extra
                # protein coding gene is partially or fully embedded in another.
                my $start1 = $gene_member1->chr_start; my $start2 = $gene_member2->chr_start; my $starttemp;
                my $end1 = $gene_member1->chr_end; my $end2 = $gene_member2->chr_end; my $endtemp;
                if ($start1 > $start2) { $starttemp = $start1; $start1 = $start2; $start2 = $starttemp; }
                if ($end1   <   $end2) {   $endtemp = $end1;     $end1 = $end2;     $end2 = $endtemp; }
                my $strand1 = $gene_member1->chr_strand; my $taxon_id1 = $gene_member1->taxon_id; my $name1 = $gene_member1->chr_name;
                print "Checking split genes overlap\n" if $self->debug;
                my @genes_in_range = @{$self->param('member_adaptor')->_fetch_all_by_source_taxon_chr_name_start_end_strand_limit('ENSEMBLGENE',$taxon_id1,$name1,$start1,$end1,$strand1,4)};

                if ((2+$self->param('max_nb_genes_no_overlap')) < scalar @genes_in_range) {
                    foreach my $gene (@genes_in_range) {
                        print STDERR "Too many genes in range: ($start1,$end1,$strand1): ", $gene->stable_id,",", $gene->chr_start,",", $gene->chr_end,"\n" if $self->debug;
                    }
                    next;
                }
                $connected_split_genes->add_connection($protein1->node_id, $protein2->node_id);
            }

        # This is a second level of contiguous gene split events, more
        # stringent on contig but less on alignment, for "skidding"
        # alignment cases.

        # These cases take place when a few of the aminoacids in the
        # alignment have been wrongly displaced from the columns that
        # correspond to the fragment, so the identity level is slightly
        # above 0. This small number of misplaced aminoacids look like
        # "skid marks" in the alignment view.

        # Condition B1: all 4 percents below 10
        } elsif ($perc_id1 < $self->param('small_overlap_percentage') && $perc_id2 < $self->param('small_overlap_percentage')
              && $perc_pos1 < $self->param('small_overlap_percentage') && $perc_pos2 < $self->param('small_overlap_percentage')) {
            my $gene_member1 = $protein1->gene_member; my $gene_member2 = $protein2->gene_member;

            # Condition B2: If non-overlapping and smaller than 500kb start and 500kb end distance
            if ($gene_member1->chr_name eq $gene_member2->chr_name 
                    && ($self->param('max_dist_small_overlap') > abs($gene_member1->chr_start - $gene_member2->chr_start)) 
                    && ($self->param('max_dist_small_overlap') > abs($gene_member1->chr_end - $gene_member2->chr_end)) 
                    && (($gene_member1->chr_start - $gene_member2->chr_start)*($gene_member1->chr_end - $gene_member2->chr_end)) > 1
                    && $gene_member1->chr_strand eq $gene_member2->chr_strand ) {

                # Condition B3: they have to be the only 2 genes in the range:
                my $start1 = $gene_member1->chr_start; my $start2 = $gene_member2->chr_start; my $starttemp;
                my $end1 = $gene_member1->chr_end; my $end2 = $gene_member2->chr_end; my $endtemp;
                if ($start1 > $start2) { $starttemp = $start1; $start1 = $start2; $start2 = $starttemp; }
                if ($end1   <   $end2) {   $endtemp = $end1;     $end1 = $end2;     $end2 = $endtemp; }
                my $strand1 = $gene_member1->chr_strand; my $taxon_id1 = $gene_member1->taxon_id; my $name1 = $gene_member1->chr_name;

                my @genes_in_range = @{$self->param('member_adaptor')->_fetch_all_by_source_taxon_chr_name_start_end_strand_limit('ENSEMBLGENE',$taxon_id1,$name1,$start1,$end1,$strand1,4)};
                if ((2+$self->param('max_nb_genes_small_overlap')) < scalar @genes_in_range) {
                    foreach my $gene (@genes_in_range) {
                        print STDERR "Too many genes in range: ($start1,$end1,$strand1): ", $gene->stable_id,",", $gene->chr_start,",", $gene->chr_end,"\n" if $self->debug;
                    }
                    next;
                }

                # Condition B4: discard if the smaller protein is 1/10 or less of the larger and all percents above 2
                my $len1 = length($protein1->sequence); my $len2 = length($protein2->sequence); my $temp;
                if ($len1 < $len2) { $temp = $len1; $len1 = $len2; $len2 = $temp; }
                if ($len1/$len2 > 10 && $perc_id1 > 2 && $perc_id2 > 2 && $perc_pos1 > 2 && $perc_pos2 > 2) {
                    next;
                }
                $connected_split_genes->add_connection($protein1->node_id, $protein2->node_id);
            }
        }
    }

    printf("%1.3f secs label gene splits\n", time()-$tmp_time) if($self->debug>1);

    if($self->debug) {
        printf("%d pairings\n", scalar(@sorted_genepairlinks));
    }

}

sub store_split_genes {
    my $self = shift;
    my $protein_tree = $self->param('protein_tree');

    my $connected_split_genes = $self->param('connected_split_genes');
    my $holding_node = $connected_split_genes->holding_node;

    my $sth0 = $self->compara_dba->dbc->prepare('DELETE split_genes FROM split_genes JOIN gene_tree_member USING (member_id) JOIN gene_tree_node USING (node_id) WHERE root_id = ?');
    $sth0->execute($self->param('protein_tree_id'));
    $sth0->finish;

    my $sth1 = $self->compara_dba->dbc->prepare('INSERT INTO split_genes (member_id) VALUES (?)');
    my $sth2 = $self->compara_dba->dbc->prepare('INSERT INTO split_genes (member_id, split_gene_id) VALUES (?, ?)');

    foreach my $link (@{$holding_node->links}) {
        my $node1 = $link->get_neighbor($holding_node);
        my $protein1 = $protein_tree->find_leaf_by_node_id($node1->node_id);
        print STDERR "node1 $node1 $protein1\n" if $self->debug;
        $sth1->execute($protein1->member_id);
        my $split_gene_id = $sth1->{'mysql_insertid'};

        foreach my $node2 (@{$node1->all_nodes_in_graph}) {
            my $protein2 = $protein_tree->find_leaf_by_node_id($node2->node_id);
            print STDERR "node2 $node2 $protein2\n" if $self->debug;
            next if $node2->node_id eq $node1->node_id;
            $sth2->execute($protein2->member_id, $split_gene_id);
        }
    }
    $sth1->finish;
    $sth2->finish;
}

1;
