package Bio::EnsEMBL::GlyphSet::structural_variation;

use strict;

use List::Util qw(min max);

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub somatic    { return $_[0]->{'my_config'}->id =~ /somatic/; }
sub colour_key { return $_[1]->class_SO_term; }

sub features {
  my $self     = shift; 
  my $slice    = $self->{'container'};
  my $source   = $self->my_config('source');
  my $set_name = $self->my_config('set_name');
  my $func     = $self->somatic ? 'get_all_somatic_StructuralVariationFeatures' : 'get_all_StructuralVariationFeatures';
  
  return $slice->get_all_StructuralVariationFeatures_by_VariationSet($self->{'config'}->hub->get_adaptor('get_VariationSetAdaptor', 'variation')->fetch_by_name($set_name)) if $set_name;
  return $slice->$func($source =~ /^\w/ ? $source : undef);  
}

sub tag {
  my ($self, $f) = @_;
  
  if ($f->is_somatic && $f->start == $f->end) {
    return ({
      style  => 'breakpoint',
      colour => 'gold',
      border => 'goldenrod',
      start  => $f->start,
    });
  }
  
  my $colour         = $self->my_colour($self->colour_key($f), 'tag');
  my $border         = 'dimgray';
  my $inner_crossing = $f->inner_start && $f->inner_end && $f->inner_start >= $f->inner_end ? 1 : 0;
  my @tags;
  
  if ($inner_crossing && $f->inner_start == $f->seq_region_end) {
    return {
      style  => 'rect',
      colour => $colour,
      border => $border,
      start  => $f->start,
      end    => $f->end
    };
  }
  
  # start of feature
  if ($f->outer_start && $f->inner_start) {
    if ($f->outer_start != $f->inner_start && !$inner_crossing) {
      push @tags, {
        style => 'rect',
        start => $f->start,
        end   => $f->inner_start - $f->seq_region_start + $f->start
      };
    }
  } elsif ($f->outer_start) {
    if ($f->outer_start == $f->seq_region_start || $inner_crossing) {
      push @tags, {
        style => 'bound_triangle_right',
        start => $f->start,
        out   => 1
      };
    }
  } elsif ($f->inner_start) {
    if ($f->inner_start == $f->seq_region_start && !$inner_crossing) {
      push @tags, {
        style => 'bound_triangle_left',
        start => $f->start
      };
    }
  }
  
  # end of feature
  if ($f->outer_end && $f->inner_end) {
    if ($f->outer_end != $f->inner_end && !$inner_crossing) {
      push @tags, {
        style => 'rect',
        start => $f->end - $f->seq_region_end + $f->inner_end,
        end   => $f->end
      };
    }
  } elsif ($f->outer_end) {
    if ($f->outer_end == $f->seq_region_end || $inner_crossing) {
      push @tags, {
        style => 'bound_triangle_left',
        start => $f->end,
        out   => 1
      };
    }
  } elsif ($f->inner_end) {
    if ($f->inner_end == $f->seq_region_end && !$inner_crossing) {
      push @tags, {
        style => 'bound_triangle_right',
        start => $f->end
      };
    }
  }
  
  foreach (@tags) {
    $_->{'colour'} = $colour;
    $_->{'border'} = $border;
  }
  
  return @tags;
}

sub render_tag {
  my ($self, $tag, $composite, $slice_length, $width, $start, $end, $img_start, $img_end) = @_;
  my @glyph;
  
  if ($tag->{'style'} =~ /^bound_triangle_(\w+)$/ && $img_start < $tag->{'start'} && $img_end > $tag->{'end'}) {
    my $pix_per_bp = $self->scalex;
    my $x          = $tag->{'start'} + ($tag->{'out'} == ($1 eq 'left') ? 1 : -1) * (($tag->{'out'} ? 1 : ($width / 2) + 1) / $pix_per_bp);
    my $y          = $width / 2;
    
    # Triangle returns an array: the triangle, and an invisible rectangle behind it for clicking purposes
    @glyph = $self->Triangle({
      mid_point    => [ $x, $y ],
      colour       => $tag->{'colour'},
      bordercolour => $tag->{'border'},
      absolutey    => 1,
      width        => $width,
      height       => $y / $pix_per_bp,
      direction    => $1,
    });
  } elsif ($tag->{'style'} eq 'breakpoint') {
    my $h     = $self->my_config('height') || [$self->get_text_width(0, 'X', '', $self->get_font_details($self->my_config('font') || 'innertext'), 1)]->[3] + 2;
    my $x     = $tag->{'start'};
    my $y     = $h / 2;
    my $width = 10 / $self->scalex;
    
    # Triangle returns an array: the triangle, and an invisible rectangle behind it for clicking purposes
    @glyph = ($self->Triangle({
      mid_point    => [ $x, $y ],
      colour       => $tag->{'colour'},
      bordercolour => $tag->{'border'},
      absolutey    => 1,
      width        => $width,
      height       => $y,
      direction    => 'up',
      z            => 12,
    }), $self->Triangle({
      mid_point    => [ $x, ($y / 2) + 2 ],
      colour       => $tag->{'colour'},
      bordercolour => $tag->{'border'},
      absolutey    => 1,
      width        => $width,
      height       => $y,
      direction    => 'down',
      z            => 12,
    }));
  }
  
  return @glyph;
}

sub href {
  my ($self, $f) = @_;
  
  return $self->_url({
    type => 'StructuralVariation',
    sv   => $f->variation_name,
    svf  => $f->dbID,
    vdb  => 'variation'
  });
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
  my ($self, $f, $composite, $pix_per_bp, $h, undef, @tags) = @_;
  
  return unless $self->core('sv') eq $f->variation_name;
  
  my $width = max(map $_->width, $composite, @tags);
  my $x     = min(map $_->x,     $composite, @tags);
  
  $self->unshift($self->Rect({
    x            => $x - 1/$pix_per_bp,
    y            => $composite->y - 1,
    width        => $width + 2/$pix_per_bp,
    height       => $h + 2,
    bordercolour => 'green',
    absolutey    => 1,
  }));
}

1;
