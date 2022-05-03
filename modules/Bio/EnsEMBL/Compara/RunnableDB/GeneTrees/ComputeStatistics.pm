
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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

This runnable computes statistics used in the benchmark of various aspects of the pipeline.
All results are stored in method_link_species_set_tag.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComputeStatistics;

use strict;
use warnings;

use Data::Dumper;
use Statistics::Descriptive;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;
    my $clusterset_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_all( -tree_type => 'clusterset', -member_type => $self->param( 'member_type' ), -clusterset_id => 'default' )->[0] or $self->die_no_retry("Could not fetch groupset tree");
    $self->param('clusterset_tree', $clusterset_tree);
}

sub run {
    my $self = shift @_;

    my $homology_counts = $self->_get_homology_counts();
    $self->param( 'homology_counts', $homology_counts );

    my $avg_perc_identity = $self->_get_avg_perc_identity();
    $self->param( 'avg_perc_identity', $avg_perc_identity );

    my $avg_duplication_confidence_score = $self->_get_avg_duplication_confidence_score();
    $self->param( 'avg_duplication_confidence_score', $avg_duplication_confidence_score );

    $self->_get_number_of_proteins_used();
    $self->_get_mean_cluster_size_per_protein();

    my $size_summary = $self->_get_sizes_summary();
    $self->param( 'size_summary', $size_summary );

    my $gini_coefficient= $self->_compute_gini_coefficient();
    $self->param( 'gini_coefficient', $gini_coefficient);

}

sub write_output {
    my $self = shift;

    my $clusterset_tree = $self->param('clusterset_tree');

    # FIXME: should be storing the tags even if the value if 0 !
    # FIXME: should not have "protein" in the name

    #homology_counts
    if ( keys %{ $self->param('homology_counts') } > 0 ) {
        print "\nStoring homology_counts\n" if $self->debug;
        foreach my $key ( keys %{ $self->param('homology_counts') } ) {
            print "$key|" . $self->param('homology_counts')->{$key} . "|\n" if $self->debug;
            $clusterset_tree->store_tag( $key, $self->param('homology_counts')->{$key} );
        }
    }

    #avg_perc_identity
    if ( keys %{ $self->param('avg_perc_identity') } > 0 ) {
        print "\nStoring avg_perc_identity\n" if $self->debug;
        foreach my $key ( keys %{ $self->param('avg_perc_identity') } ) {
            print "$key|" . $self->param('avg_perc_identity')->{$key} . "|\n" if $self->debug;
            $clusterset_tree->store_tag( $key, $self->param('avg_perc_identity')->{$key} );
        }
    }

    #avg_duplication_confidence_score
    if ( keys %{ $self->param('avg_duplication_confidence_score') } > 0 ) {
        print "\nStoring avg_duplication_confidence_score\n" if $self->debug;
        foreach my $key ( keys %{ $self->param('avg_duplication_confidence_score') } ) {
            print "$key|" . $self->param('avg_duplication_confidence_score')->{$key} . "|\n" if $self->debug;
            $clusterset_tree->store_tag( $key, $self->param('avg_duplication_confidence_score')->{$key} );
        }
    }

    #size_summary
    if ( keys %{ $self->param('size_summary') } > 0 ) {
        print "\nStoring size_summary\n" if $self->debug;
        foreach my $key ( keys %{ $self->param('size_summary') } ) {
            print "$key|" . $self->param('size_summary')->{$key} . "|\n" if $self->debug;
            $clusterset_tree->store_tag( $key, $self->param('size_summary')->{$key} );
        }
    }

    #number_of_proteins_used_in_trees
    if ( $self->param('number_of_proteins_used_in_trees') > 0 ) {
        print "\nStoring number_of_proteins_used_in_trees\n" if $self->debug;
        $clusterset_tree->store_tag( 'stat.number_of_proteins_used_in_trees', $self->param('number_of_proteins_used_in_trees') );
    }

    #gini_coefficient
    if ( $self->param('gini_coefficient') > 0 ) {
        print "\nStoring gini_coefficient\n" if $self->debug;
        $clusterset_tree->store_tag( 'stat.gini_coefficient', $self->param('gini_coefficient') );
    }

    #number_of_orphan_proteins
    if ( $self->param('number_of_orphan_proteins') > 0 ) {
        print "\nStoring number_of_orphan_proteins\n" if $self->debug;
        $clusterset_tree->store_tag( 'stat.number_of_orphan_proteins', $self->param('number_of_orphan_proteins') );
    }

    #number_of_unassigned_proteins
    if ( $self->param('number_of_unassigned_proteins') > 0 ) {
        print "\nStoring number_of_unassigned_proteins\n" if $self->debug;
        $clusterset_tree->store_tag( 'stat.number_of_unassigned_proteins', $self->param('number_of_unassigned_proteins') );
    }

    #number_of_proteins_in_single_species_trees
    if ( $self->param('number_of_proteins_in_single_species_trees') > 0 ) {
        print "\nStoring number_of_proteins_in_single_species_trees\n" if $self->debug;
        $clusterset_tree->store_tag( 'stat.number_of_proteins_in_single_species_trees', $self->param('number_of_proteins_in_single_species_trees') );
    }

    #mean_cluster_size_per_protein
    if ( $self->param('mean_cluster_size_per_protein') > 0 ) {
        print "\nStoring mean_cluster_size_per_protein\n" if $self->debug;
        $clusterset_tree->store_tag( 'stat.mean_cluster_size_per_protein', $self->param('mean_cluster_size_per_protein') );
    }
} ## end sub write_output

