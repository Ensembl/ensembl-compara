# $Id$

package EnsEMBL::Web::Component::Variation_Context;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1); 
}

sub content {
  my $self   = shift; 
  my $object = $self->object;
	
  ## first check we have a location
  if ($object->isa('Bio::EnsEMBL::Variation::Variation') && $object->not_unique_location) {
    return $self->_info(
      'A unique location can not be determined for this Variation',
      $object->not_unique_location
    );
  }
  
  my $hub           = $self->hub;
  my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor');
  my $width         = $hub->param('context') || 30000;
	my $width_max     = 1000000;
  my %mappings      = %{$object->variation_feature_mapping};  # first determine correct SNP location 
  my $v;
	my $vname         = $object->name;
  my $var_slice;
  my $html;
	
	# Different display and image configuration between Variation and Structural Variation
	my $im_cfg = 'snpview';
	if ($object->isa('EnsEMBL::Web::Object::StructuralVariation')) {
		$im_cfg = 'structural_variation';
	}
	
  
  if (keys %mappings == 1) {
    ($v) = values %mappings;
  } else { 
    $v = $mappings{$hub->param('vf')};
  }
  
  if (!$v) { 
    return $self->_info(
      '',
      "<p>Unable to draw SNP neighbourhood as we cannot uniquely determine the SNP's location</p>"
    );
  }

  my $seq_region = $v->{'Chr'};
	my $seq_type = $v->{'type'};
  my $start = $v->{'start'} <= $v->{'end'} ? $v->{'start'} : $v->{'end'};
  my $end = $v->{'start'} << $v->{'end'} ? $v->{'end'} : $v->{'start'};   
  my $length =  ($end - $start) +1;

	my $img_start = $start;
	my $img_end   = $end;
	
	# Width max > length Slice > context
	if ($length >= $width and $length <= $width_max) {
		my $new_width = 10000;
		$img_start -= $new_width; 
    $img_end += $new_width;
	}
	# length Slice > Width max
	elsif ($length > $width_max){
    my $location = $seq_region.':'.$img_start.'-'.$img_end;
    $img_end = $img_start + $width_max -1; 
    $var_slice = 1;
    my $overview_link = $hub->url({
      type   => 'Location',
      action => 'Overview',
      r      => $location,
      sv     => $object->name
    });
    $overview_link .=';cytoview=variation_feature_structural=normal';
		my $interval = $width_max/1000;
    my $warning_text = '<p>This '.$object->type.' is too large to display in full, this image and tables below contain only the information relating to the first '.$interval.' Kb of the feature. To see the full length structural variation please use the <a href="'.$overview_link.'">region overview</a> display.</p>';
 
   $html .= $self->_info(
      $object->type . ' has been truncated',
      $warning_text
    );
  }
	# context > length Slice
	else {
    $img_start -= ($width/2); 
    $img_end += ($width/2);
  }
	
	# Image slice
  my $slice = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $img_start, $img_end, 1);

	# Image
	my $image_config = $hub->get_imageconfig($im_cfg);
	
  $image_config->set_parameters( {
    image_width     => $self->image_width || 900,
    container_width => $slice->length,
    slice_number    => '1|1',
  });

	if ($im_cfg eq 'snpview') {
		my $sliceObj   = $self->new_object('Slice', $slice, $object->__data);
		my ($count_snps, $filtered_snps)       = $sliceObj->getVariationFeatures;
  	my ($genotyped_count, $genotyped_snps) = $sliceObj->get_genotyped_VariationFeatures;
  	
		$image_config->{'snps'}           = $filtered_snps;
  	$image_config->{'genotyped_snps'} = $genotyped_snps;
  	$image_config->{'snp_counts'}     = [ $count_snps + $genotyped_count, scalar @$filtered_snps + scalar @$genotyped_snps ];
	}
  
  my $image = $self->new_image($slice, $image_config, [ $object->name ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'transcript';
  $image->set_button('drag', 'title' => 'Drag to select region');
 
  $html .= $image->render;
 
	if ($length > $width_max){ # Variation truncated (slice very large)
		$var_slice = $slice;
		$html .= qq{<h2>Features overlapping the variation context:</h2><br />};
	}
	else {
		$var_slice = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $start, $end, 1);
  	$html .= qq{<h2>Features overlapping $vname:</h2><br />};
	}
	
  # structural variation table
  $html .= $self->structural_variation_table($var_slice,$vname);
  
	# copy number variant probe table
  $html .= $self->cnv_probe_table($var_slice,$vname);
	
	# sequence variation table (not displayed for structural variants and CNV probes)
  if ($im_cfg eq 'snpview') {
  	$html .= $self->sequence_variation_table($var_slice,$vname);
	}

  # regulatory region table
  $html .= $self->regulatory_feature_table($var_slice,$vname,$image_config);
  
  # constrained elements table
  $html .= $self->constrained_element_table($var_slice,$vname);
  
  return $html;
}



