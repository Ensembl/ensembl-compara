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

package EnsEMBL::Web::Component::LRG::TranscriptsImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::LRG);

sub _init { 
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub caption { return 'Transcripts'; }

sub content {
  my $self         = shift;
  my $object       = $self->object || $self->hub->core_object('lrg');
  my $slice        = $object->Obj;
  my $gene         = $object->gene;
  my $image_config = $object->get_imageconfig('lrg_summary');
  
  $image_config->set_parameters({
    container_width => $slice->length,
    image_width     => $self->image_width || 800,
    slice_number    => '1|1'
  });
  
  my $image = $self->new_image($slice, $image_config, [ $gene->stable_id ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');

  my $html = $self->_info(
    'LRG image',
    '<p>The image below displays LRG transcripts and the features overlapping <b>'.$gene->display_id.'</b>.</p>'
  );
  $html .= $image->render;
  $html .= $self->_info(
    'Configuring the display',
    '<p>Tip: use the "<strong>Configure this page</strong>" link on the left to show additional data in this region.</p>'
  );
  
  return $html;
}

1;
