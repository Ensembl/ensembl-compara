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

package EnsEMBL::Web::Component::Location::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

my %SHORT = qw(
  chromosome Chr.
  supercontig S'ctg
);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable($self->hub->action ne 'Genome');
  $self->has_image(1);
}

sub content {
  my $self = shift;
  
  return if $self->hub->action eq 'Genome';
  
  my $object = $self->object || $self->hub->core_object('location');
  my $slice  = $object->database('core')->get_SliceAdaptor->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  
  my $image_config = $object->get_imageconfig('chromosome');
  
  $image_config->set_parameters({
    container_width => $object->seq_region_length,
    image_width     => $self->image_width,
    slice_number    => '1|1'
  });

  if ($image_config->get_node('annotation_status')) {
    $image_config->get_node('annotation_status')->set('caption', '');
    $image_config->get_node('annotation_status')->set('menu', 'no');
  };

  my $caption = $object->seq_region_type . ' ' . $object->seq_region_name;
  if(length($caption) > 12 and $SHORT{$object->seq_region_type}) {
    $caption = $SHORT{$object->seq_region_type}.' '.$object->seq_region_name;
  }
  $image_config->get_node('ideogram')->set('caption', $caption);
  
  my $image = $self->new_image($slice, $image_config);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->{'panel_number'} = 'context';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  return $image->render;
}

1;
