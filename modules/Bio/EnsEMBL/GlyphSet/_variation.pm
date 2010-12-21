package Bio::EnsEMBL::GlyphSet::_variation;

use strict;

use Bio::EnsEMBL::Variation::VariationFeature;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { 
  my $self = shift;  
  my $label = $self->{'my_config'}->id =~/somatic/ ?'Somatic Mutations' : 'Variations'; 
  return $label; 
}

sub features {
  my $self         = shift;
  my $max_length   = $self->my_config('threshold') || 1000;
  my $slice_length = $self->{'container'}->length;
  
  if ($slice_length > $max_length * 1010 ) {
    $self->errorTrack("Variation features are not displayed for regions larger than ${max_length}Kb");
  } else {
    return $self->fetch_features;
  }
}

sub check_set {
  my ($self, $f, $sets) = @_; 
  
  foreach (@{$f->get_all_VariationSets}) {
    return 1 if $sets->{$_->name};
  }
  
  return 0;
}

sub check_source {
  my ($self, $f, $sources) = @_;
  
  foreach (@{$f->get_all_sources}) { 
    return 1 if $sources->{$_};
  }
  
  return 0;
}

sub fetch_features {
  my ($self) = @_;

  if (!$self->cache($self->{'my_config'}->id)) {
    # different retrieval method for somatic mutations
    if( $self->{'my_config'}->id =~/somatic/){
      my @somatic_mutations;
      if ($self->my_config('filter')){ 
        @somatic_mutations = 
        #grep { $_->map_weight < 4 }
        @{$self->{'container'}->get_all_somatic_VariationFeatures_with_annotation(undef, undef, $self->my_config('filter')) || []};

      } else { 
        @somatic_mutations = @{$self->{'container'}->get_all_somatic_VariationFeatures || []};
      }
      $self->cache($self->{'my_config'}->id, \@somatic_mutations);   
    } else { # get standard variations
      my $sources = $self->my_config('sources'); 
         $sources = { map { $_ => 1 } @$sources } if $sources; 
      my $sets    = $self->my_config('sets');
         $sets    = { map { $_ => 1 } @$sets } if $sets;
      my %ct      = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;
     
      my @vari_features;  
      if ($self->{'my_config'}->id =~/set/){
        my $track_set = $self->{'my_config'}->id; 
        $track_set =~s/variation_set_//;
        my $set_object = $self->{'container'}->adaptor->db->get_db_adaptor('variation')->get_VariationSetAdaptor->fetch_by_name($track_set); 
        @vari_features =  @{$self->{'container'}->get_all_VariationFeatures_by_VariationSet($set_object) || []}; 
      } else {
        my @temp_variations =  @{$self->{'container'}->get_all_VariationFeatures($self->my_config('filter')) || []};  
        ## Add a filtering step here
        @vari_features =
          map  { $_->[1] }                                                ## Quick indexing schwartzian transform
          sort { $a->[0] <=> $b->[0] }                                    ## to make sure that "most functional" snps appear first
          map  { [ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] }
          grep { $sources ? $self->check_source($_, $sources) : 1 }       ## If sources filter by source
          grep { $sets ? $self->check_set($_, $sets) : 1 }                ## If sets filter by set
          #grep { $_->map_weight < 4 }
          @temp_variations;
      }

      $self->cache($self->{'my_config'}->id, \@vari_features);
    }
  }

  my $snps = $self->cache($self->{'my_config'}->id) || [];

  foreach my $f (@$snps) {
    my $config  = $self->{'config'};
    my $colours = $self->my_config('colours');
    my $type    = lc $f->display_consequence; 

    if (!$config->{'variation_types'}{$type}) {
      push @{$config->{'variation_legend_features'}->{'variations'}->{'legend'}}, $colours->{$type}->{'text'}, $colours->{$type}->{'default'};
      $config->{'variation_types'}{$type} = 1;
    }
  }
  
  return $snps;
}

sub colour_key {
  my ($self, $f) = @_;
  return lc $f->display_consequence;
}

sub title {
  my ($self, $f) = @_;
  my $vid     = $f->variation_name;
  my $type    = $f->display_consequence;
  my $dbid    = $f->dbID;
  my ($s, $e) = $self->slice2sr($f->start, $f->end);
  my $loc     = $s == $e ? $s : $s <  $e ? "$s-$e" : "Between $s and $e";
  
  return "Variation: $vid; Location: $loc; Consequence: $type; Ambiguity code: ". $f->ambig_code;
}

sub href {
  my ($self, $f)  = @_;
  
  return $self->_url({
    species  => $self->species,
    type     => 'Variation',
    action   => 'Variation',
    v        => $f->variation_name,
    vf       => $f->dbID,
    snp_fake => 1
  });
}

sub feature_label {
  my ($self, $f) = @_;
  my $ambig_code = $f->ambig_code;
  return $ambig_code eq '-' ? undef : ($ambig_code, 'overlaid');
}

sub tag {
  my ($self, $f) = @_;
  
  if ($self->my_config('style') eq 'box') {
    my $style        = $f->start > $f->end ? 'left-snp' : $f->var_class eq 'in-del' ? 'delta' : 'box';
    my $letter       = $style eq 'box' ? $f->ambig_code : "";
    my $colour_key   = $self->colour_key($f); 
    my $label_colour = $self->my_colour($colour_key, 'label');
       $label_colour = 'black' if $label_colour eq $self->my_colour($colour_key);

    return {
      style        => $style,
      colour       => $self->my_colour($colour_key),
      letter       => $style eq 'box' ? $f->ambig_code : '',
      label_colour => $label_colour
    };
  }
  
  return ({ style => 'insertion', colour => $self->my_colour(lc $f->display_consequence) }) if $f->start > $f->end;
}

sub highlight {
  my $self = shift; 
  my ($f, $composite, $pix_per_bp, $h, $hi_colour) = @_;
  
  return if $self->my_config('style') ne 'box'; 
  
  ## Get highlights
  my %highlights;
  @highlights{$self->highlights} = (1);

  if ($self->{'config'}->core_objects->{'variation'}){
    my $var_id = $self->{'config'}->core_objects->{'variation'}->name;
    $var_id =~ s/rs//;  
    $highlights{$var_id} = 1;
  }

  # Are we going to highlight self item
  my $id = $f->variation_name;  
     $id =~ s/^rs//;
 
  return unless $highlights{$id} || $highlights{"rs$id"};
 
  
  $self->unshift(
    $self->Rect({ # First a black box
      x         => $composite->x - 2/$pix_per_bp,
      y         => $composite->y - 1, # + makes it go down
      width     => $composite->width + 4/$pix_per_bp,
      height    => $h + 4,
      colour    => 'black',
      absolutey => 1,
    }),
    $self->Rect({ # Then a 1 pixel smaller white box
      x         => $composite->x - 1/$pix_per_bp,
      y         => $composite->y, # + makes it go down
      width     => $composite->width + 2/$pix_per_bp,
      height    => $h + 2,
      colour    => 'white',
      absolutey => 1,
    })
  );
}

sub export_feature {
  my $self = shift;
  my ($feature) = @_;
  
  my $variation_name = $feature->variation_name;
  
  return if $self->{'export_cache'}->{"variation:$variation_name"};
  
  $self->{'export_cache'}->{"variation:$variation_name"} = 1;
  
  return $self->_render_text($feature, 'Variation', { 
    headers => [ 'variation_name', 'alleles', 'class', 'type' ],
    values  => [ $variation_name, $feature->allele_string, $feature->var_class, $feature->display_consequence ]
  });
}


1;
