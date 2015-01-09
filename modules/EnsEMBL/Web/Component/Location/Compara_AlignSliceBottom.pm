=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::Compara_AlignSliceBottom;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Location EnsEMBL::Web::Component::Compara_Alignments);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $object       = $self->object;
  my $threshold    = 1000100 * ($species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $align_params = $hub->param('align');
  my %options      = ( scores => $hub->param('opt_conservation_scores'), constrained => $hub->param('opt_constrained_elements') );
  my ($align)      = split '--', $align_params;
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  return $self->_info('No alignment specified', '<p>Select the alignment you wish to display from the box above.</p>') unless $align;
  
  my $align_details = $species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'}->{$align};

  return $self->_error('Unknown alignment', '<p>The alignment you have selected does not exist in the current database.</p>') unless $align_details;
  
  my $primary_species = $hub->species;
  
  if (!exists $align_details->{'species'}->{$primary_species}) {
    return $self->_error('Unknown alignment', sprintf(
      '<p>%s is not part of the %s alignment in the database.</p>', 
      $species_defs->species_label($primary_species),
      encode_entities($align_details->{'name'})
    ));
  }
  
  my $image_width     = $self->image_width;
  my $slice           = $object->slice;
  my ($slices)        = $self->object->get_slices({
                                              'slice' => $slice, 
                                              'align' => $align_params, 
                                              'species' => $primary_species
                        });
  my %aligned_species = map { $_->{'name'} => 1 } @$slices;
  my $i               = 1;
  my (@images, $html);
  
  my ($caption_height,$caption_img_offset) = (0,-24);
  foreach (@$slices) {
    my $species      = $_->{'name'} eq 'Ancestral_sequences' ? 'Multi' : $_->{'name'}; # Cheating: set species to Multi to stop errors due to invalid species.
    my $image_config = $hub->get_imageconfig('alignsliceviewbottom', "alignsliceviewbottom_$i", $species);
    
    $image_config->set_parameters({
      container_width => $_->{'slice'}->length,
      image_width     => $image_width || 800, # hack at the moment
      slice_number    => "$i|3",
      compara         => $i == 1 ? 'primary' : 'secondary',
      more_slices     => $i != @$slices,
    });
    
    my ($species_name, $slice_name) = split ':', $_->{'name'};
    
    my $panel_caption = $species_defs->get_config($species_name, 'SPECIES_COMMON_NAME') || 'Ancestral sequences';
    $panel_caption   .= " $slice_name" if $slice_name;

    my $asb = $image_config->get_node('alignscalebar');
    $asb->set('caption', $panel_caption);
    $asb->set('caption_position', 'bottom');
    $asb->set('caption_img',"f:24\@$caption_img_offset:".$_->{'name'});
    $asb->set('caption_height',$caption_height);
    $caption_img_offset = -20;
    $caption_height = 28;

    foreach (grep $options{$_}, keys %options) {
      my $node = $image_config->get_node("alignment_compara_$align_details->{'id'}_$_");
      $node->set('display', $options{$_}) if $node;
    }
    
    push @images, $_->{'slice'}, $image_config;
    $i++;
  }
  
  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->{'panel_number'}  = 'bottom';
  $image->{'data_export'}   = 'Alignments';
  $image->{'export_params'}   = ['align'];
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  $html .= $image->render;

  my $alert_box = $self->check_for_align_problems({
                                'align'   => $align, 
                                'species' => $primary_species, 
                                'cdb'     => $hub->param('cdb') || 'compara',
                                });
  $html .=  $alert_box;
  
  return $html;
}

sub export_options { return {'action' => 'Alignments', 'caption' => 'Download alignment'}; }

sub get_export_data {
## Get data for export
  my $self      = shift;
  return $self->hub->core_object('location');
}

1;
