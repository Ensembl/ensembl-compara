# $Id$

package EnsEMBL::Web::ZMenu::ComparaTreeNode;

use strict;

use URI::Escape qw(uri_escape);
use IO::String;
use Bio::AlignIO;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self     = shift;
  my $cdb      = shift || 'compara';
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $tree = $object->isa('EnsEMBL::Web::Object::GeneTree') ? $object->tree : $object->get_GeneTree($cdb);
  die 'No tree for gene' unless $tree;
  my $node_id  = $hub->param('node')                   || die 'No node value in params';
  my $node     = $tree->find_node_by_node_id($node_id) || die "No node_id $node_id in ProteinTree";
  
  my %collapsed_ids   = map { $_ => 1 } grep $_, split ',', $hub->param('collapse');
  my $leaf_count      = scalar @{$node->get_all_leaves};
  my $is_leaf         = $node->is_leaf;
  my $is_root         = ($node->root eq $node);
  my $parent_distance = $node->distance_to_parent || 0;
  my $tagvalues       = $node->get_tagvalue_hash;
  my $taxon_id        = $tagvalues->{'taxon_id'};
     $taxon_id        = $node->genome_db->taxon_id if !$taxon_id && $is_leaf;
  my $taxon_name      = $tagvalues->{'taxon_name'};
     $taxon_name      = $node->genome_db->taxon->name if !$taxon_name && $is_leaf;
  my $taxon_mya       = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_MYA'}->{$taxon_id};
  my $taxon_alias     = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_NAME'}->{$taxon_id};
 
  my $caption   = "Taxon: ";
  if (defined $taxon_alias) {
    $caption .= $taxon_alias;
    $caption .= (sprintf " ~%d MYA", $taxon_mya) if defined $taxon_mya;
    $caption .= " ($taxon_name)" if defined $taxon_name;
  } elsif (defined $taxon_name) {
    $caption .= $taxon_name;
    $caption .= (sprintf " ~%d MYA", $taxon_mya) if defined $taxon_mya;
  } else {
    $caption .= 'unknown';
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
    type => 'Bootstrap',
    label => (exists $tagvalues->{'bootstrap'} ? $tagvalues->{'bootstrap'} : "NA"),
    order => 4
  }) unless $is_root or $is_leaf;

  if (defined $tagvalues->{'lost_taxon_id'}) {
    my $lost_taxa = $tagvalues->{'lost_taxon_id'};
    $lost_taxa = [$lost_taxa] if ref($lost_taxa) ne 'ARRAY';
    $self->add_entry({
      type  => 'Lost taxa',
      label => join(', ', map {$hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'TAXON_NAME'}->{$_} || "taxon_id: $_"}  @$lost_taxa ),
      order => 5.6
    });
  }

  # Internal node_id
  $self->add_entry({
    type => 'node_id',
    label => $node->node_id,
    order => 13
  });
  
  my $action = $object->isa('EnsEMBL::Web::Object::GeneTree') ? 'Image' : 'Compara_Tree';
  $action .= '/pan_compara' if ($cdb =~ /pan/);

  # Expand all nodes
  if (grep $_ != $node_id, keys %collapsed_ids) {
    $self->add_entry({
      type  => 'Image',
      label => 'expand all sub-trees',
      order => 8,
      link  => $hub->url({
        type     => $hub->type,
        action   => $action,
        collapse => 'none' 
      })
    });
  }

  # Collapse other nodes
  my @adjacent_subtree_ids = map $_->node_id, @{$node->get_all_adjacent_subtrees};
  
  if (grep !$collapsed_ids{$_}, @adjacent_subtree_ids) {
    $self->add_entry({
      type  => 'Image',
      label => 'collapse other nodes',
      order => 10,
      link  => $hub->url({
        type     => $hub->type,
        action   => $action,
        collapse => join(',', keys %collapsed_ids, @adjacent_subtree_ids)
      })
    });
  }
  
  if ($is_leaf) {
    # expand all paralogs
    my $gdb_id = $node->genome_db_id;
    my %collapse_nodes;
    my %expand_nodes;
    
    foreach my $leaf (@{$tree->get_all_leaves}) {
      if ($leaf->genome_db_id == $gdb_id) {
        $expand_nodes{$_->node_id}   = $_ for @{$leaf->get_all_ancestors};
        $collapse_nodes{$_->node_id} = $_ for @{$leaf->get_all_adjacent_subtrees};
      } 
    }
    
    my @collapse_node_ids = grep !$expand_nodes{$_}, keys %collapse_nodes;
    
    if (@collapse_node_ids) {
      $self->add_entry({
        type  => 'Image',
        label => 'show all paralogs',
        order => 11,
        link  => $hub->url({
          type     => $hub->type,
          action   => $action,
          collapse => join(',', @collapse_node_ids)
        })
      }); 
    }
  } else {
    # Duplication confidence
    my $node_type = $tagvalues->{'node_type'};
    
    if (defined $node_type) {
      my $label;
      $label = "Dubious duplication" if $node_type eq 'dubious';
      $label = sprintf('Duplication (%d%s confid.)', 100*($tagvalues->{'duplication_confidence_score'} || 0), '%') if $node_type eq 'duplication';
      $label = 'Speciation' if $node_type eq 'speciation';
      $label = 'Gene split' if $node_type eq 'gene_split';
      
      $self->add_entry({
        type  => 'Type',
        label => $label,
        order => 5
      });
    }
    
    if (defined $tagvalues->{'tree_support'}) {
      $self->add_entry({
        type  => 'Support',
        label => $tagvalues->{'tree_support'},
        order => 5.5
      });
    }

    if ($is_root) {
      # GeneTree StableID
      $self->add_entry({
        type  => 'GeneTree StableID',
        label => $node->tree->stable_id,
        order => 1
       });

      # Link to TreeFam Tree
      my $treefam_tree = 
        $tagvalues->{'treefam_id'}          || 
        $tagvalues->{'part_treefam_id'}     || 
        $tagvalues->{'cont_treefam_id'}     || 
        $tagvalues->{'dev_treefam_id'}      || 
        $tagvalues->{'dev_part_treefam_id'} || 
        $tagvalues->{'dev_cont_treefam_id'} || 
        undef;
      
      if (defined $treefam_tree) {
        foreach my $treefam_id (split ';', $treefam_tree) {
          my $treefam_link = $hub->get_ExtURL('TREEFAMTREE', $treefam_id);
          
          if ($treefam_link) {
            $self->add_entry({
              type  => 'Maps to TreeFam',
              label => $treefam_id,
              link  => $treefam_link,
              extra => { external => 1 },
              order => 6
            });
          }
        }
      }
    }
    
    # Gene count
    $self->add_entry({
      type  => 'Gene Count',
      label => $leaf_count,
      order => 2
    });
    
    if ($collapsed_ids{$node_id}) {
      # Expand this node
      $self->add_entry({
        type  => 'Image',
        label => 'expand this sub-tree',
        order => 7,
        link  => $hub->url({
          type     => $hub->type,
          action   => $action,
          collapse => (grep $_ != $node_id, keys %collapsed_ids) ? join(',', grep $_ != $node_id, keys %collapsed_ids) : 'none'
        })
      });
    } else {
      # Collapse this node
      $self->add_entry({
        type  => 'Image',
        label => 'collapse this node',
        order => 9,
        link  => $hub->url({
          type     => $hub->type,
          action   => $action,
          collapse => join(',', $node_id, keys %collapsed_ids) 
        })
      });
    }
    
    if ($leaf_count <= 10) {
      my $url_params = { type => 'Location', action => 'Multi', r => undef };
      my $s = $self->hub->species eq 'Multi' ? 0 : 1;
      
      foreach (@{$node->get_all_leaves}) {
        my $gene = $_->gene_member->stable_id;
        
        next if $gene eq $hub->param('g');
        
        # FIXME: ucfirst tree->genome_db->name is a hack to get species names right.
        # There should be a way of retrieving this name correctly instead.
        if ($s == 0) {
          $url_params->{'species'} = ucfirst $_->genome_db->name;
          $url_params->{'g'} = $gene;
        } 
        else {
          $url_params->{"s$s"} = ucfirst $_->genome_db->name;
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
    
    # Subtree dumps
    my ($url_align, $url_tree) = $self->dump_tree_as_text($node);
    
    $self->add_entry({
      type  => 'View Sub-tree',
      label => 'Alignment: FASTA',
      link  => $url_align,
      extra => { external => 1 },
      order => 14
    });
    
    $self->add_entry({
      type  => 'View Sub-tree',
      label => 'Tree: New Hampshire',
      link  => $url_tree,
      extra => { external => 1 },
      order => 15
    });
    
    # Jalview
    $self->add_entry({
      type  => 'View Sub-tree',
      label => 'Expand for Jalview',
      class => 'expand',
      order => 16,
      link  => $hub->url({
        type     => 'ZMenu',
        action   => 'Gene',
        function => 'Jalview',
        file     => uri_escape($url_align),
        treeFile => uri_escape($url_tree)
      })
    });
  }
}

# Takes a compara tree and dumps the alignment and tree as text files.
# Returns the urls of the files that contain the trees
sub dump_tree_as_text {
  my $self = shift;
  my $tree = shift || die 'Need a ProteinTree object';
  
  my $var;
  my $file_fa = new EnsEMBL::Web::TmpFile::Text(extension => 'fa', prefix => 'gene_tree');
  my $file_nh = new EnsEMBL::Web::TmpFile::Text(extension => 'nh', prefix => 'gene_tree');
  my $format  = 'fasta';
  my $align   = $tree->get_SimpleAlign('', '', '', '', '', 1);
  my $aio     = new Bio::AlignIO(-format => $format, -fh => new IO::String($var));
  
  $aio->write_aln($align); # Write the fasta alignment using BioPerl
  
  print $file_fa $var;
  print $file_nh $tree->newick_format('full_web');
  
  $file_fa->save;
  $file_nh->save;

  return ($file_fa->URL, $file_nh->URL);
}

1;
