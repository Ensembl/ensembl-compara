#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::Renderer;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Rect;
use strict;
use Time::HiRes qw(time);

our $patterns = {
# south-west - north-east thin line
  'hatch_ne'    => {
    'size' => [ 4, 4 ],
    'lines' => [
      [ 0,3,3,0 ]
    ]
  },
# south-east - north-west thin line
  'hatch_nw'    => {
    'size' => [ 4, 4 ],
    'lines' => [
      [ 0,0,3,3 ]
    ]
  },
# vertical 1px lines
  'hatch_vert'  => {
    'size' => [ 4, 4 ],
    'lines' => [
      [ 0,0,0,3 ],
      [ 2,0,2,3 ]
    ]
  },
# hotizontal 1px lines
  'hatch_hori'  => {
    'size' => [ 4, 4 ],
    'lines' => [
      [ 0,0,3,0 ],
      [ 0,2,3,2 ]
     ]
  },
# sw-ne (school tie!) v-thick lines
  'hatch_thick' => {
    'size' => [ 12, 12 ],
    'polys' => [
      [ [ 0,11],[ 5,11],[11, 5],[11, 0] ],
      [ [ 0,0 ],[ 0, 4],[ 4, 0]         ],
    ],
  },
  'hatch_thick_sw' => {
    'size' => [ 12, 12 ],
    'polys' => [
      [ [ 11,11],[ 6,11],[0, 5],[0, 0] ],
      [ [ 11,0 ],[ 11, 4],[ 7, 0]         ],
    ],
  },

  'pin_ne'   => { 'size' => [8,8], 'lines' => [[0,7,7,0]]} ,
  'pin_sw'   => { 'size' => [8,8], 'lines' => [[0,0,7,7]]} ,
  'pin_hori' => { 'size' => [8,8], 'lines' => [[0,2,7,2],[0,6,7,6]]} ,
  'pin_vert' => { 'size' => [8,8], 'lines' => [[2,0,2,7],[6,0,6,7]]} ,
  'hash'     => { 'size' => [4,4], 'lines' => [[0,2,3,2],[2,0,2,3]]} ,
  'check'    => { 'size' => [6,6], 'lines' => [[0,0,5,5],[0,5,5,0]]} ,
};

sub new {
  my ($class, $config, $extra_spacing, $glyphsets_ref) = @_;
  
  my $self = {
	      'glyphsets' => $glyphsets_ref,
	      'canvas'    => undef,
	      'colourmap' => $config->colourmap(),
	      'config'    => $config,
	      'extra_spacing' => $extra_spacing,
	      'spacing'   => $config->get_parameter( 'spacing')||2,
	      'margin'    => $config->get_parameter( 'margin')||5,
	     };
  
  bless($self, $class);
  
  $self->render();
  
  return $self;
}

sub config {
  my ($self, $config) = @_;
  $self->{'config'}   = $config if($config);
  return $self->{'config'};
}

