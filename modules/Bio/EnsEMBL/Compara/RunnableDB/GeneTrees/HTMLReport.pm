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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HTMLReport

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HTMLReport;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::NotifyByEmail');

my $txt = <<EOF;
<html>
<h1>Statistics on #collection# #method_name#</h1>

<ul>
<li>Gene coverage: Number of genes and members in total, included in trees (either species-specific, or
  encompassing other species), orphaned (not in any unfiltered cluster), and unassigned (not in any tree)</h3>
<li>Tree size: Sizes of trees (genes, and distinct species), grouped according to the root ancestral species</li>
<li>Predicted gene events: For each ancestral species, number of speciation and duplication nodes (inc. dubious ones), with the average duplication score</li>
</ul>
<br/>
<h3>Number of genes and members in total, included in trees (either species-specific, or
    encompassing other species), orphaned (not in any unfiltered cluster), and unassigned (not in any tree)</h3>
#html_array1#

<br/><h3>Sizes of trees (genes, and distinct species), grouped according to the root ancestral species</h3>
#html_array2#

<br/><h3>For each ancestral species, number of speciation and duplication nodes (inc. dubious ones), with the average duplication score</h3>
#html_array3#

</html>
EOF

sub param_defaults {
    return {
        is_html => 1,
        text => $txt,
        subject => '#pipeline_name# gene-tree report',
    }
}


