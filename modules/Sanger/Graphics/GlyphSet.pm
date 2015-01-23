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

#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::GlyphSet;

use strict;

use Sanger::Graphics::Glyph::Diagnostic;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Root;
use Sanger::Graphics::Glyph::Space;

use List::Util qw(max min);

use base qw(Sanger::Graphics::Root);

#########
# constructor
#
sub new {
  my ($class, $Container, $Config, $highlights, $strand, $extra_config) = @_;
  my $self = {
    'glyphs'     => [],
    'x'          => undef,
    'y'          => undef,
    'width'      => undef,
    'highlights' => $highlights,
    'strand'     => $strand,
    'minx'       => undef,
    'miny'       => undef,
    'maxx'       => undef,
    'maxy'       => undef,
    'label'      => undef,
    'bumped'     => undef,
    'bumpbutton' => undef,
    'label2'     => undef,    
    'container'  => $Container,
    'config'     => $Config,
    'extras'     => $extra_config,
  };

  bless($self, $class);
  $self->init_label() if($self->can('init_label'));
  return $self;
}

#########
# _init creates masses of Glyphs from a data source.
# It should executes bumping and globbing on the fly and also
# keep track of x,y,width,height as it goes.
#
sub _init {
  my ($self) = @_;
  print STDERR qq($self unimplemented\n);
}

# Gets the number of Base Pairs per pixel
sub basepairs_per_pixel {
  my ($self) = @_;
  my $pixels = $self->{'config'}->get_parameter( 'width' );
  return (defined $pixels && $pixels) ? $self->{'container'}->length() / $pixels : undef; 
}  

sub glob_bp {
  my ($self) = @_;
  return int( $self->basepairs_per_pixel()*2 );
}


# join_tag joins between glyphsets in different tracks
#$self->join_tag(
#  $tglyph,     # A glyph you've drawn...
#  $key,      # Key for glyph
#  $T,        # X position in glyph (0-1)
#  0,         # Y position in glyph (0-1) 0 nearest contigs
#  $colour,     # colour to draw shape
#  'fill',      # whether to fill or draw line
#  -99        # z-index 
#);

sub join_tag {
  my ($self, $glyph, $tag, $x_pos, $y_pos, $col, $style, $zindex, $href, $alt, $class) = @_;
  
  if (ref $x_pos eq 'HASH') {
    CORE::push @{$self->{'tags'}{$tag}}, {
      %$x_pos,
      'glyph' => $glyph
    };
  } else {
    CORE::push @{$self->{'tags'}{$tag}}, {
      'glyph' => $glyph,
      'x'     => $x_pos,
      'y'     => $y_pos,
      'col'   => $col, 
      'style' => $style,
      'z'     => $zindex,
      'href'  => $href,
      'alt'   => $alt,
      'class' => $class
    };
  }
}

#########
# return our list of glyphs
#
sub glyphs {
  my ($self) = @_;
  return @{$self->{'glyphs'}};
}

#########
# push either a Glyph or a GlyphSet on to our list
#
sub push {
  my $self = CORE::shift;
  my ($gx, $gx1, $gy, $gy1);
  
  foreach my $Glyph (@_) {
      CORE::push @{$self->{'glyphs'}}, $Glyph;

      $gx  =     $Glyph->x() || 0;
      $gx1 = $gx + ($Glyph->width() || 0);
    $gy  =     $Glyph->y() || 0;
      $gy1 = $gy + ($Glyph->height() || 0);

  ######### track max and min dimensions
    $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
    $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
    $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
    $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
  }
}

#########
# unshift a Glyph or GlyphSet onto our list
#
sub unshift {
  my $self = CORE::shift;

  my ($gx, $gx1, $gy, $gy1);
  
  foreach my $Glyph (reverse @_) {
    CORE::unshift @{$self->{'glyphs'}}, $Glyph;

        $gx  =     $Glyph->x();
         $gx1 = $gx + $Glyph->width();
    $gy  =     $Glyph->y();
         $gy1 = $gy + $Glyph->height();
  
    $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
    $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
    $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
    $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
  }
}

########## pop/shift a Glyph off our list
# needs to shrink glyphset dimensions if the glyph/glyphset we pop off 

sub pop {
  my ($self) = @_;
  return CORE::pop @{$self->{'glyphs'}};
}

