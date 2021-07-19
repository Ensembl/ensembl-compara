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

package EnsEMBL::Web::Component::Gene::TranscriptsImage;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init { 
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub caption {
  return 'Transcripts';
}

sub content {
  my $self   = shift;
  my $object = $self->object || $self->hub->core_object('gene');
  my $gene   = $object->Obj;
  
  my $gene_slice = $gene->feature_Slice->expand(10e3, 10e3);
     $gene_slice = $gene_slice->invert if $object->seq_region_strand < 0;
     
  # Get the web_image_config
  my $image_config = $object->get_imageconfig('gene_summary');
  
  $image_config->set_parameters({
    container_width => $gene_slice->length,
    image_width     => $object->param('image_width') || $self->image_width || 800,
    slice_number    => '1|1',
  });

  my $key  = $image_config->get_track_key('transcript', $object);
  my $node = $image_config->get_node(lc $key);
  
  $node->set('display', 'transcript_label') if $node && $node->get('display') eq 'off';

  if ( $self->hub->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    $image_config->{'data_by_cell_line'} = $self->new_object('Slice', $gene_slice, $object->__data)->get_cell_line_data_closure($image_config) if keys %{$self->hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'}};
  }

  my $image = $self->new_image($gene_slice, $image_config, [ $gene->stable_id ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  return $image->render . $self->_info(
    'Configuring the display',
    '<p>Tip: use the "<strong>Configure this page</strong>" link on the left to show additional data in this region.</p>'
  );
}

1;
