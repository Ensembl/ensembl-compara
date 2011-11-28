package Bio::EnsEMBL::GlyphSet::structural_variation;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return 'Structural variations'; }

sub features {
  my $self   = shift; 
  my $slice  = $self->{'container'};
  my $source = $self->my_config('source');

  my $var_features;
  
  if ($source =~ /^\w/) {
    $var_features = $slice->get_all_StructuralVariationFeatures($source);
  } else {
    $var_features = $slice->get_all_StructuralVariationFeatures;
  }
  
  my @sv_features;
  foreach my $svf (@$var_features) {
    push (@sv_features,$svf) if ($svf->structural_variation->is_evidence == 0);
  }

  return \@sv_features;  
}


sub colour_key  {
  my ($self, $f) = @_;
  return $f->source;
}

sub tag {
  my ($self, $f) = @_;
  
  my $core_colour  = '#000000';
  my $bound_colour = '#AFAFAF';
  my $arrow_colour = $bound_colour;
  
  my @g_objects;
  
  my $inner_crossing = 0;
  
  my $outer_start = ($f->seq_region_start - $f->outer_start) - $f->start if (defined($f->outer_start));
  my $inner_start = ($f->inner_start - $f->seq_region_start) + $f->start if (defined($f->inner_start));
  my $inner_end   = $f->end - ($f->seq_region_end - $f->inner_end) if (defined($f->inner_end));
  my $outer_end   = $f->end + ($f->outer_end - $f->seq_region_end) if (defined($f->outer_end));
  
  my $core_start = $f->start;
  my $core_end   = $f->end;
  
  
  # Check if inner_start < inner_end
  if ($f->inner_start and $f->inner_end) {
    $inner_crossing = 1 if ($f->inner_start >= $f->inner_end);
  }

  ## START ##
  # outer & inner start
  if ($f->outer_start and $f->inner_start) {
    if ($f->outer_start != $f->inner_start && $inner_crossing == 0) {
      push @g_objects, {
        style  => 'rect',
        colour => $bound_colour,
        start  => $f->start,
        end    => $inner_start
      };
      $core_start = $inner_start;
    }
  }
  # Only outer start
  elsif ($f->outer_start) {
    if ($f->outer_start == $f->seq_region_start || $inner_crossing) {
      push @g_objects, {
        style  => 'bound_triangle_right',
        colour => $arrow_colour,
        start  => $f->start,
        out    => 1
      };
    }
  }
  # Only inner start
  elsif ($f->inner_start) {
    if ($f->inner_start == $f->seq_region_start && $inner_crossing == 0) {
      push @g_objects, {
        style  => 'bound_triangle_left',
        colour => $arrow_colour,
        start  => $f->start
      };
    }
  }
  
  ## END ##
  # outer & inner end
  if ($f->outer_end and $f->inner_end) {
    if ($f->outer_end != $f->inner_end && $inner_crossing == 0) {
      push @g_objects, {
        style  => 'rect',
        colour => $bound_colour,
        start  => $inner_end,
        end    => $f->end
      };
      $core_end = $inner_end;
    }
  }
  # Only outer end
  elsif ($f->outer_end) {
    if ($f->outer_end == $f->seq_region_end || $inner_crossing) {
      push @g_objects, {
        style  => 'bound_triangle_left',
        colour => $arrow_colour,
        start  => $f->end,
        out    => 1
      };
    }
  }
  # Only inner end
  elsif ($f->inner_end) {
    if ($f->inner_end == $f->seq_region_end && $inner_crossing == 0) {
      push @g_objects, {
        style  => 'bound_triangle_right',
        colour => $arrow_colour,
        start  => $f->end
      };
    }
  }
  
  # Central part of the structural variation
  unshift @g_objects, {
      style  => 'rect',
      colour => $core_colour, #$self->my_colour($f->source),
      start  => $core_start,
      end    => $core_end
    };
  
  return @g_objects;
} 

sub href {
  my ($self, $f) = @_;
  
  my $href = $self->_url({
    type => 'StructuralVariation',
    sv   => $f->variation_name,
    svf  => $f->dbID,
    vdb  => 'variation'
  });
  
  return $href;
}

sub title {
  my ($self, $f) = @_;
  my $id     = $f->variation_name;
  my $start  = $self->{'container'}->start + $f->start -1;
  my $end    = $self->{'container'}->end + $f->end;
  my $pos    = 'Chr ' . $f->seq_region_name . ":$start-$end";
  my $source = $f->source;

  return "Structural variation: $id; Source: $source; Location: $pos";
}

sub highlight {
  my ($self, $f, $composite, $pix_per_bp, $h) = @_;
  my $id = $f->variation_name;
  my %highlights;
  @highlights{$self->highlights} = (1);

  my $length = ($f->end - $f->start) + 1; 
  
  return unless $highlights{$id};
  
  # First a black box
  $self->unshift($self->Rect({
      x         => $composite->x - 2/$pix_per_bp,
      y         => $composite->y - 2, # + makes it go down
      width     => $composite->width + 4/$pix_per_bp,
      height    => $h + 4,
      colour    => 'black',
      absolutey => 1,
    }),
    $self->Rect({ # Then a 1 pixel smaller green box
      x         => $composite->x - 1/$pix_per_bp,
      y         => $composite->y - 1, # + makes it go down
      width     => $composite->width + 2/$pix_per_bp,
      height    => $h + 2,
      colour    => 'green',
      absolutey => 1,
    }));
}
1;