sub structural_variation_table{
  my $self     = shift;
  my $slice    = shift;
	my $v        = shift;
  my $hub      = $self->hub;
  my $title    = 'Structural variants';
	my $table_id = 'sv';
	my $html;
	
  my $columns = [
     { key => 'id',          sort => 'string',        title => 'Name'   },
     { key => 'location',    sort => 'position_html', title => 'Chr:bp' },
     { key => 'class',       sort => 'string',        title => 'Class'  },
     { key => 'source',      sort => 'string',        title => 'Source Study' },
     { key => 'description', sort => 'string',        title => 'Study description', width => '50%' },
  ];
  
  my $rows;
	
	foreach my $sv (@{$slice->get_all_StructuralVariations}) {
		my $name = $sv->variation_name;
    next if $name eq $v;
    # make PMID link for description
    my $description = $sv->source_description;
		my $ext_ref  = $sv->external_reference;
	 	my $sv_class = $sv->class;
	  my $source   = $sv->source;
	  
	  # Add study information
	  if ($sv->study_name ne '') {
	  	$source .= ":".$sv->study_name;
			$description .= $sv->study_description;
	  }
      
    if ($ext_ref =~ /pubmed\/(.+)/) {
			my $pubmed_id = $1;
			my $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
      $description =~ s/$pubmed_id/'<a href="'.$pubmed_link.'" target="_blank">'.$&.'<\/a>'/eg;
    }
			
    my $sv_link = $hub->url({
       		type    => 'StructuralVariation',
        	action  => 'Summary',
        	sv      => $name
       	});      

    my $loc_string = $sv->seq_region_name . ':' . $sv->seq_region_start . '-' . $sv->seq_region_end;
        
    my $loc_link = $hub->url({
        	type   => 'Location',
        	action => 'View',
        	r      => $loc_string,
      	});
      
    my %row = (
        	id          => qq{<a href="$sv_link">$name</a>},
        	location    => qq{<a href="$loc_link">$loc_string</a>},
        	class       => $sv_class,
        	source      => $source,
        	description => $description,
      	);
	  
    push @$rows, \%row;
  }
  
	my $sv_table = $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
	$html .= display_table_with_toggle_button($title,$table_id,1,$sv_table);
	return $html;
}


