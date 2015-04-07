=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Renderer;
use EnsEMBL::Draw::Glyph::Poly;
use EnsEMBL::Draw::Glyph::Rect;
use strict;
use Time::HiRes qw(time);

our $patterns = {
  # south-west - north-east thin line
  'hatch_ne' => {
    'size' => [ 4, 4 ],
    'lines' => [
      [ 0, 3, 3, 0 ]
    ]
  },
  # south-east - north-west thin line
  'hatch_nw' => {
    'size' => [ 4, 4 ],
    'lines' => [
      [ 0, 0, 3, 3 ]
    ]
  },
  # vertical 1px lines
  'hatch_vert' => {
    'size' => [ 4, 4 ],
    'lines' => [
      [ 0, 0, 0, 3 ],
      [ 2, 0, 2, 3 ]
    ]
  },
  # hotizontal 1px lines
  'hatch_hori' => {
    'size' => [ 4, 4 ],
    'lines' => [
      [ 0, 0, 3, 0 ],
      [ 0, 2, 3, 2 ]
     ]
  },
  # sw-ne (school tie!) v-thick lines
  'hatch_thick' => {
    'size' => [ 12, 12 ],
    'polys' => [
      [ [ 0, 11], [ 5,11 ], [11, 5 ], [ 11, 0 ] ],
      [ [ 0, 0 ], [ 0, 4 ], [ 4, 0 ] ],
    ],
  },
  'hatch_really_thick' => {
    'size' => [ 24, 24 ],
    'polys' => [
      [ [ 1, 0],[23, 0],[ 0,23],[ 0, 1] ],
      [ [ 2,23],[23, 2],[23,23] ],
    ],
  },
  'hatch_thick_sw' => {
    'size' => [ 12, 12 ],
    'polys' => [
      [ [ 11, 11], [ 6, 11 ], [ 0, 5 ], [ 0, 0 ] ],
      [ [ 11, 0 ], [ 11, 4 ], [ 7, 0 ] ],
    ],
  },

  'pin_ne'   => { 'size' => [8,8], 'lines' => [[0,7,7,0]] },
  'pin_sw'   => { 'size' => [8,8], 'lines' => [[0,0,7,7]] },
  'pin_hori' => { 'size' => [8,8], 'lines' => [[0,2,7,2],[0,6,7,6]] },
  'pin_vert' => { 'size' => [8,8], 'lines' => [[2,0,2,7],[6,0,6,7]] },
  'hash'     => { 'size' => [4,4], 'lines' => [[0,2,3,2],[2,0,2,3]] },
  'check'    => { 'size' => [6,6], 'lines' => [[0,0,5,5],[0,5,5,0]] }
};

sub new {
  my ($class, $config, $extra_spacing, $glyphsets_ref, $boxes) = @_;
  
  my $self = {
    'glyphsets'     => $glyphsets_ref,
    'canvas'        => undef,
    'colourmap'     => $config->colourmap,
    'config'        => $config,
    'extra_spacing' => $extra_spacing,
    'boxes'         => $boxes || {},
    'spacing'       => $config->get_parameter('spacing') || 2,
    'margin'        => $config->get_parameter('margin') || 5,
    'sf'            => $config->get_parameter('sf') || 1
  };
  
  bless($self, $class);
  
  $self->render;
  
  return $self;
}

sub config {
  my ($self, $config) = @_;
  $self->{'config'} = $config if $config;
  return $self->{'config'};
}

