# $Id$

package EnsEMBL::Web::Component::Gene::SpeciesTree;

use strict;

use Bio::AlignIO;
use Bio::EnsEMBL::Registry;
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
  my $hub    = $self->hub;  
  
  my $object = $self->object;
  my $member = $object->get_compara_Member($cdb);

  return (undef, '<strong>Gene is not in the compara database</strong>') unless $member;

  # if whole tree or part of the tree is chosen from the config
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
  my $stable_id   = $hub->param('g');
  my $is_speciestree = $object->isa('EnsEMBL::Web::Object::SpeciesTree') ? 1 : 0;
  my $show_exons     = $hub->param('exons') eq 'on' ? 1 : 0; 
    
  my ($gene, $member, $tree, $node, $html);
 
  if ($is_speciestree) {
    $tree   = $object->Obj;
    $member = undef;
  } else {
    $gene = $object;
    ($member, $tree, $node) = $self->get_details($cdb);
  }
 
  my ($species, $object_type, $db_type) = Bio::EnsEMBL::Registry->get_species_and_object_type($stable_id);  #get corresponding species for current gene
  my $species_name = $hub->species_defs->get_config(ucfirst($species), 'SPECIES_SCIENTIFIC_NAME');

  my @highlights     = $species_name;
  return $tree if $hub->param('g') && !$is_speciestree && !defined $member;  
  
  my $leaves               = $tree->get_all_leaves;  
  my $image_config         = $hub->get_imageconfig('speciestreeview');
  
  my $image_width          = $hub->param('image_width') || $self->image_width || 800;
  my $colouring            = $hub->param('colouring') || 'background'; 

#add collapsability param in image config to get it in the drawing code    
  $image_config->set_parameters({
    container_width => $image_width,
    image_width     => $image_width,
    slice_number    => '1|1',
    cdb             => $cdb
  });
# code to have the background colours on the tree but not sure if this is applicable to the species tree as all the nodes are aligned  
#   my $coloured_nodes;
#   
#   if ($colouring =~ /^(back|fore)ground$/) {
#     my $mode   = $1 eq 'back' ? 'bg' : 'fg';
#     my @clades = grep { $_ =~ /^group_.+_${mode}colour/ } $hub->param;
# 
#     # Get all the genome_db_ids in each clade
#     my $genome_db_ids_by_clade;
#     
#     foreach my $clade (@clades) {
#       my ($clade_name) = $clade =~ /group_(.+)_${mode}colour/;
#       $genome_db_ids_by_clade->{$clade_name} = [ split '_', $hub->param("group_${clade_name}_genome_db_ids") ];
#     }
# 
#     # Sort the clades by the number of genome_db_ids. First the largest clades,
#     # so they can be overwritten later (see ensembl-draw/modules/Bio/EnsEMBL/GlyphSet/genetree.pm)
#     foreach my $clade_name (sort { scalar @{$genome_db_ids_by_clade->{$b}} <=> scalar @{$genome_db_ids_by_clade->{$a}} } keys %$genome_db_ids_by_clade) {
#       my $genome_db_ids = $genome_db_ids_by_clade->{$clade_name};
#       my $colour        = $hub->param("group_${clade_name}_${mode}colour") || 'magenta';          
#       
#       #Get node_ids in  nodes hash
#       #my $node_id = $tree->get_node_with_genome_db_id(134)->node_id();
#       #push @$coloured_nodes, { clade => $clade_name,  colour => $colour, mode => $mode, node_ids => $node_id};
#     }
#   }
  my $image = $self->new_image($tree, $image_config, \@highlights);

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