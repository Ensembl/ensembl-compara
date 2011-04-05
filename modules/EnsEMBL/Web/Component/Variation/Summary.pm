# $Id$

package EnsEMBL::Web::Component::Variation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self               = shift;
  my $hub                = $self->hub;
  my $object             = $self->object;
  my $variation          = $object->Obj;
  my $name               = $object->name; 
  my $source             = $object->source;
  my $source_description = $object->source_description; 
  my $source_url         = $object->source_url;
  my $class              = uc $object->vari_class;
  my $is_somatic         = $variation->is_somatic;
  my $vaa                = $variation->adaptor->db->get_VariationAnnotationAdaptor;
  my $variation_features = $variation->get_all_VariationFeatures;
  my $display_name       = $object->name;
  
  if ($source eq 'dbSNP') {
    my $version = $object->source_version; 
    $display_name = $hub->get_ExtURL_link($name, 'DBSNP', $name);
    $name       = $hub->get_ExtURL_link("$source $version", 'DBSNP_HOME', $name); 
    $name       = "$class ($display_name source $name - $source_description)"; 
  } elsif ($source =~ /SGRP/) {
    $name = $hub->get_ExtURL_link($source, 'SGRP', $name);
    $name = "$class ($display_name source $name - $source_description)";
  } elsif ($source =~ /COSMIC/) {
    $name = $hub->get_ExtURL_link($source, 'COSMIC', $name);
    $display_name = $hub->get_ExtURL_link($display_name, 'COSMIC_ID', $display_name);
    $name = "$class ($display_name source $name - $source_description)";
  } elsif ($source =~ /HGMD/) { # HACK - should get its link properly somehow
    foreach my $va (@{$vaa->fetch_all_by_Variation($variation)}) {
      next unless $va->source_name =~ /HGMD/;
			my $display_name = $hub->get_ExtURL_link($display_name, 'HGMD', { ID => $va->associated_gene, ACC => $name });
      $name = $hub->get_ExtURL_link($va->source_name, 'HGMD-PUBLIC', '');
			$name = "$class ($display_name source $name $source_description)";
    }
  } else {
    $name = defined $source_url ? qq{<a href="$source_url">$source</a>} : $source;
    $name = "$class ($display_name source $name - $source_description)";
  }

  my $html;
  
  # get slice for variation feature
  my $feature_slice;
  
  foreach my $vf (@$variation_features) {
    $feature_slice = $vf->feature_Slice if $vf->dbID == $hub->core_param('vf');
  }
  
  ## First warn if variation has been failed
  if ($variation->failed_description) {
    my @descs = @{$variation->get_all_failed_descriptions};
	
	for my $i(0..$#descs) {
	  if(defined($feature_slice)) {
		my $seq = $feature_slice->seq;
		$seq =~ s/.{60}/$&\n/g;
		
		if($descs[$i] =~ /match.+reference\ allele/ && defined($feature_slice)) {
		  $descs[$i] =~ s/reference allele/$& \($seq\)/;
		}
	  }
	}
	
	my $failed_html;
	
	if(scalar @descs > 1) {
	  $failed_html = '<p><ul>';
	  $failed_html .= '<li>'.$_.'</li>' foreach @descs;
	  $failed_html .= '</ul></p>';
	}
	else {
	  $failed_html = $descs[0];
	}
    
    $html .= $self->_warning('This variation has been flagged as failed', $failed_html, '50%');
  }
 
  $html .= qq{
	
    <dl class="summary">
      <dt> Variation class </dt> 
      <dd>$name</dd>
  };

  # First add co-located variation info if count == 1
  if ($feature_slice) {
    my $vfa = $hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');
    my $variation_string;
    my @germline_variations = @{$vfa->fetch_all_by_Slice($feature_slice)};  
    my @somatic_mutations = @{$vfa->fetch_all_somatic_by_Slice($feature_slice)};
    my @variations = (@germline_variations, @somatic_mutations);

    if (@variations) {
      $variation_string = 'with'; #$is_somatic ? 'with variation ' : 'with somatic mutation ';
      
	  	my %by_source;
	  
      foreach my $v (@variations) {
        my $v_name           = $v->variation_name; 
        next if $v_name eq $object->name;
        my $v_start = $v->start + $feature_slice->start -1;
        my $v_end = $v->end + $feature_slice->start -1;
        next unless (( $v_start == $feature_slice->start) && ($v_end == $feature_slice->end)); 
        my $link           = $hub->url({ v => $v_name, vf => $v->dbID });
        my $variation      = qq{<a href="$link">$v_name</a>};
				push @{$by_source{$v->source}}, $variation;
      }
	  
	  	if(scalar keys %by_source) {
		
				foreach my $source(keys %by_source) {
		  		$variation_string .= ' <b>'.$source.'</b> ';
		  		$variation_string .= (join ", ", @{$by_source{$source}});
				}
		
				$html .= qq{
		  		<dl class='summary'>
						<dt>Co-located </dt>
						<dd>$variation_string</dd>
		  		</dl>
				};
	 		}
   	}
  }
  
 
  ## Add synonyms
  my %synonyms = %{$object->dblinks};
  my $info;
  
  foreach my $db (keys %synonyms) {
    my @ids = @{$synonyms{$db}};
    my @urls;

    if ($db =~ /dbsnp rs/i) { # Glovar stuff
      @urls = map { $hub->get_ExtURL_link($_, 'SNP', $_) } @ids;
    } elsif ($db =~ /dbsnp/i) {
      foreach (@ids) {
        next if /^ss/; # don't display SSIDs - these are useless
        push @urls , $hub->get_ExtURL_link($_, 'SNP', $_);
      }
      
      next unless @urls;
    } elsif ($db =~ /HGVbase|TSC/) {
      next;
    } elsif ($db =~ /Uniprot/) { 
      push @urls , $hub->get_ExtURL_link($_, 'UNIPROT_VARIATION', $_) for @ids;
    } elsif ($db =~ /HGMD/) { # HACK - should get its link properly somehow
      foreach (@ids) {
        foreach my $va (@{$vaa->fetch_all_by_Variation($variation)}) {
          next unless $va->source_name =~ /HGMD/;
          push @urls, $hub->get_ExtURL_link($_, 'HGMD', { ID => $va->associated_gene, ACC => $_ });
        }
      }
    } else {
      @urls = @ids;
    }

    # Do wrapping
    for (my $counter = 7; $counter < $#urls; $counter +=7) {
      my @front   = splice (@urls, 0, $counter);
      $front[-1] .= '</tr><tr><td></td>';
      @urls       = (@front, @urls);
    }

    $info .= "<b>$db</b> " . (join ', ', @urls) . '<br />';
  }

  $info ||= 'None currently in the database';
 
  $html .= qq{
    	<dt>Synonyms</dt>
    	<dd>$info</dd>
		</dl>	
  }; 

  ## Add variation sets
  my $variation_sets = $object->get_variation_set_string;
  
  if (scalar @$variation_sets) {
		my $vs_count = scalar @$variation_sets; 
    @$variation_sets = sort(@$variation_sets); 
		
		my $vs_list = '';
		$html .= '<dl class="summary">';
		# Large text display
    if ($vs_count<6 ) {
			$vs_list = join(',', @$variation_sets);
			$html .= '<dt>Present in</dt>';
			$html .= "<dd>$vs_list</dd>";
		}
		# Collapsed div display 
		else {
			my $set_label = "This feature is present in <b>$vs_count</b> sets";
			
			## 1000 genomes sets
			foreach my $set (@$variation_sets) {
				if ($set =~ /(1000\sgenomes)/i) {
					$vs_count--;
				}
			}
			if ($vs_count != scalar @$variation_sets) {		
					$set_label = "This feature is present in <b>1000 genomes</b> and <b>$vs_count</b> other sets";
			}
			$vs_list = '<ul><li>'.join('</li><li>', @$variation_sets).'</li></ul>';
			$html .= sprintf(qq{
		  	<dt class="toggle_button" title="Click to toggle sets names"><span>Present in</span><em class="closed"></em></dt>
		  	<dd>$set_label - click the plus to show all sets</dd>
		  	<dd class="toggle_info" style="display:none;font-weight:normal;">$vs_list</dd>
				<table class="toggle_table" style="display:none"></table>
			});
		}
		$html .= '</dl>';
  }

  ## Add Alleles
  my $label       = 'Alleles';
  my $alleles     = $object->alleles;
  my $vari_class  = $object->vari_class || 'Unknown';
  my $allele_html = "<b>$alleles</b>";

  if ($vari_class eq 'snp' or $vari_class eq 'SNP') {
    my $ambig_code = $variation->ambig_code;
		if ($alleles =~ /HGMD/) { $ambig_code='not available'; }
    $allele_html .= " (Ambiguity code: <strong>$ambig_code</strong>)";
  }

  # Check somatic mutation base matches reference
  if ($feature_slice) {
    my $ref_base = $feature_slice->seq;
    my @alleles = split /\//, $alleles;
    
    if($alleles[0] =~ /^[ACGTN]+$/) {
      my $ref_seq = length $ref_base == 1 ? 'base': 'sequence';
	  $ref_base =~ s/.{60}/$&<br\/>/g;
      $allele_html .= "<br /><em>Note</em>: The reference $ref_seq for this mutation ($alleles[0]) does not match the Ensembl reference $ref_seq ($ref_base) at this location." if $ref_base ne $alleles[0];
    }
  }
  
  $html .= qq{
			<dl class="summary">
      	<dt>Alleles</dt><dd>$allele_html</dd>
			</dl>
  };
	
	## Add Ancestral Allele
	my $ancestor  = $object->ancestor;
  if ($ancestor) {
		$html .= qq{
			<dl class="summary">
				<dt>Ancestral allele<dt><dd>$ancestor</dd>
			</dl>	
		};	
	}

  ## Add location information
  my $location; 
  my $strand   = '(forward strand)';
  my %mappings = %{$object->variation_feature_mapping};
  my $count    = scalar keys %mappings;
  my $id       = $object->name;

  $html  .= '<dl class="summary">';
  
  if ($count < 1) {
    $html .= '<dt>Location</dt><dd>This feature has not been mapped.</dd></dl>';
  }
  else {
    my @values;
    my $selected_vf;
    my $loc_html;
    
    # selected_vf is used to construct a link to location view
    # when count is one we just want the VF ID (the only one)
    if ($count == 1) {
      $selected_vf = $variation_features->[0]->dbID;
    }
    
    else {
      
      # add default value
      push @values, {value => 'null', name => 'None selected'};
      
      # get selected VF from the params
      $selected_vf = $self->hub->core_param('vf');
      
      # add values for each mapping
      foreach my $varif_id (sort
      {
        $mappings{$a}->{'Chr'} cmp $mappings{$b}->{'Chr'} ||
        $mappings{$a}->{'start'} <=> $mappings{$b}->{'start'}
      } keys %mappings) {
        
        my $region          = $mappings{$varif_id}{'Chr'}; 
        my $start           = $mappings{$varif_id}{'start'};
        my $end             = $mappings{$varif_id}{'end'};
        my $str             = $mappings{$varif_id}{'strand'};
        my $display_region  = $region . ':' . ($start - 500) . '-' . ($end + 500);
        my $location_string =
          ($start == $end ? "$region:$start" : "$region:$start-$end").
          ' ('.($str > 0 ? "forward" : "reverse").' strand)';
        
        push @values, {value => $varif_id, name => $location_string};
      }
      
      # create form
      my $url = $hub->url({ vf => undef, v => $id, source => $source, });
      my $form  = new EnsEMBL::Web::Form('select_loc', $url, 'get', 'nonstd check');
      
      # add dropdown
      $form->add_element(
        type         => 'DropDown',
        select       => 'select',
        name         => 'vf',
        values       => \@values,
        value        => $selected_vf, # default to selected_vf
      );
      
      # add submit
      $form->add_element(
        type         => 'Submit',
        value        => 'Go',
      );
      
      # add hidden values for all other params
      my %params = %{$self->hub->core_params};
      foreach my $param(keys %params) {
        
        # ignore vf and region as we want them to be overwritten
        next if $param eq 'vf' or $param eq 'r';
        
        $form->add_element(
          type => 'Hidden',
          name => $param,
          value => $params{$param},
        ) if defined $params{$param};
      }
      
      # render to string
      $loc_html = 'This feature maps to '.$count.' genomic locations'.$form->render;
      
      # strip off unwanted HTML layout tags from form
      $loc_html =~ s/\<\/?(div|tr|th|td|table|tbody|fieldset)+.*?\>\n?//g;
      
      # insert text
      $loc_html =~ s/\<form.*?\>/$&.'<span style="font-weight: bold;">Selected location: <\/span>'/e;
    }
    
    # construct location view link and other strings
    my ($location_string, $location_string_long, $location_link_html);
    
    if(defined($selected_vf)) {
      my $region          = $mappings{$selected_vf}{'Chr'}; 
      my $start           = $mappings{$selected_vf}{'start'};
      my $end             = $mappings{$selected_vf}{'end'};
      my $str             = $mappings{$selected_vf}{'strand'};
      my $display_region  = $region . ':' . ($start - 500) . '-' . ($end + 500);
      
      $location_string = ($start == $end ? "$region:$start" : "$region:$start-$end");
      $location_string_long = $location_string.' ('.($str > 0 ? "forward" : "reverse").' strand)';
      
      # turn on somatic or normal variation track
      my $track_name = $is_somatic ? 'somatic_mutation_COSMIC' : 'variation_feature_variation';
      
      my $location_link = $hub->url({ type =>'Location', action => 'View', r => $display_region, v => $id, source => $source, vf => $selected_vf, contigviewbottom => $track_name.'=normal' });
      $location_link_html = qq( | <a href="$location_link">View in location tab</a>);
    }
    
    # finish off html
    if($count == 1) {
      $loc_html = 'This feature maps to '.$location_string_long.$location_link_html;
    }
    else {
      #insert location link
      $loc_html =~ s/\<\/form\>/$location_link_html.$&/e;
    }
    
    # add to main $html
    $html .= '<dt>Location</dt><dd>'.$loc_html.'</dd></dl>';
  }

  ## Add validation status
  my $stat;
  my @status = @{$object->status};

  if (@status) {
    my $snp_name = $object->name;

    my (@status_list, $hapmap_html);

    foreach my $status (@status) {
      if ($status eq 'hapmap') {
        $hapmap_html = "<b>HapMap variant</b>", $hub->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
      } elsif ($status eq 'failed') {
        my $description = $variation->failed_description;
      } else {
        $status = "frequency" if $status eq 'freq';
        push @status_list, $status;
      }
    }

    $stat = join ', ', @status_list;

    if ($stat) {
      if ($stat eq 'observed' or $stat eq 'non-polymorphic') {
        $html = '<b>'.ucfirst($stat).'</b> ';
      } else {
        $stat = "Proven by <b>$stat</b> ";
      }
      #$stat .= ' (<i>Feature tested and validated by a non-computational method</i>).<br /> ';
    }

    $stat .= $hapmap_html;
  } else {
   $stat = 'Unknown';
  }

  $stat = 'Undefined' unless $stat =~ /^\w/;

  $html .= qq(
      <dl class="summary">
      	<dt>Validation status</dt>
      	<dd> $stat</dd>);


	## HGVS NOTATIONS
  ## count locations
  my $mapping_count = scalar keys %{$object->variation_feature_mapping};

  # skip if somatic mutation with mutation ref base different to ensembl ref base
  if (!$object->is_somatic_with_different_ref_base && $mapping_count) {
    my %mappings = %{$object->variation_feature_mapping};
    my $loc;

    if (keys %mappings == 1) {
      ($loc) = values %mappings;
    } else {
      $loc = $mappings{$hub->param('vf')};
    }

    # get vf object
    my $vf;

    foreach (@{$variation->get_all_VariationFeatures}) {
      $vf = $_ if $_->seq_region_start == $loc->{'start'} && $_->seq_region_end == $loc->{'end'} && $_->seq_region_name eq $loc->{'Chr'};
    }

    if (defined $vf) {

      ## HGVS
      #######

      my (%by_allele, $hgvs_html);

      # now get normal ones
      # go via transcript variations (should be faster than slice)
	  	my %genomic_alleles_added;
	  
	  	my $tvs = $vf->get_all_TranscriptVariations;
	  
	  	# if we've come from an LRG, add LRG TVs
			my $lrg_vf;
	  
	  	if($self->hub->param('lrg') =~ /LRG\_\d+/) {
		
				# transform to LRG coord system
				$lrg_vf = $vf->transform('LRG');
		
				if(defined($lrg_vf)) {
		  
		  		# force API to recalc consequences for LRG
		  		delete $lrg_vf->{'dbID'};
		  		delete $lrg_vf->{'transcript_variations'};
		  
		  		# add consequences to existing list
		  		push @$tvs, @{$lrg_vf->get_all_TranscriptVariations};
				}
	  	}
	  
    	foreach my $tv (@{$tvs}) {
				foreach my $tva(@{$tv->get_all_alternate_TranscriptVariationAlleles}) {
		 			unless($genomic_alleles_added{$tva->variation_feature_seq}) {
						push @{$by_allele{$tva->variation_feature_seq}}, $tva->hgvs_genomic;
						$genomic_alleles_added{$tva->variation_feature_seq} = 1;
		  		}
  
		  		# group by allele
		  		push @{$by_allele{$tva->variation_feature_seq}}, $tva->hgvs_coding if $tva->hgvs_coding;
		  		push @{$by_allele{$tva->variation_feature_seq}}, $tva->hgvs_protein if $tva->hgvs_protein && $tva->hgvs_protein !~ /p\.\=/;
				}
			}

    	# count alleles
    	my $allele_count = scalar keys %by_allele;

    	# make HTML
    	my @temp;

    	foreach my $a(keys %by_allele) {
    		push @temp, (scalar @temp ? '<br/>' : '') . "<b>Variant allele $a</b>" if $allele_count > 1;

      	foreach my $h (@{$by_allele{$a}}) {

					$h =~ s/LRG\_\d+(\.\d+)?/'<a href="'.$hub->url({
            	type => 'LRG',
            	action => 'Variation_LRG',
            	db     => 'core',
            	r      => undef,
            	t      => $&,
            	v      => $object->name,
            	source => $variation->source}).'">'.$&.'<\/a>'/eg;

					$h =~ s/ENS(...)?T\d+(\.\d+)?/'<a href="'.$hub->url({
            	type => 'Transcript',
            	action => $hub->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary',
            	db     => 'core',
            	r      => undef,
            	t      => $&,
            	v      => $object->name,
            	source => $variation->source}).'">'.$&.'<\/a>'/eg;

					$h =~ s/ENS(...)?P\d+(\.\d+)?/'<a href="'.$hub->url({
            	type => 'Transcript',
            	action => 'ProtVariations',
            	db     => 'core',
            	r      => undef,
            	p      => $&,
            	v      => $object->name,
            	source => $variation->source}).'">'.$&.'<\/a>'/eg;

        	push @temp, $h;
				}
			}

			$hgvs_html = join '<br/>', @temp;
	  	my $count = scalar grep {$_ =~ /\:/} @temp;

			$hgvs_html ||= "<h5>None</h5>";
	  
	  	if($count == 0) {
				$html .= qq{<dl class="summary"><dt>HGVS names</dt><dd>$hgvs_html</dd></dl>};
	  	}
	  
	  	else {
				my $several = ($count>1) ? 's' : '';
				$html .= sprintf(qq{
		  			<dt class="toggle_button" title="Click to toggle HGVS names"><span>HGVS names</span><em class="closed"></em></dt>
		  			<dd>This feature has $count HGVS name$several - click the plus to show</dd>
		  			<dd class="toggle_info" style="display:none;font-weight:normal;">$hgvs_html</dd>
		  		</dl>
		  		<table class="toggle_table" style="display:none" id="hgvs"></table>
				});
	  	}
  	}
	}

  return qq{<div class="summary_panel">$html</div>};
}

1;
