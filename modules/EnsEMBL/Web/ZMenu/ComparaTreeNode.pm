# $Id$

package EnsEMBL::Web::ZMenu::ComparaTreeNode;

use strict;

use URI::Escape qw(uri_escape);
use IO::String;
use Bio::AlignIO;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object   = $self->object;
  my $node_id  = $object->param('node')                || die 'No node value in params';
  my $tree     = $object->get_GeneTree                 || die 'No tree for gene';
  my $node     = $tree->find_node_by_node_id($node_id) || die "No node_id $node_id in ProteinTree";
  
  my %collapsed_ids   = map { $_ => 1 } grep $_, split ',', $object->param('collapse');
  my $leaf_count      = scalar @{$node->get_all_leaves};
  my $is_leaf         = $node->is_leaf;
  my $parent_distance = $node->distance_to_parent || 0;
  my $tagvalues       = $node->get_tagvalue_hash;
  my $caption         = $tagvalues->{'taxon_name'};
  
  $caption   = $node->genome_db->name if !$caption && $is_leaf;
  $caption ||= 'unknown';
  $caption   = "Taxon: $caption";
  
  if ($tagvalues->{'taxon_alias_mya'}) {
    $caption .= " ($tagvalues->{'taxon_alias_mya'})";
  } elsif ($tagvalues->{'taxon_alias'}) {
    $caption .= " ($tagvalues->{'taxon_alias'})";
  }
  
  $self->caption($caption);
  
  # Branch length
  $self->add_entry({
    type  => 'Branch_Length',
    label => $parent_distance,
    order => 3
  });

  # Bootstrap
  $self->add_entry({
    type => 'Bootstrap',
    label => $tagvalues->{'Bootstrap'},
    order => 4
  });

  # Internal node_id
  $self->add_entry({
    type => 'node_id',
    label => $node->node_id,
    order => 13
  });
  
  # Expand all nodes
  if (grep $_ != $node_id, keys %collapsed_ids) {
    $self->add_entry({
      type  => 'Image',
      label => 'expand all sub-trees',
      order => 8,
      link  => $object->_url({
        type     => 'Gene',
        action   => 'Compara_Tree',
        collapse => '' 
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
      link  => $object->_url({
        type     => 'Gene',
        action   => 'Compara_Tree',
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
        link  => $object->_url({
          type     => 'Gene', 
          action   => 'Compara_Tree',
          collapse => join(',', @collapse_node_ids)
        })
      }); 
    }
  } else {
    # Duplication confidence
    my $dup = $tagvalues->{'Duplication'};
    
    if (defined $dup) {
      my $con = sprintf '%.3f', $tagvalues->{'duplication_confidence_score'} || $dup || 0;
      
      $con = 'dubious' if $tagvalues->{'dubious_duplication'};
      
      $self->add_entry({
        type  => 'Type',
        label => $dup ? "Duplication (confidence $con)" : 'Speciation',
        order => 5
      });
    }
    
    if ($node->stable_id) {
      # GeneTree StableID
      $self->add_entry({
        type  => 'GeneTree_StableID',
        label => $node->stable_id,
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
          my $treefam_link = $object->get_ExtURL('TREEFAMTREE', $treefam_id);
          
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
      type  => 'Gene_Count',
      label => $leaf_count,
      order => 2
    });
    
    if ($collapsed_ids{$node_id}) {
      # Expand this node
      $self->add_entry({
        type  => 'Image',
        label => 'expand this sub-tree',
        order => 7,
        link  => $object->_url({
          type     => 'Gene', 
          action   => 'Compara_Tree',
          collapse => join(',', grep $_ != $node_id, keys %collapsed_ids)
        })
      });
    } else {
      # Collapse this node
      $self->add_entry({
        type  => 'Image',
        label => 'collapse this node',
        order => 9,
        link  => $object->_url({
          type     => 'Gene',
          action   => 'Compara_Tree',
          collapse => join(',', $node_id, keys %collapsed_ids) 
        })
      });
    }
    
    if ($leaf_count <= 10) {
      my $url_params = { type => 'Location', action => 'Multi', r => undef };
      my $s = 1;
      
      for (@{$node->get_all_leaves}) {
        my $gene = $_->gene_member->stable_id;
        
        next if $gene eq $object->param('g');
        
        ($url_params->{"s$s"} = $_->genome_db->name) =~ s/ /_/g;
        $url_params->{"g$s"}  = $gene;
        $s++;
      }
      
      $self->add_entry({
        type  => 'Comparison',
        label => 'Jump to Multi-species view',
        link  => $object->_url($url_params),
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
      link  => $object->_url({
        type     => 'Zmenu',
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
