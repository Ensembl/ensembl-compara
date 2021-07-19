=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::SpeciesTree;

use strict;

use Bio::EnsEMBL::Registry;

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
  
  my $object = shift || $self->object || $self->hub->core_object('gene');
  my $member = $object->get_compara_Member($cdb);

  return (undef, '<strong>Gene is not in the compara database</strong>') unless $member;

  # if whole tree or part of the tree is chosen from the config
  my $tree = $object->get_SpeciesTree($cdb);

  return (undef, '<strong>Gene is not in a compara tree</strong>') unless $tree;

  my $node = $tree->root->get_all_nodes;
  return (undef, '<strong>Gene is not in the compara tree</strong>') unless $node;
  
  return ($member, $tree, $node);
}

sub content {
  my $self        = shift;
  my $cdb         = shift || 'compara';
  my $hub         = $self->hub;
  my $object      = $self->object || $self->hub->core_object('gene');
  my $stable_id   = $hub->param('g');

  my $is_speciestree = $object->isa('EnsEMBL::Web::Object::SpeciesTree') ? 1 : 0;
    
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
  
  my $leaves               = $tree->root->get_all_leaves;  
  my $image_config         = $hub->get_imageconfig('speciestreeview');
  
  my $image_width          = $self->image_width || 800;
  my $colouring            = $hub->param('colouring') || 'background'; 

#add collapsability param in image config to get it in the drawing code    
  $image_config->set_parameters({
    container_width => $image_width,
    image_width     => $image_width,
    slice_number    => '1|1',
    cdb             => $cdb
  });

  my $image = $self->new_image($tree->root, $image_config, \@highlights);

  return $html if $self->_export_image($image, 'no_text');

  my $image_id = $gene->stable_id;
  
  $image->image_type       = 'genetree';
  $image->image_name       = ($hub->param('image_width')) . "-$image_id";
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'tree';
  $image->set_button('drag', 'title' => 'Drag to select region');

  ## Need to pass gene name to export form 
  my $gene_name;
  if ($gene) {
    my $dxr    = $gene->Obj->can('display_xref') ? $gene->Obj->display_xref : undef;
    $gene_name = $dxr ? $dxr->display_id : $gene->stable_id;
  }
  else {
    $gene_name = $tree->tree->stable_id;
  }
  $image->{'export_params'} = [['gene_name', $gene_name],['align', 'tree']];
  $image->{'data_export'}   = 'SpeciesTree';
  
  $html .= $image->render;
  
  return $html;
}

sub export_options { return {'action' => 'SpeciesTree'}; }

sub get_export_data {
## Get data for export
  my ($self, $type) = @_;
  my $cdb       = $self->hub->param('cdb') || 'compara';
  my $gene      = $self->hub->core_object('gene');
  my ($member, $tree) = $self->get_details($cdb, $gene);
  return $tree;
}

1;
