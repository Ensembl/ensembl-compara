#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 NAME

gene_tree_stats.pl

=head1 DESCRIPTION

Generates and prints the gene coverage, gene tree sizes and gene events stats (sorted by taxon name)
for the given MLSS ID and Compara database URL.

=head1 SYNOPSIS

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/gene_tree_stats.pl \
        --url <db_url> --mlss_id <mlss_id> [--collection <collection_name>] [--html]

=head1 EXAMPLES

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/gene_tree_stats.pl \
         --url mysql://ensro@mysql-ens-compara-prod-5:4615/jalvarez_wheat_cultivars_plants_protein_trees_106 \
         --mlss_id 40151 --html

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--url url_to_gene_tree_db]>

Gene tree database URL.

=item B<[--mlss_id|--mlss-id mlss_id]>

MLSS ID to get the statistics from.

=item B<[--collection name]>

Optional. Collection name of the species tree used. By default, "default".

=item B<[--html]>

Optional. Print the stats in HTML format. By default, use TSV format.

=back

=cut

use strict;
use warnings;

use DBI;
use Getopt::Long;
use Pod::Usage;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


my ( $help, $url, $mlss_id, $html );
my $collection = "default";
GetOptions(
    "help|?"            => \$help,
    "url=s"             => \$url,
    "mlss_id|mlss-id=i" => \$mlss_id,
    "collection=s"      => \$collection,
    "html"              => \$html,
) or pod2usage(-verbose => 2);

# Handle "print usage" scenarios
pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$url or !$mlss_id;

my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($url);
my $mlss = $dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
my $species_tree = $dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($mlss_id, $collection);
my $sorted_nodes = $species_tree->root->get_all_sorted_nodes();

my $gene_tree_cov = get_gene_tree_cov($sorted_nodes);
my $tree_sizes = get_tree_sizes($sorted_nodes);
my $gene_events = get_gene_events($sorted_nodes);

print stringify_stats($gene_tree_cov, $html);
print stringify_stats($tree_sizes, $html);
print stringify_stats($gene_events, $html);


sub set_default_value_for_tag {
    my ($node, $value, @tag_list) = @_;

    foreach my $tag (@tag_list) {
        $node->add_tag($tag, $value) if not $node->has_tag($tag);
    }
}


sub roundperc2 {
    return sprintf('%.2f', 100 * $_[0]);
}


sub round2 {
    return sprintf('%.2f', $_[0]);
}


sub thousandify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}


=head2 get_gene_tree_cov

    Calculates the gene coverage, i.e. number of genes and members in total, included in trees
    (either species-specific, or encompassing other species), and orphaned (not in any tree).

=cut

sub get_gene_tree_cov {
    my $sorted_nodes = shift @_;

    my @gene_coverage = ();
    my @sums = (0) x 8;
    my @tags = qw(nb_genes nb_seq nb_orphan_genes nb_genes_in_unfiltered_cluster nb_genes_unassigned
                  nb_genes_in_tree nb_genes_in_tree_single_species nb_genes_in_tree_multi_species);
    foreach my $node (@$sorted_nodes) {
        next unless $node->is_leaf();
        set_default_value_for_tag($node, 0, @tags);
        $sums[0] += $node->get_value_for_tag('nb_genes');
        $sums[1] += $node->get_value_for_tag('nb_seq');
        $sums[2] += $node->get_value_for_tag('nb_orphan_genes');
        $sums[3] += $node->get_value_for_tag('nb_genes_in_unfiltered_cluster');
        $sums[4] += $node->get_value_for_tag('nb_genes_unassigned');
        $sums[5] += $node->get_value_for_tag('nb_genes_in_tree');
        $sums[6] += $node->get_value_for_tag('nb_genes_in_tree_single_species');
        $sums[7] += $node->get_value_for_tag('nb_genes_in_tree_multi_species');
        push @gene_coverage, [
            $node->taxon_id,
            $node->node_name,
            thousandify($node->get_value_for_tag('nb_genes')),
            thousandify($node->get_value_for_tag('nb_seq')),
            thousandify($node->get_value_for_tag('nb_orphan_genes')),
            thousandify($node->get_value_for_tag('nb_genes_in_unfiltered_cluster')),
            thousandify($node->get_value_for_tag('nb_genes_unassigned')),
            thousandify($node->get_value_for_tag('nb_genes_in_tree')),
            $node->get_value_for_tag('nb_genes') ? roundperc2($node->get_value_for_tag('nb_genes_in_tree') / $node->get_value_for_tag('nb_genes')) : 'NA',
            thousandify($node->get_value_for_tag('nb_genes_in_tree_single_species')),
            $node->get_value_for_tag('nb_genes') ? roundperc2($node->get_value_for_tag('nb_genes_in_tree_single_species') / $node->get_value_for_tag('nb_genes')) : 'NA',
            thousandify($node->get_value_for_tag('nb_genes_in_tree_multi_species')),
            $node->get_value_for_tag('nb_genes') ? roundperc2($node->get_value_for_tag('nb_genes_in_tree_multi_species') / $node->get_value_for_tag('nb_genes')) : 'NA',
        ];
    }
    # Sort array by taxon name
    my @gene_coverage_sorted = sort { lc($a->[1]) cmp lc($b->[1]) } @gene_coverage;
    # Prepend header
    unshift @gene_coverage_sorted, [
        'Taxon ID',
        'Taxon name',
        'Nb genes',
        'Nb sequences',
        'Nb orphaned genes',
        'Nb genes in unfiltered clusters',
        'Nb unassigned genes',
        'Nb genes in trees',
        '% genes in trees',
        'Nb genes in single-species trees',
        '% genes in single-species trees',
        'Nb genes in multi-species trees',
        '% genes in multi-species trees',
    ];
    # Add totals at the end of the array
    push @gene_coverage_sorted, [
        undef,
        'Total',
        thousandify($sums[0]),
        thousandify($sums[1]),
        thousandify($sums[2]),
        thousandify($sums[3]),
        thousandify($sums[4]),
        thousandify($sums[5]),
        roundperc2($sums[5] / $sums[0]),
        thousandify($sums[6]),
        roundperc2($sums[6] / $sums[0]),
        thousandify($sums[7]),
        roundperc2($sums[7] / $sums[0]),
    ];

    return \@gene_coverage_sorted;
}


