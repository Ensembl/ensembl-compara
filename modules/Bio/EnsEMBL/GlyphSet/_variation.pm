package Bio::EnsEMBL::GlyphSet::_variation;

use strict;

use List::Util qw(min);

use Bio::EnsEMBL::Variation::Utils::Constants;
use Bio::EnsEMBL::Variation::VariationFeature;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub colour_key    { return lc $_[1]->display_consequence; }
sub label_overlay { return 1; }

sub my_config { 
  my $self = shift;
  my $term = shift;

  if ($term eq 'depth') {
    my $depth = ($self->{'my_config'}->get($term) > 1) ? $self->{'my_config'}->get($term) : 20;
    
    return 1 if ($self->{'display'} eq 'gradient'); # <=> collapsed in 1 line
    
    my $length = $self->{'container'}->end - $self->{'container'}->start + 1;
    
    return ($length > 200000) ? 1 : $depth if ($self->{'display'} eq 'normal'); # limit 200kb

    if ($self->{'display'} eq 'gene_label') { # <=> expanded with name (limit 10kb)
      return 1000 if ($length <= 10000);
      $self->{'display'} = 'gene_nolabel'; # <=> expanded without name
    }
    return $depth; # <=> expanded without name
  }
  return $self->{'my_config'}->get($term);
}

sub my_label { 
  my $self  = shift;  
  my $label = $self->{'my_config'}->id =~ /somatic/ ? 'Somatic Mutations' : 'Variations'; 
  return $label; 
}

