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

package EnsEMBL::Web::Component::Variation_Context;

use strict;

use base qw(EnsEMBL::Web::Component::Shared);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1); 
  $self->has_image(1);
}

sub content {
  my $self   = shift; 
  my $hub    = $self->hub;
  my $object = $self->object || $hub->core_object(lc($hub->param('data_type')));
  
  ## first check we have a location
  return $self->_info('A unique location can not be determined for this variation', $object->not_unique_location) if $object->not_unique_location;
  
  my $hub                = $self->hub;
  my $slice_adaptor      = $hub->get_adaptor('get_SliceAdaptor');
  my $svf_adaptor        = $hub->database('variation')->get_StructuralVariationFeatureAdaptor;
  my $width              = $hub->param('context') || 30000;
  my $max_display_length = 1000000;
  my %mappings           = %{$object->variation_feature_mapping};  # first determine correct SNP location 
  my $vname              = $object->name;
  my $im_cfg             = 'snpview'; # Different display and image configuration between Variation and Structural Variation
  my ($v, $feature_start, $feature_end, $var_slice, $html);
  
  ($v) = values %mappings if keys %mappings == 1;
  

  # Structural variation 
  if ($object->isa('EnsEMBL::Web::Object::StructuralVariation')) {
    $im_cfg = 'structural_variation';
    my $svf_id = $hub->param('svf');
    $max_display_length = $object->max_display_length;

    $feature_start = $mappings{$svf_id}{'start'} <= $mappings{$svf_id}{'end'} ? $mappings{$svf_id}{'start'} : $mappings{$svf_id}{'end'};
    $feature_end   = $mappings{$svf_id}{'start'} <= $mappings{$svf_id}{'end'} ? $mappings{$svf_id}{'end'}   : $mappings{$svf_id}{'start'};

    # Somatic Breakpoints
    if ( $svf_id && $mappings{$svf_id}{breakpoint_order} && $object->is_somatic == 1 && $v){
      my @locations;
      my $region = $mappings{$svf_id}{'Chr'}; 
      my $start  = $mappings{$svf_id}{'start'};
      my $end    = $mappings{$svf_id}{'end'};
      my $str    = $mappings{$svf_id}{'strand'};
        
      my $bpf = ($hub->param('bpf')) ? $hub->param('bpf') : $svf_id.'from';
        
      push @locations, {
          value    => $svf_id.'from',
          name     => sprintf('%s (%s strand)', "$region:$start", ($str > 0 ? 'forward' : 'reverse')),
          selected => $svf_id.'from' eq $bpf ? ' selected' : ''
      };
      push @locations, {
          value    => $svf_id.'to',
          name     => sprintf('%s (%s strand)', "$region:$end", ($str > 0 ? 'forward' : 'reverse')),
          selected => $svf_id.'to' eq $bpf ? ' selected' : ''
      };
      
      my $params    = $hub->core_params;
      my $core_params = join '', map $params->{$_} && $_ ne 'svf' && $_ ne 'r' ? qq(<input name="$_" value="$params->{$_}" type="hidden" />) : (), keys %$params;
      my $options     = join '', map qq(<option value="$_->{'value'}"$_->{'selected'}>$_->{'name'}</option>), @locations;
    
      $html .= qq{<div style="margin-bottom:20px"><div style="font-weight:bold;margin-right:20px;vertical-align:middle;float:left">Selected breakpoint</div>};
      $html .= sprintf(q(<form action="%s" method="get">%s<select name="bpf" class="fselect">%s</select> <input value="Go" class="fbutton" type="submit"></form>),
        $hub->url({ svf => undef, sv => $vname, source => $object->source_name }),
        $core_params,
        $options
      ); 
      $html .= qq{</div>};
      
      if ($hub->param('bpf')) {
        $v->{'end'}   = $mappings{$svf_id}{start} if ($hub->param('bpf') =~ /from/) ;
        $v->{'start'} = $mappings{$svf_id}{end} if ($hub->param('bpf') =~ /to/) ;
      } else {
        $v->{'end'} = $mappings{$svf_id}{start};
      }
    } else {
      $v ||= $mappings{$svf_id};
    }
  } else { # Variation
    
    my $vf_id = $hub->param('vf');
    $v ||= $mappings{$vf_id};

    $feature_start = $mappings{$vf_id}{'start'} <= $mappings{$vf_id}{'end'} ? $mappings{$vf_id}{'start'} : $mappings{$vf_id}{'end'};
    $feature_end   = $mappings{$vf_id}{'start'} <= $mappings{$vf_id}{'end'} ? $mappings{$vf_id}{'end'}   : $mappings{$vf_id}{'start'};
  }
  
  return $self->_info('Display', "<p>Unable to draw SNP neighbourhood as we cannot uniquely determine the variation's location</p>") unless $v;

  my $seq_region = $v->{'Chr'};
  my $seq_type   = $v->{'type'};
  my $start      = $v->{'start'} <= $v->{'end'} ? $v->{'start'} : $v->{'end'};
  my $end        = $v->{'start'} <= $v->{'end'} ? $v->{'end'}   : $v->{'start'};   
  my $length     = $end - $start + 1;
  my $img_start  = $start;
  my $img_end    = $end;
  
  # Width max > length Slice > context
  if ($length >= $width && $length <= $max_display_length) {
    my $new_width = ($length < ($max_display_length-int($max_display_length/5))) ? int($length/10) : int($length-$max_display_length/2);
    $img_start -= $new_width; 
    $img_end   += $new_width;
  } elsif ($length > $max_display_length) { # length Slice > Width max
    return $self->feature_is_too_long($seq_region,$start,$end,$max_display_length,'display');
  } else { # context > length Slice
    $img_start -= int($width/2 - ($length/2)); 
    $img_end   += int($width/2 - ($length/2));
  }
  
  my $slice        = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $img_start, $img_end, 1);
  my $image_config = $hub->get_imageconfig($im_cfg);
  
  if ($object->isa('EnsEMBL::Web::Object::Variation') && $object->Obj->failed_description) {
    $image_config->modify_configs(
      [ 'variation_set_fail_all' ],
      { display => 'normal' }
    );
  }
  
  
  my $sv_count = scalar(@{$svf_adaptor->fetch_all_by_Slice($slice)});
    
  $html .= $self->_warning(
    "Structural variants display",
    sprintf('
      <p>
        There are %s structural variants overlapping this region. 
        Some of them might not be displayed as we limit the size of each structural variation track to 100 rows.
      </p>
      ', $sv_count)
  ) if $sv_count > 100;
  
  
  $image_config->set_parameters( {
    image_width     => $self->image_width || 900,
    container_width => $slice->length,
    slice_number    => '1|1',
  });
  
  my $image = $self->new_image($slice, $image_config, [ $object->name ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'transcript';
  $image->set_button('drag', 'title' => 'Drag to select region');
 
  $html .= $image->render;
 
  # Calculate the real length of the feature (i.e. in case of SV with breakpoints we used to display each of them, with a length of 1)
  my $real_feature_length = $feature_end - $feature_start + 1;
  if ($real_feature_length > $max_display_length){ # Variation truncated (slice very large)
    return $html.$self->feature_is_too_long($seq_region,$feature_start,$feature_end,$max_display_length,'table');
  } else {
    $var_slice = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $start, $end, 1);
    $html     .= "<h2>Features overlapping $vname:</h2>";
  }
  
  $html .= $self->structural_variation_table($slice, 'Structural variants',        'sv',  ['fetch_all_by_Slice','fetch_all_somatic_by_Slice'], 1);
  $html .= $self->structural_variation_table($slice, 'Copy number variant probes', 'cnv', ['fetch_all_cnv_probe_by_Slice']);
  $html .= $self->regulatory_feature_table($var_slice,  $vname, $image_config) if $hub->species_defs->databases->{'DATABASE_FUNCGEN'};
  $html .= $self->constrained_element_table($var_slice, $vname) unless $SiteDefs::NO_COMPARA;
  
  return $html;
}


sub regulatory_feature_table {
  my ($self, $slice, $v, $image_config) = @_;
  my $hub = $self->hub;
  my $fsa = $hub->get_adaptor('get_FeatureSetAdaptor', 'funcgen');
  my $rows;
  
  my $columns = [
    { key => 'id',         sort => 'string',        title => 'Name'              },
    { key => 'location',   sort => 'position_html', title => 'Chr:bp'            },
    { key => 'bound',      sort => 'numeric',       title => 'Bound coordinates' },
    { key => 'type',       sort => 'string',        title => 'Type'              },
    { key => 'featureset', sort => 'string',        title => 'Feature set'       },
  ];
  
  if ($fsa) {
    foreach my $set (@{$fsa->fetch_all_by_feature_class('regulatory')}) {
      my $set_name = (split /\s+/, $set->display_label)[-1];

      # check if this feature set is switched on in the image config
      if ($image_config->get_node('functional')->get_node("reg_feats_$set_name")) {
        foreach my $rf (@{$set->get_Features_by_Slice($slice)}) {
          my $stable_id   = $rf->stable_id;
          my $region_name = $rf->seq_region_name;
          my $loc_string  = "$region_name:" . ($slice->start + $rf->bound_start - 1) . '-' . ($slice->start + $rf->bound_end - 1);
          
          my $rf_link = $hub->url({
            type   => 'Regulation',
            action => 'Summary',
            fdb    => 'funcgen',
            r      => undef,
            rf     => $stable_id,
          });
          
          my $loc_link  = $hub->url({
            type             => 'Location',
            action           => 'View',
            r                => $loc_string,
            contigviewbottom => "reg_feats_$set_name=normal",
          });
          
          push @$rows, {
            id         => qq{<a href="$rf_link">$stable_id</a>},
            location   => qq{<a href="$loc_link">$region_name:} . $rf->seq_region_start . '-' . $rf->seq_region_end . '</a>',
            bound      => qq{<a href="$loc_link">$loc_string</a>},
            type       => $rf->feature_type->name,
            featureset => $set->display_label,
          };
        }
      }
    }
  }

  return '' if ( !$rows || scalar(@{$rows}) < 1 );
  
  return $self->toggleable_table('Regulatory features', 'reg', $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ], data_table_config => {iDisplayLength => 25} }), 1);
}

