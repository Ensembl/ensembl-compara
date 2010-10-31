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
  my %mappings      = %{$object->variation_feature_mapping};  # first determine correct SNP location 
  my $v;
  
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
  my $start = $v->{'start'} <= $v->{'end'} ? $v->{'start'} : $v->{'end'};
  my $end = $v->{'start'} << $v->{'end'} ? $v->{'end'} : $v->{'start'};   
  $start -= ($width/2); 
  $end += ($width/2);
  my $seq_type = $v->{'type'};
  my $slice      = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $start, $end, 1);
  my $sliceObj   = $self->new_object('Slice', $slice, $object->__data);

  my ($count_snps, $filtered_snps)       = $sliceObj->getVariationFeatures;
  my ($genotyped_count, $genotyped_snps) = $sliceObj->get_genotyped_VariationFeatures;

  my $image_config = $hub->get_imageconfig('snpview'); 
  
  $image_config->set_parameters( {
    image_width     => $self->image_width || 900,
    container_width => $slice->length,
    slice_number    => '1|1',
  });

  $image_config->{'snps'}           = $filtered_snps;
  $image_config->{'genotyped_snps'} = $genotyped_snps;
  $image_config->{'snp_counts'}     = [ $count_snps + $genotyped_count, scalar @$filtered_snps + scalar @$genotyped_snps ];

  
  my $image = $self->new_image($slice, $image_config, [ $object->name ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'transcript';
  $image->set_button('drag', 'title' => 'Drag to select region');
 
  my $html = $image->render;
 
  my $var_slice = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $v->{'start'}, $v->{'end'}, 1);
  
  $html .= '<h2>Overlapping features</h2>';
  
  # structural variation table
  $html .= '<h3>Structural variants</h3>';
  $html .= $self->structural_variation_table($var_slice);

  # sequence variation table
  $html .= '<h3>Sequence variants</h3>';
  $html .= $self->sequence_variation_table($var_slice);

  # regulatory region table
  $html .= '<h3>Regulatory features</h3>';
  $html .= $self->regulatory_feature_table($var_slice);
  
  # constrained elements table
  $html .= '<h3>Constrained elements</h3>';
  $html .= $self->constrained_element_table($var_slice);
  
  return $html;
}

sub structural_variation_table{
  my $self   = shift;
  my $slice  = shift;
  my $hub    = $self->hub;
  my $v      = $self->object->name;
  my $svs    = $slice->get_all_StructuralVariations;
 
  my $columns = [
     { key => 'id',          sort => 'string',        title => 'Name'   },
     { key => 'location',    sort => 'position_html', title => 'Chr:bp' },
     { key => 'class',       sort => 'string',        title => 'Class'  },
     { key => 'source',      sort => 'string',        title => 'Source' },
     { key => 'description', sort => 'string',        title => 'Source description', width => '40%' },
  ];
  
  my $rows;
  
  if (defined $svs) {
    foreach my $sv (@$svs) {
      next if $sv->variation_name eq $v;
      # make PMID link for description
      my $description = $sv->source_description;
      my $pubmed_link;
      
      if ($description =~ /PMID/) {
        my @description_string = split ':', $description;
        my $pubmed_id          = pop @description_string;
        
        $pubmed_id   =~ s/\s+.+//g;
        $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
        $description =~ s/$pubmed_id/'<a href="'.$pubmed_link.'" target="_blank">'.$&.'<\/a>'/eg;
      }
      my $name = $sv->variation_name;
      my $sv_link = $hub->url({
        type    => 'StructuralVariation',
        action  =>  'Summary',
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
        class       => $sv->class,
        source      => $sv->source,
        description => $description,
      );
      
      push @$rows, \%row;
    }
  }
   
  return $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
}

sub sequence_variation_table {
 my $self   = shift;
  my $slice  = shift;
  my $hub    = $self->hub;
  my $v      = $self->object->name;
  my $vfs    = $slice->get_all_VariationFeatures;

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
  
  if (defined $vfs){
    foreach my $vf (@$vfs){
      next if $vf->variation_name eq $v;
      
      my $name = $vf->variation_name;
      my $vf_dbid = $vf->dbID;
      my $vf_link = $hub->url({
        type    => 'Variation',
        action  =>  'Summary',
        v       => $name,
        vf      => $vf_dbid
      });

      my $loc_string = $vf->slice->seq_region_name . ':' . $vf->slice->start . '-' . $vf->slice->end;

      my $loc_link = $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $loc_string,
      });

     my $validation        = $vf->get_all_validation_states || [];
    
        
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
  }

  return $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
}

