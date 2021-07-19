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

package EnsEMBL::Web::ZMenu::StructuralVariation;

use strict;

use EnsEMBL::Draw::GlyphSet::structural_variation;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $svf        = $hub->param('svf');
  my $db         = $hub->param('vdb');
  my $click_data = $self->click_data;
  my @features;
  
  if ($click_data) {
    @features = @{EnsEMBL::Draw::GlyphSet::structural_variation->new($click_data)->features};
    @features = () if $svf && !(grep $_->dbID eq $svf, @features);
  }
  elsif (!$svf) {
    my $adaptor   = $hub->database($db)->get_StructuralVariationAdaptor;
    my @sv_names  = split ',', $hub->param('sv');

    for (0..$#sv_names) {
      push @features, @{$adaptor->fetch_by_name($sv_names[$_])->get_all_StructuralVariationFeatures};
    }
  }
  
  @features = $hub->database($db)->get_StructuralVariationFeatureAdaptor->fetch_by_dbID($svf) if $svf && !scalar @features;
  
  $self->feature_content($_) for @features;
}

sub feature_content {
  my ($self, $feature) = @_;
  my $hub         = $self->hub;
  my $variation   = $feature->structural_variation;
  my $sv_id       = $feature->variation_name;
  my $seq_region  = $feature->seq_region_name;
  my $start       = $feature->seq_region_start;
  my $end         = $feature->seq_region_end;
  my $class       = $variation->var_class;
  my $vstatus     = $variation->validation_status;
  my $study       = $variation->study;
  my $ssvs        = $variation->isa('Bio::EnsEMBL::Variation::SupportingStructuralVariation') ? [ $variation ] : $variation->get_all_SupportingStructuralVariants;
  my $description = $variation->source_description;
  my $position    = $start;
  my $length      = $end - $start;
  my $max_length  = ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1) * 1e6; 
  my ($pubmed_link, $location_link, $location_link_class, $study_name, $study_url, $is_breakpoint, @allele_types);
  
  $self->new_feature;
  
  if (defined $study) {
    $study_name  = $study->name;
    $description = $study->description;
    $study_url   = $study->url; 
  }
  
  if ($end < $start) {
    $position = "between $end & $start";
  } elsif ($end > $start) {
    $position = "$start-$end";
  }
  
  if (defined $feature->breakpoint_order && $feature->is_somatic == 1) {
    $is_breakpoint = 1;
  } elsif ($length > $max_length) {
    $location_link = $hub->url({
      type     => 'Location',
      action   => 'Overview',
      r        => "$start-$end",
      cytoview => sprintf('%s=normal', $variation->is_somatic ? 'somatic_sv_feature' : 'variation_feature_structural'),
    });
  } else {
    $location_link = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => "$seq_region:$start-$end",
    });
    $location_link_class = '_location_change _location_mark';
  }
  
  if ($description =~ /PMID/) {
    my @description_string = split (':', $description);
    my $pubmed_id          = pop @description_string;
       $pubmed_id          =~ s/\s+.+//g;
       $pubmed_link        = $hub->get_ExtURL('EPMC_MED', $pubmed_id);
  }    
  
  foreach my $ssv (@$ssvs) {
    my $a_type = $ssv->var_class;
    push @allele_types, $a_type unless grep $a_type eq $_, @allele_types;
  }
  
  @allele_types = sort @allele_types;
  
  $self->caption($class eq 'CNV_PROBE' ? 'CNV probe: ' : 'Structural variation: ' . $sv_id);

  # Display link to SV page only for the non private data
  if ($hub->param('vdb') eq 'variation') {
    $self->add_entry({
      label_html => "$sv_id properties",
      link       => $hub->url({
        type     => 'StructuralVariation',
        action   => 'Explore',
        sv       => $sv_id,
      })
    });
  }
  else {
    my $source = $feature->source_name;
    if ($source eq 'LOVD') {
      # http://varcache.lovd.nl/redirect/hg38.chr###ID### , e.g. for ID: 1:808922_808922(FAM41C:n.1101+570C>T)
       my $tmp_end = ($start>$end) ? $start+1 : $end;
       my $external_url = $hub->get_ExtURL_link("View in $source", 'LOVD', { ID => "$seq_region:$start\_$tmp_end($sv_id)" });
       $self->add_entry({
         label_html => $external_url
       });
    }
    elsif ($source =~ /DECIPHER/i) {
      my $sv_samples = $variation->get_all_StructuralVariationSamples; 
      my $individual = (scalar(@$sv_samples)) ? $sv_samples->[0]->strain->name : '';
      my $external_url = $hub->get_ExtURL_link("View in $source", 'DECIPHER', { ID => $individual });
      $self->add_entry({
        label_html => $external_url
      });
    }
    else {
      my $external_url = $hub->get_ExtURL_link("View in $source", uc($source));
      $self->add_entry({
        label_html => $external_url
      });
    }
  }  

  $self->add_entry({
    type  => 'Class',
    label => $class,
  });

  if (scalar @allele_types) {
    $self->add_entry({
      type  => 'Allele type' . (scalar @allele_types > 1 ? 's' : ''),
      label => join(', ', @allele_types),
    });
  }

  if ($is_breakpoint) {
    $self->add_entry({
      type       => 'Location',
      label_html => $self->get_locations($sv_id),
    });
  } else {
    $self->add_entry({
      type        => 'Location',
      label       => sprintf('%s: %s', $self->neat_sr_name($feature->slice->coord_system->name, $seq_region), $position),
      link        => $location_link,
      link_class  => $location_link_class
    });
  }
  
  if (defined $study_name) {
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
  
  if ($vstatus && ref $vstatus eq 'ARRAY' && $vstatus->[0]) {
    $self->add_entry({
      type  => 'Validation',
      label => join(',', @$vstatus),
    });    
  }

  # Display associated phenotype for private database
  if ($hub->param('vdb') ne 'variation') {
    my $phenotypes_list = $variation->get_all_PhenotypeFeatures;
    if (scalar(@$phenotypes_list)) {
      my $phenotypes = join(', ', map { $_->phenotype->description } @$phenotypes_list);
      $self->add_entry({
        type  => 'Phenotype'.(scalar @$phenotypes_list > 1 ? 's' : ''),
        label => $phenotypes,
      });
    }
  }
}