sub shift {
  my ($self) = @_;
  return CORE::shift @{$self->{'glyphs'}};
}

########## read-only getters
sub x {
  my ($self) = @_;
  return $self->{'x'};
}

sub y {
  my ($self) = @_;
  return $self->{'y'};
}

sub highlights {
  my ($self) = @_;
  return defined $self->{'highlights'} ? @{$self->{'highlights'}} : ();
}

########## read-write get/setters...

sub minx {
  my ($self, $minx) = @_;
  $self->{'minx'} = $minx if(defined $minx);
  return $self->{'minx'};
}

sub miny {
  my ($self, $miny) = @_;
  $self->{'miny'} = $miny if(defined $miny);
  return $self->{'miny'};
}

sub maxx {
  my ($self, $maxx) = @_;
  $self->{'maxx'} = $maxx if(defined $maxx);
  return $self->{'maxx'};
}

sub maxy {
  my ($self, $maxy) = @_;
  $self->{'maxy'} = $maxy if(defined $maxy);
  return $self->{'maxy'};
};

sub strand {
  my ($self, $strand) = @_;
  $self->{'strand'} = $strand if(defined $strand);
  return $self->{'strand'};
}

sub label {
  my ($self, $val) = @_;
  $self->{'label'} = $val if(defined $val);
  return $self->{'label'};
}

sub label_img {
  my ($self, $val) = @_;
  $self->{'label_img'} = $val if(defined $val);
  return $self->{'label_img'};
}

sub _label_glyphs {
  my ($self) = @_;

  my $label = $self->label;
  return [] unless $label;
  my $glyphs = [$label];
  if($label->can('glyphs')) {
    $glyphs = [ $self->{'label'}->glyphs ];
  }
  return $glyphs;
}

sub label_text {
  my ($self) = @_;

  return join(' ',map { $_->{'text'} } @{$self->_label_glyphs});
}

# Text wrapping is a job for the human eye. We do the best we can:
# wrap on word boundaries but don't have <6 trailing characters.
sub _split_label {
  my ($self,$text,$width,$font,$ptsize,$chop) = @_;

  for (1..$chop) {
    $text =~ s/.\t</\t</;
    $text =~ s/\t>./\t>/;
  }
  $text =~ s/\t[<>]//;
  my $max_rows = $self->max_label_rows;
  my @words = split(/(?<=[ \-\._])/,$text);
  while(@words > 1 and length($words[-1]) < 6) {
    my $tail = pop @words;
    $words[-1] .= $tail;
  }
  my @split;
  my $line_so_far = '';
  foreach my $word (@words) {
    my $candidate_line = $line_so_far.$word;
    my $replacement_line = $candidate_line;
    $candidate_line =~ s/^ +//;
    $candidate_line =~ s/ +$//;
    my @res = $self->get_text_width(undef, $candidate_line, '', font => $font, ptsize => $ptsize);
    if(!@split or $res[2] > $width) { # CR
      if(@split == $max_rows) { # No room!
        my @res = $self->get_text_width($width, $candidate_line, '', ellipsis => 1, font => $font, ptsize => $ptsize);
        $split[-1][0] = $res[0];
        $split[-1][1] = $res[2];
        return (\@split,$text,1);
        last;
      }
      my @res = $self->get_text_width($width, $word, '', ellipsis => 1, font => $font, ptsize => $ptsize);
      $line_so_far = $res[0];
      push @split,[$line_so_far,$res[2]];
    } else {
      $line_so_far = $replacement_line;
      $split[-1][0] = $line_so_far;
      $split[-1][1] = $res[2];
    }
  }
  return (\@split,$text,0);
}

