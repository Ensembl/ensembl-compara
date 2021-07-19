=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::StructuralVariation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::StructuralVariation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $object       = $self->object;
  return '' unless $object;
  my $source_name  = $object->source_name;
  my $mappings     = $object->variation_feature_mapping;
  my $validation   = $object->validation_status;
  my $failed       = $object->Obj->failed_description ? $self->failed() : ''; ## First warn if the SV has been failed
  my $sv_sets      = $object->get_variation_set_string;
  my $hub          = $self->hub;
  my $avail        = $object->availability;

  my $transcript_url  = $hub->url({ action => "StructuralVariation", action => "Mappings",    sv => $object->name });
  my $evidence_url    = $hub->url({ action => "StructuralVariation", action => "Evidence",    sv => $object->name });
  my $phenotype_url   = $hub->url({ action => "StructuralVariation", action => "Phenotype",   sv => $object->name });  
 
  my @str_array;
  push @str_array, sprintf('overlaps <a class="dynamic-link" href="%s">%s %s</a>', 
                      $transcript_url, 
                      $avail->{has_transcripts}, 
                      $avail->{has_transcripts} eq "1" ? "transcript" : "transcripts"
                  ) if($avail->{has_transcripts});
                  
  push @str_array, sprintf('is associated with <a class="dynamic-link" href="%s">%s %s</a>', 
                      $phenotype_url, 
                      $avail->{has_phenotypes}, 
                      $avail->{has_phenotypes} eq "1" ? "phenotype" : "phenotypes"
                  ) if($avail->{has_phenotypes});

  push @str_array, sprintf('is supported by <a class="dynamic-link" href="%s">%s %s of evidence</a>',
                      $evidence_url, 
                      $avail->{has_supporting_structural_variation}, 
                      $avail->{has_supporting_structural_variation} eq "1" ? "piece" : "pieces" 
                  )if($avail->{has_supporting_structural_variation});                  
                  
  return sprintf qq{<div class="summary_panel">$failed%s</div>}, $self->new_twocol(
    $self->variation_class,
    $self->get_allele_types($source_name),
    $self->get_source($source_name, $object->source_description),
    $self->get_study,
    $self->get_alias,
    $self->clinical_significance,
    scalar(@$sv_sets) ? ['Present in', sprintf '<p><b>%s</b></p>', join(', ',@$sv_sets)] : (),
    $self->get_strains,
    $self->location($mappings),
    $self->size($mappings),
    $validation ? ['Validation status', $validation] : (),
    @str_array ? ["About this structural variant", sprintf('This structural variant %s.', $self->join_with_and(@str_array))] : ()
  )->render;
}

sub variation_class {
  my $self = shift;
  my $object = $self->object;
  my $so_accession = $object->Obj->class_SO_accession;
  $so_accession = $self->hub->get_ExtURL_link($so_accession, 'SEQUENCE_ONTOLOGY', $so_accession);
  
  return ['Variation class', $object->class."<small class=\"_ht\" title=\"SO term: ".$object->Obj->class_SO_term."\" style=\"padding-left:6px\">($so_accession)</small>"];
}

sub failed {
  my $self = shift;
  my @descs = @{$self->object->Obj->get_all_failed_descriptions};
  my $html;
  
  if (scalar @descs > 1) {
    $html  = '<p><ul>';
    $html .= "<li>$_</li>" foreach @descs;
    $html .= '</ul></p>';
  } else {
    $html = $descs[0];
  }
  
  return $self->_warning('This structural variation has been flagged as failed', $html, '50%');
}

# Returns the list of the allele types (supporting evidence classes) with the associate colour
sub get_allele_types {
  my $self   = shift;
  my $source = shift;
  
  return if $source ne 'DGVa';
  
  my $object = $self->object;
  my $ssvs   = $object->supporting_sv;
  my (@allele_types, $html);
  
  foreach my $ssv (@$ssvs) {
    my $SO_term = $ssv->class_SO_term;

    if (!grep {$ssv->class_SO_term eq $_} @allele_types) {
      push @allele_types, $SO_term;

      my $so_accession = $ssv->class_SO_accession;
      $so_accession = $self->hub->get_ExtURL_link($so_accession, 'SEQUENCE_ONTOLOGY', $so_accession);

      $html .= sprintf('<p><span class="structural-variation-allele" style="background-color:%s"></span>%s<small class="_ht" style="padding-left:6px" title="%s">(%s)</small></p>',
        $object->get_class_colour($SO_term),
        $ssv->var_class,
        "SO term: $SO_term",
        $so_accession
      );
    }
  }

  return $html ? ['Allele type(s)', $html] : ();
}


