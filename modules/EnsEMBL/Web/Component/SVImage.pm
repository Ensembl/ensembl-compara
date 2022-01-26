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

package EnsEMBL::Web::Component::SVImage;

use strict;

use base qw(EnsEMBL::Web::Component::Shared);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object || $hub->core_object(lc($hub->param('data_type')));
  my $slice  = $object->slice;

  my $im_cfg = 'gene_sv_view';

  if ($object->isa('EnsEMBL::Web::Object::LRG')) {
    $im_cfg = 'lrg_sv_view';
  } else {
    $slice  = $slice->invert if $object->seq_region_strand < 0;
  }
     
  # Get the web_image_config
  my $image_config = $object->get_imageconfig($im_cfg);
  
  $image_config->set_parameters({
    container_width => $slice->length,
    image_width     => $object->param('image_width') || $self->image_width || 800,
    slice_number    => '1|1',
  });
  
  # Transcript track
  my $key  = $image_config->get_track_key('transcript', $object);
  my $node = $image_config->get_node(lc $key);
  $node->set('display', 'transcript_label') if $node && $node->get('display') eq 'off';

  my $image = $self->new_image($slice, $image_config, [ $object->stable_id ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  return $image->render;
}

1;