sub regulatory_feature_table{
  my $self  = shift;
  my $slice = shift;
  my $hub   = $self->hub;
  my $v     = $self->object->name;
  
  my $columns = [
    { key => 'id',         sort => 'string',        title => 'Name'              },
    { key => 'location',   sort => 'position_html', title => 'Chr:bp'            },
    { key => 'bound',      sort => 'numerical',     title => 'Bound coordinates' },
    { key => 'type',       sort => 'string',        title => 'Type'              },
    { key => 'featureset', sort => 'string',        title => 'Feature set'       },
  ];
  
  my $rows;
  my $fsa = $hub->get_adaptor('get_FeatureSetAdaptor', 'funcgen');
  
  # get image config
  my $image_config = $hub->get_imageconfig('snpview');
  
  if (defined $fsa) {
    foreach my $set(@{$fsa->fetch_all_by_feature_class('regulatory')}) {
      my $set_name = (split /\s+/, $set->display_label)[-1];
      
      # check if this feature set is switched on in the image config
      if (defined $image_config->get_node('functional')->get_node("reg_feats_$set_name")) {
         if ($image_config->get_node('functional')->get_node("reg_feats_$set_name")->get('display') eq 'normal') {
           foreach my $rf (@{$set->get_Features_by_Slice($slice)}) {
             my $rf_link = $hub->url({
               type   => 'Regulation',
               action => 'Summary',
               fdb    => 'funcgen',
               r      => undef,
               rf     => $rf->stable_id,
             });
             
             my $loc_string = $rf->seq_region_name . ':' . ($slice->start + $rf->bound_start - 1) . '-' . ($slice->start + $rf->bound_end - 1);
             
             my $loc_link = $hub->url({
               type             => 'Location',
               action           => 'View',
               r                => $loc_string,
               contigviewbottom => "reg_feats_$set_name=normal",
             });
             
             push @$rows, {
               id         => qq{<a href="$rf_link">}  . $rf->stable_id . '</a>',
               location   => qq{<a href="$loc_link">} . $rf->seq_region_name . ':' . $rf->seq_region_start . '-' . $rf->seq_region_end . '</a>',
               bound      => qq{<a href="$loc_link">$loc_string</a>},
               type       => $rf->feature_type->name,
               featureset => $set->display_label,
             };
          }
        }
      }
    }
  }
  
  return $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
}

sub constrained_element_table {
  my $self  = shift;
  my $slice = shift;
  my $hub   = $self->hub;
  my $v     = $self->object->name;
  
  my $mlssa = $hub->get_adaptor('get_MethodLinkSpeciesSetAdaptor', 'compara');
  my $cea   = $hub->get_adaptor('get_ConstrainedElementAdaptor',   'compara');
  
  my $columns = [
    { key => 'location', sort => 'position_html', title => 'Chr:bp'          },
    { key => 'score',    sort => 'numeric',       title => 'Score'           },
    { key => 'p-value',  sort => 'numeric',       title => 'p-value'         },
    { key => 'level',    sort => 'string',        title => 'Taxonomic level' },
  ];
  
  my $rows;
  
  if (defined $mlssa && defined $cea) {
    foreach my $mlss (@{$mlssa->fetch_all_by_method_link_type('GERP_CONSTRAINED_ELEMENT')}) {
      foreach my $ce (@{$cea->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice)}) {
        my $loc_string = $ce->slice->seq_region_name . ':' . ($slice->start + $ce->start - 1) . '-' . ($slice->start + $ce->end - 1);
        
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
  
  return $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
}

1;
