=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Regulation::FeatureDetails;

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
  my ($html, $Configs);

  my $context      = $self->param( 'context' ) || 200; 
  my $object_slice = $object->get_bound_context_slice($context);
     $object_slice = $object_slice->invert if $object_slice->strand < 1;

  my $wuc = $object->get_imageconfig( 'reg_summary_page' );
  $wuc->set_parameters({
    'container_width'   => $object_slice->length,
    'image_width',      => $self->image_width || 800,
    'slice_number',     => '1|1',
    'opt_highlight'     => $self->param('opt_highlight') || 0,
  });

  my $image    = $self->new_image( $object_slice, $wuc,[$object->stable_id] );
      $image->imagemap           = 'yes';
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

  $html .= $image->render;

  ## Now that we have so many cell lines, it's quicker to show activity in a table
  $html .= '<h3>Epigenomic activity</h3>';
  my $table = $self->new_table;
  my @rows;

  $table->add_columns(
                      {'key' => 'epigenome',  'title' => 'Epigenome', 'width' => '50%'},
                      {'key' => 'activity',   'title' => 'Activity',  'width' => '50%'},
                      );

  foreach (@{$object->all_epigenomes}) {
    my ($name, $id) = split(':', $_);
    push @rows, {
                'epigenome' => $name,
                'activity'  => $object->activity($name) || '-',
                };
  }

  if (scalar @rows) {
    $table->add_rows(@rows);
    $html .= $table->render;
  }
  else {
    $html .= '<p>No epigenomic data available for this feature.</p>';
  }
  return $html;
}

1;
