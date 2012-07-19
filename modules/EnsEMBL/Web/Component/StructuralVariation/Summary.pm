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

  return sprintf qq{<div class="summary_panel">$failed%s</div>}, $self->new_twocol(
    ['Variation class', $object->class],
    $self->get_allele_types($source),
    $self->get_source($source, $object->source_description),
    $self->get_study,
    scalar(@$sv_sets) ? ['Present in', sprintf '<p><b>%s</b></p>', join(', ',@$sv_sets)] : (),
    $self->get_annotations,
    $self->location($mappings),
    $self->size($mappings),
    $validation ? ['Validation status', "<p>$validation</p>"] : ()
  )->render;
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

      $html .= sprintf('<p><span class="structural-variation-allele" style="background-color:%s"></span>%s</p>',
        $object->get_class_colour($SO_term),
        $ssv->var_class
      );
    }
  }

  return $html ? ['Allele type(s)', $html, 1] : ();
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
  $source      = "<p>$source_link - $description</p>";

  return ['Source', $source, 1];
}

sub get_study {
  my $self       = shift;
  my $object     = $self->object;
  my $study_name = $object->study_name;
  
  return unless $study_name;
  
  my $study_description = $self->add_pubmed_link($object->study_description);
  my $study_line        = sprintf '<a href="%s">%s</a>', $object->study_url, $study_name;
  
  return ['Study', "<p>$study_line - $study_description</p>", 1];
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
    my $core_params = join '', map $params->{$_} && $_ ne 'svf' && $_ ne 'r' ? qq(<input name="$_" value="$params->{$_}" type="hidden" />) : (), keys %$params;
    my $options     = join '', map qq(<option value="$_->{'value'}"$_->{'selected'}>$_->{'name'}</option>), @locations;
    
    $location_info = "This feature maps to $count genomic locations" if (!defined($location_info));
    
    return (
      ['Location', $location_info],
      ['Selected location', sprintf(q(<div class="twocol-cell"><form action="%s" method="get">%s<select name="svf" class="fselect">%s</select><input value="Go" class="fbutton" type="submit">%s</form>%s</div>),
        $hub->url({ svf => undef, sv => $name, source => $object->source }),
        $core_params,
        $options,
        $location_link
      ), 1]
    );
  }
  
  my $current_svf = $mappings->{$svf};

  return ['Location', sprintf("<p>$location$location_link%s%s</p>", $self->get_outer_coordinates($current_svf), $self->get_inner_coordinates($current_svf)), 1];
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
  
  return $svf || scalar(keys %$mappings) == 1 ? ['Genomic size', sprintf('%s bp%s',
    $self->thousandify($mappings->{$svf}{'end'} - $mappings->{$svf}{'start'} + 1),
    defined($mappings->{$svf}{'breakpoint_order'}) ? ' (breakpoint)' : ''
  )] : ();
}

sub get_annotations {
  my $self   = shift;
  my $object = $self->object;
  my @strain;

  foreach my $sva (@{$object->get_structural_variation_annotations}) {
    push(@strain,$sva->strain_name) if ($sva->strain_name);
  }

  return scalar @strain ? ['Strain', sprintf('<p>%s</p>', join(', ', @strain)), 1] : ();
}

1;
