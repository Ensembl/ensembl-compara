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
 -compara_db mysql://server/mm14_compara_homology_67 -gene_tree_id 267568

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes;

use strict;
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Utils::ConnectedComponents;
use Bio::EnsEMBL::Compara::MemberSet;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'genome_db_id'                  => undef,   # By default, we process all the genome_dbs

            'max_dist_no_overlap'           => 1000000, # Max distance between genes that do not overlap
            'max_nb_genes_no_overlap'       => 1,       # Number of genes between two genes that do not overlap
            'max_dist_small_overlap'        => 500000,  # Max distance between genes that slightly overlap
            'small_overlap_percentage'      => 10,      # Max %ID and %pos to define a 'small' overlap
            'max_nb_genes_small_overlap'    => 0,       # Number of genes between two genes that slightly overlap
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->param('connected_split_genes', new Bio::EnsEMBL::Compara::Utils::ConnectedComponents);

    # We can directly fetch the leaves
    my $gene_tree_id = $self->param_required('gene_tree_id');
    my $all_protein_leaves =  $self->compara_dba->get_GeneTreeNodeAdaptor->fetch_all_AlignedMember_by_root_id($gene_tree_id);

    # The Runnable needs all these fields
    my @good_leaves = grep {defined $_->genome_db_id and defined $_->dnafrag_start and defined $_->dnafrag_end and defined $_->dnafrag_id and defined $_->dnafrag_strand} @$all_protein_leaves;

    # And sometimes, only 1 genome_db_id
    if ($self->param('genome_db_id')) {
        @good_leaves = grep {$_->genome_db_id == $self->param('genome_db_id')} @good_leaves;

    } elsif ($self->param('split_genes_gene_count') and scalar(@good_leaves) > $self->param('split_genes_gene_count')) {
        my %gdb_ids = ();
        $gdb_ids{$_->genome_db_id} = 1 for @good_leaves;
        $self->dataflow_output_id( { gene_tree_id => $gene_tree_id, genome_db_id => $_ }, 2 ) for keys %gdb_ids;
        $self->complete_early("Too many genes, will check the split-genes 1 species at a time");
    }

    # Let's preload the gene members
    # Note that we have already filtered the list at this stage, to reduce
    # the number of sequences to load, and thus the memory usage
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($self->compara_dba->get_GeneMemberAdaptor, \@good_leaves);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, \@good_leaves);

    # Note that if $self->param('genome_db_id') is set, the hash will
    # contain a single entry
    my %protein_leaves_by_genome_db_id = ();
    foreach my $leaf (@good_leaves) {
        push @{$protein_leaves_by_genome_db_id{$leaf->genome_db_id}}, $leaf;
    }
    $self->param('protein_leaves_by_genome_db_id', \%protein_leaves_by_genome_db_id);
}


sub run {
    my $self = shift;

    foreach my $genome_db_id (keys %{$self->param('protein_leaves_by_genome_db_id')}) {
        $self->check_for_split_genes($genome_db_id);
    }
}


sub write_output {
    my $self = shift;

    $self->store_split_genes;
}