sub features {
  my $self         = shift;
  my $max_length   = $self->my_config('threshold') || 1000;
  my $slice_length = $self->{'container'}->length;
  
  if ($slice_length > $max_length * 1010 ) {
    $self->errorTrack("Variation features are not displayed for regions larger than ${max_length}Kb");
    return [];
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
  my $self      = shift;
  my $config    = $self->{'config'};
  my $slice     = $self->{'container'};
  my $colourmap = $config->colourmap;
  my $id        = $self->{'my_config'}->id;
  
  if (!$self->cache($id)) {
  
    my $variation_db_adaptor = $config->hub->database('variation', $self->species);
    my $orig_failed_flag = $variation_db_adaptor->include_failed_variations;
    # Disable the display of failed variations by default
    $variation_db_adaptor->include_failed_variations(0);
  
    # different retrieval method for somatic mutations
    if ($id =~ /somatic/) {
      my @somatic_mutations;
      
      if ($self->my_config('filter')) { 
        @somatic_mutations = @{$slice->get_all_somatic_VariationFeatures_with_annotation(undef, undef, $self->my_config('filter')) || []};
      } elsif ($self->my_config('source')) {
        @somatic_mutations = @{$slice->get_all_somatic_VariationFeatures_by_source($self->my_config('source')) || []};
      } else { 
        @somatic_mutations = @{$slice->get_all_somatic_VariationFeatures || []};
      }
      
      $self->cache($id, \@somatic_mutations);   
    } else { # get standard variations
      my $sources = $self->my_config('sources'); 
         $sources = { map { $_ => 1 } @$sources } if $sources; 
      my $sets    = $self->my_config('sets');
         $sets    = { map { $_ => 1 } @$sets } if $sets;
      my %ct      = map { $_->SO_term => $_->rank } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
      my @vari_features;
      
      if ($id =~ /set/) {
        my $track_set            = $self->my_config('set_name');
        my $set_object           = $variation_db_adaptor->get_VariationSetAdaptor->fetch_by_name($track_set);
    
        # Enable the display of failed variations in order to display the failed variation track
        $variation_db_adaptor->include_failed_variations(1) if $track_set =~ /failed/i;
        
        @vari_features = @{$slice->get_all_VariationFeatures_by_VariationSet($set_object) || []};
        
        # Reset the flag for displaying of failed variations to its original state
        $variation_db_adaptor->include_failed_variations($orig_failed_flag);
      } else {
        my @temp_variations = @{$slice->get_all_VariationFeatures() || []}; 
        
        ## Add a filtering step here
        @vari_features =
          map  { $_->[1] }                                                ## Quick indexing schwartzian transform
          sort { $a->[0] <=> $b->[0] }                                    ## to make sure that "most functional" snps appear first
          map  { [ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] }
          grep { $sources ? $self->check_source($_, $sources) : 1 }       ## If sources filter by source
          grep { $sets ? $self->check_set($_, $sets) : 1 }                ## If sets filter by set
          @temp_variations;
      }

      # Reset the flag for displaying of failed variations to its original state
      $variation_db_adaptor->include_failed_variations($orig_failed_flag);

      $self->cache($id, \@vari_features);
    }
  }

  my $snps = $self->cache($id) || [];

  $self->{'legend'}{'variation_legend'}{$_->display_consequence} ||= $self->get_colours($_)->{'feature'} for @$snps;
  
  return $snps;
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
  return $ambig_code eq '-' ? undef : $ambig_code;
}

sub tag {
  my ($self, $f) = @_;
  
  my $colours = $self->get_colours($f);
  my $colour  = $colours->{'feature'};
  
  if ($self->my_config('style') eq 'box') {
    my $style        = $f->start > $f->end ? 'left-snp' : $f->var_class eq 'in-del' ? 'delta' : 'box';
    my $label_colour = $colours->{'label'};
       $label_colour = 'black' if $label_colour eq $colour;

    return {
      style        => $style,
      colour       => $colour,
      letter       => $style eq 'box' ? $f->ambig_code : '',
      label_colour => $label_colour,
      start        => $f->start
    };
  }
  elsif ($self->{'display'} eq 'gene_label') {
    my $text_colour = $self->my_colour($colours->{'key'}, 'tag');
    my $pix_per_bp = $self->scalex;
    
    my %font = $self->get_font_details($self->my_config('font') || 'innertext', 1);
    my $text = $f->variation_name;
    my (undef, undef, $text_width, undef) = $self->get_text_width(0, $text, '', %font);
    
    return {
      style        => 'underline',
      colour       => $colour,
      text_colour  => $text_colour,
      start        => $f->start,
      end          => $f->end + (6 + $text_width)/$pix_per_bp,
      feature      => $f,
    };
  
  }
  
  return { style => 'insertion', colour => $colour, feature => $f } if $f->start > $f->end;
}

sub render_tag {
  my ($self, $tag, $composite, $slice_length, $height, $start, $end) = @_;
  my $pix_per_bp = $self->scalex;
  my @glyph;
  
  if ($tag->{'style'} eq 'insertion') {
    push @glyph, $self->Triangle({
      mid_point  => [ $start - 1, $height - 1 ],
      colour     => $tag->{'colour'},
      absolutey  => 1,
      width      => 4 / $pix_per_bp,
      height     => 3,
      direction  => 'up',
    });
    
    my $width = min(1, 16/$pix_per_bp);
    
    # invisible box to make inserts more clickable
    $composite->push($self->Rect({
      x         => $start - 1 - $width/2,
      y         => 0,
      absolutey => 1,
      width     => $width,
      height    => $height + 2,
      href      => $self->href($tag->{'feature'})
    }));
  } elsif ($start <= $tag->{'start'}) {
    my $box_width = 8 / $pix_per_bp;
    my %font = $self->get_font_details($self->my_config('font') || 'innertext', 1);
    
    if ($tag->{'style'} eq 'box') {
      my (undef, undef, $text_width, $text_height) = $self->get_text_width(0, $tag->{'letter'}, '', %font);
      my $width = $text_width / $pix_per_bp;
      my $box_x = $start - 4/$pix_per_bp;
      my $text_x = ($box_width<$width) ? $box_x : $start + 0.5 - ($width/2) ;
      
      $composite->push($self->Rect({
        x         => $box_x - 0.5,
        y         => 0,
        width     => $box_width,
        height    => $height,
        colour    => $tag->{'colour'},
        absolutey => 1
      }), $self->Text({
        x         => $text_x,
        y         => ($height - $text_height) / 2,
        width     => $width,
        textwidth => $text_width,
        height    => $text_height,
        halign    => 'center',
        colour    => $tag->{'label_colour'},
        text      => $tag->{'letter'},
        absolutey => 1,
        %font
      }));
      
    } elsif ($tag->{'style'} =~ /^(delta|left-snp)$/) {
      push @glyph, $self->Triangle({
        mid_point => [ $start - 0.5, $tag->{'style'} eq 'delta' ? $height : 0 ],
        colour    => $tag->{'colour'},
        absolutey => 1,
        width     => $box_width,
        height    => $height,
        direction => $tag->{'style'} eq 'delta' ? 'down' : 'up',
      });
      
      # invisible box to make inserts more clickable
      $composite->push($self->Rect({
        x         => $start - 1 - $box_width/2,
        y         => 0,
        absolutey => 1,
        width     => $box_width,
        height    => $height,
      }));
      
    } elsif ($tag->{'style'} eq 'underline') { 
      # Expanded with name
      my $text = $tag->{feature}->variation_name;
      my (undef, undef, $text_width, $text_height) = $self->get_text_width(0, $text, '', %font);
      
      $composite->push(
        $self->Text({
          x         => $tag->{end} - ($text_width + 2)/$pix_per_bp,
          y         => ($height - $text_height) / 2 - 1,
          height    => $height,
          width     => $text_width/$pix_per_bp,
          halign    => 'left',
          colour    => (defined($tag->{'text_colour'})) ? $tag->{'text_colour'} : $tag->{'colour'},
          text      => $text,
          absolutey => 1,
          %font
        }),
        $self->Rect({
          x         => $start,
          y         => 0,
          absolutey => 1,
          width     => $tag->{feature}->end-$tag->{feature}->start,
          height    => $height,
          colour    => $tag->{'colour'},
      }));    
    }
  }
  
  return @glyph;
}

sub highlight {
  my $self = shift; 
  my ($f, $composite, $pix_per_bp, $h, $hi_colour) = @_;
  
  ## Get highlights
  my %highlights = map { $_ => 1 } $self->highlights;

  if ($self->{'config'}->core_objects->{'variation'}){
    my $var_id = $self->{'config'}->core_objects->{'variation'}->name;
       $var_id =~ s/rs//;
       
    $highlights{$var_id} = 1;
  }

  # Are we going to highlight self item
  my $id = $f->variation_name;  
     $id =~ s/^rs//;
 
  return unless $highlights{$id} || $highlights{"rs$id"};
  
  $composite->z(20);
  
  my $z = ($f->start > $f->end) ? 0 :18;
  
  if ($self->{'display'} eq 'gene_label') {
    $self->unshift(
      $self->Rect({ # First a black box
        x         => $composite->x - 1 / $pix_per_bp,
        y         => $composite->y - 1, # + makes it go down
        width     => $composite->width,
         height    => $h + 2,
         colour    => 'black',
         absolutey => 1,
         z         => $z,
      })
    ); 
  } else {
    $self->unshift(
      $self->Rect({ # First a black box
        x         => $composite->x - 2 / $pix_per_bp,
        y         => $composite->y - 2, # + makes it go down
        width     => $composite->width + 4 / $pix_per_bp,
        height    => $h + 4,
        colour    => 'black',
        absolutey => 1,
         z         => $z,
      })
    );
  }
}

sub export_feature {
  my $self = shift;
  my ($feature) = @_;
  
  my $variation_name = $feature->variation_name;
  
  return if $self->{'export_cache'}{"variation:$variation_name"};
  
  $self->{'export_cache'}{"variation:$variation_name"} = 1;
  
  return $self->_render_text($feature, 'Variation', { 
    headers => [ 'variation_name', 'alleles', 'class', 'type' ],
    values  => [ $variation_name, $feature->allele_string, $feature->var_class, $feature->display_consequence ]
  });
}

1;
