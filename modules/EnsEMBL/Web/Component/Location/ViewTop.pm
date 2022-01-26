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

package EnsEMBL::Web::Component::Location::ViewTop;

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object || $hub->core_object('location');

  return if $self->param('show_panel') eq 'no';
  
  my $flanking     = $self->param('flanking');
  my $flank_length = $flanking ? $object->length + (2 * $flanking) : 0;
  my $image_config = $hub->get_imageconfig('contigviewtop');
  my $threshold    = $image_config->get_parameter('min_size');
  my ($seq_region_type, $seq_region_name, $seq_region_length) = map $object->$_, qw(seq_region_type seq_region_name seq_region_length);
  my $slice;
  
  if ($object->length > $threshold) {
    $slice = $object->slice;
  } elsif ($flanking && $flank_length <= $threshold && $flank_length <= $seq_region_length) {
    $slice = $object->slice->expand($flanking, $flanking);
  } elsif ($seq_region_length < $threshold) {
    $slice = $hub->database('core')->get_SliceAdaptor->fetch_by_region($seq_region_type, $seq_region_name, 1, $seq_region_length, 1);
  } else {
    my $c = int $object->centrepoint;
    my $s = ($c - $threshold/2) + 1;
       $s = 1 if $s < 1;
    my $e = $s + $threshold - 1;
    
    if ($e > $seq_region_length) {
      $e = $seq_region_length;
      $s = $e - $threshold + 1;
    }
    
    $slice = $hub->database('core')->get_SliceAdaptor->fetch_by_region($seq_region_type, $seq_region_name, $s, $e, 1);
  }
  
  $image_config->set_parameters({
    container_width => $slice->end - $slice->start + 1,
    image_width     => $self->image_width,
    slice_number    => '1|2'
  });
  
  my $s_o = $self->new_object('Location', {
    seq_region_name   => $slice->seq_region_name,
    seq_region_type   => $slice->coord_system->name,
    seq_region_start  => $slice->start,
    seq_region_end    => $slice->end,
    seq_region_strand => $slice->strand
  }, $object->__data);
  
  $image_config->_update_missing($s_o);

  if ($image_config->get_node('annotation_status')) {
    $image_config->get_node('annotation_status')->set('caption', '');
    $image_config->get_node('annotation_status')->set('menu', 'no');
  };

  ## Force display of individual low-weight markers on pages linked to from Location/Marker
  if (my $marker_id = $hub->param('m')) {
    $image_config->modify_configs(
      [ 'marker' ],
      { marker_id => $marker_id }
    );
  }
  
  my $image = $self->new_image($slice, $image_config, $object->highlights);
  
  return if $self->_export_image($image);
 
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  return $image->render . ($flanking && $flanking * 2 < $threshold ? '<span class="hash_change_reload"></span>' : '');
}

1;
