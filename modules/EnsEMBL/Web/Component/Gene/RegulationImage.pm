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

package EnsEMBL::Web::Component::Gene::RegulationImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->has_image(1);
}

sub content {
  my $self = shift;
  my $object = $self->object || $self->hub->core_object('gene');
  my $extended_slice = $object->get_extended_reg_region_slice;

  my $wuc = $object->get_imageconfig( 'generegview' );
  $wuc->set_parameters({
    'container_width'   => $extended_slice->length,
    'image_width',      => $self->image_width || 800,
  });

  ## Turn gene display on....
  my $key = $wuc->get_track_key( 'transcript', $object );
  $wuc->modify_configs( [$key], {qw(display collapsed_label)} );

  if ( $self->hub->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    $wuc->{'data_by_cell_line'} = $self->new_object('Slice', $extended_slice, $object->__data)->get_cell_line_data($wuc) if keys %{$self->hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'}};
  }

  my $image    = $self->new_image( $extended_slice, $wuc, [] );
  $image->imagemap           = 'yes';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

  return $image->render;
}
1;
