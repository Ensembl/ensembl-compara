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

package EnsEMBL::Web::Component::Location::Region;

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self         = shift;
  my $object       = $self->object || $self->hub->core_object('location');
  my $slice        = $object->slice;
  my $length       = $slice->end - $slice->start + 1;
  my $image_config = $object->get_imageconfig('cytoview');
  
  $image_config->set_parameters({
    container_width => $length,
    image_width     => $self->image_width || 800,
    slice_number    => '1|2'
  });

  $image_config->modify_configs(
    [ 'user_data' ],
    { strand => 'r' }
  );
  
  $image_config->_update_missing($object);
  
  my $image = $self->new_image($slice, $image_config, $object->highlights);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');

  return $image->render;
}

1;
