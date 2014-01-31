=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use List::MoreUtils qw(uniq);

use EnsEMBL::Web::Document::Table;

use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

use base qw(EnsEMBL::Web::Document::HTML::Compara);


sub order_species_by_clade {
  my ($self, $species) = @_;
  my $species_sets = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'SPECIES_SET'} || {};

  my @species_set_names = grep {$species_sets->{$_}->{'taxon_id'}} (keys %$species_sets);
  my %ss_by_gdb_ids = ();
  my %ss_length = ();
  foreach my $name (@species_set_names) {
    foreach my $gdb_id (uniq @{$species_sets->{$name}->{genome_db_ids}}) {
      push @{$ss_by_gdb_ids{$gdb_id}}, $name;
      $ss_length{$name} ++;
    }
  }
  my %is_below = ();
  my %after_rules = ();
  my %true_content = ();
  foreach my $gdb_id (keys %ss_by_gdb_ids) {
    my @names = sort {$ss_length{$a} <=> $ss_length{$b}} @{$ss_by_gdb_ids{$gdb_id}};
    push @{$true_content{$names[0]}}, $gdb_id;
    while (scalar(@names) >= 2) {
      $after_rules{$names[1]}{$names[0]} = 1;
      $is_below{$names[0]} = 1;
      shift @names;
    }
  }
  my @ss_order = ();
  my @top_names = sort {$ss_length{$b} <=> $ss_length{$a} || lc $a cmp lc $b} (grep {not $is_below{$_}} @species_set_names);
  $self->add_species_set($_, \%after_rules, \%ss_length, \@ss_order) for @top_names;

  my %stn_by_gdb_id = ();
  foreach my $stn (@$species) {
    $stn_by_gdb_id{$stn->genome_db_id} = $stn;
  };

  my @final_sets;
  foreach my $name (reverse @ss_order) {
    my @species_here = map {delete $stn_by_gdb_id{$_}} @{$true_content{$name}};
    push @final_sets, [(scalar(@species_here) != $ss_length{$name} ? 'other ' : '').$name, [sort {$a->node_name cmp $b->node_name} @species_here]];
  }
  push @final_sets, [undef, [sort {$a->node_name cmp $b->node_name} (grep {$stn_by_gdb_id{$_->genome_db_id} } @$species)]] if scalar(keys %stn_by_gdb_id);

  return \@final_sets;
}

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
  return unless $compara_db;

  my $mlss_adaptor    = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $mlss = $mlss_adaptor->fetch_all_by_method_link_type($method)->[0];
  return unless $mlss;

  my $species_tree_adaptor = $compara_db->get_adaptor('SpeciesTree');
  my $species_tree = $species_tree_adaptor->fetch_by_method_link_species_set_id_label($mlss->dbID, 'default');

  # Reads the species set that are defined in the database (if any)
  my $ordered_species = $self->order_species_by_clade($species_tree->root->get_all_leaves);

  my $piechart_radius = 14;
  my $counter_raphael_holders = 0;

  my $html = q{
Below are a few tables that summarize the:
<ul>
  <li><a href='#gt_coverage'>Gene-tree coverage</a> for each species</li>
  <li><a href='#gt_sizes'>Size of the gene trees</a> (split by their root taxon)</li>
  <li><a href='#gt_nodes'>Gene-tree nodes</a>, and the inference of speciation / duplication events</li>
</ul>
};
  $html .= q{<div class="js_panel">};
  $html .= q{<h2 id="gt_coverage">Gene-tree coverage (per species)</h2>};
  foreach my $set (@$ordered_species) {
    $html .= sprintf('<h3>%s</h3>', ucfirst $set->[0] || 'Others') if scalar(@$ordered_species) > 1;
    $html .= $self->get_html_for_gene_tree_coverage($set->[0], $set->[1], $method, $piechart_radius, \$counter_raphael_holders);
    $html .= q{<div style="text-align: right"><a href='#main'>Top&uarr;</a></div>};
  }
  $html .= q{<h2 id="gt_sizes">Size of the trees (per root node)</h2>};
  $html .= $self->get_html_for_tree_size_statistics($species_tree->root);
  $html .= q{<div style="text-align: right"><a href='#main'>Top&uarr;</a></div>};
  $html .= q{<h2 id="gt_nodes">Statistics about the gene-tree nodes</h2>};
  $html .= $self->get_html_for_node_statistics($species_tree->root, $piechart_radius, \$counter_raphael_holders);
  $html .= q{<div style="text-align: right"><a href='#main'>Top&uarr;</a></div>};
  $html .= q{</div>};

  return $html;
}

