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

package EnsEMBL::Web::ZMenu::ComparaTreeNode;

use strict;

use LWP::Simple qw($ua head);
use URI::Escape qw(uri_escape);
use IO::String;
use Bio::AlignIO;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self   = shift;
  my $cdb    = shift || 'compara';
  my $hub    = $self->hub;
  my $object = $self->object;
  my $tree   = $object->isa('EnsEMBL::Web::Object::GeneTree') ? $object->tree : $object->get_GeneTree($cdb);
  
  die 'No tree for gene' unless $tree;
  
  my $node_id         = $hub->param('node')                   || die 'No node value in params';
  my $node            = $tree->find_node_by_node_id($node_id);
  
  if (!$node and $tree->tree->{'_supertree'}) {
    $node = $tree->tree->{'_supertree'}->find_node_by_node_id($node_id);
  }
  unless ($node) {
    $node = $tree->adaptor->fetch_node_by_node_id($node_id);
    die "No node_id $node_id in ProteinTree" unless $node;
  }
  
  my %collapsed_ids   = map { $_ => 1 } grep /\d/, split ',', $hub->param('collapse');
  my $leaf_count      = scalar @{$node->get_all_leaves};
  my $is_leaf         = $node->is_leaf;
  my $is_root         = ($node->root eq $node);
  my $is_supertree    = ($node->tree->tree_type eq 'supertree');
  my $parent_distance = $node->distance_to_parent || 0;

  if ($is_leaf and $is_supertree) {
    my $child = $node->children->[0] || $node->adaptor->fetch_node_by_node_id($node->{_subtree}->root_id);
    $node->add_tag('species_tree_node_id', $child->get_tagvalue('species_tree_node_id'));
    my $members = $node->adaptor->fetch_all_AlignedMember_by_root_id($child->node_id);
    $node->{_sub_leaves_count} = scalar(@$members);
    my $link_gene = $members->[0];
    foreach my $g (@$members) {
      $link_gene = $g if (lc $hub->species_defs->production_name_mapping($g->genome_db->name)) eq (lc $hub->species);
    }
    $node->{_sub_reference_gene} = $link_gene->gene_member;
  }

  my $tagvalues       = $node->get_tagvalue_hash;
  my $speciesTreeNode = $node->species_tree_node();
  my $taxon_name      = $speciesTreeNode->get_scientific_name;
  my $taxon_mya       = $speciesTreeNode->get_divergence_time;
  my $taxon_alias     = $speciesTreeNode->get_common_name;

  my $caption         = 'Taxon: ';
  
  if (defined $taxon_alias) {
    $caption .= $taxon_alias;
    $caption .= sprintf ' ~%d MYA', $taxon_mya if defined $taxon_mya;
    $caption .= " ($taxon_name)";
  } else {
    $caption .= $taxon_name;
    $caption .= sprintf ' ~%d MYA', $taxon_mya if defined $taxon_mya;
  }
  
  $self->caption($caption);
  
  # Branch length
  $self->add_entry({
    type  => 'Branch Length',
    label => $parent_distance,
    order => 3
  }) unless $is_root;
  
  # Bootstrap
  $self->add_entry({
    type  => 'Bootstrap',
    label => exists $tagvalues->{'bootstrap'} ? $tagvalues->{'bootstrap'} : 'NA',
    order => 4
  }) unless $is_root || $is_leaf || $is_supertree;

  if (defined $tagvalues->{'lost_species_tree_node_id'}) {
    my $lost_taxa = $node->lost_taxa;
       
    $self->add_entry({
      type  => 'Lost taxa',
      label => join(', ', map { $_->get_common_name || $_->get_scientific_name } @$lost_taxa ),
      order => 5.6
    });
  }
  
  # Internal node_id
  $self->add_entry({
    type  => 'node_id',
    label => $node->node_id,
    order => 13
  }); 
  
  if (not $is_supertree) {

  # Expand all nodes
  if (grep $_ != $node_id, keys %collapsed_ids) {

    my %subnodes = map {($_->node_id => 1)} @{$node->get_all_nodes};
    my $collapse = join ',', (grep {not $subnodes{$_}} (keys %collapsed_ids));

    $self->add_entry({
      type          => 'Image',
      label         => 'expand all sub-trees',
      link_class    => 'update_panel',
      order         => 8,
      update_params => qq{<input type="hidden" class="update_url" name="collapse" value="$collapse" />},
      link          => '#'
    });
  }

  # Collapse other nodes
  my @adjacent_subtree_ids = map $_->node_id, @{$node->get_all_adjacent_subtrees};
  
  if (grep !$collapsed_ids{$_}, @adjacent_subtree_ids) {
    my $collapse = join ',', keys %collapsed_ids, @adjacent_subtree_ids;
    
    $self->add_entry({
      type          => 'Image',
      label         => 'collapse other nodes',
      link_class    => 'update_panel',
      order         => 10,
      update_params => qq{<input type="hidden" class="update_url" name="collapse" value="$collapse" />},
      link          => '#'
    });
  }
  
  }

  if ($is_leaf and $is_supertree) {

      # Gene count
      $self->add_entry({
        type  => 'Gene Count',
        label => $node->{_sub_leaves_count},
        order => 2,
      });
    
      my $link_gene = $node->{_sub_reference_gene};
      ## Strain trees and pon-compara trees are very different!
      my ($species, $action, $base_url);  
      if ($hub->action =~ /Strain/) {
        $species = $hub->species_defs->production_name_mapping($link_gene->genome_db->name);
        $action = $hub->action;
      }
      else {
        my $pan_lookup = $hub->species_defs->multi_val('PAN_COMPARA_LOOKUP', $link_gene->genome_db->name);
        $species = $pan_lookup->{'species_url'};
        my $site = $pan_lookup->{'division'};
        if ($site) {
          $site = 'www' if $site eq 'vertebrates';
          $base_url = sprintf 'https://%s.ensembl.org', $site;
        }
        $action = 'Compara_Tree';
      }

      $self->add_entry({
        type  => 'Gene',
        label => 'Switch to that tree',
        order => 11,
        link  => $base_url.$hub->url({
          species  => $species,
          type     => 'Gene',
          action   => $action,
          __clear  => 1,
          g        => $link_gene->stable_id,
        })
      }); 

  } elsif ($is_leaf) {
    # expand all paralogs
    my $gdb_id = $node->genome_db_id;
    my (%collapse_nodes, %expand_nodes);
    
    foreach my $leaf (@{$tree->get_all_leaves}) {
      if ($leaf->genome_db_id == $gdb_id) {
        $expand_nodes{$_->node_id}   = $_ for @{$leaf->get_all_ancestors};
        $collapse_nodes{$_->node_id} = $_ for @{$leaf->get_all_adjacent_subtrees};
      } 
    }
    
    my @collapse_node_ids = grep !$expand_nodes{$_}, keys %collapse_nodes;
    
    if (@collapse_node_ids) {
      my $collapse = join ',', @collapse_node_ids;
      
      $self->add_entry({
        type          => 'Image',
        label         => 'show all paralogs',
        link_class    => 'update_panel',
        order         => 11,
        update_params => qq{<input type="hidden" class="update_url" name="collapse" value="$collapse" />},
        link          => '#'
      }); 
    }
  } else {
    # Duplication confidence
    my $node_type = $tagvalues->{'node_type'};
    
    if (defined $node_type) {
      my $label = {
          'dubious'         => 'Dubious duplication',
          'duplication'     => 'Duplication',
          'speciation'      => 'Speciation',
          'sub-speciation'  => 'Sub-speciation',
          'gene_split'      => 'Gene split',
      }->{$node_type};
      $label .= sprintf ' (%d%s confid.)', 100 * ($tagvalues->{'duplication_confidence_score'} || 0), '%' if $node_type eq 'duplication';
      
      $self->add_entry({
        type  => 'Type',
        label => $label,
        order => 5
      });
    }
    
    if (defined $tagvalues->{'tree_support'}) {
      my $tree_support = $tagvalues->{'tree_support'};
         $tree_support = [ $tree_support ] if ref $tree_support ne 'ARRAY';
      $self->add_entry({
        type  => 'Support',
        label => join(',', @$tree_support),
        order => 5.5
      });
    }

    if ($is_root and not $is_supertree) {
      # GeneTree StableID
      $self->add_entry({
        type  => 'GeneTree StableID',
        label => $node->tree->stable_id,
        order => 1
       });

      # Link to TreeFam Tree
      my $tree_tagvalues  = $tree->get_tagvalue_hash;
      my $treefam_tree = 
        $tree_tagvalues->{'treefam_id'}          || 
        $tree_tagvalues->{'part_treefam_id'}     || 
        $tree_tagvalues->{'cont_treefam_id'}     || 
        undef;
      
      if (defined $treefam_tree) {
        foreach my $treefam_id (split ';', $treefam_tree) {
          my $treefam_link = $hub->get_ExtURL('TREEFAMTREE', $treefam_id);
          
          if ($treefam_link) {
            $self->add_entry({
              type     => 'Maps to TreeFam',
              label    => $treefam_id,
              link     => $treefam_link,
              external => 1,
              order    => 6
            });
          }
        }
      }
    }
    
    # Gene count
    $self->add_entry({
      type  => $is_supertree ? 'Tree Count' : 'Gene Count',
      label => $leaf_count,
      order => 2
    });
    
    return if $is_supertree;
    
    if ($collapsed_ids{$node_id}) {
      my $collapse = join(',', grep $_ != $node_id, keys %collapsed_ids) || 'none';
      
      # Expand this node
      $self->add_entry({
        type          => 'Image',
        label         => 'expand this sub-tree',
        link_class    => 'update_panel',
        order         => 7,
        update_params => qq{<input type="hidden" class="update_url" name="collapse" value="$collapse" />},
        link          => '#'
      });
    } else {
      my $collapse = join ',', $node_id, keys %collapsed_ids;
      
      # Collapse this node
      $self->add_entry({
        type          => 'Image',
        label         => 'collapse this node',
        link_class    => 'update_panel',
        order         => 9,
        update_params => qq{<input type="hidden" class="update_url" name="collapse" value="$collapse" />},
        link          => '#'
      });
    }
    
    if ($leaf_count <= 10) {
      my $url_params = { type => 'Location', action => 'Multi', r => undef };
      my $s = $self->hub->species eq 'Multi' ? 0 : 1;
      
      foreach (@{$node->get_all_leaves}) {
        my $gene = $_->gene_member->stable_id;
        
        next if $gene eq $hub->param('g');
        
        if ($s == 0) {
          $url_params->{'species'} = $hub->species_defs->production_name_mapping($_->genome_db->name);
          $url_params->{'g'} = $gene;
        } 
        else {
          $url_params->{"s$s"} = $hub->species_defs->production_name_mapping($_->genome_db->name);
          $url_params->{"g$s"} = $gene;
        }
        $s++;
      }
      
      $self->add_entry({
        type  => 'Comparison',
        label => 'Jump to Region Comparison view',
        link  => $hub->url($url_params),
        order => 13
      });
    }
  
    ## Build URL for data export 
    my $gene_name;
    my $gene      = $self->object->Obj;
    my $dxr       = $gene->can('display_xref') ? $gene->display_xref : undef;
    my $gene_name = $hub->species eq 'Multi' ? $hub->param('gt') : $dxr ? $dxr->display_id : $gene->stable_id;
    my $params    = {
                      'type'      => 'DataExport',
                      'action'    => 'GeneTree',
                      'data_type' => 'Gene',
                      'component' => 'ComparaTree',
                      'gene_name' => $gene_name,
                      'align'     => 'tree',
                      'node'      => $node_id,
                    };

    $self->add_entry({
      type        => 'Export sub-tree',
      label       => 'Tree or Alignment',
      link        => $hub->url($params),
      link_class  => 'modal_link',
      order       => 14,
    }); 

    $params->{'align_type'} = 'msa_dna';
    $self->add_entry({
      type        => 'Export sub-tree',
      label       => 'Sequences',
      link        => $hub->url($params),
      link_class  => 'modal_link',
      order       => 15,
    }); 

    # FIXME - Quick hack to hide Wasabi for all strains trees. This should be removed once we have the HAL ready
    if ($hub->referer->{ENSEMBL_ACTION} ne 'Strain_Compara_Tree') {

      # Get wasabi files if found in session store
      my $is_strain = $hub->species_defs->IS_STRAIN_OF ? 1 : 0;
      my $gt_id               = $is_strain ? $gene->stable_id : $node->tree->stable_id;
      my $is_ncrna            = ($node->tree->member_type eq 'ncrna');
      $gt_id = $is_ncrna ? $hub->param('g') : $gt_id;
      my $wasabi_session_key  = $gt_id . "_" . $node_id;
      my $wasabi_session_data = $hub->session->get_data(type=>'tree_files', code => 'wasabi');

      my ($alignment_file, $tree_file, $link);
      if ($wasabi_session_data->{$wasabi_session_key}) {
        $tree_file      = $wasabi_session_data->{$wasabi_session_key}->{tree};

        # Create wasabi url to load from their end
        $link = sprintf (
                          '/wasabi/wasabi.htm?tree=%s',
                          uri_escape($object->species_defs->ENSEMBL_BASE_URL . $tree_file)
                        );
      }
      else {
        my $rest_url = $hub->species_defs->ENSEMBL_REST_URL;

        # Fall back to file generation if REST fails.
        # To make it work for e! archives
        $ua->timeout(10);

        my $is_success = head($rest_url);
        if ($is_success) {
          $rest_url .= sprintf('/genetree/%sid/%s?content-type=text/javascript&aligned=1&subtree_node_id=%s&%s',
                        ($is_strain or $is_ncrna) ? 'member/' : '',
                        $gt_id,
                        $node_id,
                        $is_strain ? 'clusterset_id=murinae' : '');

          if ($hub->wasabi_status) {
            $link = $hub->get_ExtURL('WASABI_ENSEMBL', {
              'URL' => uri_escape($rest_url)
            });
          }
          
        }
        else {
          my $filegen_url = $hub->url('Json', {
                              type => 'GeneTree', 
                              action => 'fetch_wasabi',
                              node => $node_id, 
                              gt => $gt_id, 
                              treetype => 'json'
                            });

          $link = sprintf (
                            '/wasabi/wasabi.htm?filegen_url=%s',
                            uri_escape($filegen_url)
                          );
        }
      }

      # Wasabi Tree Link
      $self->add_entry({
        type       => 'View sub-tree',
        label      => $link ? 'Wasabi viewer' : 'Not available' ,
        link_class => 'popup',
        order      => 16,
        link       => $link || ''
      });
    }
  }
}

1;