sub get_locations {
  my ($self, $sv_id) = @_;
	my $hub       = $self->hub;
	my $mappings  = $self->object->variation_feature_mapping;
  my $params    = $hub->core_params;
  my @locations = ({ value => 'null', name => 'None selected' });
  my ($global_location_info, $location_info);
	
  # add locations for each mapping
  foreach (sort { $mappings->{$a}{'Chr'} cmp $mappings->{$b}{'Chr'} || $mappings->{$a}{'start'} <=> $mappings->{$b}{'start'}} keys %$mappings) {
    my $region   = $mappings->{$_}{'Chr'}; 
    my $start    = $mappings->{$_}{'start'};
    my $end      = $mappings->{$_}{'end'};
    my $str      = $mappings->{$_}{'strand'};
    
    if (defined $mappings->{$_}{'breakpoint_order'}) {
      my @coords = ($start);
			push @coords, $end if $start != $end;
			
			foreach my $coord (@coords) {
        my $loc_text = "<b>$region:$coord</b>";
        my $loc_link = sprintf(
          '<a href="%s" class="constant">%s</a>',
          $hub->url({
            type             => 'Location',
            action           => 'View',
            r                => $region . ':' . ($coord - 500) . '-' . ($coord + 500),
            sv               => $sv_id,
            svf              => $_,
            contigviewbottom => 'somatic_sv_feature=normal'
          }), $loc_text
        );
        
        $loc_link .= '<br />(' . ($str > 0 ? 'forward' : 'reverse') . ' strand)';
        
        if (!$location_info) {
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
  
  return "$global_location_info$location_info";
}

1;