sub constrained_element_table {
  my ($self, $slice, $v) = @_;
  my $hub               = $self->hub;
  my $mlssa             = $hub->get_adaptor('get_MethodLinkSpeciesSetAdaptor', 'compara');
  my $cea               = $hub->get_adaptor('get_ConstrainedElementAdaptor',   'compara');
  my $slice_start       = $slice->start;
  my $slice_region_name = $slice->seq_region_name;
  my $rows;
  
  my $columns = [
    { key => 'location', sort => 'position_html', title => 'Chr:bp'          },
    { key => 'score',    sort => 'numeric',       title => 'Score'           },
    { key => 'p-value',  sort => 'numeric',       title => 'p-value'         },
    { key => 'level',    sort => 'string',        title => 'Taxonomic level' },
  ];
  
  if ($mlssa && $cea) {
    foreach my $mlss (@{$mlssa->fetch_all_by_method_link_type('GERP_CONSTRAINED_ELEMENT')}) {
      my $level = ucfirst $mlss->species_set->name;
      
      foreach my $ce (@{$cea->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice)}) {
        my $loc_string = $slice_region_name . ':' . ($slice_start + $ce->start - 1) . '-' . ($slice_start + $ce->end - 1);
        
        push @$rows, {
          'location' => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Location', action => 'View', r => $loc_string }), $loc_string),
          'score'    => $ce->score,
          'p-value'  => $ce->p_value,
          'level'    => $level,
        };
      }
    }
  }

  return '' if ( !$rows || scalar(@{$rows}) < 1 );
  
  return $self->toggleable_table('Constrained elements', 'cons', $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ], data_table_config => {iDisplayLength => 25} }), 1);
}