sub cnv_probe_table{
  my $self     = shift;
  my $slice    = shift;
	my $v        = shift;
  my $hub      = $self->hub;
  my $title    = 'Copy number variants probes';
	my $table_id = 'cnv';
	my $html;
	
  my $columns = [
     { key => 'id',          sort => 'string',        title => 'Name'   },
     { key => 'location',    sort => 'position_html', title => 'Chr:bp' },
     { key => 'class',       sort => 'string',        title => 'Class'  },
     { key => 'source',      sort => 'string',        title => 'Source Study' },
     { key => 'description', sort => 'string',        title => 'Study description', width => '40%' },
  ];
  
  my $rows;
	
	foreach my $sv (@{$slice->get_all_CopyNumberVariantProbes}) {
		my $name = $sv->variation_name;
    next if $name eq $v;
    # make PMID link for description
    my $description = $sv->source_description;
    my $ext_ref  = $sv->external_reference;
	 	my $sv_class = $sv->class;
	  my $source   = $sv->source;
	  
	  # Add study information
	  if ($sv->study_name ne '') {
	  	$source .= ":".$sv->study_name;
			$description .= $sv->study_description;
	  }
    if ($ext_ref =~ /pubmed\/(.+)/) {
			my $pubmed_id = $1;
			my $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
      $description =~ s/$pubmed_id/'<a href="'.$pubmed_link.'" target="_blank">'.$&.'<\/a>'/eg;
    }
			
    my $sv_link = $hub->url({
       		type    => 'StructuralVariation',
        	action  => 'Summary',
        	sv      => $name
      	});      

    my $loc_string = $sv->seq_region_name . ':' . $sv->seq_region_start . '-' . $sv->seq_region_end;
        
    my $loc_link = $hub->url({
        	type   => 'Location',
        	action => 'View',
        	r      => $loc_string,
      	});
      
    my %row = (
        	id          => qq{<a href="$sv_link">$name</a>},
        	location    => qq{<a href="$loc_link">$loc_string</a>},
        	class       => $sv_class,
        	source      => $source,
        	description => $description,
      	);
	  
    push @$rows, \%row;
  }
  
	my $cnv_table = $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
	$html .= display_table_with_toggle_button($title,$table_id,0,$cnv_table);
	return $html;
}


sub sequence_variation_table {
  my $self     = shift;
  my $slice    = shift;
	my $v        = shift;
  my $hub      = $self->hub;
	my $title    = 'Sequence variants';
	my $table_id = 'seq';

  my $columns = [
     { key => 'id',          sort => 'string',        title => 'Name'       },
     { key => 'location',    sort => 'position_html', title => 'Chr:bp'     },
     { key => 'alleles',     sort => 'string',        title => 'Alleles'    }, 
     { key => 'ambiguity',   sort => 'string',        title => 'Ambiguity'  },
     { key => 'class',       sort => 'string',        title => 'Class'      },
     { key => 'source',      sort => 'string',        title => 'Source'     },
     { key => 'valid',       sort => 'string',        title => 'Validation' },
  ];

  my $rows;
  
	foreach my $vf (@{$slice->get_all_VariationFeatures}){
		my $name = $vf->variation_name;
    next if $name eq $v;
      
    my $vf_link = $hub->url({
        	type    => 'Variation',
        	action  =>  'Summary',
        	v       => $name,
        	vf      => $vf->dbID
      	});

		my $region_start = $vf->seq_region_start;
		my $region_end = $vf->seq_region_end;
			
    my $loc_string = $vf->seq_region_name . ':' . $region_start . ($region_start = $region_end ? '' : '-' . $region_end);
    my $loc_link = $hub->url({
        	type   => 'Location',
        	action => 'View',
        	r      => $loc_string,
      	});

    my $validation = $vf->get_all_validation_states || [];
    
        
		my %row = (
        	id          => qq{<a href="$vf_link">$name</a>},
        	location    => qq{<a href="$loc_link">$loc_string</a>},
        	alleles     => $vf->allele_string,
        	ambiguity   => $vf->ambiguity_code,
        	class       => $vf->var_class,
        	source      => $vf->source,
        	valid       =>  join(', ',  @$validation) || '-',
      	);

    push @$rows, \%row;
  }
	
	my $table = $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
	
	return display_table_with_toggle_button($title,$table_id,1,$table);
}

