package EnsEMBL::Web::Component::Variation::Context;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}


sub content {
  my $self = shift;
  my $object = $self->object;
  
  ## first check we have uniquely determined variation
  unless ($object->core_objects->{'parameters'}{'vf'} ){
  my  $html = "<p>You must select a location from the panel above to see this information</p>";
   return $self->_info(
   'A unique location can not be determined for this Variation',
   $html
   );
  }

  my $width = $object->param('context') || "30000";

  # first determine correct SNP location 
  my %mappings = %{ $object->variation_feature_mapping }; 
  my $v;
  if( keys %mappings == 1 ) {
    ($v) = values %mappings;
  } else { 
    $v = $mappings{$object->param('vf')};
  }
  unless ($v) { 
    return $self->_info(
      '',
      "<p>Unable to draw SNP neighbourhood as we cannot uniquely determine the SNP's location</p>"
    );
  }

  my $seq_region = $v->{Chr};  
  my $start      = $v->{start};  
  my $seq_type   = $v->{type};  


  my $end   = $start + ($width/2);
     $start -= ($width/2);
  my $slice =
    $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $start, $end, 1
  );

  my $sliceObj = EnsEMBL::Web::Proxy::Object->new( 'Slice', $slice, $object->__data );

  my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures();
  my ($genotyped_count, $genotyped_snps) = $sliceObj->get_genotyped_VariationFeatures();

  my $wuc = $object->image_config_hash( 'snpview' ); 
 # $wuc->tree->dump("View Bottom configuration", '([[caption]])');
  $wuc->set_parameters( {
    'image_width' =>  $self->image_width || 900,
    'container_width' => $slice->length,
    'slice_number' => '1|1',
  });

  $wuc->{'snps'}           = $filtered_snps;
  $wuc->{'genotyped_snps'} = $genotyped_snps;
  $wuc->{'snp_counts'}     = [$count_snps+$genotyped_count, scalar @$filtered_snps+scalar @$genotyped_snps];

  ## If you want to resize this image
  my $image    = $self->new_image( $slice, $wuc, [$object->name] );
  return if $self->_export_image( $image );
  $image->imagemap = 'yes';
  $image->{'panel_number'} = 'transcript';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

 my $T = $image->render;
 return $T;
}


1;
