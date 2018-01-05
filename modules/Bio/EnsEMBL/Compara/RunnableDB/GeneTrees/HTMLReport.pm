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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HTMLReport

=cut

=head1 CONTACT

Please email comments or questions to the public Ensembl developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at <http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HTMLReport;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

my $txt = <<EOF;
<html>
<h1>Statistics on gene trees</h1>

<a name='gtstat_top'/><ul>
<li><a href='#gt_coverage'>Gene coverage</a>: Number of genes and members in total, included in trees (either species-specific, or encompassing other species), and orphaned (not in any tree)</li>
<li><a href='#gt_sizes'>Tree size</a>: Sizes of trees (genes, and distinct species), grouped according to the root ancestral species</li>
<li><a href='#gt_treenodes'>Predicted gene events</a>: For each ancestral species, number of speciation and duplication nodes (inc. dubious ones), with the average duplication score</li>
</ul>
<br/><a name='gt_coverage' href='#gtstat_top'>Top&uarr;</a><h3>Number of genes and members in total, included in trees (either species-specific, or encompassing other species), and orphaned (not in any tree)</h3>
#html_array1#

<br/><a name='gt_sizes' href='#gtstat_top'>Top&uarr;</a><h3>Sizes of trees (genes, and distinct species), grouped according to the root ancestral species</h3>
#html_array2#

<br/><a name='gt_treenodes' href='#gtstat_top'>Top&uarr;</a><h3>For each ancestral species, number of speciation and duplication nodes (inc. dubious ones), with the average duplication score</h3>
#html_array3#

</html>
EOF

sub param_defaults {
    return {
        is_html => 1,
        text => $txt,
        subject => 'Gene-tree pipeline report',
    }
}


sub fetch_input {
    my $self = shift @_;

    my $mlss_id      = $self->param_required('mlss_id');
    my $species_tree = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($mlss_id, 'default');

    my $sorted_nodes = $species_tree->root->get_all_sorted_nodes();

    {
        my @data1 = ();
        my @sums = (0) x 6;
        push @data1, [
            'Taxon ID',
            'Taxon name',
            'Nb genes',
            'Nb sequences',
            'Nb orphaned genes',
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
            $sums[3] += $species->get_value_for_tag('nb_genes_in_tree');
            $sums[4] += $species->get_value_for_tag('nb_genes_in_tree_single_species');
            $sums[5] += $species->get_value_for_tag('nb_genes_in_tree_multi_species');
            push @data1, [
                $species->taxon_id,
                $species->node_name,
                thousandify($species->get_value_for_tag('nb_genes')),
                thousandify($species->get_value_for_tag('nb_seq')),
                thousandify($species->get_value_for_tag('nb_orphan_genes')),
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
            roundperc2($sums[3] / $sums[0]),
            thousandify($sums[4]),
            roundperc2($sums[4] / $sums[0]),
            thousandify($sums[5]),
            roundperc2($sums[5] / $sums[0]),
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