sub get_source {
  my $self        = shift;
  my $source      = shift; 
  my $description = shift;
  my $hub         = $self->hub;
  my $source_link = $source;
  
  if ($source eq 'DGVa') {
    $source_link = $hub->get_ExtURL_link($source, uc($source), $source);
  } elsif ($source eq 'dbVar') {
    $source_link = $hub->get_ExtURL_link($source, uc($source), $source);
  } elsif ($source =~ /affy/i) {
    $source_link = $hub->get_ExtURL_link($source, 'AFFYMETRIX', $source);
  } elsif ($source =~ /illumina/i) {
    $source_link = $hub->get_ExtURL_link($source, 'ILLUMINA', $source);
  }
  
  $source = "<p>$source_link - $description</p>";

  return ['Source', $source];
}

sub get_study {
  my $self       = shift;
  my $object     = $self->object;
  my $study_name = $object->study_name;
  
  return unless $study_name;
  
  my $study_description = $self->add_pubmed_link($object->study_description);
  my $study_line        = sprintf '<a href="%s" class="constant" rel="external">%s</a>', $object->study_url, $study_name;
  
  return ['Study', "$study_line - $study_description"];
}


sub get_alias {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $alias  = $object->Obj->alias;
  my $study_name = $object->study_name;

  # Alias (RCV IDs) from ClinVar
  if ($study_name && $study_name eq 'nstd102') {
    my $cv_alias = '';
    foreach my $ssv (@{$object->supporting_sv}) {
      my $ssv_alias = $ssv->alias;
      if ($ssv_alias && $ssv_alias =~ /^(RCV\d+)/) {
        my $clinvar_alias = $1;
        my $clinvar_url = $hub->get_ExtURL_link($clinvar_alias, 'CLINVAR', $clinvar_alias);
        $cv_alias .= ', ' if ($cv_alias ne '');
        $cv_alias .= $clinvar_url;
      }
    }
    $alias = $cv_alias if ($cv_alias ne '');
  }
  # Alias (COSMIC IDs) from the COSMIC study
  else {
    my $er_url = $object->external_reference;
    if ($er_url =~ /cosmic/) {
      $alias =~ /(\d+)/;
      my $cosmic_id = ($1) ? $1 : '';
      $alias = $hub->get_ExtURL_link($alias, 'COSMIC_SV', $cosmic_id);
    }
  }
  
  return ($alias) ? ['Alias', $alias] : undef;
}


# Method to add a pubmed link to the expression "PMID:xxxxxxx"
# in the source or study description, if it is present.
sub add_pubmed_link {
  my $self        = shift;
  my $description = shift;
  my $hub         = $self->hub;
  my $er_url      = $self->object->external_reference;
  
  if ($description =~ /PMID/) { 
    my @temp = split /\s/, $description;
    
    foreach (@temp) {
      if (/PMID/) {
        (my $id = $_)   =~ s/PMID://; 
        my $pubmed_url  = $hub->get_ExtURL_link($_, 'EPMC_MED', $id);
           $description =~ s/$_/$pubmed_url/;
      }
    }
  } 
  elsif ($er_url && $er_url =~ /^http|ftp/){
    my $url;
    if ($er_url =~ /cosmic/) {
      my $alias = $self->object->Obj->alias;
         $alias =~ /(\d+)/;
      my $cosmic_id = ($1) ? $1 : '';   
      $url = $hub->get_ExtURL_link('View in COSMIC website', 'COSMIC_SV', $cosmic_id);
    } 
    else { 
      $url = qq{<a href="$er_url" rel="external">Go to the website</a>};
    }
    $description .= " | $url";
  } 
  
  return $description;
}

