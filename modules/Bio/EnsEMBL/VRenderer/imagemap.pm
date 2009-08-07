package Bio::EnsEMBL::VRenderer::imagemap;

use strict;

use CGI qw(escapeHTML);

use base qw(Bio::EnsEMBL::VRenderer);

#########
# imagemaps are basically strings, so initialise the canvas with ""
# imagemaps also aren't too fussed about width & height boundaries
#
sub init_canvas {
  shift->canvas('');
}

sub add_canvas_frame {
	return;	
}

sub render_Circle  {}
sub render_Line    {}
sub render_Ellipse {}
sub render_Intron  {}

sub render_Composite { shift->render_Rect(@_); }
sub render_Space     { shift->render_Rect(@_); }
sub render_Text      { shift->render_Rect(@_); }

sub render_Rect {
  my ($self, $glyph) = @_;
  
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;
  
  my $x1 = $glyph->{'pixelx'};
  my $x2 = $x1 + $glyph->{'pixelwidth'};
  my $y1 = $glyph->{'pixely'};
  my $y2 = $y1 + $glyph->{'pixelheight'};

  $x1 = 0 if $x1 < 0;
  $x2 = 0 if $x2 < 0;
  $y1 = 0 if $y1 < 0;
  $y2 = 0 if $y2 < 0;
  
  $y2++;
  $x2++;
  
  $self->render_area('rect', [ $y1, $x1, $y2, $x2 ], $attrs);  
}

sub render_Poly {
  my ($self, $glyph) = @_;
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;
  
  $self->render_area('poly', [ reverse @{$glyph->pixelpoints} ], $attrs);
}

sub render_area {
  my ($self, $shape, $points, $attrs) = @_;
  
  my $coords = join ',', map int, @$points;
  
  $self->{'canvas'} = qq{<area shape="$shape" coords="$coords"$attrs />\n$self->{'canvas'}};
}

sub get_attributes {
  my ($self, $glyph) = @_;

  my %actions = ();

  foreach (qw(title alt href target class)) {
    my $attr = $glyph->$_;
    
    if (defined $attr) {
      if ($_ eq 'alt' || $_ eq 'title') {
        $actions{'title'} = $actions{'alt'} = CGI::escapeHTML($attr);
      } else {
        $actions{$_} = $attr;
      }
    }
  }

  return unless $actions{'title'} || $actions{'href'};
  
  $actions{'alt'} ||= '';

  return join '', map qq{ $_="$actions{$_}"}, keys %actions;
}

1;
