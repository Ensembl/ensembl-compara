# $Id$

package EnsEMBL::Web::Component::Location::LDImage;

use strict;

use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  
  return unless $hub->param('pop1');
  
  my $slice = $object->slice;
  
  if ($slice->length >= 100000) {
    return $self->_error(
      'Region too large', 
      '<p>The region you have selected is too large to display linkage data, a maximum region of 100kb is allowed. Please change the region using the navigation controls above.<p>'
    );
  }
  
  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $hub->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH    = $hub->species_defs->ENSEMBL_TMP_TMP;
  
  my $image_config = $hub->get_imageconfig('ldview');
  my $parameters   = { 
    image_width     => $self->image_width || 800, 
    container_width => $slice->length
  };
  
  $image_config->init_slice($parameters);
  
  # Do images for first section
  my $containers_and_configs = [ $slice, $image_config ];

  # Do images for each population
  foreach my $pop_name (sort { $a cmp $b } @{$object->current_pop_name}) {
    next unless $object->pop_obj_from_name($pop_name)->{$pop_name}; # skip if not a valid population name
   
    my $population_image_config = $hub->get_imageconfig('ldview', $pop_name);
    $population_image_config->init_population($parameters, $pop_name);
    push @$containers_and_configs, $slice, $population_image_config;
  }

  my $image = $self->new_image($containers_and_configs, $object->highlights);
  
  return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'top';
  $image->imagemap         = 'yes';
  $image->set_button('drag', 'title' => 'Drag to select region');

  return $image->render;
}

1;
