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

package EnsEMBL::Web::Component::Transcript::TranscriptImage;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self         = shift;
  my $object       = $self->object || $self->hub->core_object('transcript');
  my $transcript   = $object->Obj;
  my $slice        = $transcript->feature_Slice;
     $slice        = $slice->invert if $slice->strand < 1; ## Put back onto correct strand
  my $image_config = $object->get_imageconfig('single_transcript');
  
  $image_config->set_parameters({
    container_width => $slice->length,
    image_width     => $self->image_width || 800,
    slice_number    => '1|1',
  });

  ## Now we need to turn on the transcript we wish to draw

  my $key  = $image_config->get_track_key('transcript', $object);
  my $node = $image_config->get_node($key) || $image_config->get_node(lc $key);
  if (!$node) {
    warn ">>> NO NODE FOR KEY $key";
    return "<p>Cannot display image for this transcript</p>";
  }
  
  $node->set('display', 'transcript_label') if $node->get('display') eq 'off';
  $node->set('show_labels', 'off');

  ## Show the ruler only on the same strand as the transcript
  $image_config->modify_configs(
    [ 'ruler' ],
    { 'strand', $transcript->strand > 0 ? 'f' : 'r' }
  );

  $image_config->set_parameter('single_Transcript' => $transcript->stable_id);
  $image_config->set_parameter('single_Gene'       => $object->gene->stable_id) if $object->gene;

  my $image = $self->new_image($slice, $image_config, []);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'transcript';
  $image->set_button('drag', 'title' => 'Drag to select region');

  return $image->render;
}

1;