sub feature_is_too_long {
  my $self            = shift;
  my $seq_region      = shift;
  my $start           = shift;
  my $end             = shift;
  my $max_displayable = shift;
  my $htype           = shift;
  my $hub             = $self->hub;
  my $object          = $self->object || $hub->core_object(lc($hub->param('data_type')));
  my $type            = lc($object->type);
  
  $htype ||= 'display';
  $type =~ s/structuralv/structural v/;
  $type =~ s/variation/variant/;

  my $region          = "$seq_region:$start-$end";
  my $max_display_end = $start + $max_displayable - 1;

  my $region_overview_url = $hub->url({
       type   => 'Location',
       action => 'Overview',
       db     => 'core',
       r      => $region,
       sv     => $hub->param('sv'),
       svf    => $hub->param('svf'),
       cytoview => 'variation_feature_structural_smaller=compact,variation_feature_structural_larger=gene_nolabel'
  });
  my $region_detail_url = $hub->url({
       type   => 'Location',
       action => 'View',
       db     => 'core',
       r      => "$seq_region:$start-$max_display_end",
       sv     => $hub->param('sv'),
       svf    => $hub->param('svf'),
       contigviewbottom => 'variation_feature_structural_smaller=gene_nolabel,variation_feature_structural_larger=gene_nolabel'
  });

  my %header_text = ( 'display' => 'for this display',
                      'table'   => 'to display the list of overlapping features/elements'
                    );

  my $warning_header = sprintf('The %s is too long %s (more than %sbp)', $type, $header_text{$htype}, $self->thousandify($max_displayable));
  my $warning_content = qq{Please, view the list of overlapping genes, transcripts and structural variants in the <a href="$region_overview_url">Region overview</a> page};
  my $warning_content_end = sprintf('.<br />The context of the first %sbp of the structural variant is available in the <a href="%s">Region in detail</a> page.',
                                    $self->thousandify($max_displayable),$region_detail_url
                                   );
  if ($hub->species_defs->ENSEMBL_MART_ENABLED) {
    my @species = split('_',lc($hub->species));
    my $mart_dataset = substr($species[0],0,1).$species[1].'_gene_ensembl';
    my $mart_url = sprintf( '/biomart/martview?VIRTUALSCHEMANAME=default'.
                            '&ATTRIBUTES=%s.default.feature_page.ensembl_gene_id|%s.default.feature_page.ensembl_transcript_id|'.
                            '%s.default.feature_page.strand|%s.default.feature_page.ensembl_peptide_id'.
                            '&FILTERS=%s.default.filters.chromosomal_region.%s:%i:%i:1&VISIBLEPANEL=resultspanel',
                            $mart_dataset,$mart_dataset,$mart_dataset,$mart_dataset,$mart_dataset,$seq_region, $start, $end
                          );
    $warning_content .= qq{ or in <a href="$mart_url">BioMart</a>};
  }
  return $self->_warning( $warning_header, $warning_content.$warning_content_end );
}

1;
