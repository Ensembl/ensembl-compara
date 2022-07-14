=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::ComparaTree;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub get_details {
  my $self   = shift;
  my $cdb    = shift;
  my $object = shift || $self->object || $self->hub->core_object('gene');

  my $member = $object->get_compara_Member($cdb);
  return (undef, '<strong>Gene is not in the compara database</strong>') unless $member;

  my $strain_tree  = $self->hub->species_defs->get_config($self->hub->species,'RELATED_TAXON') if ($self->hub->is_strain || $self->hub->param('strain') || $self->hub->action =~ /Strain_/);
  my $species_tree = $object->get_SpeciesTree($cdb, $strain_tree);  
  my $tree = $object->get_GeneTree($cdb,"", $strain_tree);
  return (undef, '<strong>Gene is not in a compara tree</strong>') unless $tree;

  my $node = $tree->get_leaf_by_Member($member);
  return (undef, '<strong>Gene is not in the compara tree</strong>') unless $node;

  return ($member, $tree, $node, $species_tree);
}

sub content_sub_supertree {
  my $self = shift;
  my $hub = $self->hub;
  my $cdb = $self->param('cdb') || 'compara';
  my $object      = $self->object;
  my $is_genetree = $object->isa('EnsEMBL::Web::Object::GeneTree') ? 1 : 0;
  my ($gene, $member, $tree, $node, $test_tree);
  if ($is_genetree) {
    $tree   = $object->Obj;
    $member = undef;
  } else {
    $gene = $object;
    ($member, $tree, $node, $test_tree) = $self->get_details($cdb);
  }
  my $html = '';
  my $parent      = $tree->tree->{'_supertree'};
  my $tree_stable_id       = $tree->tree->stable_id;
  my $super_image_config = $hub->get_imageconfig('supergenetreeview');
  $super_image_config->set_parameters({
    container_width => 400,
    image_width     => 400,
    slice_number    => '1|1',
    cdb             => $cdb
  });
  my $image = $self->new_image($parent->root, $super_image_config, []);
  $image->image_type       = 'genetree';
  $image->image_name       = ($self->param('image_width')) . "-SUPER-$tree_stable_id";
  $image->imagemap         = 'yes';
  $image->set_button('drag', 'title' => 'Drag to select region');
  $html .= sprintf(
    '<h3>Super-tree (%d trees and %d genes in total)</h3>',
    scalar @{$parent->root->get_all_leaves},
    $parent->{'_total_num_leaves'},
  );
  $html .= $image->render ;
  $self->id('');
  return "<div>$html</div>";
}