=head2 get_tree_sizes

    Calculates the size of each tree (genes, and distinct species), grouped according to the root
    ancestral species.

=cut

sub get_tree_sizes {
    my $sorted_nodes = shift @_;

    my @tree_sizes = ();
    my @sums = (0) x 5;
    my @mins = (1e10) x 2;
    my @maxs = (-1) x 2;
    my @tags = qw(root_nb_trees root_nb_genes root_avg_spec root_avg_gene_per_spec root_min_gene
                  root_min_spec root_max_gene root_max_spec);
    foreach my $node (@$sorted_nodes) {
        set_default_value_for_tag($node, 0, @tags);
        $sums[0] += $node->get_value_for_tag('root_nb_trees');
        $sums[1] += $node->get_value_for_tag('root_nb_genes');
        if ($node->get_value_for_tag('root_nb_trees')) {
            $sums[2] += $node->get_value_for_tag('root_avg_spec') * $node->get_value_for_tag('root_nb_trees');
            $sums[3] += $node->get_value_for_tag('root_avg_gene_per_spec') * $node->get_value_for_tag('root_nb_trees');
            $mins[0] = $node->get_value_for_tag('root_min_gene') if $node->get_value_for_tag('root_min_gene') < $mins[0];
            $mins[1] = $node->get_value_for_tag('root_min_spec') if $node->get_value_for_tag('root_min_spec') < $mins[1];
            $maxs[0] = $node->get_value_for_tag('root_max_gene') if $node->get_value_for_tag('root_max_gene') > $maxs[0];
            $maxs[1] = $node->get_value_for_tag('root_max_spec') if $node->get_value_for_tag('root_max_spec') > $maxs[1];
            push @tree_sizes, [
                $node->taxon_id,
                $node->node_name,
                thousandify($node->get_value_for_tag('root_nb_trees')),
                thousandify($node->get_value_for_tag('root_nb_genes')),
                round2($node->get_value_for_tag('root_avg_gene')),
                $node->get_value_for_tag('root_min_gene'),
                thousandify($node->get_value_for_tag('root_max_gene')),
                round2($node->get_value_for_tag('root_avg_spec')),
                $node->get_value_for_tag('root_min_spec'),
                thousandify($node->get_value_for_tag('root_max_spec')),
                round2($node->get_value_for_tag('root_avg_gene_per_spec')),
            ];
        } else {
            push @tree_sizes, [
                $node->taxon_id,
                $node->node_name,
                0, 0, ('NA') x 7,
            ];
        }
    }
    # Sort array by taxon name
    my @tree_sizes_sorted = sort { lc($a->[1]) cmp lc($b->[1]) } @tree_sizes;
    # Prepend header
    unshift @tree_sizes_sorted, [
        'Taxon ID',
        'Taxon name',
        'Nb of trees',
        'Nb of genes',
        'Avg nb of genes',
        'Min nb of genes',
        'Max nb of genes',
        'Avg nb of species',
        'Min nb of species',
        'Max nb of species',
        'Avg nb of genes per species',
    ];
    # Add totals at the end of the array
    push @tree_sizes_sorted, [
        undef,
        'Total',
        thousandify($sums[0]),
        thousandify($sums[1]),
        round2($sums[1] / $sums[0]),
        $mins[0],
        thousandify($maxs[0]),
        round2($sums[2] / $sums[0]),
        $mins[1],
        thousandify($maxs[1]),
        round2($sums[3] / $sums[0]),
    ];

    return \@tree_sizes_sorted;
}


