package Bio::EnsEMBL::VRenderer;
use strict;
use warnings;
no warnings 'uninitialized';

sub new {
  my ($class, $config, $container, $glyphsets_ref) = @_;

  my $self = {
    'glyphsets' => $glyphsets_ref,
    'canvas'    => undef,
    'colourmap' => $config->colourmap(),
    'config'    => $config,
    'container' => $container
  };
  bless($self, $class);
  $self->render();
  return $self;
}

sub render {
  my ($self) = @_;

  my $config = $self->{'config'};

  my $im_width  = $config->get_parameter('max_width');
  my $im_height = $config->get_parameter('max_height');

  ########## create a fresh canvas
  if($self->can('init_canvas')) {
    $self->init_canvas($config, $im_width, $im_height);
  }

  for my $glyphset (@{$self->{'glyphsets'}}) {
    ########## loop through everything and draw it
    for my $glyph ($glyphset->glyphs()) {
      my $method = $self->method($glyph);
      if($self->can($method)) {
        $self->$method($glyph);
      } else {
        print STDERR qq(Bio::EnsEMBL::Renderer::render: Do not know how to $method\n);
      }
    }

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
        my $first = $glyphset->{'tags'}{$_}[0];
        my $PAR = {
          'absolutex'    => 1,
          'absolutewidth'=> 1,
          'absolutey'    => 1,
        };
        my $glyph;
        $PAR->{'bordercolour'} = $COL if defined $COL;
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
          $glyph = $COL ? Sanger::Graphics::Glyph::Rect->new($PAR) : Sanger::Graphics::Glyph::Space->new($PAR);
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
          $glyph = $COL ? Sanger::Graphics::Glyph::Rect->new($PAR) : Sanger::Graphics::Glyph::Space->new($PAR);
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
  for my $layer ( sort { $a<=>$b } keys %layers ) {
    #########
    # loop through everything and draw it
    #
    for ( @{$layers{$layer}} ) {
      my $method = $M{$_} ||= $self->method($_);
      if($self->can($method)) {
        $self->$method($_);
      } else {
        print STDERR qq(Sanger::Graphics::Renderer::render: Do not know how to $method\n);
      }
    }
  }
    
  ########## the last thing we do in the render process is add a frame
  ########## so that it appears on the top of everything else...
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

sub render_Composite {
  my ($self, $glyph) = @_;

  for my $subglyph (@{$glyph->{'composite'}}) {
    my $method = $self->method($subglyph);

    if($self->can($method)) {
      $self->$method($subglyph);
    } else {
      print STDERR qq(Bio::EnsEMBL::VRenderer::render_Composite: Do not know how to $method\n);
    }
  }
}

########## empty stub for Blank spacer objects with no rendering at all
sub render_Blank { }

1;