sub content {
  my $self        = shift;
  my $cdb         = shift || 'compara';
  my $hub         = $self->hub;
  my $object      = $self->object || $self->hub->core_object('gene');
  my $is_genetree = $object && $object->isa('EnsEMBL::Web::Object::GeneTree') ? 1 : 0;
  my ($gene, $member, $tree, $node, $test_tree);

  my $type   = $self->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);
  warn ">>> GENE TREE? $is_genetree";

  if ($is_genetree) {
    $tree   = $object->Obj;
    $member = undef;
  } else {
    $gene = $object;
    ($member, $tree, $node, $test_tree) = $self->get_details($cdb);
  }

  return $tree . $self->genomic_alignment_links($cdb) if $self->param('g') && !$is_genetree && !defined $member;

  my $leaves               = $tree->get_all_leaves;
  my $tree_stable_id       = $tree->tree->stable_id;
  my $highlight_gene       = $hub->param('g1');
  my $highlight_status     = $hub->get_cookie_value('gene_tree_highlighting') || 'on'; # get the the highlight switch status from the cookie

  # Set $highlight_gene to undefined if the highlight status is off. This is due to the module relying heavily on $highlight_gene to do the rendering based on the highlight status.
  if ($highlight_status eq 'off') {
    $highlight_gene = undef;
  }

  my $highlight_ancestor   = $self->param('anc');
  my $image_width          = $self->image_width       || 800;
  my $colouring            = $self->param('colouring') || 'background';
  my $collapsability       = $is_genetree ? '' : ($vc->get('collapsability') || $self->param('collapsability'));
  my $clusterset_id        = $vc->get('clusterset_id') || $self->param('clusterset_id');
  my $show_exons           = $self->param('exons') eq 'on' ? 1 : 0;
  my $image_config         = $hub->get_imageconfig('genetreeview');
  my @hidden_clades        = grep { $_ =~ /^group_/ && $self->param($_) eq 'hide'     } $self->param;
  my @collapsed_clades     = grep { $_ =~ /^group_/ && $self->param($_) eq 'collapse' } $self->param;
  my @highlights           = $gene && $member ? ($gene->stable_id, $member->genome_db->dbID) : (undef, undef);
  my $hidden_genes_counter = 0;
  my $link                 = $hub->type eq 'GeneTree' ? '' : sprintf ' <a href="%s">%s</a>', $hub->url({ species => 'Multi', type => 'GeneTree', action => 'Image', gt => $tree_stable_id, __clear => 1 }), $tree_stable_id;
  my $html                 = '<input type="hidden" class="panel_type" value="ComparaTree" />';
  my (%hidden_genome_db_ids, $highlight_species, $highlight_species_name, $highlight_genome_db_id);

  $html                 .= sprintf '<h3>GeneTree%s</h3>%s', $link, $self->new_twocol(
    ['Number of genes',             scalar(@$leaves)                                                  ],
    ['Number of speciation nodes',  $self->get_num_nodes_with_tag($tree, 'node_type', 'speciation') + $self->get_num_nodes_with_tag($tree, 'node_type', 'sub-speciation')   ],
    ['Number of duplication',       $self->get_num_nodes_with_tag($tree, 'node_type', 'duplication')  ],
    ['Number of ambiguous',         $self->get_num_nodes_with_tag($tree, 'node_type', 'dubious')      ],
    ['Number of gene split events', $self->get_num_nodes_with_tag($tree, 'node_type', 'gene_split')   ]
  )->render;

  my $parent      = $tree->tree->{'_supertree'};
  if (defined $parent) {

    if ($vc->get('super_tree') eq 'on' || $self->param('super_tree') eq 'on') {
      my $super_url = $self->ajax_url('sub_supertree',{ cdb => $cdb, update_panel => undef });
      $html .= qq(<div class="ajax"><input type="hidden" class="ajax_load" value="$super_url" /></div>);
    } else {
      $html .= $self->_info(
        sprintf(
          'This tree is part of a super-tree of %d trees (%d genes in total)',
          scalar @{$parent->root->get_all_leaves},
          $parent->{'_total_num_leaves'},
        ),
        'The super-tree is currently not displayed. Use the "configure page" link in the left panel to change the options'
      );
    }
  }

  if ($hub->type eq 'Gene') {
    if ($tree->tree->clusterset_id ne $clusterset_id && !$self->is_strain) {
      $html .= $self->_info('Phylogenetic model selection',
        sprintf(
          'The phylogenetic model <I>%s</I> is not available for this tree. Showing the default (consensus) tree instead.', $clusterset_id
          )
      );
    } elsif ($tree->tree->ref_root_id) {

      my $text = sprintf(
          'The tree displayed here has been built with the phylogenetic model <I>%s</I>. It has then been merged with trees built with other models to give the final tree and homologies. Data shown here may be inconsistent with the rest of the comparative analyses, especially homologies.', $clusterset_id
      );
      my $rank = $tree->tree->get_tagvalue('k_score_rank');
      my $score = $tree->tree->get_tagvalue('k_score');
      $text .= sprintf('<br/>This tree is the <b>n&deg;%d</b> closest to the final tree, with a K-distance of <b>%f</b>, as computed by <a href="http://molevol.cmima.csic.es/castresana/Ktreedist.html">Ktreedist</a>.', $rank, $score) if $rank;
      $html .= $self->_info('Phylogenetic model selection', $text);
    }
  }

  # store g1 param in a different param as $highlight_gene can be undef if highlighting is disabled
  my $gene_to_highlight = $hub->param('g1');
  my $current_gene_display_name;

  if ($gene && defined $gene->Obj->display_xref) {
    $current_gene_display_name = $gene->Obj->display_xref->display_id;
  } else {
    $current_gene_display_name = $hub->param('g'); 
  } 
     
  my $lookup = $hub->species_defs->prodnames_to_urls_lookup; 
  foreach my $this_leaf (@$leaves) {
    if ($gene_to_highlight && $this_leaf->gene_member->stable_id eq $gene_to_highlight) {
      $highlight_species            = $lookup->{$this_leaf->gene_member->genome_db->name};
      $highlight_species_name       = $this_leaf->gene_member->genome_db->display_name;
      $highlight_genome_db_id       = $this_leaf->gene_member->genome_db_id;
      last;
    }
  }

  # check if highlight ancestor (anc param) is available or not
  # if it isn't then there is no need for a message as there will be no g1 (highlight gene) as well
  if ($highlight_ancestor) {
    # use $highlight_gene to check if highlight is enabled or not
    # $gene_to_highlight will be used for getting info necessary to display the highlighting message
    if ($highlight_gene) {
      if ($member && $gene && $highlight_species) {
        $html .= $self->_info('Highlighted genes',
          sprintf(
            '<p>The <i>%s</i> %s gene, its paralogues, its orthologue in <i>%s</i>, and paralogues of the <i>%s</i> gene, have all been highlighted. <a href="#" class="switch_highlighting on">Click here to disable highlighting</a>.</p>',
            $hub->species_defs->get_config($lookup->{$member->genome_db->name}, 'SPECIES_DISPLAY_NAME'),
            $current_gene_display_name,
            $hub->species_defs->get_config($highlight_species, 'SPECIES_DISPLAY_NAME') || $highlight_species_name,
            $hub->species_defs->get_config($highlight_species, 'SPECIES_DISPLAY_NAME') || $highlight_species_name
          )
        );
      } else {
        $html .= $self->_warning('WARNING', "<p>$highlight_gene gene is not in this Gene Tree</p>");
        $highlight_gene = undef;
      }
    } else {
      $html .= $self->_info('Highlighted genes', 
        sprintf(
          '<p>The <i>%s</i> %s gene and its paralogues are highlighted. <a href="#" class="switch_highlighting off">Click here to enable highlighting of %s homologues</a>.</p>',
          $hub->species_defs->get_config($lookup->{$member->genome_db->name}, 'SPECIES_DISPLAY_NAME'),
          $current_gene_display_name,
          $hub->species_defs->get_config($highlight_species, 'SPECIES_DISPLAY_NAME') || $highlight_species_name
        )
      );
    }
  }
  
  # Get all the genome_db_ids in each clade
  # Ideally, this should be stored in $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}
  # or any other centralized place, to avoid recomputing it many times
  my %genome_db_ids_by_clade = map {$_ => []} @{ $self->hub->species_defs->TAXON_ORDER };
  my $genome_db_adaptor = $tree->adaptor->db->get_GenomeDBAdaptor;
  foreach my $species_name (keys %{$self->hub->get_species_info}) {  
    foreach my $clade (@{ $self->hub->species_defs->get_config($species_name, 'SPECIES_GROUP_HIERARCHY') }) {
      my $production_name = $hub->species_defs->get_config($species_name, 'SPECIES_PRODUCTION_NAME');
      my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($production_name);
      push @{$genome_db_ids_by_clade{$clade}}, $genome_db->dbID if $genome_db;
    }
  }

  if (@hidden_clades) {
    %hidden_genome_db_ids = ();
    
    foreach my $clade (@hidden_clades) {
      my ($clade_name) = $clade =~ /group_([\w\-]+)_display/;
      $hidden_genome_db_ids{$_} = 1 for @{ $genome_db_ids_by_clade{$clade_name} };
    }
    
    foreach my $this_leaf (@$leaves) {
      my $genome_db_id = $this_leaf->genome_db_id;
      
      next if $highlight_genome_db_id && $genome_db_id eq $highlight_genome_db_id;
      next if $highlight_gene && $this_leaf->gene_member->stable_id eq $highlight_gene;
      next if $member && $genome_db_id == $member->genome_db_id;
      
      if ($hidden_genome_db_ids{$genome_db_id}) {
        $hidden_genes_counter++;
        $this_leaf->disavow_parent;
        $tree = $tree->minimize_tree;
      }
    }

    $html .= $self->_info('Hidden genes', "<p>There are $hidden_genes_counter hidden genes in the tree. Use the 'configure page' link in the left panel to change the options.</p>") if $hidden_genes_counter;
  }

  $image_config->set_parameters({
    container_width => $image_width,
    image_width     => $image_width,
    slice_number    => '1|1',
    cdb             => $cdb
  });
  
  # Keep track of collapsed nodes
  my $collapsed_nodes = $self->param('collapse');
  my ($collapsed_to_gene, $collapsed_to_para);
  
  if (!$is_genetree) {
    $collapsed_to_gene = $self->collapsed_nodes($tree, $node, 'gene',     $highlight_genome_db_id, $highlight_gene);
    $collapsed_to_para = $self->collapsed_nodes($tree, $node, 'paralogs', $highlight_genome_db_id, $highlight_gene);
  }
  
  my $collapsed_to_dups = $self->collapsed_nodes($tree, undef, 'duplications', $highlight_genome_db_id, $highlight_gene);

  if (!defined $collapsed_nodes) { # Examine collapsabilty
    $collapsed_nodes = $collapsed_to_gene if $collapsability eq 'gene';
    $collapsed_nodes = $collapsed_to_para if $collapsability eq 'paralogs';
    $collapsed_nodes = $collapsed_to_dups if $collapsability eq 'duplications';
    $collapsed_nodes ||= '';
  }

  if (@collapsed_clades) {
    foreach my $clade (@collapsed_clades) {
      my ($clade_name) = $clade =~ /group_([\w\-]+)_display/;
      my $extra_collapsed_nodes = $self->find_nodes_by_genome_db_ids($tree, $genome_db_ids_by_clade{$clade_name}, 'internal');
      
      if (%$extra_collapsed_nodes) {
        $collapsed_nodes .= ',' if $collapsed_nodes;
        $collapsed_nodes .= join ',', keys %$extra_collapsed_nodes;
      }
    }
  }

  my $coloured_nodes;
  
  if ($colouring =~ /^(back|fore)ground$/) {
    my $mode   = $1 eq 'back' ? 'bg' : 'fg';

    # TAXON_ORDER is ordered by increasing phylogenetic size. Reverse it to
    # get the largest clades first, so that they can be overwritten later
    # (see ensembl-webcode/modules/EnsEMBL/Draw/GlyphSet/genetree.pm)
    foreach my $clade_name (reverse @{ $self->hub->species_defs->TAXON_ORDER }) {
      next unless $self->param("group_${clade_name}_${mode}colour");
      my $genome_db_ids = $genome_db_ids_by_clade{$clade_name};
      my $colour        = $self->param("group_${clade_name}_${mode}colour");
      my $nodes         = $self->find_nodes_by_genome_db_ids($tree, $genome_db_ids, $mode eq 'fg' ? 'all' : undef);
      
      push @$coloured_nodes, { clade => $clade_name,  colour => $colour, mode => $mode, node_ids => [ keys %$nodes ] } if %$nodes;
    }
  }
 
  push @highlights, $collapsed_nodes        || undef;
  push @highlights, $coloured_nodes         || undef;
  push @highlights, $highlight_genome_db_id || undef;
  push @highlights, $highlight_gene         || undef;
  push @highlights, $highlight_ancestor     || undef;
  push @highlights, $show_exons;

  my $image = $self->new_image($tree, $image_config, \@highlights);
  
  return if $self->_export_image($image, 'no_text');

  my $image_id = $gene ? $gene->stable_id : $tree_stable_id;
  my $li_tmpl  = '<li><a href="%s">%s</a></li>';
  my @view_links;


  $image->image_type        = 'genetree';
  $image->image_name        = ($self->param('image_width')) . "-$image_id";
  $image->imagemap          = 'yes';
  $image->{'panel_number'}  = 'tree';

  ## Need to pass gene name to export form 
  my $gene_name;
  if ($gene) {
    my $dxr    = $gene->Obj->can('display_xref') ? $gene->Obj->display_xref : undef;
    $gene_name = $dxr ? $dxr->display_id : $gene->stable_id;
  }
  else {
    $gene_name = $tree_stable_id;
  }

  ## Parameters to pass into export form
  $image->{'export_params'} = [['gene_name', $gene_name],['align', 'tree']];
  my @extra_params = qw(g1 anc collapse);
  foreach (@extra_params) {
    push @{$image->{'export_params'}}, [$_, $self->param($_)];
  }
  foreach ($self->param) {
    if (/^group/) {
      push @{$image->{'export_params'}}, [$_, $self->param($_)];
    }
  }
  $image->{'data_export'}   = 'GeneTree';
  $image->{'remove_reset'}  = 1;

  $image->set_button('drag', 'title' => 'Drag to select region');
  my $default_view_url = $hub->url({ collapse => $collapsed_to_gene, g1 => $highlight_gene });
  if ($gene) {
    push @view_links, sprintf '<li><a href="%s">%s</a> (Default) </li>', $default_view_url, $highlight_gene ? 'View current genes only' : 'View current gene only';
    push @view_links, sprintf $li_tmpl, $hub->url({ collapse => $collapsed_to_para, g1 => $highlight_gene }), $highlight_gene ? 'View paralogs of current genes' : 'View paralogs of current gene';
  }
  
  push @view_links, sprintf $li_tmpl, $hub->url({ collapse => $collapsed_to_dups, g1 => $highlight_gene }), 'View all duplication nodes';
  push @view_links, sprintf $li_tmpl, $hub->url({ collapse => 'none', g1 => $highlight_gene }), 'View fully expanded tree';

  {
    my @rank_options = ( q{<option value="#">-- Select a rank--</option>} );
    my $selected_rank = $self->param('gtr') || '';
    foreach my $rank (qw(species genus family order class phylum kingdom)) {
      my $collapsed_to_rank = $self->collapsed_nodes($tree, $node, "rank_$rank", $highlight_genome_db_id, $highlight_gene);
      push @rank_options, sprintf qq{<option value="%s" %s>%s</option>\n}, $hub->url({ collapse => $collapsed_to_rank, g1 => $highlight_gene, gtr => $rank }), $rank eq $selected_rank ? 'selected' : '', ucfirst $rank;
    }
    push @view_links, sprintf qq{<li>Collapse all the nodes at the taxonomic rank <select onchange="Ensembl.redirect(this.value)">%s</select></li>}, join("\n", @rank_options) if(!$self->is_strain);
  }

  $html .= $image->render;
  $html .= sprintf(qq{
    <div>
      <h4>View options:</h4>
      <ul>%s</ul>
      <p>Use the 'configure page' link in the left panel to set the default. Further options are available from menus on individual tree nodes.</p>
    </div>
  }, join '', @view_links);
  
  return $html;
}