sub piechart_gene_coverage {
  my ($self, $values, $piechart_radius, $ref_index_piechart) = @_;

  my $index = $$ref_index_piechart;
  $$ref_index_piechart++;
  my @ccolors = qw(#fc0 #909 #69f #8a2 #a22 #25a);
  return sprintf(q{<div>
      <input class="panel_type" type="hidden" value="Piechart" />
      <input class="graph_config" type="hidden" name="stroke" value="'#999'" />
      <input class="graph_config" type="hidden" name="legend" value="false" />
      <input class="graph_dimensions" type="hidden" value="[%d,%d,%d]" />
      <input class="graph_config" type="hidden" name="colors" value="[%s]" />
      <input class="graph_data" type="hidden" value="[%s]" />
    </div>
    <div style="align: center">
      <div id="graphHolder%d" style="width: %dpx; height: %dpx; margin: auto;"></div>
    </div>
    },
    $piechart_radius, $piechart_radius, $piechart_radius-1,
    join(',', map {sprintf(q{'%s'}, $_)} @ccolors),
    join(',', map {sprintf('[%s]', $values->[$_] || 0.01)} 0..((scalar @ccolors)-1)),
    $index, $piechart_radius*2, $piechart_radius*2,
  );
}

sub get_html_for_gene_tree_coverage {
  my ($self, $name, $species, $method, $piechart_radius, $counter_raphael_holders) = @_;

  $name =~ s/ /_/g;
  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'species',                         width => '18%', align => 'left',   sort => 'string',  title => 'Species', },
      { key => 'nb_genes',                        width => '6%',  align => 'center', sort => 'integer', style => 'color: #8a2', title => '# Genes', },
      { key => 'nb_seq',                          width => '9%',  align => 'center', sort => 'integer', title => '# Sequences', },
      { key => 'nb_genes_in_tree',                width => '10%', align => 'center', sort => 'integer', title => '# Genes in a tree', },
      { key => 'nb_orphan_genes',                 width => '9%', align => 'center', sort => 'integer', style => 'color: #ca4', title => '# Orphaned genes', },
      { key => 'nb_genes_in_tree_single_species', width => '10%', align => 'center', sort => 'integer', style => 'color: #909', title => "# Genes in a single-species tree", },
      { key => 'nb_genes_in_tree_multi_species',  width => '10%', align => 'center', sort => 'integer', style => 'color: #69f', title => '# Genes in a multi-species tree', },
      { key => 'piechart1',                       width => '4%',  align => 'center', sort => 'none',    title => 'Coverage', },
      { key => 'nb_dup_nodes',                    width => '10%', align => 'center', sort => 'integer', style => 'color:#a22', title => '# species-specific duplications', },
    ], [], {data_table => 1, id => sprintf('gene_tree_coverage_%s', $name), sorting => ['species asc']});
  $table->add_columns(
    { key => 'nb_gene_splits',                  width => '9%', align => 'center', sort => 'integer', style => 'color:#25a', title => '# Gene splits', },
  ) if $method eq 'PROTEIN_TREES';
  $table->add_columns(
    { key => 'piechart2',                       width => '5%',  align => 'center', sort => 'none',    title => 'Gene events', },
  );

  my $common_names = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_NAME'};

  foreach my $sp (@$species) {

    my $v1 = $sp->get_value_for_tag('nb_orphan_genes');
    my $v2 = $sp->get_value_for_tag('nb_genes_in_tree_single_species');
    my $v3 = $sp->get_value_for_tag('nb_genes_in_tree_multi_species');
    my $v4 = $sp->get_value_for_tag('nb_genes');
    my $v5 = $sp->get_value_for_tag('nb_gene_splits');
    my $v6 = $sp->get_value_for_tag('nb_dup_nodes');
    my $piechart = $self->piechart_gene_coverage([$v1, $v2, $v3], $piechart_radius, $counter_raphael_holders);
    my $piechart2 = $self->piechart_gene_coverage([0, 0, 0, $v4-$v5-$v6, $v6, $v5], $piechart_radius, $counter_raphael_holders);

    $table->add_row({
        'species' => $common_names->{$sp->taxon_id} ? sprintf('%s (<i>%s</i>)', $common_names->{$sp->taxon_id}, $sp->node_name) : $sp->node_name,
        'piechart1' => $piechart,
        'piechart2' => $sp->get_value_for_tag('nb_genes_in_tree') ? $piechart2 : '',
        map {($_ => $sp->get_value_for_tag($_) || 0)} (qw(nb_genes nb_seq nb_orphan_genes nb_genes_in_tree nb_genes_in_tree_single_species nb_genes_in_tree_multi_species nb_gene_splits nb_dup_nodes)),
      });
  }
  return $table->render;
}