sub recast_label {
  # XXX we should see which of these args are used and also pass as hash
  my ($self,$pixperbp,$width,$rows,$text,$font,$ptsize,$colour) = @_;

  my $caption = $self->my_label_caption;
  $text = $caption if $caption;

  my $n = 0;
  my ($ov,$text_out);
  ($rows,$text_out,$ov) = $self->_split_label($text,$width,$font,$ptsize,0);
  if($ov and $text =~ /\t[<>]/) {
    $text.="\t<" unless $text =~ /\t[<>]/;
    $text =~ s/\t>./...\t>/;
    $text =~ s/.\t</\t<.../;
    my $ov = 1;
    my $text_out;
    my $known_good = length $text;
    my $known_bad = 0;
    my $good_rows;
    foreach my $step ((5,2,1)) {
      my $n = $known_bad + $step;
      while($n<$known_good) {
        ($rows,$text_out,$ov) = $self->_split_label($text,$width,$font,$ptsize,$n);
        if($ov) { $known_bad = $n; }
        else    { $known_good = $n; $good_rows = $rows; }
        $n += $step;
      }
    }
    $rows = $good_rows if defined $good_rows;
  }

  my $max_width = max(map { $_->[1] } @$rows);

  my $composite = $self->Composite({
    halign => 'left',
    absolutex => 1,
    absolutewidth => 1,
    width => $max_width,
    x => 0,
    y => 0,
    class     => $self->label->{'class'},
    alt       => $self->label->{'alt'},
    hover     => $self->label->{'hover'},
  });

  my $y = 0;
  my $h = $self->my_config('caption_height') || $self->label->{'height'};
  foreach my $row_data (@$rows) {
    my ($row_text,$row_width) = @$row_data;
    next unless $row_text;
    my $pad = 0;
    $pad = 4 if !$y and @$rows>1;
    my $row = $self->Text({
      font => $font,
      ptsize => $ptsize,
      text => $row_text,
      height => $h + $pad,
      colour    => $colour,
      y => $y,
      width => $max_width,
      halign => 'left',
    });
    $composite->push($row);
    $y += $h + $pad; # The 4 is to add some extra delimiting margin
  }
  $self->label($composite);
}

sub bumped {
  my ($self, $val) = @_;
  $self->{'bumped'} = $val if(defined $val);
  return $self->{'bumped'};
}

##
## additional derived functions
##

sub height {
  my ($self) = @_;
  return int(abs($self->{'maxy'}-$self->{'miny'}) + 0.5);
}

sub width {
  my ($self) = @_;
  return abs($self->{'maxx'}-$self->{'minx'});
}

sub length {
  my ($self) = @_;
  return scalar @{$self->{'glyphs'}};
}

sub transform {
  my ($self) = @_;
  my $T = $self->{'config'}->{'transform'};
  foreach( @{$self->{'glyphs'}} ) {
    $_->transform($T);
  }
}

sub _dump {
  my($self) = CORE::shift;
  $self->push( Sanger::Graphics::Glyph::Diagnostic->new({
  'x'    =>0 ,
  'y'    =>0 ,
  'track'  => ref($self),
  'strand' => $self->strand(),
  'glyphs' => scalar @{$self->{'glyphs'}},
  @_
  }));
  return;
}

sub errorTrack {
  my ($self, $message, $x, $y) = @_;
  my $length = $self->{'config'}->image_width();
  my $w    = $self->{'config'}->texthelper()->width('Tiny');
  my $h    = $self->{'config'}->texthelper()->height('Tiny');
  my $h2   = $self->{'config'}->texthelper()->height('Small');
  $self->push( Sanger::Graphics::Glyph::Text->new({
      'x'     => $x || int( ($length - $w * CORE::length($message))/2 ),
    'y'     => $y || int( ($h2-$h)/2 ),
      'height'  => $h2,
    'font'    => 'Tiny',
    'colour'  => "red",
    'text'    => $message,
    'absolutey' => 1,
    'absolutex' => 1,
    'absolutewidth' => 1,
    'pixperbp'  => $self->{'config'}->{'transform'}->{'scalex'} ,
  }) );
  
  return;
}

sub commify { CORE::shift; local $_ = reverse $_[0]; s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g; return scalar reverse $_; }

sub check {
  my $self   = CORE::shift;
  my ($name) = ref($self) =~ /::([^:]+)$/;
  return $name;
} 

sub section {
  my $self = CORE::shift;

  return $self->my_config('section') || '';
}

sub section_zmenu { $_[0]->my_config('section_zmenu'); }
sub section_no_text { $_[0]->my_config('no_section_text'); }

sub section_text {
  $_[0]->{'section_text'} = $_[1] if @_>1;
  return $_[0]->{'section_text'};
}

sub section_height {
  return 0 unless $_[0]->{'section_text'};
  return 24;
}

1;