sub collapsed_nodes {
  # Takes the ProteinTree and node related to this gene and a view action
  # ('gene', 'paralogs', 'duplications' ) and returns the list of
  # tree nodes that should be collapsed according to the view action.
  # TODO: Move to Object::Gene, as the code is shared by the ajax menus
  my $self                   = shift;
  my $tree                   = shift;
  my $node                   = shift;
  my $action                 = shift;
  my $highlight_genome_db_id = shift;
  my $highlight_gene         = shift;
  
  die "Need a GeneTreeNode, not a $tree" unless $tree->isa('Bio::EnsEMBL::Compara::GeneTreeNode');
  die "Need an GeneTreeMember, not a $node" if $node && !$node->isa('Bio::EnsEMBL::Compara::GeneTreeMember');

  my %collapsed_nodes;
  my %expanded_nodes;
  
  # View current gene
  if ($action eq 'gene') {
    return unless $node;
    $collapsed_nodes{$_->node_id} = $_ for @{$node->get_all_adjacent_subtrees};
    
    if ($highlight_gene) {
      $expanded_nodes{$_->node_id} = $_ for @{$node->get_all_ancestors};
      
      foreach my $leaf (@{$tree->get_all_leaves}) {
        $collapsed_nodes{$_->node_id} = $_ for @{$leaf->get_all_adjacent_subtrees};
        
        if ($leaf->gene_member->stable_id eq $highlight_gene) {
          $expanded_nodes{$_->node_id} = $_ for @{$leaf->get_all_ancestors};
          last;
        }
      }
    }
  } elsif ($action eq 'paralogs') { # View all paralogs
    return unless $node;
    my $gdb_id = $node->genome_db_id;
    
    foreach my $leaf (@{$tree->get_all_leaves}) {
      if ($leaf->genome_db_id == $gdb_id || ($highlight_genome_db_id && $leaf->genome_db_id == $highlight_genome_db_id)) {
        $expanded_nodes{$_->node_id}  = $_ for @{$leaf->get_all_ancestors};
        $collapsed_nodes{$_->node_id} = $_ for @{$leaf->get_all_adjacent_subtrees};
      }
    }
  } elsif ($action eq 'duplications') { # View all duplications
    foreach my $tnode(@{$tree->get_all_nodes}) {
      next if $tnode->is_leaf;
      
      if ($tnode->get_tagvalue('node_type', '') ne 'duplication') {
        $collapsed_nodes{$tnode->node_id} = $tnode;
        next;
      }
      
      $expanded_nodes{$tnode->node_id} = $tnode;
      $expanded_nodes{$_->node_id}     = $_ for @{$tnode->get_all_ancestors};
    }
  } elsif ($action =~ /rank_(\w+)/) {
    my $asked_rank = $1;
    my @rank_order = qw(subspecies species subgenus genus subfamily family superfamily parvorder infraorder suborder order superorder infraclass subclass class superclass subphylum phylum superphylum subkingdom kingdom superkingdom);
    my %rank_pos = map {$rank_order[$_] => $_} 0..(scalar(@rank_order)-1);
    my @nodes_to_check = ($tree);
    while (@nodes_to_check) {
      my $internal_node = shift @nodes_to_check;
      next if $internal_node->is_leaf;
      next unless $internal_node->species_tree_node;
      my $taxon = $internal_node->species_tree_node->taxon;
      my $this_rank = $taxon->rank;
      if ($this_rank eq 'no rank') {
        # We traverse the taxonomy upwards until we find a rank, and get
        # the rank just below instead
        while ($this_rank eq 'no rank') {
          $taxon = $taxon->parent;
          last unless $taxon;
          $this_rank = $taxon->rank;
        }
        $this_rank = $rank_pos{$this_rank}-1;
        #warn sprintf("Mapped 'no rank' %s to %s\n", $internal_node->species_tree_node->taxon->name, $rank_order[$this_rank]);
      } else {
        $this_rank = $rank_pos{$this_rank};
      }
      $this_rank = scalar(@rank_order) unless defined $this_rank;
      if ($this_rank <= $rank_pos{$asked_rank}) {
        $collapsed_nodes{$internal_node->node_id} = $internal_node;
      } else {
        push @nodes_to_check, @{$internal_node->children};
      }
    }
  }
  
  return join ',', grep !$expanded_nodes{$_}, keys %collapsed_nodes;
}