sub location {
  my $self     = shift;
  my $mappings = shift;
  my $object   = $self->object;
  my $count    = scalar keys %$mappings;
  
  return ['Location', 'This feature has not been mapped.'] unless $count;

  my $hub  = $self->hub;
  my $svf  = $hub->param('svf');
  my $name = $object->name;
  my ($location_link, $location);
  
  if ($svf) {
    my $type     = $mappings->{$svf}{'Type'};
    my $region   = $mappings->{$svf}{'Chr'}; 
    my $start    = $mappings->{$svf}{'start'};
    my $end      = $mappings->{$svf}{'end'};
    my $strand   = $mappings->{$svf}{'strand'};
    
    # Breakpoint feature
    if (defined($mappings->{$svf}{'breakpoint_order'}) && $object->is_somatic == 1 && $start!=$end) {
      
      foreach my $coord ($start,$end) {
        my $loc_text = "<b>$region:$coord</b>";
      
        my $loc_link = sprintf(
          '<a href="%s" class="constant">%s</a>',
            $hub->url({
              type              => 'Location',
              action            => 'View',
              r                 => $region . ':' . ($coord - 500) . '-' . ($coord + 500),
              sv                => $name,
              svf               => $svf,
              contigviewbottom  => 'somatic_sv_feature=gene_nolabel'
          }), $loc_text
        );
        $loc_link .= ' ('.($strand > 0 ? 'forward' : 'reverse').' strand)';
        
        $location  .= (defined($location)) ? " to $loc_link" : "from $loc_link";
        
      }
    }
    # Normal feature
    else {
      $location = ucfirst(lc $type).' <b>'.($start == $end ? "$region:$start" : "$region:$start-$end") . '</b> (' . ($mappings->{$svf}{'strand'} > 0 ? 'forward' : 'reverse') . ' strand)';
    
      $location_link = sprintf(
        ' | <a href="%s" class="constant">View in location tab</a>',
        $hub->url({
          type             => 'Location',
          action           => 'View',
          r                => $region . ':' . ($start - 500) . '-' . ($end + 500),
          sv               => $name,
          svf              => $svf,
          contigviewbottom => 'variation_feature_structural_larger=compact,variation_feature_structural_smaller=gene_nolabel'
        })
      );
    }
  }

  if ($count > 1) {
    my $params    = $hub->core_params;
    my @locations = ({ value => 'null', name => 'None selected' });
    
    my $is_breakpoint;
    my $location_info;
    
    # add locations for each mapping
    foreach (sort { $mappings->{$a}{'Chr'} cmp $mappings->{$b}{'Chr'} || $mappings->{$a}{'start'} <=> $mappings->{$b}{'start'}} keys %$mappings) {
      my $region   = $mappings->{$_}{'Chr'}; 
      my $start    = $mappings->{$_}{'start'};
      my $end      = $mappings->{$_}{'end'};
      my $str      = $mappings->{$_}{'strand'};
      my $bp_order = $mappings->{$_}{'breakpoint_order'};
            
      push @locations, {
        value    => $_,
        name     => sprintf('%s (%s strand)', ($start == $end ? "$region:$start" : "$region:$start-$end"), ($str > 0 ? 'forward' : 'reverse')),
        selected => $svf == $_ ? ' selected' : ''
      };
       
      if (defined($bp_order) && $object->is_somatic) {
      
        my $loc_text = '<b>'.($start == $end ? "$region:$start" : "$region:$start-$end"). '</b>';
        
            
        my $loc_link = sprintf(
          '<a href="%s" class="constant">%s</a>',
            $hub->url({
              type              => 'Location',
              action            => 'View',
              r                 => $region . ':' . ($start - 500) . '-' . ($end + 500),
              sv                => $name,
              svf               => $svf,
              contigviewbottom  => 'somatic_sv_feature=gene_nolabel'
          }), $loc_text
        );
        $loc_link .= ' ('.($str > 0 ? 'forward' : 'reverse').' strand)';
        
        if (!defined($location_info)) {
          $location_info = "from $loc_link";
        } else {
          $location_info .= " to $loc_link";
        }  
        
      }
    }
    
    # ignore svf and region as we want them to be overwritten
    my $core_params = join '', map $params->{$_} && $_ ne 'svf' && $_ ne 'r' ? qq(<input name="$_" value="$params->{$_}" type="hidden" />) : (), keys %$params;
    my $options     = join '', map qq(<option value="$_->{'value'}"$_->{'selected'}>$_->{'name'}</option>), @locations;
    
    $location_info = "This feature maps to $count genomic locations" if (!defined($location_info));
    
    return (
      ['Location', $location_info],
      ['Selected location', sprintf(q(<div class="twocol-cell"><form action="%s" method="get">%s<select name="svf" class="fselect">%s</select> <input value="Go" class="fbutton" type="submit">%s</form>%s</div>),
        $hub->url({ svf => undef, sv => $name, source => $object->source_name }),
        $core_params,
        $options,
        $location_link
      )]
    );
  }
  
  my $current_svf = $mappings->{$svf};
  
  return ['Location', "$location$location_link".$self->get_outer_coordinates($current_svf).$self->get_inner_coordinates($current_svf)];
} 