sub render {
  my $self = shift;
  
  my $config = $self->{'config'};
  
  # now set all our labels up with scaled negative coords and while we're looping, tot up the image height
  my $spacing   = $self->{'spacing'};
  my $im_height = $self->{'margin'} * 2 - $spacing;
  
  for my $glyphset (@{$self->{'glyphsets'}}) {
    next if scalar @{$glyphset->{'glyphs'}} == 0 || 
            scalar @{$glyphset->{'glyphs'}} == 1 && ref($glyphset->{'glyphs'}[0]) =~ /Diagnostic/;
    
    my $fntheight = defined $glyphset->label ? $config->texthelper->height($glyphset->label->font) : 0;
    my $gstheight = $glyphset->height + $glyphset->section_height;
    
    if ($gstheight > $fntheight) {
      $im_height += $gstheight + $spacing;
    } else {
      $im_height += $fntheight + $spacing;
    }
  }
  
  $im_height += $self->{'extra_spacing'};
  $config->image_height($im_height);
  
  my $im_width = $config->image_width;
  
  # create a fresh canvas
  $self->init_canvas($config, $im_width, $im_height) if $self->can('init_canvas');
  
  my %tags;
  my %layers;
  
  for my $glyphset (@{$self->{'glyphsets'}}) {
    foreach (keys %{$glyphset->{'tags'}}) {
      if ($tags{$_}) {
        my $COL   = undef;
        my $FILL  = undef;
        my $Z     = undef;
        my $glyph;
        my @points;
        
        for (@{$tags{$_}}, @{$glyphset->{'tags'}{$_}}) {
          $COL  = defined $COL  ? $COL  : $_->{'col'};
          $FILL = defined $FILL ? $FILL : ($_->{'style'} && $_->{'style'} eq 'fill'); 
          $Z    = defined $Z    ? $Z    : $_->{'z'};
          
          push (@points, 
            $_->{'glyph'}->pixelx + $_->{'x'} * $_->{'glyph'}->pixelwidth,
            $_->{'glyph'}->pixely + $_->{'y'} * $_->{'glyph'}->pixelheight
          );
        }
        
        my $PAR = { 
          'absolutex'     => 1,
          'absolutewidth' => 1,
          'absolutey'     => 1,
          'href'          => $tags{$_}[0]->{'href'},
          'alt'           => $tags{$_}[0]->{'alt'},
          'id'            => $tags{$_}[0]->{'id'},
          'class'         => $tags{$_}[0]->{'class'}
        };
        
        $PAR->{'bordercolour'} = $COL if defined $COL;
        $PAR->{'colour'} = $COL if $FILL;
        
        if (@points == 4 && ($points[0] == $points[2] || $points[1] == $points[3])) {
          $PAR->{'pixelx'}      = $points[0] < $points[2] ? $points[0] : $points[2];
          $PAR->{'pixely'}      = $points[1] < $points[3] ? $points[1] : $points[3];
          $PAR->{'pixelwidth'}  = $points[0] + $points[2] - 2 * $PAR->{'pixelx'};
          $PAR->{'pixelheight'} = $points[1] + $points[3] - 2 * $PAR->{'pixely'};
          
          $glyph = $COL ? EnsEMBL::Draw::Glyph::Rect->new($PAR) : EnsEMBL::Draw::Glyph::Space->new($PAR);
        } elsif (@points == 8 &&
            $points[0] == $points[6] && $points[1] == $points[3] &&
            $points[2] == $points[4] && $points[5] == $points[7]
        ) {
          $PAR->{'pixelx'}      = $points[0] < $points[2] ? $points[0] : $points[2];
          $PAR->{'pixely'}      = $points[1] < $points[5] ? $points[1] : $points[5];
          $PAR->{'pixelwidth'}  = $points[0] + $points[2] - 2 * $PAR->{'pixelx'};
          $PAR->{'pixelheight'} = $points[1] + $points[5] - 2 * $PAR->{'pixely'};
          
          $glyph = $COL ? EnsEMBL::Draw::Glyph::Rect->new($PAR) : EnsEMBL::Draw::Glyph::Space->new($PAR);
        } else {
          $PAR->{'pixelpoints'} = [ @points ];
          $glyph = EnsEMBL::Draw::Glyph::Poly->new($PAR);
        }
        
        push @{$layers{defined $Z ? $Z : -1 }}, $glyph;
        delete $tags{$_};
      } else {
        $tags{$_} = $glyphset->{'tags'}{$_};
      }       
    }
    
    push @{$layers{$_->{'z'}||0}}, $_ for @{$glyphset->{'glyphs'}};
  }

  # add the highlight boxes
  my ($top_layer) = sort { $b <=> $a } keys %layers;
  for (sort keys %{$self->{'boxes'}}) {
    push @{$layers{$top_layer + 1}},
      EnsEMBL::Draw::Glyph::Line->new({colour => 'red', pixelx => $self->{'boxes'}{$_}{'l'}, pixely => $self->{'boxes'}{$_}{'t'}, pixelwidth => $self->{'boxes'}{$_}{'r'} - $self->{'boxes'}{$_}{'l'}, pixelheight => 0 }),
      EnsEMBL::Draw::Glyph::Line->new({colour => 'red', pixelx => $self->{'boxes'}{$_}{'r'}, pixely => $self->{'boxes'}{$_}{'t'}, pixelwidth => 0, pixelheight => $self->{'boxes'}{$_}{'b'} - $self->{'boxes'}{$_}{'t'} }),
      EnsEMBL::Draw::Glyph::Line->new({colour => 'red', pixelx => $self->{'boxes'}{$_}{'l'}, pixely => $self->{'boxes'}{$_}{'b'}, pixelwidth => $self->{'boxes'}{$_}{'r'} - $self->{'boxes'}{$_}{'l'}, pixelheight => 0 }),
      EnsEMBL::Draw::Glyph::Line->new({colour => 'red', pixelx => $self->{'boxes'}{$_}{'l'}, pixely => $self->{'boxes'}{$_}{'t'}, pixelwidth => 0, pixelheight => $self->{'boxes'}{$_}{'b'} - $self->{'boxes'}{$_}{'t'} });
  }

  my %M;
  my $Ta;

  my @keys = sort { $a <=> $b } keys %layers;
  if (ref($self) =~ /imagemap/) {
    @keys = reverse @keys;
  }

  
#  for my $layer (sort { $a <=> $b } keys %layers) {
  for my $layer (@keys) {
    # loop through everything and draw it
    for (@{$layers{$layer}}) {
      my $method = $M{$_} ||= $self->method($_);
      my $T = time;
      
      if ($self->can($method)) {
        $self->$method($_, $Ta);
      } else {
        print STDERR "EnsEMBL::Draw::Renderer::render: $self does not know how to $method\n";
      }
      
      $Ta->{$method} ||= [];
      $Ta->{$method}[0] += time - $T;
      $Ta->{$method}[1]++;   
    }
  }
  
  
  # the last thing we do in the render process is add a frame so that it appears on the top of everything else
  $self->add_canvas_frame($config, $im_width, $im_height);
}

sub canvas {
  my ($self, $canvas) = @_;
  $self->{'canvas'} = $canvas if defined $canvas;
  return $self->{'canvas'};
}

sub method {
  my ($self, $glyph) = @_;
  
  my ($suffix) = ref($glyph) =~ /.*::(.*)/;
  return "render_$suffix";
}

sub render_Composite {
  my ($self, $glyph, $Ta) = @_;
  
  for my $subglyph (@{$glyph->{'composite'}}) {
    my $method = $self->method($subglyph);
    my $T = time;
    
    if ($self->can($method)) {
      $self->$method($subglyph, $Ta);
    } else {
      print STDERR "EnsEMBL::Draw::Renderer::render_Composite: $self does not know how to $method\n";
    }
    
    $Ta->{$method} ||= [];
    $Ta->{$method}[0] += time - $T;
    $Ta->{$method}[1]++;   
  }
}

# empty stub for Blank spacer objects with no rendering at all
sub render_Space      {}
sub render_Diagnostic {}
sub render_Sprite     { return shift->render_Rect(@_); } # placeholder for renderers which can't import sprites
sub render_Triangle   { return shift->render_Poly(@_); }

1;