sub get_num_nodes_with_tag {
  my ($self, $tree, $tag, $test_value, $exclusion_tag_array) = @_;
  my $count = 0;

  OUTER: foreach my $tnode(@{$tree->get_all_nodes}) {
    my $tag_value = $tnode->get_tagvalue($tag);
    #Accept if the test value was not defined but got a value from the node
    #or if we had a tag value and it was equal to the test
    if( (! $test_value && $tag_value) || ($test_value && $tag_value eq $test_value) ) {
      
      #If we had an exclusion array then check & skip if it found anything
      if($exclusion_tag_array) {
        foreach my $exclusion (@{$exclusion_tag_array}) {
          my $exclusion_value = $tnode->get_tagvalue($exclusion);
          if($exclusion_value) {
            next OUTER;
          }
        }
      }
      $count++;
    }
  }

  return $count;
}

sub find_nodes_by_genome_db_ids {
  my ($self, $tree, $genome_db_ids, $mode) = @_;
  my $node_ids = {};

  if ($tree->is_leaf) {
    my $genome_db_id = $tree->genome_db_id;

    if (grep $_ eq $genome_db_id, @$genome_db_ids) {
      $node_ids->{$tree->node_id} = 1;
    }
  } else {
    my $tag = 1;
    foreach my $this_child (@{$tree->children}) {
      my $these_node_ids = $self->find_nodes_by_genome_db_ids($this_child, $genome_db_ids, $mode);
      
      foreach my $node_id (keys %$these_node_ids) {
        $node_ids->{$node_id} = 1;
      }
      
      $tag = 0 unless $node_ids->{$this_child->node_id};
    }
    
    if ($mode eq 'internal') {
      foreach my $this_child (@{$tree->children}) {
        delete $node_ids->{$this_child->node_id} if $this_child->is_leaf;
      }
    }
    
    if ($tag) {
      if ($mode ne 'all') {
        foreach my $this_child (@{$tree->children}) {
          delete $node_ids->{$this_child->node_id};
        }
      }
      
      $node_ids->{$tree->node_id} = 1;
    }
  }
  
  return $node_ids;
}

