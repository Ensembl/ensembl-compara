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

package EnsEMBL::Web::Component::Regulation::FeatureSummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Regulation);


sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self = shift;
  my $object = $self->object || $self->hub->core_object('regulation');

  $self->cell_line_button('reg_summary');

  my $object_slice = $object->get_context_slice(25000);
     $object_slice = $object_slice->invert if $object_slice->strand < 1; 


  my $fsets = $object->get_feature_sets;

  my $wuc = $object->get_imageconfig( 'reg_summary' ); 
  $wuc->cache( 'feature_sets', $fsets);

  $wuc->set_parameters({
    'container_width'   => $object_slice->length,
    'image_width',      => $self->image_width || 800,
    'slice_number',     => '1|1',
  });

  $wuc->{'data_by_cell_line'} = $self->new_object('Slice', $object_slice, $object->__data)->get_cell_line_data($wuc);

  my $image    = $self->new_image( $object_slice, $wuc, [$object->stable_id] );
      $image->imagemap           = 'yes';
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

  return $image->render;
}

1;