##########################################
#
# internal methods
#
##########################################

sub _get_homology_counts {
    my ($self) = @_;

    my %homology_counts;

    #Compute Homology counts
    my $sql = "SELECT description, is_tree_compliant, node_type, COUNT(*) FROM homology JOIN gene_tree_node_attr ON gene_tree_node_id = node_id GROUP BY description, is_tree_compliant, node_type";
    my $sth = $self->compara_dba->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute();
    while ( my @row = $sth->fetchrow_array() ) {
        my $description       = $row[0];
        my $is_tree_compliant = $row[1];
        my $node_type         = $row[2];
        my $count             = $row[3];

        my $tree_compliance = $is_tree_compliant ? "tree_compliant" : "not_tree_compliant";
        my $key = "stat.homology_counts.$description.$node_type.$tree_compliance";
        $homology_counts{$key} = $count;
    }
    $sth->finish();

    return \%homology_counts;
}

sub _get_avg_perc_identity {
    my ($self) = @_;
    my %avg_perc_identity;

    #Compute Average percentage identity
    my $sql = "SELECT description, is_tree_compliant, ROUND(AVG(perc_id),2) FROM homology JOIN homology_member USING (homology_id) GROUP BY description, is_tree_compliant";
    my $sth = $self->compara_dba->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute();
    while ( my @row = $sth->fetchrow_array() ) {
        my $description       = $row[0];
        my $is_tree_compliant = $row[1];
        my $count             = $row[2];

        if ( $count > 0 ) {
            my $tree_compliance = $is_tree_compliant ? "tree_compliant" : "not_tree_compliant";
            my $key = "stat.avg_perc_identity.$description.$tree_compliance";
            $avg_perc_identity{$key} = $count;
        }
    }
    $sth->finish();

    return \%avg_perc_identity;
}

sub _get_avg_duplication_confidence_score {
    my ($self) = @_;

    my %avg_duplication_confidence_score;

    #Compute Average duplication confidence score
    my $sql = "SELECT description, AVG(duplication_confidence_score) FROM homology JOIN gene_tree_node_attr ON gene_tree_node_id = node_id WHERE node_type = 'duplication' GROUP BY description;";
    my $sth = $self->compara_dba->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute();
    while ( my @row = $sth->fetchrow_array() ) {
        my $description = $row[0];
        my $score       = $row[1];

        my $key = "stat.avg_duplication_confidence_score." . $description;
        $avg_duplication_confidence_score{$key} = $score;
    }
    $sth->finish();

    return \%avg_duplication_confidence_score;
}