sub genomic_alignment_links {
  my $self          = shift;
  my $hub           = $self->hub;
  my $cdb           = shift || $self->param('cdb') || 'compara';
  (my $ckey = $cdb) =~ s/compara//;
  my $species_defs  = $hub->species_defs;
  my $alignments    = $species_defs->multi_hash->{$ckey}{'ALIGNMENTS'}||{};
  my $species       = $hub->species;
  my $url           = $hub->url({ action => "Compara_Alignments$ckey", align => undef });
  my $url_lookup    = $hub->species_defs->prodnames_to_urls_lookup;
  my (%species_hash, $list);
  
  foreach my $row_key (grep $alignments->{$_}{'class'} !~ /pairwise/, keys %$alignments) {
    my $row = $alignments->{$row_key};
    
    next unless $row->{'species'}->{$species};
    
    $row->{'name'} =~ s/_/ /g;
    
    $list .= qq{<li><a href="$url;align=$row_key">$row->{'name'}</a></li>};
  }
  
  foreach my $i (grep $alignments->{$_}{'class'} =~ /pairwise/, keys %$alignments) {
    foreach (keys %{$alignments->{$i}->{'species'}}) {
      if ($alignments->{$i}->{'species'}->{$species} && $_ ne $species) {
        my $type = lc $alignments->{$i}->{'type'};
        
        $type =~ s/_net//;
        $type =~ s/_/ /g;
        
        $species_hash{$species_defs->species_label($url_lookup->{$_}) . "###$type"} = $i;
      }
    } 
  }
  
  foreach (sort { $a cmp $b } keys %species_hash) {
    my ($name, $type) = split /###/, $_;
    
    $list .= qq(<li><a href="$url;align=$species_hash{$_}">$name - $type</a></li>);
  }
  
  return qq{<div class="alignment_list"><p>View genomic alignments for this gene</p><ul>$list</ul></div>};
}