=head2 get_gene_events

    Calculates the predicted gene events, i.e. for each ancestral species, number of speciation and
    duplication nodes (including dubious ones), with the average duplication score.

=cut

sub get_gene_events {
    my $sorted_nodes = shift @_;

    my @gene_events = ();
    my @sums = (0) x 7;
    my @tags = qw(nb_nodes nb_dup_nodes nb_gene_splits nb_spec_nodes nb_dubious_nodes avg_dupscore
                  avg_dupscore_nondub);
    foreach my $node (@$sorted_nodes) {
        set_default_value_for_tag($node, 0, @tags);
        $sums[0] += $node->get_value_for_tag('nb_nodes');
        $sums[1] += $node->get_value_for_tag('nb_dup_nodes');
        $sums[2] += $node->get_value_for_tag('nb_gene_splits');
        $sums[3] += $node->get_value_for_tag('nb_spec_nodes');
        $sums[4] += $node->get_value_for_tag('nb_dubious_nodes');
        $sums[5] += $node->get_value_for_tag('avg_dupscore') * ($node->get_value_for_tag('nb_dup_nodes') + $node->get_value_for_tag('nb_dubious_nodes'));
        $sums[6] += $node->get_value_for_tag('avg_dupscore_nondub') * $node->get_value_for_tag('nb_dup_nodes');
        push @gene_events, [
            $node->taxon_id,
            $node->node_name,
            thousandify($node->get_value_for_tag('nb_nodes')),
            thousandify($node->get_value_for_tag('nb_dup_nodes')),
            thousandify($node->get_value_for_tag('nb_gene_splits')),
            thousandify($node->get_value_for_tag('nb_spec_nodes')),
            thousandify($node->get_value_for_tag('nb_dubious_nodes')),
            ($node->get_value_for_tag('nb_dup_nodes') + $node->get_value_for_tag('nb_dubious_nodes')) ? roundperc2($node->get_value_for_tag('avg_dupscore')) : 'NA',
            $node->get_value_for_tag('nb_dup_nodes') ? roundperc2($node->get_value_for_tag('avg_dupscore_nondub')) : 'NA',
        ];
    }
    # Sort array by taxon name
    my @gene_events_sorted = sort { lc($a->[1]) cmp lc($b->[1]) } @gene_events;
    # Prepend header
    unshift @gene_events_sorted, [
        'Taxon ID',
        'Taxon name',
        'Nb of nodes',
        'Nb of duplication nodes',
        'Nb of gene splits',
        'Nb of speciation nodes',
        'Nb of dubious nodes',
        'Avg confidence score (%)',
        'Avg confidence score (%) on non-dubious nodes',
    ];
    # Add totals at the end of the array
    push @gene_events_sorted, [
        undef,
        'Total',
        thousandify($sums[0]),
        thousandify($sums[1]),
        thousandify($sums[2]),
        thousandify($sums[3]),
        thousandify($sums[4]),
        roundperc2($sums[5] / ($sums[1] + $sums[4])),
        roundperc2($sums[6] / $sums[1]),
    ];

    return \@gene_events_sorted;
}


sub html_tag_list {
    my ($list, $tag) = @_;
    return join('', map {sprintf("<$tag>%s</$tag>", defined $_ ? $_ : '')} @$list);
}


sub stringify_stats {
    my ($stats, $html) = @_;

    my $output;
    if ( $html ) {
        $output = "<table style=\"width:100%\">\n<tr>\n" . html_tag_list($stats->[0], 'th') . "\n</tr>\n";
        for my $i (1 .. $#$stats) {
            $output .= "<tr>\n" . html_tag_list($stats->[$i], 'td') . "\n</tr>\n";
        }
        $output .= "</table>\n\n";
    } else {
        foreach my $row (@$stats) {
            # Replace defined empty strings by zeros (but leave undef as such)
            $output .= join("\t", map { (defined $_ and $_ eq '') ? 0 : $_ } @$row) . "\n";
        }
        $output .= "\n";
    }

    return $output;
}
