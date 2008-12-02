package EnsEMBL::Web::Component::Location::LDImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use EnsEMBL::Web::Factory::SNP;
use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  my $object = $self->object;
  my ($seq_region, $start, $end, $seq_type ) = ($object->seq_region_name, $object->seq_region_start, $object->seq_region_end, $object->seq_region_type);

  my $caption = "Context " . $seq_type ." ". $seq_region ." ". $start;
  return;
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my ($seq_region, $start, $end, $seq_type ) = ($object->seq_region_name, $object->seq_region_start, $object->seq_region_end, $object->seq_region_type);

  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $object->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH = $object->species_defs->ENSEMBL_TMP_TMP;

  my $wuc_ldview = $object->get_imageconfig( 'ldview' );
  my $context = $wuc_ldview->get_parameter('context');
  my $var_length = ($end -$start) +1;           
  my $offset = ($context - $var_length) /2; 
  my $r_start = $start - $offset;
  my $r_end = $end + $offset;
  my $slice =
    $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $r_start, $r_end, 1
  );
   
 
  my $ld_object = EnsEMBL::Web::Proxy::Object->new( 'Slice', $slice, $object->__data );
   
#  my ($count_snps, $snps) = $object->getVariationsOnSlice();
#  my ($genotyped_count, $genotyped_snps) = $object->get_genotyped_VariationsOnSlice();
  my ($count_snps, $snps) = $ld_object->getVariationFeatures();
  my ($genotyped_count, $genotyped_snps) = $ld_object->get_genotyped_VariationFeatures();

  $wuc_ldview->set_parameters({ 'image_width' =>  $self->image_width || 800 });
  $wuc_ldview->container_width($slice->length);
  $wuc_ldview->{'_databases'}     = $object->DBConnection;
  $wuc_ldview->{'_add_labels'}    = 'true';
  $wuc_ldview->{'snps'}           = $snps;
  $wuc_ldview->{'genotyped_snps'} = $genotyped_snps;


  # Do images for first section
  my @containers_and_configs = ( $slice, $wuc_ldview );

  # Do images for each population
  foreach my $pop_name ( sort { $a cmp $b } @{ $object->current_pop_name } ) {
    my $pop_obj = $object->pop_obj_from_name($pop_name);
    next unless $pop_obj->{$pop_name}; # i.e. skip name if not a valid pop name
   
    #my $wuc_pop = $object->get_imageconfig( "LD_population_$pop_name", 'LD_population' );
    my $wuc_pop = $object->get_imageconfig( 'ld_population' );
    $wuc_pop->set_parameters({ 
      'image_width'     => $self->image_width ||800,
      'container_width' => $slice->length,
     });
    $wuc_pop->{'_databases'}     = $object->DBConnection;
    $wuc_pop->{'_add_labels'}    = 'true';
    $wuc_pop->{'_ld_population'} = [$pop_name];
    $wuc_pop->{'text'} = $pop_name;
    $wuc_pop->{'snps'} = $snps;
   
    push @containers_and_configs, $slice, $wuc_pop;
  }

  my $image    = $object->new_image([ @containers_and_configs, ],
             $object->highlights, );
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

  return $image->render;
}
1;