sub regulatory_feature_table{
  my $self         = shift;
  my $slice        = shift;
	my $v            = shift;
	my $image_config = shift;
  my $hub          = $self->hub;
  my $title        = 'Regulatory features';
	my $table_id     = 'reg';
	
  my $columns = [
    { key => 'id',         sort => 'string',        title => 'Name'              },
    { key => 'location',   sort => 'position_html', title => 'Chr:bp'            },
    { key => 'bound',      sort => 'numerical',     title => 'Bound coordinates' },
    { key => 'type',       sort => 'string',        title => 'Type'              },
    { key => 'featureset', sort => 'string',        title => 'Feature set'       },
  ];
  
  my $rows;
  my $fsa = $hub->get_adaptor('get_FeatureSetAdaptor', 'funcgen');
  
  if (defined $fsa) {
		
    foreach my $set(@{$fsa->fetch_all_by_feature_class('regulatory')}) {
      my $set_name = (split /\s+/, $set->display_label)[-1];

      # check if this feature set is switched on in the image config
      if (defined $image_config->get_node('functional')->get_node("reg_feats_$set_name")) {
				foreach my $rf (@{$set->get_Features_by_Slice($slice)}) {
            
					my $stable_id = $rf->stable_id;
					my $rf_link = $hub->url({
               type   => 'Regulation',
               action => 'Summary',
               fdb    => 'funcgen',
               r      => undef,
               rf     => $stable_id,
             });
             
					my $region_name = $rf->seq_region_name;
          my $loc_string = "$region_name:" . ($slice->start + $rf->bound_start - 1) . '-' . ($slice->start + $rf->bound_end - 1);
             
					my $loc_link = $hub->url({
               type             => 'Location',
               action           => 'View',
               r                => $loc_string,
               contigviewbottom => "reg_feats_$set_name=normal",
             });
             
          push @$rows, {
               id         => qq{<a href="$rf_link">}  . $stable_id . '</a>',
               location   => qq{<a href="$loc_link">$region_name:} . $rf->seq_region_start . '-' . $rf->seq_region_end . '</a>',
               bound      => qq{<a href="$loc_link">$loc_string</a>},
               type       => $rf->feature_type->name,
               featureset => $set->display_label,
          };
      	}
      }
    }
  }
  
  my $table = $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
	
	return display_table_with_toggle_button($title,$table_id,1,$table);
}

sub constrained_element_table {
  my $self     = shift;
  my $slice    = shift;
	my $v        = shift;
  my $hub      = $self->hub;
  my $title    = 'Constrained elements';
	my $table_id = 'cons';
	
  my $mlssa = $hub->get_adaptor('get_MethodLinkSpeciesSetAdaptor', 'compara');
  my $cea   = $hub->get_adaptor('get_ConstrainedElementAdaptor',   'compara');
  
  my $columns = [
    { key => 'location', sort => 'position_html', title => 'Chr:bp'          },
    { key => 'score',    sort => 'numeric',       title => 'Score'           },
    { key => 'p-value',  sort => 'numeric',       title => 'p-value'         },
    { key => 'level',    sort => 'string',        title => 'Taxonomic level' },
  ];
  
  my $rows;
	
  my $slice_start = $slice->start;
	my $slice_region_name = $slice->seq_region_name;
	
  if (defined $mlssa && defined $cea) {
    foreach my $mlss (@{$mlssa->fetch_all_by_method_link_type('GERP_CONSTRAINED_ELEMENT')}) {
      foreach my $ce (@{$cea->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice)}) {
			
        my $loc_string = $slice_region_name . ':' . ($slice_start + $ce->start - 1) . '-' . ($slice_start + $ce->end - 1);
        
        my $loc_link = $hub->url({
          type   => 'Location',
          action => 'View',
          r      => $loc_string,
        });
        
        push @$rows, {
          'location' => qq{<a href="$loc_link">$loc_string</a>},
          'score'    => $ce->score,
          'p-value'  => $ce->p_value,
          'level'    => ucfirst $ce->taxonomic_level,
        };
      }
    }
  }
  
  my $table = $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
	
	return display_table_with_toggle_button($title,$table_id,1,$table);
}


sub display_table_with_toggle_button {
	my $title = shift;
	my $id    = shift;
	my $state = shift;
	my $table = shift;
	
	my $is_show = 'show';
	my $is_open = 'open';
	if ($state==0) {
		$is_show = 'hide';
		$is_open = 'closed';
	}
	
	$table->add_option('data_table', "toggle_table $is_show");
  $table->add_option('id', $id.'_table');
	my $html = qq{
  	<div>
    	<h2 style="float:left">$title</h2>
      <span class="toggle_button" id="$id"><em class="$is_open" style="margin:5px"></em></span>
      <p class="invisible">.</p>
    </div>\n
	};
	$html .= $table->render;	
	$html .= qq{<br />};
		
	return $html;
}
1;
