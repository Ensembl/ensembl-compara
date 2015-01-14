=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::Compara::GeneTrees;

## Provides content for compara gene-trees documentation
## Base class - does not itself output content

use strict;

use List::Util qw(min max sum);
use List::MoreUtils qw(uniq);

use EnsEMBL::Web::Document::Table;

use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

sub add_species_set {
  my ($self, $name, $after_rules, $ss_length, $acc) = @_;
  my @sub_names = sort {$ss_length->{$b} <=> $ss_length->{$a} || lc $a cmp lc $b} (keys %{$after_rules->{$name}});
  foreach my $sub_name (@sub_names) {
    $self->add_species_set($sub_name, $after_rules, $ss_length, $acc);
  }
  unshift @$acc, $name;
}

sub format_gene_tree_stats {
  my ($self, $method) = @_;
  my $hub  = $self->hub;

  my $compara_db = $self->hub->database('compara');
  my $page       = $self->hub->param('page');
  return unless $compara_db;

  my $mlss_adaptor    = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $mlss = $mlss_adaptor->fetch_all_by_method_link_type($method)->[0];
  return unless $mlss;

  my $species_tree_adaptor = $compara_db->get_adaptor('SpeciesTree');
  my $species_tree = $species_tree_adaptor->fetch_by_method_link_species_set_id_label($mlss->dbID, 'default');

  # Reads the species set that are defined in the database (if any)
  my $ordered_species = $hub->order_species_by_clade($species_tree->root->get_all_leaves);

  my $counter_raphael_holders = 0;

  my $html = q{
List of available views:
<ul>
  <li><a href='?'>Overview</a></li>
  <li><a href='?page=coverage'>Gene-tree coverage</a> for each species</li>
  <li><a href='?page=sizes'>Size of the gene trees</a> (split by their root taxon)</li>
  <li><a href='?page=nodes'>Gene-tree nodes</a>, and the inference of speciation / duplication events</li>
</ul>
<div class="js_panel">
};

  if (not $page) {

    $html .= q{<p>This is an overview of the various statistics.
    The phylogenetic tree summarizes all the piecharts found in the other views.
    </p>};
    $html .= $self->piechart_header([qw(#fc0 #909 #69f #a22 #25a #8a2)]);
    my $cell_style = q{width="16%" style="border-bottom: solid 1px #ccc; vertical-align: middle;"};
    $html .= sprintf(qq{<table class="ss">
    <tr>
      <th colspan="6" style="text-align: center">Legend</th>
    </tr>
    <tr>
      <td $cell_style>Internal nodes (ancestral taxa)</td>
      <td $cell_style>Node types</td>
      <td $cell_style><span style="color: #fc0">Speciations</span></td>
      <td $cell_style><span style="color: #909">Duplications</span></td>
      <td $cell_style><span style="color: #69f">Dubious nodes</span></td>
      <td $cell_style>%s</td>
    </tr>
    <tr>
      <td $cell_style rowspan="2">Leaves (extant species)</td>
      <td $cell_style>Gene events</td>
      <td $cell_style><span style="color: #fc0">Default genes</span></td>
      <td $cell_style><span style="color: #909">Species-specific duplications</span></td>
      <td $cell_style><span style="color: #69f">Gene splits</span></td>
      <td $cell_style>%s</td>
    </tr>
    <tr>
      <td $cell_style>Gene-tree coverage</td>
      <td $cell_style><span style="color: #8a2">Genes in multi-species trees</span></td>
      <td $cell_style><span style="color: #a22">Orphaned genes</span></td>
      <td $cell_style><span style="color: #25a">Genes in single-species trees</span></td>
      <td $cell_style>%s</td>
    </tr>
    </table>
    }, $self->piechart_data([1,1,1], \$counter_raphael_holders),
       $self->piechart_data([1,1,1], \$counter_raphael_holders),
       $self->piechart_data([0,0,0,1,1,1], \$counter_raphael_holders),
   );
   $html .= $self->get_html_for_tree_stats_overview($species_tree->root, \$counter_raphael_holders);

} elsif ($page eq 'coverage')  {

    my $n_group = scalar(@$ordered_species)-1;
    $html .= q{<h2>Gene-tree coverage (per species)</h2>};
    $html .= '<p>Quick links: '.join(', ', map {sprintf('<a href="#cladegroup%d">%s</a>', $_, $ordered_species->[$_]->[0])} 1..$n_group).'</p>' if scalar(@$ordered_species) > 1;
    $html .= $self->piechart_header([qw(#fc0 #909 #69f #a22 #25a #8a2)]);
    for (0..$n_group) {
      my $set = $ordered_species->[$_];
      $html .= sprintf('<h3><a name="cladegroup%d"></a>%s</h3>', $_, ucfirst $set->[0] || 'Others') if scalar(@$ordered_species) > 1;
      $html .= $self->get_html_for_gene_tree_coverage($set->[0], $set->[1], $method, \$counter_raphael_holders);
    }

  } elsif ($page eq 'sizes') {
    $html .= q{<h2>Size of the trees (per root node)</h2>};
    $html .= $self->piechart_header([qw(#89C #fff)]);
    $html .= $self->get_html_for_tree_size_statistics($species_tree->root, \$counter_raphael_holders);

  } elsif ($page eq 'nodes') {
    $html .= q{<h2>Statistics about the gene-tree nodes</h2>};
    $html .= $self->piechart_header([qw(#fc0 #909 #69f)]);
    $html .= $self->get_html_for_node_statistics($species_tree->root, \$counter_raphael_holders);
  };

  $html .= q{</div>};
  return $html;
}


sub piechart_header {
  my ($self, $colors) = @_;

  my $piechart_radius = 14;

  return sprintf(q{<div style="display: none;">
      <input class="panel_type" type="hidden" value="Piechart" />
      <input class="graph_config" type="hidden" name="stroke" value="'#999'" />
      <input class="graph_config" type="hidden" name="legend" value="false" />
      <input class="graph_dimensions" type="hidden" value="[%d,%d,%d]" />
      <input class="graph_config" type="hidden" name="colors" value="[%s]" />
    </div>
    },
    $piechart_radius, $piechart_radius, $piechart_radius-1,
    join(',', map {sprintf(q{'%s'}, $_)} @$colors),
  );
}


sub piechart_data {
  my ($self, $values, $ref_index_piechart, $title) = @_;

  my $index = $$ref_index_piechart;
  $$ref_index_piechart++;

  my $piechart_radius = 14;

  return sprintf(q{
    <div style="display: none;">
      <input class="graph_data" type="hidden" value="[%s]" />
    </div>
    <div %s id="graphHolder%d" style="width: %dpx; height: %dpx; margin: auto;"></div>
    },
    join(',', map {sprintf('[%s]', $_ || 0.01)} @$values),
    $title ? sprintf(q{title="%s"}, $title) : '',
    $index, $piechart_radius*2, $piechart_radius*2,
  );
}


sub get_html_for_gene_tree_coverage {
  my ($self, $name, $species, $method, $counter_raphael_holders) = @_;

  $name =~ s/ /_/g;
  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'species',                         width => '18%', align => 'left',   sort => 'string',  title => 'Species', },
      { key => 'nb_genes',                        width => '6%',  align => 'center', sort => 'numeric', style => 'color: #ca4', title => '# Genes', },
      { key => 'nb_seq',                          width => '9%',  align => 'center', sort => 'numeric', title => '# Sequences', },
      { key => 'nb_genes_in_tree',                width => '10%', align => 'center', sort => 'numeric', title => '# Genes in a tree', },
      { key => 'nb_orphan_genes',                 width => '9%',  align => 'center', sort => 'numeric', style => 'color: #a22', title => '# Orphaned genes', },
      { key => 'nb_genes_in_tree_single_species', width => '10%', align => 'center', sort => 'numeric', style => 'color: #25a', title => "# Genes in a single-species tree", },
      { key => 'nb_genes_in_tree_multi_species',  width => '10%', align => 'center', sort => 'numeric', style => 'color: #8a2', title => '# Genes in a multi-species tree', },
      { key => 'piechart_cov',                    width => '4%',  align => 'center', sort => 'none',    title => 'Coverage', },
      { key => 'nb_dup_nodes',                    width => '10%', align => 'center', sort => 'numeric', style => 'color:#909', title => '# species-specific duplications', },
    ], [], {data_table => 1, id => sprintf('gene_tree_coverage_%s', $name), sorting => ['species asc']});
  $table->add_columns(
    { key => 'nb_gene_splits',                  width => '9%', align => 'center', sort => 'numeric', style => 'color:#69f', title => '# Gene splits', },
  ) if $method eq 'PROTEIN_TREES';
  $table->add_columns(
    { key => 'piechart_dup',                      width => '5%',  align => 'center', sort => 'none',    title => 'Gene events', },
  );

  my $common_names = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_NAME'};

  foreach my $sp (@$species) {
    my $piecharts = $self->get_piecharts_for_species($sp, $counter_raphael_holders);
    $table->add_row({
        'species' => $common_names->{$sp->taxon_id} ? sprintf('%s (<i>%s</i>)', $common_names->{$sp->taxon_id}, $sp->node_name) : $sp->node_name,
        'piechart_cov' => $piecharts->[1],
        'piechart_dup' => $sp->get_value_for_tag('nb_genes_in_tree') ? $piecharts->[0] : '',
        map {($_ => $sp->get_value_for_tag($_) || 0)} (qw(nb_genes nb_seq nb_orphan_genes nb_genes_in_tree nb_genes_in_tree_single_species nb_genes_in_tree_multi_species nb_gene_splits nb_dup_nodes)),
      });
  }
  return $table->render;
}

sub get_piecharts_for_species {
  my ($self, $node, $counter_raphael_holders) = @_;
  my $v1 = $node->get_value_for_tag('nb_orphan_genes');
  my $v2 = $node->get_value_for_tag('nb_genes_in_tree_single_species');
  my $v3 = $node->get_value_for_tag('nb_genes_in_tree_multi_species');
  my $v4 = $node->get_value_for_tag('nb_genes');
  my $v5 = $node->get_value_for_tag('nb_gene_splits');
  my $v6 = $node->get_value_for_tag('nb_dup_nodes');
  my $piechart2 = $self->piechart_data([0, 0, 0, $v1, $v2, $v3], $counter_raphael_holders, sprintf("Gene coverage (%s)", $node->node_name));
  my $piechart = $self->piechart_data([$v4-$v5-$v6, $v6, $v5], $counter_raphael_holders, sprintf("Gene events (%s)", $node->node_name));

  return [$piechart, $piechart2];
}

sub get_piecharts_for_internal_node {
  my ($self, $node, $counter_raphael_holders) = @_;
  my $v1 = $node->get_value_for_tag('nb_spec_nodes');
  my $v2 = $node->get_value_for_tag('nb_dup_nodes');
  my $v3 = $node->get_value_for_tag('nb_dubious_nodes');
  my $piechart = $self->piechart_data([$v1, $v2, $v3], $counter_raphael_holders, sprintf("Node types (%s)", $node->node_name));

  return [$piechart];
}

sub get_html_for_tree_size_statistics {
  my ($self, $species_tree_root, $counter_raphael_holders) = @_;

  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'species',                   width => '15%', align => 'left',   sort => 'string',  title => 'Species', },
      { key => 'root_nb_trees',             width => '6%',  align => 'center', sort => 'numeric', title => '# Trees', },
      { key => 'root_perc_trees',           width => '5%',  align => 'center', sort => 'numeric', title => '% Trees', },
      { key => 'root_nb_genes',             width => '7%',  align => 'center', sort => 'numeric', title => '# Genes', },
      { key => 'root_perc_genes',           width => '5%',  align => 'center', sort => 'numeric', title => '% Genes', },
      { key => 'root_min_gene',             width => '8%',  align => 'center', sort => 'numeric', title => 'Min # genes', },
      { key => 'root_max_gene',             width => '8%',  align => 'center', sort => 'numeric', title => 'Max # genes', },
      { key => 'root_avg_gene',             width => '11%',  align => 'center', sort => 'numeric', title => 'Average # genes', },
      { key => 'root_min_spec',             width => '9%',  align => 'center', sort => 'numeric', title => 'Min # species', },
      { key => 'root_max_spec',             width => '9%',  align => 'center', sort => 'numeric', title => 'Max # species', },
      { key => 'root_avg_spec',             width => '11%',  align => 'center', sort => 'numeric', title => 'Average # species', },
      { key => 'root_avg_gene_per_spec',    width => '11%',  align => 'center', sort => 'numeric', title => 'Average # genes per species', },
    ], [], {data_table => 1, sorting => ['species asc']} );

  my $common_names = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_NAME'};
  my $tot_ntrees = sum(map {$_->get_value_for_tag('root_nb_trees') || 0} @{$species_tree_root->get_all_nodes});
  my $tot_ngenes = sum(map {$_->get_value_for_tag('root_nb_genes') || 0} @{$species_tree_root->get_all_nodes});

  foreach my $node (@{$species_tree_root->get_all_nodes}) {
    my $ntrees = $node->get_value_for_tag('root_nb_trees');
    my $ngenes = $node->get_value_for_tag('root_nb_genes');
    next unless $ntrees;

    $table->add_row({
        'species' => $common_names->{$node->taxon_id} ? sprintf('%s (<i>%s</i>)', $common_names->{$node->taxon_id}, $node->node_name) : $node->node_name,
        'root_perc_trees' => $self->piechart_data([$ntrees, $tot_ntrees-$ntrees], $counter_raphael_holders),
        'root_perc_genes' => $self->piechart_data([$ngenes, $tot_ngenes-$ngenes], $counter_raphael_holders),
        (map {$_ => $node->get_value_for_tag($_)} qw(root_nb_trees root_nb_genes root_min_gene root_max_gene root_min_spec root_max_spec)),
        (map {$_ => sprintf('%.1f', 0+$node->get_value_for_tag($_))} qw(root_avg_gene root_avg_spec root_avg_gene_per_spec)),
      });
  }

  return $table->render;
}

sub get_html_for_node_statistics {
  my ($self, $species_tree_root, $counter_raphael_holders) = @_;

  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'species',               width => '18%', align => 'left',   sort => 'string',  title => 'Species', },
      { key => 'nb_nodes',              width => '7%',  align => 'center', sort => 'numeric', title => '# Nodes', },
      { key => 'nb_spec_nodes',         width => '12%', align => 'center', sort => 'numeric', style => 'color: #ca4', title => '# speciation nodes', },
      { key => 'nb_dup_nodes',          width => '12%', align => 'center', sort => 'numeric', style => 'color: #909', title => '# duplication nodes', },
      { key => 'nb_dubious_nodes',      width => '11%', align => 'center', sort => 'numeric', style => 'color: #69f', title => '# dubious nodes', },
      { key => 'piechart',              width => '7%', align => 'center', sort => 'none',    title => 'Node types', },
      { key => 'avg_dupscore',          width => '12%', align => 'center', sort => 'numeric', title => 'Average duplication confidence score', },
      { key => 'avg_dupscore_nondub',   width => '12%', align => 'center', sort => 'numeric', title => 'Average duplication confidence score (non-dubious nodes)', },
    ], [], {data_table => 1, sorting => ['species asc']} );

  my $common_names = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_NAME'};
  foreach my $node (@{$species_tree_root->get_all_nodes}) {
    next if $node->is_leaf;
    next unless $node->get_value_for_tag('nb_nodes');
    my $piecharts = $self->get_piecharts_for_internal_node($node, $counter_raphael_holders);

    $table->add_row({
        'species' => $common_names->{$node->taxon_id} ? sprintf('%s (<i>%s</i>)', $common_names->{$node->taxon_id}, $node->node_name) : $node->node_name,
        'piechart' => $piecharts->[0],
        (map {$_ => $node->get_value_for_tag($_)} qw(nb_nodes nb_spec_nodes nb_dup_nodes nb_dubious_nodes)),
        (map {$_ => sprintf('%.1f&nbsp;%%', 100*$node->get_value_for_tag($_))} qw(avg_dupscore avg_dupscore_nondub)),
      });
  }

  return $table->render;
}

sub get_html_for_tree_stats_overview {
  my ($self, $species_tree_root, $counter_raphael_holders) = @_;

  my $width = $species_tree_root->max_depth * 2 + 4;
  my $height = scalar(@{$species_tree_root->get_all_leaves});
  my @matrix = map {[(undef) x $width]} 1..$height;
  my $y_pos - 0;
  my $internal_counter = 0;
  $self->draw_tree(\@matrix, $species_tree_root, \$y_pos, \$internal_counter);

# -ii-ii-tt
#
#   +----s3
# -oo  +-s2
#   +-oo
#      +-s1
  my $html = q{<table style="padding: 0px; text-align: center; margin: auto">};
  foreach my $row (@matrix) {
    foreach my $i (0..($width-1)) {
      if ($row->[$i] and ($row->[$i] =~ /graphHolder/)) {
        $row->[$i] =~ s/graphHolder[0-9]*/graphHolder$$counter_raphael_holders/;
        $$counter_raphael_holders++;
      }
    }
    $html .= '<tr>'.join('', map {sprintf(q{<td style="padding: 0px">%s</td>}, $_ || '')} @{$row}).'</tr>';
  }
  $html .= '</table>';
  return $html;
}


sub draw_tree {
  my ($self, $matrix, $node, $next_y, $counter_raphael_holders) = @_;
  my $nchildren = scalar(@{$node->children});

  my $common_names  = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_NAME'};

  my $horiz_branch  = q{<img style="width: 28px; height: 28px;" alt="---" src="ct_hor.png" />};
  my $vert_branch   = q{<img style="width: 28px; height: 28px;" alt="---" src="ct_ver.png" />};
  my $top_branch    = q{<img style="width: 28px; height: 28px;" alt="---" src="ct_top.png" />};
  my $bottom_branch = q{<img style="width: 28px; height: 28px;" alt="---" src="ct_bot.png" />};
  my $middle_branch = q{<img style="width: 28px; height: 28px;" alt="---" src="ct_mid.png" />};
  my $half_horiz_branch  = q{<img style="width: 14px; height: 28px;" alt="-" src="ct_half_hor.png" />};

  if ($nchildren) {
    my @subtrees = map {$self->draw_tree($matrix, $_, $next_y, $counter_raphael_holders)} @{$node->sorted_children};
    my $anchor_x_pos = min(map {$_->[0]} @subtrees)-1;
    my $min_y = min(map {$_->[1]} @subtrees);
    my $max_y = max(map {$_->[1]} @subtrees);
    my $anchor_y_pos = int(($min_y+$max_y)/2);
    foreach my $coord (@subtrees) {
      $matrix->[$coord->[1]]->[$_] = ($_ % 2 ? $horiz_branch : $half_horiz_branch) for ($anchor_x_pos+1)..($coord->[0]-1);
    }
    my $piecharts = $self->get_piecharts_for_internal_node($node, $counter_raphael_holders);
    $matrix->[$_]->[$anchor_x_pos] = $vert_branch for ($min_y+1)..($max_y-1);
    $matrix->[$_->[1]]->[$anchor_x_pos] = $middle_branch for @subtrees;
    $matrix->[$min_y]->[$anchor_x_pos] = $top_branch;
    $matrix->[$max_y]->[$anchor_x_pos] = $bottom_branch;
    $matrix->[$anchor_y_pos]->[$anchor_x_pos] = $piecharts->[0];
    $matrix->[$anchor_y_pos]->[$anchor_x_pos-1] = $half_horiz_branch;

    return [$anchor_x_pos-1, $anchor_y_pos];

  } else {
    my $y = $$next_y;
    $$next_y++;
    my $width = scalar(@{$matrix->[$y]});
    my $piecharts = $self->get_piecharts_for_species($node, $counter_raphael_holders);
    $matrix->[$y]->[$width-1] = $common_names->{$node->taxon_id} || $node->node_name;
    $matrix->[$y]->[$width-1] = $common_names->{$node->taxon_id} || $node->node_name;
    $matrix->[$y]->[$width-2] = $piecharts->[1];
    $matrix->[$y]->[$width-3] = $piecharts->[0];
    $matrix->[$y]->[$width-4] = $half_horiz_branch;
    return [$width-4, $y];
  }

}



1;
