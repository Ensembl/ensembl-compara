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

package EnsEMBL::Web::Component::Location::Ideogram;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->has_image(1);
}

sub content {
  my $self = shift;
  
  my $object = $self->object || $self->hub->core_object('location');
  my $slice  = $object->database('core')->get_SliceAdaptor->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  
  my $image_config = $object->get_imageconfig('chromosome');
  $image_config->container_width($object->seq_region_length);

  my $image = $self->new_image($slice, $image_config);
  
  return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'ideogram';
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');

  return '<p>.</p>' . $image->render;

}

1;