sub render {
  my ($self) = @_;
  
  my $config = $self->{'config'};
  
  #########
  # now set all our labels up with scaled negative coords
  # and while we're looping, tot up the image height
  #
  my $spacing   = $self->{'spacing'};
  my $im_height = $self->{'margin'} * 2 - $spacing;
  
  for my $glyphset (@{$self->{'glyphsets'}}) {
    next if (scalar @{$glyphset->{'glyphs'}} == 0 || 
             scalar @{$glyphset->{'glyphs'}} == 1 && ref($glyphset->{'glyphs'}[0])=~/Diagnostic/ );
    
    my $fntheight = (defined $glyphset->label())?$config->texthelper->height($glyphset->label->font()):0;
    my $gstheight = $glyphset->height();
    
    if($gstheight > $fntheight) {
      $im_height += $gstheight + $spacing;
    } else {
      $im_height += $fntheight + $spacing;
    }
  }
  $im_height += $self->{'extra_spacing'};
  $config->image_height( $im_height );
  my $im_width = $config->image_width();
  
  #########
  # create a fresh canvas
  #
  if($self->can('init_canvas')) {
    $self->init_canvas($config, $im_width, $im_height );
  }
  
  my %tags;
  my %layers = ();
  for my $glyphset (@{$self->{'glyphsets'}}) {
    foreach( keys %{$glyphset->{'tags'}}) {
      if($tags{$_}) {
	# my @points = ( @{$tags{$_}}, @{$glyphset->{'tags'}{$_}} );
        my $COL   = undef;
        my $FILL  = undef;
        my $Z     = undef;
	my @points = map { 
          $COL  = defined($COL)  ? $COL  : $_->{'col'};
          $FILL = defined($FILL) ? $FILL : ($_->{'style'} && $_->{'style'} eq 'fill'); 
          $Z    = defined($Z)    ? $Z    : $_->{'z'};
	  (
	   $_->{'glyph'}->pixelx + $_->{'x'} * $_->{'glyph'}->pixelwidth,
	   $_->{'glyph'}->pixely + $_->{'y'} * $_->{'glyph'}->pixelheight
	  ) } (@{$tags{$_}}, @{$glyphset->{'tags'}{$_}});
#     warn Data::Dumper::Dumper($tags{$_});
#	warn Data::Dumper::Dumper(\@points);
	my $first = $glyphset->{'tags'}{$_}[0];
        my $PAR = { 
          'bordercolour' => $COL,
          'absolutex'    => 1,
          'absolutewidth'=> 1,
          'absolutey'    => 1,
        };
	my $glyph;
	$PAR->{'href'}   = $tags{$_}[0]->{'href'};
	$PAR->{'alt'}    = $tags{$_}[0]->{'alt'};
	$PAR->{'id'}     = $tags{$_}[0]->{'id'};
        $PAR->{'colour'} = $COL if($FILL);
# 794 5 123 5 123 421 794 421
        if( @points == 4 &&
          ($points[0] == $points[2] || $points[1] == $points[3])
        ) {
          $PAR->{'pixelx'}      = $points[0] < $points[2] ? $points[0] : $points[2];
          $PAR->{'pixely'}      = $points[1] < $points[3] ? $points[1] : $points[3];
          $PAR->{'pixelwidth'}  = $points[0] + $points[2] - 2 * $PAR->{'pixelx'};
          $PAR->{'pixelheight'} = $points[1] + $points[3] - 2 * $PAR->{'pixely'};
          $glyph = Sanger::Graphics::Glyph::Rect->new($PAR);
        } elsif( @points == 8 &&
	    $points[0] == $points[6] &&
	    $points[1] == $points[3] &&
	    $points[2] == $points[4] &&
	    $points[5] == $points[7]
	) {
	  $PAR->{'pixelx'}      = $points[0] < $points[2] ? $points[0] : $points[2];
	  $PAR->{'pixely'}      = $points[1] < $points[5] ? $points[1] : $points[5];
	  $PAR->{'pixelwidth'}  = $points[0] + $points[2] - 2 * $PAR->{'pixelx'};
	  $PAR->{'pixelheight'} = $points[1] + $points[5] - 2 * $PAR->{'pixely'};
	  $glyph = Sanger::Graphics::Glyph::Rect->new($PAR);
	} else {
	  $PAR->{'pixelpoints'}  = [ @points ];
	  $glyph = Sanger::Graphics::Glyph::Poly->new($PAR);
	}

	push @{$layers{defined $Z ? $Z : -1 }}, $glyph;
	delete $tags{$_};
      } else {
	$tags{$_} = $glyphset->{'tags'}{$_}
      }       
    }
    foreach( @{$glyphset->{'glyphs'}} ) {
      push @{$layers{$_->{'z'}||0}}, $_;
    }
  }

my %M;
my $Ta;
  for my $layer ( sort { $a<=>$b } keys %layers ) {
    #########
    # loop through everything and draw it
    #
    for ( @{$layers{$layer}} ) {
      my $method = $M{$_} ||= $self->method($_);
my $T = time();
      if($self->can($method)) {
	$self->$method($_,$Ta);
      } else {
	print STDERR qq(Sanger::Graphics::Renderer::render: Do not know how to $method\n);
      }
      $Ta->{$method} ||= [];
      $Ta->{$method}[0] += time()-$T;
      $Ta->{$method}[1] ++;   
    }
  }
  
  
  #########
  # the last thing we do in the render process is add a frame
  # so that it appears on the top of everything else...
  
  $self->add_canvas_frame($config, $im_width, $im_height);
}

sub canvas {
  my ($self, $canvas) = @_;
  $self->{'canvas'} = $canvas if(defined $canvas);
  return $self->{'canvas'};
}

sub method {
  my ($self, $glyph) = @_;
  
  my ($suffix) = ref($glyph) =~ /.*::(.*)/;
  return qq(render_$suffix);
}

sub render_Diagnostic { 1; }
sub render_Composite {
  my ($self, $glyph,$Ta) = @_;
  
  for my $subglyph (@{$glyph->{'composite'}}) {
    my $method = $self->method($subglyph);
my $T = time();
    if($self->can($method)) {
      $self->$method($subglyph,$Ta);
    } else {
      print STDERR qq(Sanger::Graphics::Renderer::render_Composite: Do not know how to $method\n);
    }
      $Ta->{$method} ||= [];
      $Ta->{$method}[0] += time()-$T;
      $Ta->{$method}[1] ++;   
  }
}

#########
# empty stub for Blank spacer objects with no rendering at all
#
sub render_Space {
}

#########
# placeholder for renderers which can't import sprites
#
sub render_Sprite {
  my $self = shift;
  return $self->render_Rect(@_);
}

1;
