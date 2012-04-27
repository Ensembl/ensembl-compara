# $Id$

package EnsEMBL::Web::Component::Variation_Context;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1); 
  $self->has_image(1);
}

sub content {
  my $self   = shift; 
  my $object = $self->object;
  
  ## first check we have a location
  return $self->_info('A unique location can not be determined for this variation', $object->not_unique_location) if $object->not_unique_location;
  
  my $hub           = $self->hub;
  my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor');
  my $width         = $hub->param('context') || 30000;
  my $width_max     = 1000000;
  my %mappings      = %{$object->variation_feature_mapping};  # first determine correct SNP location 
  my $vname         = $object->name;
  my $im_cfg        = 'snpview'; # Different display and image configuration between Variation and Structural Variation
  my ($v, $var_slice, $html);
  
  ($v) = values %mappings if keys %mappings == 1;
  
  # Structural variation 
  if ($object->isa('EnsEMBL::Web::Object::StructuralVariation')) {
    $im_cfg = 'structural_variation';
    $v    ||= $mappings{$hub->param('svf')};
  }  else { # Variation
    $v ||= $mappings{$hub->param('vf')};
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
  if ($length >= $width && $length <= $width_max) {
    my $new_width = ($length < ($width_max-int($width_max/5))) ? int($length/10) : int($length-$width_max/2);
    $img_start -= $new_width; 
    $img_end   += $new_width;
  } elsif ($length > $width_max) { # length Slice > Width max
    my $location  = "$seq_region:$img_start-$img_end";
       $img_end   = $img_start + $width_max -1; 
       $var_slice = 1;
    my $interval = $width_max/1000;
    
    my $overview_link = $hub->url({
      type     => 'Location',
      action   => 'Overview',
      r        => $location,
      sv       => $object->name,
      cytoview => 'variation_feature_structural=normal',
    });
 
   $html .= $self->_info(
      $object->type . ' has been truncated',
      sprintf('
        <p>
          This %s is too large to display in full, this image and tables below contain only the information relating to the first %s Kb of the feature. 
          To see the full length structural variation please use the <a href="%s">region overview</a> display.
        </p>
      ', $object->type, $interval, $overview_link)
    );
  } else { # context > length Slice
    $img_start -= int($width/2 - ($length/2)); 
    $img_end   += int($width/2 - ($length/2));
  }
  
  my $slice        = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $img_start, $img_end, 1);
  my $image_config = $hub->get_imageconfig($im_cfg);
  
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
 
  if ($length > $width_max){ # Variation truncated (slice very large)
    $var_slice = $slice;
    $html .= '<h2>Features overlapping the variation context:</h2><br />';
  } else {
    $var_slice = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $start, $end, 1);
    $html     .= "<h2>Features overlapping $vname:</h2><br />";
  }
  
  $html .= $self->structural_variation_table($slice, 'Structural variants',         'sv',  ['get_all_StructuralVariationFeatures','get_all_somatic_StructuralVariationFeatures'], 1);
  $html .= $self->structural_variation_table($slice, 'Copy number variants probes', 'cnv', ['get_all_CopyNumberVariantProbeFeatures']);
  $html .= $self->regulatory_feature_table($var_slice,  $vname, $image_config);
  $html .= $self->constrained_element_table($var_slice, $vname);
  
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
  
  return $self->toggleable_table('Regulatory features', 'reg', $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] }), 1);
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
      my $level = ucfirst $mlss->species_set_obj->get_tagvalue('name');
      
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
  
  return $self->toggleable_table('Constrained elements', 'cons', $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] }), 1);
}

1;