sub check_for_split_genes {
    my $self = shift;
    my $genome_db_id = shift;

    printf("Working on genome_db_id $genome_db_id\n") if $self->debug;
    my $connected_split_genes = $self->param('connected_split_genes');
    my $gene_member_adaptor = $self->compara_dba->get_GeneMemberAdaptor;
    $gene_member_adaptor->db->dbc->disconnect_if_idle;

    my $tmp_time = time();

    my @these_protein_leaves = @{$self->param('protein_leaves_by_genome_db_id')->{$genome_db_id}};
    my @good_leaves = grep {defined $_->dnafrag_start and defined $_->dnafrag_end and defined $_->dnafrag_id and defined $_->dnafrag_strand} @these_protein_leaves;

    if($self->debug) {
        printf("%1.3f secs to fetch all %d/%dleaves\n", time()-$tmp_time, scalar(@these_protein_leaves), scalar(@good_leaves));
        print "build paralogs graph\n";
    }
    my @genepairlinks;
    my $graphcount = 0;
    while (my $protein1 = shift @good_leaves) {
        foreach my $protein2 (@good_leaves) {
            next if $protein1->dnafrag_id != $protein2->dnafrag_id;  ## HACK: this is only true as long as the detection algorithm below requires it
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
        $a->[0]->dnafrag_id <=> $b->[0]->dnafrag_id
            || $a->[1]->dnafrag_id <=> $b->[1]->dnafrag_id
            || abs($a->[0]->dnafrag_start - $a->[1]->dnafrag_start) <=> abs($b->[0]->dnafrag_start - $b->[1]->dnafrag_start) } @genepairlinks;

    foreach my $genepairlink (@sorted_genepairlinks) {
        my ($protein1, $protein2) = @$genepairlink;

        # Compute the sequence overlap
        my $aln = 0;
        my $len1 = 0;
        my @aln1 = split(//, $protein1->alignment_string);
        my $len2 = 0;
        my @aln2 = split(//, $protein2->alignment_string);

        for (my $i=0; $i <= $#aln1; $i++) {
            $len1++ if ($aln1[$i] ne '-');
            $len2++ if ($aln2[$i] ne '-');
            $aln++ if ($aln1[$i] ne '-' && $aln2[$i] ne '-');
        }
 
        printf("Pair: %s-%s: %d out of %d-%d\n", $protein1->stable_id, $protein2->stable_id, $aln, $len1, $len2) if ($self->debug);

        my $gene_member1 = $protein1->gene_member; my $gene_member2 = $protein2->gene_member;
        my $start1 = $gene_member1->dnafrag_start; my $start2 = $gene_member2->dnafrag_start; my $starttemp;
        my $end1 = $gene_member1->dnafrag_end; my $end2 = $gene_member2->dnafrag_end; my $endtemp;
        my $strand1 = $gene_member1->dnafrag_strand; my $strand2 = $gene_member2->dnafrag_strand;
        my $gdb_id1 = $gene_member1->genome_db_id; my $gdb_id2 = $gene_member2->genome_db_id;
        my $dnafrag_id1 = $gene_member1->dnafrag_id; my $dnafrag_id2 = $gene_member2->dnafrag_id;

        # Checking for gene_split cases
        if ($aln == 0) {

            # Condition A1: If same seq region and less than 1MB distance
            if ($dnafrag_id1 == $dnafrag_id2 && ($self->param('max_dist_no_overlap') > abs($start1 - $start2)) && $strand1 eq $strand2 ) {

                # Condition A2: there have to be the only 2 or 3 protein coding
                # genes in the range defined by the gene pair. This should
                # strictly be 2, only the pair in question, but in clean perc_id
                # = 0 cases, we allow for 2+1: the rare case where one extra
                # protein coding gene is partially or fully embedded in another.
                if ($start1 > $start2) { $starttemp = $start1; $start1 = $start2; $start2 = $starttemp; }
                if ($end1   <   $end2) {   $endtemp = $end1;     $end1 = $end2;     $end2 = $endtemp; }
                print "Checking split genes overlap\n" if $self->debug;
                my $n_genes_in_range = $gene_member_adaptor->_count_all_by_dnafrag_id_start_end_strand($dnafrag_id1, $start1, $end1, $strand1);
                $gene_member_adaptor->db->dbc->disconnect_if_idle;

                if ((2+$self->param('max_nb_genes_no_overlap')) < $n_genes_in_range) {
                    print STDERR "Too many genes in range: $n_genes_in_range\n" if $self->debug;
                    next;
                }
                $self->warning(sprintf('A pair: %s %s', $protein1->stable_id, $protein2->stable_id));
                $connected_split_genes->add_connection($protein1->seq_member_id, $protein2->seq_member_id);
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
        } elsif (100*$aln < $len1*$self->param('small_overlap_percentage')
                && 100*$aln < $len2*$self->param('small_overlap_percentage')) {

            # Condition B2: If non-overlapping and smaller than 500kb start and 500kb end distance
            if ($dnafrag_id1 == $dnafrag_id2
                    && ($self->param('max_dist_small_overlap') > abs($start1 - $start2)) 
                    && ($self->param('max_dist_small_overlap') > abs($end1 - $end2)) 
                    && (($start1 - $start2)*($end1 - $end2)) > 1
                    && $strand1 eq $strand2 ) {

                # Condition B3: they have to be the only 2 genes in the range:
                if ($start1 > $start2) { $starttemp = $start1; $start1 = $start2; $start2 = $starttemp; }
                if ($end1   <   $end2) {   $endtemp = $end1;     $end1 = $end2;     $end2 = $endtemp; }

                my $n_genes_in_range = $gene_member_adaptor->_count_all_by_dnafrag_id_start_end_strand($dnafrag_id1, $start1, $end1, $strand1);
                $gene_member_adaptor->db->dbc->disconnect_if_idle;
                if ((2+$self->param('max_nb_genes_small_overlap')) < $n_genes_in_range) {
                    print STDERR "Too many genes in range: $n_genes_in_range\n" if $self->debug;
                    next;
                }

                $self->warning(sprintf('B pair: %s %s', $protein1->stable_id, $protein2->stable_id));
                $connected_split_genes->add_connection($protein1->seq_member_id, $protein2->seq_member_id);
            }
        }
    }


    if($self->debug) {
        printf("%1.3f secs to analyze %d pairings of genome_db_id %d, (%d groups found)\n", time()-$tmp_time, scalar(@sorted_genepairlinks), $genome_db_id, $connected_split_genes->get_component_count);
    }

}

sub store_split_genes {
    my $self = shift;

    my $connected_split_genes = $self->param('connected_split_genes');

    if ($self->param('genome_db_id')) {
        my $sth0 = $self->compara_dba->dbc->prepare('DELETE split_genes FROM split_genes JOIN gene_tree_node USING (seq_member_id) JOIN seq_member USING (seq_member_id) WHERE root_id = ? AND genome_db_id = ?');
        $sth0->execute($self->param('gene_tree_id'), $self->param('genome_db_id'));
        $sth0->finish;
    } else {
        my $sth0 = $self->compara_dba->dbc->prepare('DELETE split_genes FROM split_genes JOIN gene_tree_node USING (seq_member_id) WHERE root_id = ?');
        $sth0->execute($self->param('gene_tree_id'));
        $sth0->finish;
    }

    my $sth1 = $self->compara_dba->dbc->prepare('INSERT INTO split_genes (seq_member_id) VALUES (?)');
    my $sth2 = $self->compara_dba->dbc->prepare('INSERT INTO split_genes (seq_member_id, gene_split_id) VALUES (?, ?)');

    foreach my $comp (@{$connected_split_genes->get_components}) {
        my $node1 = shift @$comp;
        print STDERR "node1 $node1\n" if $self->debug;
        $sth1->execute($node1);
        my $gene_split_id = $self->dbc->db_handle->last_insert_id(undef, undef, 'split_genes', 'gene_split_id');

        foreach my $node2 (@$comp) {
            print STDERR "node2 $node2\n" if $self->debug;
            $sth2->execute($node2, $gene_split_id);
        }
    }
    $sth1->finish;
    $sth2->finish;
}

1;
