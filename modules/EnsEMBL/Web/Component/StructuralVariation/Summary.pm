# $Id$

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
  my $source       = $object->source;
  my $mappings     = $object->variation_feature_mapping;
  my $validation   = $object->validation_status;
  my $failed       = $object->Obj->failed_description ? $self->failed() : ''; ## First warn if the SV has been failed
  my $sv_sets      = $object->get_variation_set_string;
  my $summary      = sprintf '<dt>Variation class</dt><dd>%s</dd>', $object->class;
     $summary     .= $self->get_allele_types($source);
     $summary     .= $self->get_source($source, $object->source_description);
     $summary     .= $self->get_study; 
     $summary     .= "<dt>Present in </dt><dd><b>".join(', ',@$sv_sets)."</b></dd>" if scalar(@$sv_sets);
     $summary     .= $self->get_annotations;
     $summary     .= $self->location($mappings);
     $summary     .= $self->size($mappings);
     $summary     .= "<dt>Validation status</dt><dd>$validation</dd>" if $validation; 
  return qq{
    <div class="summary_panel">
      $failed
      <dl class="summary">
        $summary
      </dl>
    </div>
  };
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
      
      my $colour = $object->get_class_colour($SO_term);
      my $class  = $ssv->var_class;
         $html  .= qq{<td style="width:5px"></td>} if $html;
         $html  .= qq{
          <td style="vertical-align:middle">
            <table style="border-spacing:0px"><tr><td style="background-color:$colour;width:7px;height:7px"></td></tr></table>
          </td>
          <td style="padding-left:2px">$class</td>
        };
    }
  }
  
  $html = qq{<dt>Allele type(s)</dt><dd><table style="border-spacing:0px"><tr>$html</tr></table></dd>} if $html;
  
  return $html;
}


sub get_source {
  my $self        = shift;
  my $source      = shift; 
  my $description = shift;
  my $hub         = $self->hub;
  my $source_link = $source;
  
  if ($source eq 'DGVa') {
    $source_link = $hub->get_ExtURL_link($source, 'DGVA', $source);
  } elsif ($source =~ /affy/i ) {
    $source_link = $hub->get_ExtURL_link($source, 'AFFYMETRIX', $source);
  } elsif ($source =~ /illumina/i) {
    $source_link = $hub->get_ExtURL_link($source, 'ILLUMINA', $source);
  }
  
  $description = $self->add_pubmed_link($description);
  $source      = "$source_link - $description";
  
  return qq{<dt>Source</dt><dd>$source</dd>};
}

sub get_study {
  my $self       = shift;
  my $object     = $self->object;
  my $study_name = $object->study_name;
  
  return unless $study_name;
  
  my $study_description = $self->add_pubmed_link($object->study_description);
  my $study_line        = sprintf '<a href="%s">%s</a>', $object->study_url, $study_name;
  
  return qq{<dt>Study</dt><dd>$study_line - $study_description</dd>};
}

# Method to add a pubmed link to the expression "PMID:xxxxxxx"
# in the source or study description, if it is present.
sub add_pubmed_link {
  my $self        = shift;
  my $description = shift;
  my $hub         = $self->hub;
  
  if ($description =~ /PMID/) { 
    my @temp = split /\s/, $description;
    
    foreach (@temp) {
      if (/PMID/) {
        (my $id = $_)   =~ s/PMID://; 
        my $pubmed_url  = $hub->get_ExtURL_link($_, 'PUBMED', $id); 
           $description =~ s/$_/$pubmed_url/;
      }
    }
  }
  
  return $description;
}

sub location { 
  my $self     = shift;
  my $mappings = shift;
  my $object   = $self->object;
  my $count    = scalar keys %$mappings;
  
  return '<dl class="summary"><dt>Location</dt><dd>This feature has not been mapped.</dd></dl>' unless $count;
  
  my $hub  = $self->hub;
  my $svf  = $hub->param('svf');
  my $name = $object->name;
  my ($location_link, $html, $location);
  
  if ($svf) {
    my $type     = $mappings->{$svf}{'Type'};
    my $region   = $mappings->{$svf}{'Chr'}; 
    my $start    = $mappings->{$svf}{'start'};
    my $end      = $mappings->{$svf}{'end'};
       $location = ucfirst(lc $type).' <b>'.($start == $end ? "$region:$start" : "$region:$start-$end") . '</b> (' . ($mappings->{$svf}{'strand'} > 0 ? 'forward' : 'reverse') . ' strand)';
    
    $location_link = sprintf(
      ' | <a href="%s">View in location tab</a>',
      $hub->url({
        type              => 'Location',
        action            => 'View',
        r                 => $region . ':' . ($start - 500) . '-' . ($end + 500),
        sv                => $name,
        svf               => $svf,
        contigviewbottom  => 'variation_feature_structural=normal'
      })
    );
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
       
      if (defined($bp_order)) {
      
        my $loc_text = '<b>'.($start == $end ? "$region:$start" : "$region:$start-$end"). '</b>';
        
            
        my $loc_link = sprintf(
          '<a href="%s">%s</a>',
            $hub->url({
              type              => 'Location',
              action            => 'View',
              r                 => $region . ':' . ($start - 500) . '-' . ($end + 500),
              sv                => $name,
              svf               => $svf,
              contigviewbottom  => 'somatic_sv_feature=normal'
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
    my $core_params = join '', map $params->{$_} && $_ ne 'svf' && $_ ne 'r' ? qq{<input name="$_" value="$params->{$_}" type="hidden" />} : (), keys %$params;
    my $options     = join '', map qq{<option value="$_->{'value'}"$_->{'selected'}>$_->{'name'}</option>}, @locations;
    
    $location_info = "This feature maps to $count genomic locations" if (!defined($location_info));
    
    $html = sprintf('
      %s
      </dd>
      <dt>Selected location</dt>
      <dd>
        <form action="%s" method="get">
          %s
          <select name="svf" class="fselect">
            %s
          </select>
          <input value="Go" class="fbutton" type="submit">
          %s
        </form>
      </dd>',
      $location_info,
      $hub->url({ svf => undef, sv => $name, source => $object->source }),
      $core_params,
      $options,
      $location_link
    );
  } else {
    my $current_svf = $mappings->{$svf};
    
    $html .= "$location$location_link";
    $html .= $self->get_outer_coordinates($current_svf);
    $html .= $self->get_inner_coordinates($current_svf);
  }
  
  return qq{<dt>Location</dt><dd>$html</dd>};
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
  my $svf      = $self->hub->param('svf');
  
  return sprintf ('<dt>Genomic size</dt><dd>%s bp%s</dd>', 
                  $self->thousandify($mappings->{$svf}{'end'} - $mappings->{$svf}{'start'} + 1), 
                  defined($mappings->{$svf}{'breakpoint_order'}) ? ' (breakpoint)' : ''
                 ) if $svf || scalar(keys %$mappings) == 1;
}

sub get_annotations {
  my $self   = shift;
  my $object = $self->object;
  my @strain;
  my $html;
  foreach my $sva (@{$object->get_structural_variation_annotations}) {
    push(@strain,$sva->strain_name) if ($sva->strain_name);
  }
  $html .= '<dt>Strain</dt><dd>'.join(', ',@strain).'</dd>' if (scalar @strain);
  
  return $html;
}

1;
