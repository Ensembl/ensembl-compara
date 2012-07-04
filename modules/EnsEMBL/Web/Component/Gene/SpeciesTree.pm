# $Id$

package EnsEMBL::Web::Component::Gene::SpeciesTree;

use strict;

use Bio::AlignIO;
use IO::Scalar;

use EnsEMBL::Web::Constants;

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
  my $object = $self->object;
  my $member = $object->get_compara_Member($cdb);

  return (undef, '<strong>Gene is not in the compara database</strong>') unless $member;

  my $tree = $object->get_SpeciesTree($cdb);

  return (undef, '<strong>Gene is not in a compara tree</strong>') unless $tree;

  my $node = $tree->get_all_nodes;
  return (undef, '<strong>Gene is not in the compara tree</strong>') unless $node;

  return ($member, $tree, $node);
}

sub content {
  my $self        = shift;
  my $cdb         = shift || 'compara';
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $is_speciestree = $object->isa('EnsEMBL::Web::Object::SpeciesTree') ? 1 : 0;
  my $show_exons     = $hub->param('exons') eq 'on' ? 1 : 0;
  my $collapsability = $hub->param('collapsability');
  
  my ($gene, $member, $tree, $node);
  
  if ($is_speciestree) {
    $tree   = $object->Obj;
    $member = undef;
  } else {
    $gene = $object;
    ($member, $tree, $node) = $self->get_details($cdb);
  }

  return $tree if $hub->param('g') && !$is_speciestree && !defined $member;  
  
  my $leaves               = $tree->get_all_leaves;  
  my $image_config         = $hub->get_imageconfig('genetreeview');
  my $image_width          = $self->image_width       || 800;
  my $colouring            = $hub->param('colouring') || 'background';
  
  my $html = sprintf('
    <h3>SpeciesTree%s</h3>
    ',
  );  
  
  $image_config->set_parameters({
    container_width => $image_width,
    image_width     => $image_width,
    slice_number    => '1|1',
    cdb             => $cdb
  });
  
#   foreach my $this_leaf (@$leaves) {    
#     $highlight_species = $this_leaf->gene_member->genome_db->name;    
#   }
  
  my $image = $self->new_image($tree, $image_config, undef);

  return $html if $self->_export_image($image, 'no_text');

  my $image_id = $gene->stable_id;
  
  $image->image_type       = 'genetree';
  $image->image_name       = ($hub->param('image_width')) . "-$image_id";
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'tree';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  $html .= $image->render;
  
  return $html;
}

1;