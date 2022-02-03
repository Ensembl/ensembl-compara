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

package EnsEMBL::Web::Component::Location::Compara_AlignSliceBottom;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Location EnsEMBL::Web::Component::Compara_Alignments);

sub _init {
  my $self = shift;
  my $hub = $self->hub;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
  # Getting alignments_selector data from sessions;
  my $alignments_session_data = $hub->session ? $hub->session->get_record_data({'type' => 'view_config', 'code' => 'alignments_selector'}) : {};
  %{$self->{'viewconfig'}{'Location'}{_user_settings}} = (%{$self->{'viewconfig'}{'Location'}{_user_settings}||{}}, %{$alignments_session_data||{}});
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $object       = $self->object || $self->hub->core_object('location');
  my $threshold    = 1000100 * ($species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $align_params = $hub->get_alignment_id || '';
  my %options      = ( scores => $self->param('opt_conservation_scores'), constrained => $self->param('opt_constrained_elements') );
  my ($align)      = split '--', $align_params;

  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  return $self->_info('No alignment specified', '<p>Select the alignment you wish to display from the box above.</p>') unless $align;

  my $align_details = $species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'}->{$align};

  return $self->_error('Unknown alignment', '<p>The alignment you have selected does not exist in the current database.</p>') unless $align_details;

  my $primary_species = $hub->species;
  my $prodname = $species_defs->SPECIES_PRODUCTION_NAME;

  if (!exists $align_details->{'species'}->{$prodname}) {
    return $self->_error('Unknown alignment', sprintf(
        '<p>%s is not part of the %s alignment in the database.</p>', 
      $species_defs->species_label($primary_species),
      encode_entities($align_details->{'name'})
    ));
  }
  
  my $image_width     = $self->image_width;
  my $slice           = $object->slice;
  my %export_params   = $hub->param('data_type') ? ('data_type' => $hub->param('data_type'), 'component' => $hub->param('data_action'))
                                                 : ();
  my ($slices)        = $object->get_slices({
                                              'slice' => $slice, 
                                              'align' => $align_params, 
                                              'species' => $primary_species,
                                              %export_params
                        });
  my %aligned_species = map { $_->{'name'} => 1 } @$slices;
  my $i               = 1;
  my (@images, $html);
  
  my ($caption_height,$caption_img_offset) = (0,-24);
  my $lookup = $species_defs->prodnames_to_urls_lookup;
  foreach (@$slices) {
    my ($species_name, $slice_name) = split ':', $_->{'name'};
    my $species       = $lookup->{$species_name};

    my $species_url   = $species eq 'Ancestral_sequences' ? 'Multi' : $species; # Cheating: set species to Multi to stop errors due to invalid species.
    my $image_config  = $hub->get_imageconfig({'type' => 'alignsliceviewbottom', 'cache_code' => "alignsliceviewbottom_$i", 'species' => $species_url});
    
    $image_config->set_parameters({
      container_width => $_->{'slice'}->length,
      image_width     => $image_width || 800, # hack at the moment
      slice_number    => "$i|3",
      compara         => $i == 1 ? 'primary' : 'secondary',
      more_slices     => $i != @$slices,
    });
    
    my $panel_caption = $species_defs->get_config($species, 'SPECIES_DISPLAY_NAME') || 'Ancestral sequences';
    $panel_caption   .= " $slice_name" if $slice_name;

    my $asb = $image_config->get_node('alignscalebar');
    $asb->set_data('caption', $panel_caption);
    $asb->set_data('caption_position', 'bottom');
    $asb->set_data('caption_img',"f:24\@$caption_img_offset:".$species_defs->get_config($species, 'SPECIES_IMAGE'));
    $asb->set_data('caption_height',$caption_height);
    $caption_img_offset = -20;
    $caption_height = 28;

    foreach (grep $options{$_}, keys %options) {
      my $node = $image_config->get_node("alignment_compara_$align_details->{'id'}_$_");
      $node->set_data('display', $options{$_}) if $node;
    }
    
    push @images, $_->{'slice'}, $image_config;
    $i++;
  }
  
  my $image = $self->new_image(\@images);
  $image->{'export_params'} = [['align', $align]];

  return if $self->_export_image($image);
  
  $image->{'panel_number'}  = 'bottom';
  $image->{'data_export'}   = 'Alignments';
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  $html .= $image->render;

  my ($alert_box, $error) = $self->check_for_align_problems({
                                'align'   => $align, 
                                'species' => $prodname, 
                                'cdb'     => $self->param('cdb') || 'compara',
                                'ignore'  => 'ancestral_sequences',
                                });

  return $alert_box if $error;

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
