# $Id$

package EnsEMBL::Web::Component::LRG::TranslationImage;

use strict;

use base qw(EnsEMBL::Web::Component::LRG);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $transcript  = $self->get_lrg_transcript;
  my $translation = $transcript->translation_object;
  
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
  $image_config->cache('image_snps',   $transcript->variation_data);
  $image_config->cache('image_splice', $transcript->peptide_splice_sites);

  $image_config->tree->dump('Tree', '[[caption]]') if $species_defs->ENSEMBL_DEBUG_FLAGS & $species_defs->ENSEMBL_DEBUG_TREE_DUMPS;

  my $image = $self->new_image($peptide, $image_config, []);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->{'panel_number'} = 'translation';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  my $html = ($translation ? sprintf '<h2>Protein ID: %s</h2><h3>(Transcript ID: %s)</h3>', $translation->stable_id, $transcript->stable_id : '');
  
  return $html.$image->render;
}


sub get_lrg_transcript {
  my $self        = shift;
  my $param       = $self->hub->param('lrgt');
  my $transcripts = $self->builder->object->get_all_transcripts;
  if ($param && (grep $_->stable_id eq $param, @$transcripts)) {
    foreach my $tr (@$transcripts) {
      return $tr if ($tr->stable_id eq $param);
    }
  }
  else {
    return $transcripts->[0];
  }
}

1;