sub get_html_for_tree_size_statistics {
  my ($self, $species_tree_root) = @_;

  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'species',                   width => '18%', align => 'left',   sort => 'string',  title => 'Species', },
      { key => 'root_nb_trees',             width => '6%',  align => 'center', sort => 'integer', title => '# Trees', },
      { key => 'root_nb_genes',             width => '7%',  align => 'center', sort => 'integer', title => '# Genes', },
      { key => 'root_min_gene',             width => '9%',  align => 'center', sort => 'integer', title => 'Min # genes', },
      { key => 'root_max_gene',             width => '9%',  align => 'center', sort => 'integer', title => 'Max # genes', },
      { key => 'root_avg_gene',             width => '11%',  align => 'center', sort => 'numeric', title => 'Average # genes', },
      { key => 'root_min_spec',             width => '9%',  align => 'center', sort => 'integer', title => 'Min # species', },
      { key => 'root_max_spec',             width => '9%',  align => 'center', sort => 'integer', title => 'Max # species', },
      { key => 'root_avg_spec',             width => '11%',  align => 'center', sort => 'numeric', title => 'Average # species', },
      { key => 'root_avg_gene_per_spec',    width => '11%',  align => 'center', sort => 'numeric', title => 'Average # genes per species', },
    ], [], {data_table => 1, sorting => ['species asc']} );

  my $common_names = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_NAME'};
  foreach my $node (@{$species_tree_root->get_all_nodes}) {
    next unless $node->get_value_for_tag('root_nb_trees');
    $table->add_row({
        'species' => $common_names->{$node->taxon_id} ? sprintf('%s (<i>%s</i>)', $common_names->{$node->taxon_id}, $node->node_name) : $node->node_name,
        (map {$_ => $node->get_value_for_tag($_)} qw(root_nb_trees root_nb_genes root_min_gene root_max_gene root_min_spec root_max_spec)),
        (map {$_ => sprintf('%.1f', 0+$node->get_value_for_tag($_))} qw(root_avg_gene root_avg_spec root_avg_gene_per_spec)),
      });
  }

  return $table->render;
}

sub get_html_for_node_statistics {
  my ($self, $species_tree_root, $piechart_radius, $counter_raphael_holders) = @_;

  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'species',               width => '18%', align => 'left',   sort => 'string',  title => 'Species', },
      { key => 'nb_nodes',              width => '7%',  align => 'center', sort => 'integer', title => '# Nodes', },
      { key => 'nb_spec_nodes',         width => '12%', align => 'center', sort => 'integer', style => 'color: #909', title => '# speciation nodes', },
      { key => 'nb_dup_nodes',          width => '12%', align => 'center', sort => 'integer', style => 'color: #ca4', title => '# duplication nodes', },
      { key => 'nb_dubious_nodes',      width => '11%', align => 'center', sort => 'integer', style => 'color: #69f', title => '# dubious nodes', },
      { key => 'avg_dupscore',          width => '12%', align => 'center', sort => 'numeric', title => 'Average duplication confidence score', },
      { key => 'avg_dupscore_nondub',   width => '12%', align => 'center', sort => 'numeric', title => 'Average duplication confidence score (non-dubious nodes)', },
      { key => 'piechart',              width => '7%', align => 'center', sort => 'none',    title => 'Node types', },
    ], [], {data_table => 1, sorting => ['species asc']} );

  my $common_names = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_NAME'};
  foreach my $node (@{$species_tree_root->get_all_nodes}) {
    next if $node->is_leaf;
    next unless $node->get_value_for_tag('nb_nodes');
    my $v1 = $node->get_value_for_tag('nb_spec_nodes');
    my $v2 = $node->get_value_for_tag('nb_dup_nodes');
    my $v3 = $node->get_value_for_tag('nb_dubious_nodes');
    my $piechart = $self->piechart_gene_coverage([$v1, $v2, $v3], $piechart_radius, $counter_raphael_holders);

    $table->add_row({
        'species' => $common_names->{$node->taxon_id} ? sprintf('%s (<i>%s</i>)', $common_names->{$node->taxon_id}, $node->node_name) : $node->node_name,
        'piechart' => $piechart,
        (map {$_ => $node->get_value_for_tag($_)} qw(nb_nodes nb_spec_nodes nb_dup_nodes nb_dubious_nodes)),
        (map {$_ => sprintf('%.1f&nbsp;%%', 100*$node->get_value_for_tag($_))} qw(avg_dupscore avg_dupscore_nondub)),
      });
  }

  return $table->render;
}

1;