sub export_options { return {'action' => 'GeneTree'}; }

sub get_export_data {
## Get data for export
  my ($self, $type) = @_;
  my $hub   = $self->hub;
  my $cdb   = $self->param('cdb');
  my $gene  = $hub->core_object('gene');
  my ($tree, $node, $member);

  unless ( $cdb ) {
    my $function = $hub->referer->{'ENSEMBL_FUNCTION'};
    $cdb = $function && $function eq 'pan_compara' ? 'compara_pan_ensembl' : 'compara';  
  }
  
  ## First, get tree
  if ($gene && $type && $type eq 'genetree') { 
    $tree = $gene->get_GeneTree($cdb, 1);
  }
  elsif ($hub->species eq 'Multi' && $self->param('gt')) {
    my $gene_tree = $hub->builder->create_object('GeneTree');
    $tree         = $gene_tree->Obj;
  }
  else {
    ($member, $tree) = $self->get_details($cdb, $gene);
  }

  ## Get node if required
  if ($self->param('node')) {
    $node = $tree->find_node_by_node_id($self->param('node'))
  }

  ## Finally return correct object type
  if ($type) {
    return $node ? $node : $tree;
  }
  else {
    return $node ? $node->get_SimpleAlign(-APPEND_SP_SHORT_NAME => 1) 
                 : $tree->tree->get_SimpleAlign(-APPEND_SP_SHORT_NAME => 1);
  }
}

1;