sub get_outer_coordinates {
  my $self        = shift;
  my $svf         = shift;
  my $region      = $svf->{'Chr'};
  my $outer_start = defined $svf->{'outer_start'} ? $svf->{'outer_start'} : $svf->{'start'};
  my $outer_end   = defined $svf->{'outer_end'}   ? $svf->{'outer_end'}   : $svf->{'end'};
  
  return $outer_start == $svf->{'start'} && $outer_end == $svf->{'end'} ? '' : "<br />Outer coordinates: $region:$outer_start-$outer_end";
}


sub get_inner_coordinates {
  my $self        = shift;
  my $svf         = shift;
  my $region      = $svf->{'Chr'};
  my $inner_start = defined $svf->{'inner_start'} ? $svf->{'inner_start'} : $svf->{'start'};
  my $inner_end   = defined $svf->{'inner_end'}   ? $svf->{'inner_end'}   : $svf->{'end'};
  
  return $inner_start == $svf->{'start'} && $inner_end == $svf->{'end'} ? '' : "<br />Inner coordinates: $region:$inner_start-$inner_end";
}

sub size {
  my $self     = shift; 
  my $mappings = shift;
  my $SO_term  = shift;
  
  return () if (!$self->object->show_size);
  
  my $svf = $self->hub->param('svf');
  
  return () if (defined($mappings->{$svf}{'breakpoint_order'}));
  
  return $svf || scalar(keys %$mappings) == 1 ? ['Genomic size', sprintf('%s bp',
    $self->thousandify($mappings->{$svf}{'end'} - $mappings->{$svf}{'start'} + 1)
  )] : ();
}

sub get_strains {
  my $self   = shift;
  my $object = $self->object;
  my @strain;

  foreach my $svs (@{$object->Obj->get_all_StructuralVariationSamples}) {
    push(@strain,$svs->strain->name) if ($svs->strain);
  }

  return scalar @strain ? [ucfirst($self->hub->species_defs->STRAIN_TYPE), join(', ', @strain)] : ();
}

sub clinical_significance {
  my $self   = shift;
  my $object = $self->object;
  my $hub    = $self->hub;
  my $clin_sign = $object->clinical_significance;

  return unless (scalar(@$clin_sign));

  my $src = $self->img_url.'/16/info12.png';
  my $img = qq{<img src="$src" class="_ht" style="vertical-align:bottom;margin-bottom:2px;" title="Click to see all the clinical significances"/>};
  my $info_link = qq{<a href="/info/genome/variation/phenotype/phenotype_annotation.html#clin_significance" target="_blank">$img</a>};

  my %clin_sign_icon;
  foreach my $cs (@{$clin_sign}) {
    my $icon_name = $cs;
    $icon_name =~ s/ /-/g;
    $clin_sign_icon{$cs} = $icon_name;
  }

  my $url = $hub->url({
    type   => 'StructuralVariation',
    action => 'Evidence',
    sv     => $object->name,
    svf    => $hub->param('svf')
  });

  my $cs_content = join("",
    map {
      sprintf(
        '<a href="%s"><img class="_ht" style="margin-right:6px;margin-bottom:-2px;vertical-align:top" title="%s" src="%s/val/clinsig_%s.png" /></a>',
        $url, $_, $self->img_url, $clin_sign_icon{$_}
      )
    } @$clin_sign
  );

  return [ "Clinical significance $info_link" , $cs_content ];
}

1;
