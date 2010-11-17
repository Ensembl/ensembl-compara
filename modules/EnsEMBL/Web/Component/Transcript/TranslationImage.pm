# $Id$

package EnsEMBL::Web::Component::Transcript::TranslationImage;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $translation = $object->translation_object;
  
  return $self->non_coding_error unless $translation;

  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $image_config = $hub->get_imageconfig('protview');
  my $peptide      = $translation->Obj;
  
  $image_config->set_parameters({
     container_width => $peptide->length,
     image_width     => $self->image_width || 800,
     slice_number    => '1|1'
  });
  
  $image_config->cache('object',       $translation);
  $image_config->cache('image_snps',   $object->variation_data);
  $image_config->cache('image_splice', $object->peptide_splice_sites);

  $image_config->tree->dump('Tree', '[[caption]]') if $species_defs->ENSEMBL_DEBUG_FLAGS & $species_defs->ENSEMBL_DEBUG_TREE_DUMPS;

  my $image = $self->new_image($peptide, $image_config, []);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->{'panel_number'} = 'translation';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  return $image->render;
}

1;