sub fetch_input {
    my $self = shift @_;

    $self->SUPER::fetch_input();    # To initialize pipeline_name

    my $collection   = 'default';
    my $mlss_id      = $self->param_required('mlss_id');
    my $species_tree = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($mlss_id, $collection);

    $self->param('collection', $collection);
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    $self->param('method_name', $mlss->method->display_name);

    my $sorted_nodes = $species_tree->root->get_all_sorted_nodes();

    {
        my @data1 = ();
        my @sums = (0) x 8;
        push @data1, [
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
        foreach my $species (@$sorted_nodes) {
            next unless $species->is_leaf();
            set_default_value_for_tag($species, 0, qw(nb_genes nb_seq nb_orphan_genes nb_genes_in_tree nb_genes_in_tree_single_species nb_genes_in_tree_multi_species));
            $sums[0] += $species->get_value_for_tag('nb_genes');
            $sums[1] += $species->get_value_for_tag('nb_seq');
            $sums[2] += $species->get_value_for_tag('nb_orphan_genes');
            $sums[3] += $species->get_value_for_tag('nb_genes_in_unfiltered_cluster');
            $sums[4] += $species->get_value_for_tag('nb_genes_unassigned');
            $sums[5] += $species->get_value_for_tag('nb_genes_in_tree');
            $sums[6] += $species->get_value_for_tag('nb_genes_in_tree_single_species');
            $sums[7] += $species->get_value_for_tag('nb_genes_in_tree_multi_species');
            push @data1, [
                $species->taxon_id,
                $species->node_name,
                thousandify($species->get_value_for_tag('nb_genes')),
                thousandify($species->get_value_for_tag('nb_seq')),
                thousandify($species->get_value_for_tag('nb_orphan_genes')),
                thousandify($species->get_value_for_tag('nb_genes_in_unfiltered_cluster')),
                thousandify($species->get_value_for_tag('nb_genes_unassigned')),
                thousandify($species->get_value_for_tag('nb_genes_in_tree')),
                $species->get_value_for_tag('nb_genes') ? roundperc2($species->get_value_for_tag('nb_genes_in_tree') / $species->get_value_for_tag('nb_genes')) : 'NA',
                thousandify($species->get_value_for_tag('nb_genes_in_tree_single_species')),
                $species->get_value_for_tag('nb_genes') ? roundperc2($species->get_value_for_tag('nb_genes_in_tree_single_species') / $species->get_value_for_tag('nb_genes')) : 'NA',
                thousandify($species->get_value_for_tag('nb_genes_in_tree_multi_species')),
                $species->get_value_for_tag('nb_genes') ? roundperc2($species->get_value_for_tag('nb_genes_in_tree_multi_species') / $species->get_value_for_tag('nb_genes')) : 'NA',
            ];
        }
        push @data1, [
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
        $self->param('html_array1', array_arrays_to_html_table(@data1));
    }
    {
        my @data2 = ();
        my @sums = (0) x 5;
        my @mins = (1e10) x 2;
        my @maxs = (-1) x 2;
        push @data2, [
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
        foreach my $node (@$sorted_nodes) {
            set_default_value_for_tag($node, 0, qw(root_nb_trees root_nb_genes root_avg_spec root_avg_gene_per_spec root_min_gene root_min_spec root_max_gene root_max_spec));
            $sums[0] += $node->get_value_for_tag('root_nb_trees');
            $sums[1] += $node->get_value_for_tag('root_nb_genes');
            if ($node->get_value_for_tag('root_nb_trees')) {
                $sums[2] += $node->get_value_for_tag('root_avg_spec')*$node->get_value_for_tag('root_nb_trees');
                $sums[3] += $node->get_value_for_tag('root_avg_gene_per_spec')*$node->get_value_for_tag('root_nb_trees');
                $mins[0] = $node->get_value_for_tag('root_min_gene') if $node->get_value_for_tag('root_min_gene') < $mins[0];
                $mins[1] = $node->get_value_for_tag('root_min_spec') if $node->get_value_for_tag('root_min_spec') < $mins[1];
                $maxs[0] = $node->get_value_for_tag('root_max_gene') if $node->get_value_for_tag('root_max_gene') > $maxs[0];
                $maxs[1] = $node->get_value_for_tag('root_max_spec') if $node->get_value_for_tag('root_max_spec') > $maxs[1];
                push @data2, [
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
                push @data2, [
                    $node->taxon_id,
                    $node->node_name,
                    0, 0, ('NA') x 7,
                ];
            }
        }
        push @data2, [
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
        $self->param('html_array2', array_arrays_to_html_table(@data2));
    }
    {
        my @data3 = ();
        my @sums = (0) x 7;
        push @data3, [
            'Taxon ID',
            'Taxon name',
            'Nb of nodes',
            'Nb of duplication nodes',
            'Nb of gene splits',
            'Nb of speciation nodes',
            'Nb of dubious nodes',
            'Avg confidence score',
            'Avg confidence score on non-dubious nodes',
        ];
        foreach my $node (@$sorted_nodes) {
                set_default_value_for_tag($node, 0, qw(nb_nodes nb_dup_nodes nb_gene_splits nb_spec_nodes nb_dubious_nodes avg_dupscore avg_dupscore_nondub));
                $sums[0] += $node->get_value_for_tag('nb_nodes');
                $sums[1] += $node->get_value_for_tag('nb_dup_nodes');
                $sums[2] += $node->get_value_for_tag('nb_gene_splits');
                $sums[3] += $node->get_value_for_tag('nb_spec_nodes');
                $sums[4] += $node->get_value_for_tag('nb_dubious_nodes');
                $sums[5] += $node->get_value_for_tag('avg_dupscore') * ($node->get_value_for_tag('nb_dup_nodes')+$node->get_value_for_tag('nb_dubious_nodes'));
                $sums[6] += $node->get_value_for_tag('avg_dupscore_nondub') * $node->get_value_for_tag('nb_dup_nodes');
                push @data3, [
                    $node->taxon_id,
                    $node->node_name,
                    thousandify($node->get_value_for_tag('nb_nodes')),
                    thousandify($node->get_value_for_tag('nb_dup_nodes')),
                    thousandify($node->get_value_for_tag('nb_gene_splits')),
                    thousandify($node->get_value_for_tag('nb_spec_nodes')),
                    thousandify($node->get_value_for_tag('nb_dubious_nodes')),
                    ($node->get_value_for_tag('nb_dup_nodes')+$node->get_value_for_tag('nb_dubious_nodes')) ? roundperc2($node->get_value_for_tag('avg_dupscore')) : 'NA',
                    $node->get_value_for_tag('nb_dup_nodes') ? roundperc2($node->get_value_for_tag('avg_dupscore_nondub')) : 'NA',
                ]
        }
        push @data3, [
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
        $self->param('html_array3', array_arrays_to_html_table(@data3));
    }
}




sub set_default_value_for_tag {
    my ($node, $value, @tags) = @_;
    foreach my $t (@tags) {
        $node->add_tag($t, $value) if not $node->has_tag($t);
    };
}

# Functions to produce some HTML

sub array_to_html_tr {
    return '<tr>'.join('', map {sprintf('<td>%s</td>', defined $_ ? $_ : '')} @_)."</tr>\n";
}

sub array_arrays_to_html_table {
    return '<table>'.join('', map {array_to_html_tr(@$_)} @_)."</table>\n";
}



# Functions to format the numbers

sub roundperc2 {
    return sprintf('%.2f&nbsp;%%', 100*$_[0]);
}

sub round2 {
    return sprintf('%.2f', $_[0]);
}

sub thousandify {
    my $value = shift;
    local $_ = reverse $value;
    s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $_;
}


1;
