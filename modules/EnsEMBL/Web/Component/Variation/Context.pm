package EnsEMBL::Web::Component::Variation::Context;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}


sub content {
  my $self = shift;
  my $object = $self->object;
  
  ## first check we have a location
  if ( $object->not_unique_location ){
    return $self->_info(
      'A unique location can not be determined for this Variation',
      $object->not_unique_location
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

  my $sliceObj = $self->new_object( 'Slice', $slice, $object->__data );

  my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures();
  my ($genotyped_count, $genotyped_snps) = $sliceObj->get_genotyped_VariationFeatures();

  my $wuc = $object->get_imageconfig( 'snpview' ); 
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

 #my $T = $image->render;
 
 my $html;
 $html .= $image->render;
 
 my $var_slice =
    $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $v->{start}, $v->{end}, 1
  );
 
 $html .= '<h2>Overlapping features</h2>';
 
 # structural variation table
 $html .= '<h3>Structural variations</h3>';
 $html .= $self->structural_variation_table($var_slice);
 
 # regulatory region table
 $html .= '<h3>Regulatory features</h3>';
 $html .= $self->regulatory_feature_table($var_slice);
 
 # constrained elements table
 $html .= '<h3>Constrained elements</h3>';
 $html .= $self->constrained_element_table($var_slice);
 
 return $html;
}

sub structural_variation_table{
  my $self = shift;
  my $slice = shift;
  
  my $object = $self->object;
  
  my $svs = $slice->get_all_StructuralVariations();
 
  my $columns = [
     { key => 'id', sort => 'string', title => "Name" },
     { key => 'location', sort => 'position_html', title => 'Chr:bp' },
     { key => 'class', sort => 'string', title => 'Class' },
     { key => 'source', sort => 'string', title => 'Source' },
     { key => 'description', sort => 'string', title => 'Source description', width => "40%" },
  ];
   
  my $rows;
   
  if(defined($svs)) {
    foreach my $sv(@$svs) {
      
      # make PMID link for description
      my $description = $sv->source_description;
      my $pubmed_link;
      
      if ($description =~/PMID/) {
        my @description_string = split (':', $description);
        my $pubmed_id = pop @description_string;
        $pubmed_id =~ s/\s+.+//g;
        $pubmed_link = $object->get_ExtURL('PUBMED', $pubmed_id);
        
        $description =~ s/$pubmed_id/'<a href="'.$pubmed_link.'" target="_blank">'.$&.'<\/a>'/eg;
      }
      
      my $loc_string = $sv->seq_region_name.":".$sv->seq_region_start."-".$sv->seq_region_end;
        
      my $loc_link = $object->_url({
        type => 'Location',
        action => 'View',
        r => $loc_string,
        v => $object->name,
      });
      
      my %row = (
        'id' => $sv->variation_name,
        'location' => '<a href="'.$loc_link.'">'.$loc_string.'</a>',
        'class' => $sv->class,
        'source' => $sv->source,
        'description' => $description,
      );
      
      push @$rows, \%row;
    }
  }
   
  return new EnsEMBL::Web::Document::SpreadSheet($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
}

sub regulatory_feature_table{
  my $self = shift;
  my $slice = shift;
  
  my $object = $self->object;
  
  my $columns = [
    { key => 'id', sort => 'string', title => "Name" },
    { key => 'location', sort => 'position_html', title => 'Chr:bp' },
    { key => 'bound', sort => 'numerical', title => 'Bound coordinates'},
    { key => 'type', sort => 'string', title => 'Type' },
    { key => 'featureset', sort => 'string', title => 'Feature set' },
  ];
  
  my $rows;
  
  my $fsa = $object->get_adaptor('get_FeatureSetAdaptor','funcgen');
  
  # get image config
  my $wuc = $object->get_imageconfig( 'snpview' );
  
  if(defined($fsa)) {
    foreach my $set(@{$fsa->fetch_all_by_feature_class('regulatory')}) {
      
      my $set_name = (split /\s+/, $set->display_label)[-1];
      
      # check if this feature set is switched on in the image config
      if(defined($wuc->get_node('functional')->get_node('reg_feats_'.$set_name))) {
         if($wuc->get_node('functional')->get_node('reg_feats_'.$set_name)->get('display') eq 'normal') {
        
          foreach my $rf(@{$set->get_Features_by_Slice($slice)}) {
            my $rf_link = $object->_url({
              type => 'Regulation',
              action => 'Summary',
              fdb     => 'funcgen',
              r      => undef,
              rf      => $rf->stable_id,
              v      => $object->name
            });
            
            my $loc_string = $rf->seq_region_name.":".($slice->start+$rf->bound_start-1).'-'.($slice->start+$rf->bound_end-1);
            
            my $loc_link = $object->_url({
              type => 'Location',
              action => 'View',
              r => $loc_string,
              v => $object->name,
            });
            
            my %row = (
              'id' => '<a href="'.$rf_link.'">'.$rf->stable_id.'</a>',
              'location' => '<a href="'.$loc_link.'">'.$rf->seq_region_name.":".$rf->seq_region_start."-".$rf->seq_region_end.'</a>',
              'bound' => '<a href="'.$loc_link.'">'.$loc_string.'</a>',
              'type' => $rf->feature_type->name,
              'featureset' => $set->display_label,
            );
            
            push @$rows, \%row;
          }
        }
      }
    }
  }
  
  return new EnsEMBL::Web::Document::SpreadSheet($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
}

sub constrained_element_table {
  my $self = shift;
  my $slice = shift;
  
  my $object = $self->object;
  
  my $mlssa = $object->get_adaptor('get_MethodLinkSpeciesSetAdaptor','compara');
  my $cea = $object->get_adaptor('get_ConstrainedElementAdaptor','compara');
  
  my $columns = [
    { key => 'location', sort => 'position_html', title => 'Chr:bp' },
    { key => 'score', sort => 'numeric', title => 'Score' },
    { key => 'p-value', sort => 'numeric', title => 'p-value' },
    { key => 'level', sort => 'string', title => 'Taxonomic level' },
  ];
  
  my $rows;
  
  if(defined $mlssa and defined $cea) {
    foreach my $mlss(@{$mlssa->fetch_all_by_method_link_type("GERP_CONSTRAINED_ELEMENT")}) {
      foreach my $ce (@{$cea->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice)}) {
        
        my $loc_string =
          $ce->slice->seq_region_name.":".
          ($slice->start + $ce->start - 1)."-".
          ($slice->start + $ce->end - 1);
        
        my $loc_link = $object->_url({
          type => 'Location',
          action => 'View',
          r => $loc_string,
          v => $object->name,
        });
        
        my %row = (
          'location' => '<a href="'.$loc_link.'">'.$loc_string.'</a>',
          'score' => $ce->score,
          'p-value' => $ce->p_value,
          'level' => ucfirst($ce->taxonomic_level),
        );
        
        push @$rows, \%row;
      }
    }
 
  }
  
  return new EnsEMBL::Web::Document::SpreadSheet($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
}
1;
