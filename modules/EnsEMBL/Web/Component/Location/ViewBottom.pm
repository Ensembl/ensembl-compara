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

package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->configurable(1);
  $self->has_image(1);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object || $hub->core_object('location');
  my $threshold   = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $image_width = $self->image_width;
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  
  my $slice        = $object->slice;
  my $length       = $slice->end - $slice->start + 1;
  my $image_config = $hub->get_imageconfig('contigviewbottom');
  
  $image_config->set_parameters({
    container_width => $length,
    image_width     => $image_width || 800, # hack at the moment
    slice_number    => '1|3'
  });

  ## Force display of individual low-weight markers on pages linked to from Location/Marker
  if (my $marker_id = $hub->param('m')) {
    $image_config->modify_configs(
      [ 'marker' ],
      { marker_id => $marker_id }
    );
  }

  # Add multicell configuration
  if ( $hub->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    $image_config->{'data_by_cell_line'} = $self->new_object('Slice', $slice, $object->__data)->get_cell_line_data_closure($image_config) if keys %{$hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'}};
  }
  $image_config->_update_missing($object);

  my $info  = $self->_add_object_track($image_config);
  my $image = $self->new_image($slice, $image_config, $object->highlights);
  
	return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'bottom';
  $image->imagemap         = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  return $info . $image->render;
}

sub _add_object_track {
  my ($self, $image_config) = @_;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $extra;
  
  # Add track for gene if not on by default
  if (my $gene = $hub->core_object('gene')) {
    my $key  = $image_config->get_track_key('transcript', $gene);
    my $node = $image_config->get_node(lc $key);
 
    if ($node) {
      my $current = $node->get('display');
      my $default = $node->data->{'display'};
      
      if ($current eq 'off' && $default eq 'off') {
        my $flag = $session->get_record_data({type => 'auto_add', code => lc $key})->{'flag'};
        
        if (!$flag) { # haven't done this before
          $image_config->update_track_renderer(lc $key, 'transcript_label');
          $session->set_record_data({type => 'auto_add' , code => lc $key, flag => 1});

          $extra = $self->_info('Information', '<p>The track containing the highlighted gene has been added to your display.</p>');
        }
      }
    }
  }
  
  return $extra;
}

1;
