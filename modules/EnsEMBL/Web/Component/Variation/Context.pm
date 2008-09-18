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
  
  ## first check we have a location
  unless ($object->core_objects->location ){
   my  $html = "<p>You must select a location from the panel above to see this information</p>";
   return $html;
  }


  my $width = $object->param('w') || "30000";

  # first determine correct SNP location 
  my %mappings = %{ $object->variation_feature_mapping };
  my $location = $object->core_objects->{'parameters'}{'vl'};
  my ($seq_region, $start, $seq_type);

  foreach my $varif_id (keys %mappings) {
    ## Check vari feature matches the location we are intrested in
    my $seq_reg = $mappings{$varif_id}{Chr};
    my $st  = $mappings{$varif_id}{start};
    my $end    = $mappings{$varif_id}{end};
    my $v_loc  = $seq_reg.":".$st;
    my $type =  $mappings{$varif_id}{region_type};
 
    if  ($v_loc eq $location){
      $seq_region = $seq_reg;
      $start = $st;
      $seq_type = $type; 
    } else { next;}
  
         
  }

  unless ($seq_region) { 
  my $html = "<p>Unable to draw SNP neighbourhood as we cannot uniquely determine the SNP's location</p>";
  return $html; 
  }

  my $end   = $start + ($width/2);
  $start -= ($width/2);
  my $slice =
    $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $start, $end, 1
  );

  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $slice, $object->__data
       );

  my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures();
  my ($genotyped_count, $genotyped_snps) = $sliceObj->get_genotyped_VariationFeatures();

  my $wuc = $object->image_config_hash( 'snpview' );
  $wuc->set( '_settings', 'width', $object->param('image_width') );
  $wuc->{'snps'}           = $filtered_snps;
  $wuc->{'genotyped_snps'} = $genotyped_snps;
  $wuc->{'snp_counts'}     = [$count_snps+$genotyped_count, scalar @$filtered_snps+scalar @$genotyped_snps];

  ## If you want to resize this image
  my $image    = $object->new_image( $slice, $wuc, [$object->name] );
  $image->imagemap = 'yes';

 my $T = $image->render;
 return $T;
}


1;
