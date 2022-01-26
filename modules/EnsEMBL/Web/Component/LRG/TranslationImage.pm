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
  my $object      = $self->object || $self->hub->core_object('lrg');
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

  my $image = $self->new_image($peptide, $image_config, []);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->{'panel_number'} = 'translation';
  $image->set_button('drag', 'title' => 'Drag to select region'); 

  my $external_name = $transcript->Obj->external_name;
  my $display_id = ($external_name && $external_name ne '') ? $external_name : $transcript->Obj->stable_id;

  return sprintf '<h2>Protein ID: %s</h2><h3>(Transcript ID: %s)</h3>%s', $peptide->display_id, $display_id, $image->render;
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
