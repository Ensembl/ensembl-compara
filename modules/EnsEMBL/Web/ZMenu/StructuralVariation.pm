package EnsEMBL::Web::ZMenu::StructuralVariation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift; 
  my $hub  = $self->hub;
  my $sv_id = $hub->param('sv');
  
  return unless $sv_id;
  
  my $db_adaptor      = $hub->database('variation');
  my $var_adaptor     = $db_adaptor->get_StructuralVariation;
  my $variation       = $var_adaptor->fetch_by_name($sv_id); 
  my $svf             = $variation->get_all_StructuralVariationFeatures();
  my $max_length      = ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1) * 1e6; 
  my $class           = $variation->var_class;
  my $vstatus         = $variation->get_all_validation_states;
  my $pubmed_link     = '';
  my $location_link;
  my $feature;
  my $study_name;
  my $description;
  my $study_url;
  my $is_breakpoint;
  my $study = $variation->study;
  
  if (defined($study)) {
    $study_name   = $study->name;
    $description = $study->description;
    $study_url   = $study->url; 
  }

  if (scalar @$svf == 1) {
    $feature = $svf->[0];
  } else {
    foreach (@$svf) {
      $feature = $_ if $_->dbID eq $hub->param('svf');
    }
  }
  
  my $start      = $feature->start;
  my $end        = $feature->end;
  my $seq_region = $feature->seq_region_name;
  my $position   = "$seq_region:$start";
  my $length     = $end - $start;
  
  if ($end < $start) {
    $position = "$seq_region: between $end &amp; $start";
  } elsif ($end > $start) {
    $position = "$seq_region:$start-$end";
  }
	
	
  if (! $description) {
    $description = $variation->source_description;
  }
  
	if (defined($feature->breakpoint_order) && $feature->is_somatic == 1) {
	  $is_breakpoint = " (breakpoint)";
	  $position = $self->get_locations($sv_id);
	
	} elsif ($length > $max_length) {
    my $track_name = $variation->is_somatic ? 'somatic_sv_feature' : 'variation_feature_structural';  
    $location_link = $hub->url({
      type     => 'Location',
      action   => 'Overview',
      r        => $seq_region . ':' . $start . '-' . $end,
      cytoview => "$track_name=normal",
    });
  } else {
    $location_link = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $seq_region . ':' . $start . '-' . $end,
    });
  }
  
  if ($description =~/PMID/) {
    my @description_string = split (':', $description);
    my $pubmed_id = pop @description_string;
    $pubmed_id =~ s/\s+.+//g;
    $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);  
  }    

  my $ssvs   = $self->object->supporting_sv;
  my @allele_types;
  foreach my $ssv (@$ssvs) {
    my $a_type = $ssv->var_class;
    
    next if (grep {$a_type eq $_} @allele_types);
    push @allele_types, $a_type;
  }
  @allele_types = sort(@allele_types);

  my $sv_caption = 'Structural variation: ';
  if ($class eq 'CNV_PROBE') {
    $sv_caption = 'CNV probe: ';
  }
  $self->caption($sv_caption . $sv_id);

  $self->add_entry({
    label_html => $sv_id.' properties',
    link       => $hub->url({
      type     => 'StructuralVariation',
      action   => 'Summary',
      sv       => $sv_id,
    })
  });

  $self->add_entry({
    type  => 'Source',
    label => $variation->source,
  });
  
  
  if (defined($study_name)) {
    $self->add_entry({
      type  => 'Study',
      label => $study_name,
      link  => $study_url, 
    });
  }

  $self->add_entry({
    type  => 'Description',
    label => $description,
    link  => $pubmed_link, 
  });

  $self->add_entry({
    type  => 'Class',
    label => $class,
  });

  if (scalar(@allele_types)) {
    my $s = (scalar(@allele_types) > 1) ? 's' : '';
    $self->add_entry({
      type  => "Allele type$s",
      label => join(', ',@allele_types),
    });
  }

  if (scalar(@$vstatus) and $vstatus->[0]) {
    $self->add_entry({
      type  => 'Validation',
      label => join(',',@$vstatus),
    });    
  }

  if ($is_breakpoint) {
	 $self->add_entry({
      type  => 'Location',
      label_html => $position,
    });
	} else {
    $self->add_entry({
      type  => 'Location',
      label => $position.$is_breakpoint,
      link  => $location_link,
    });
	}
}


sub get_locations {
  my $self  = shift;
	my $sv_id = shift;
	my $hub   = $self->hub;
	my $mappings = $self->object->variation_feature_mapping;
	
  my $params    = $hub->core_params;
  my @locations = ({ value => 'null', name => 'None selected' });
    
  my $location_info;
  my $global_location_info;
	  
  # add locations for each mapping
  foreach (sort { $mappings->{$a}{'Chr'} cmp $mappings->{$b}{'Chr'} || $mappings->{$a}{'start'} <=> $mappings->{$b}{'start'}} keys %$mappings) {
    my $region   = $mappings->{$_}{'Chr'}; 
    my $start    = $mappings->{$_}{'start'};
    my $end      = $mappings->{$_}{'end'};
    my $str      = $mappings->{$_}{'strand'};
    my $bp_order = $mappings->{$_}{'breakpoint_order'};
       
    if (defined($bp_order)) {
      my @coords = ($start);
			push (@coords, $end) if ($start!=$end);
			
			foreach my $coord (@coords) {
        my $loc_text = "<b>$region:$coord</b>";
        my $loc_link = sprintf(
          '<a href="%s" class="constant">%s</a>',
            $hub->url({
              type              => 'Location',
              action            => 'View',
              r                 => $region . ':' . ($coord - 500) . '-' . ($coord + 500),
              sv                => $sv_id,
              svf               => $_,
              contigviewbottom  => 'somatic_sv_feature=normal'
            }), $loc_text
        );
        $loc_link .= '<br />('.($str > 0 ? 'forward' : 'reverse').' strand)';
        
        if (!defined($location_info)) {
          $location_info = "Breakpoints<br />FROM $loc_link";
        } elsif ($location_info =~ /<br \/>TO/) {
				  $global_location_info .= $location_info;
					$location_info = "<br />Breakpoints<br />FROM $loc_link";
				} else {
          $location_info .= "<br />TO $loc_link";
        }  
      } 
    }
  }
    
  return ($global_location_info) ? $global_location_info.$location_info : $location_info;
}

1;