sub _get_number_of_proteins_used {
    my ($self) = @_;

    #Compute the number of proteins used in trees
    my $sql = "SELECT SUM(nb_genes_in_tree), SUM(nb_orphan_genes), SUM(nb_genes_in_tree_single_species) FROM species_tree_node_attr JOIN species_tree_node USING (node_id) WHERE node_id IN (SELECT node_id FROM species_tree_node where genome_db_id IS NOT NULL)";

    my $sth = $self->compara_dba->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute();
    while ( my @row = $sth->fetchrow_array() ) {
        my $number_of_proteins_used_in_trees           = $row[0];
        my $number_of_orphan_proteins                  = $row[1];
        my $number_of_proteins_in_single_species_trees = $row[2];

        $self->param( 'number_of_proteins_used_in_trees',           $number_of_proteins_used_in_trees );
        $self->param( 'number_of_orphan_proteins',                  $number_of_orphan_proteins );
        $self->param( 'number_of_proteins_in_single_species_trees', $number_of_proteins_in_single_species_trees );
    }
    $sth->finish();

    # Compute the number of genes that are unassigned to a tree
    my $sql2 = q/
        SELECT SUM(stnt.value)
        FROM species_tree_node_tag stnt JOIN species_tree_node USING (node_id)
        WHERE stnt.tag = 'nb_genes_unassigned'
        AND node_id IN (SELECT node_id FROM species_tree_node WHERE genome_db_id IS NOT NULL)
    /;

    my $sth2 = $self->compara_dba->dbc->prepare( $sql2, { 'mysql_use_result' => 1 } );
    $sth2->execute();
    while ( my @row = $sth2->fetchrow_array() ) {
        $self->param( 'number_of_unassigned_proteins', $row[0] );
    }
    $sth2->finish();
}

sub _get_sizes_summary {
    my ($self) = @_;

    my %sizes_summary;
    my $stats = new Statistics::Descriptive::Full;
    my @count_seq_member_ids;

    #Compute Mean and median, max, min cluster sizes, number of proteins per cluster:
    my $sql = "SELECT count(seq_member_id) FROM gene_tree_root JOIN gene_tree_node USING (root_id) where clusterset_id = 'default' and tree_type = 'tree' and member_type = '" . $self->param( 'member_type' ) . "' and seq_member_id IS NOT NULL GROUP BY root_id";
    my $sth = $self->compara_dba->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute();
    while ( my @row = $sth->fetchrow_array() ) {
        push( @count_seq_member_ids, $row[0] );
    }
    $sth->finish();

    $stats->add_data( \@count_seq_member_ids );
    my $median = $stats->median;
    my $mean   = $stats->mean;
    my $max    = $stats->max;
    my $min    = $stats->min;

    $sizes_summary{"stat.sizes_summary.median"} = $median;
    $sizes_summary{"stat.sizes_summary.mean"}   = $mean;
    $sizes_summary{"stat.sizes_summary.max"}    = $max;
    $sizes_summary{"stat.sizes_summary.min"}    = $min;
    return \%sizes_summary;
} ## end sub _get_sizes_summary

# Computes the Gini coefficient which measures the inequality among values.
sub _compute_gini_coefficient {
    my ($self) = @_;

    # The following code was initially based on a script implemented by Paul Kersey.
    # But the following implementation is more efficient:  http://shlegeris.com/2016/12/29/gini
    # ------------------------------------------------------------------------------
    my $sql = "SELECT b.root_id, count(seq_member_id) AS cni
                             FROM gene_tree_root a, gene_tree_node b
                             WHERE a.root_id = b.root_id
                             AND tree_type = 'tree'
                             AND clusterset_id = 'default'
                             AND member_type = '" . $self->param( 'member_type' ) . "'
                             AND seq_member_id is NOT NULL
                             GROUP BY root_id
                             ORDER BY cni";

    my $sum_of_absolute_differences = 0;
    my $subsum                      = 0;
    my $cluster_count               = 0;

    my $sth = $self->compara_dba->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute();
    while ( my @row = $sth->fetchrow_array() ) {
        $sum_of_absolute_differences += $cluster_count*$row[1] - $subsum;
        $subsum += $row[1];
        $cluster_count++;
    }
    $sth->finish();

    my $gini_coefficient = $sum_of_absolute_differences/$subsum/$cluster_count;

    # ------------------------------------------------------------------------------

    return $gini_coefficient;
} ## end sub _compute_gini_coefficient

sub _get_mean_cluster_size_per_protein  {
    my ($self) = @_;

    #Compute the mean cluster size per protein
    my $sql = "SELECT AVG(gene_count) FROM gene_tree_root_attr JOIN gene_tree_root USING (root_id) JOIN gene_tree_node USING (root_id) WHERE seq_member_id IS NOT NULL AND clusterset_id = 'default' AND member_type = '" . $self->param( 'member_type' ) . "' AND tree_type = 'tree'";

    my $mean_cluster_size_per_protein = $self->compara_dba->dbc->sql_helper->execute_single_result(-SQL => $sql);

    $self->param( 'mean_cluster_size_per_protein', $mean_cluster_size_per_protein);
}

1;
