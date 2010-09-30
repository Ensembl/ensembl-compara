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
  
  return unless $object->param('pop1');
  
  my ($seq_region, $start, $end, $seq_type) = ($object->seq_region_name, $object->seq_region_start, $object->seq_region_end, $object->seq_region_type);

  my $slice_length = ($end - $start) + 1;
  
  if ($slice_length >= 100001) {
    my $html = "<p>The region you have selected is too large to display linkage data, a maximum region of 100kb is allowed. Please change the region using the navigation controls above.<p>";
    return $self->_error('Region too large', $html);
  }

  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $object->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH    = $object->species_defs->ENSEMBL_TMP_TMP;

  my $image_config_ldview = $object->get_imageconfig('ldview');
  my $slice               = $hub->database('core')->get_SliceAdaptor->fetch_by_region($seq_type, $seq_region, $start, $end, 1);
  my $ld_object           = $self->new_object('Slice', $slice, $object->__data);
  my $databases           = $hub->databases;
  my ($count_snps, $snps) = $ld_object->getVariationFeatures;
  my ($genotyped_count, $genotyped_snps) = $ld_object->get_genotyped_VariationFeatures;

  $image_config_ldview->set_parameters({ image_width => $self->image_width || 800 });
  $image_config_ldview->container_width($slice->length);
  $image_config_ldview->{'_databases'}     = $databases;
  $image_config_ldview->{'_add_labels'}    = 'true';
  $image_config_ldview->{'snps'}           = $snps;
  $image_config_ldview->{'genotyped_snps'} = $genotyped_snps;
  # Do images for first section
  my @containers_and_configs = ( $slice, $image_config_ldview );

  # Do images for each population
  foreach my $pop_name (sort { $a cmp $b } @{$object->current_pop_name}) {
    my $pop_obj = $object->pop_obj_from_name($pop_name);
    next unless $pop_obj->{$pop_name}; # i.e. skip name if not a valid pop name
   
    my $image_config_pop = $object->get_imageconfig('ld_population');
    
    $image_config_pop->set_parameters({ 
      image_width     => $self->image_width ||800,
      container_width => $slice->length,
    });
    
    $image_config_pop->{'_databases'}     = $databases;
    $image_config_pop->{'_add_labels'}    = 'true';
    $image_config_pop->{'_ld_population'} = [ $pop_name ];
    $image_config_pop->{'text'}           = $pop_name;
    $image_config_pop->{'snps'}           = $snps;
   
    push @containers_and_configs, $slice, $image_config_pop;
  }

  my $image = $self->new_image(
    [ @containers_and_configs ],
    $object->highlights,
  );
  
  return if $self->_export_image($image);
  $image->{'panel_number'} = 'top';
  $image->imagemap         = 'yes';
  $image->set_button('drag', 'title' => 'Drag to select region');

  return $image->render;
}
1;
