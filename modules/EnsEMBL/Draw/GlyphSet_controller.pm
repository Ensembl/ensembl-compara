=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet_controller;

### A "dummy" glyphset that gathers data from an EnsEMBL::Web::Draw::Data 
### object and passes it to the appropriate EnsEMBL::Web::Draw::Output module,
### thus turning the drawing code into something resembling MVC

### All of this functionality could/should eventually be moved into
### DrawableContainer, which is the real controller

use strict;

use EnsEmBL::Draw::Glyph::Composite;
use EnsEmBL::Draw::Glyph::Line;
use EnsEmBL::Draw::Glyph::Text;

sub new {
  my ($class, $args) = @_;

    my $self = {
                container  => $args->{'container'},
                config     => $args->{'config'},
                hub        => $args->{'config'}{'hub'},
                my_config  => $args->{'my_config'},
                strand     => $args->{'strand'},
                extras     => $args->{'extra'}   || {},
                highlights => $args->{'highlights'},
                display    => $args->{'display'} || 'off',
                legend     => $args->{'legend'}  || {},
                glyphs     => [],
              };

  bless $self, $class;

  $self->init_label;

  return $self;
}

sub render {
### This is where we implement the MVC structure!
  my $self = CORE::shift;

  my $track_config = {
                      container  => $self->{'container'},
                      config     => $self->{'config'},
                      hub        => $args->{'config'}{'hub'},
                      my_config  => $self->{'my_config'},
                      strand     => $self->{'strand'},
                      extras     => $self->{'extra'},
                      highlights => $self->{'highlights'},
                      display    => $self->{'display'},
                      };

  ## Fetch the data
  my $data_class = 'EnsEMBL::Draw::Data::'.$self->{'my_config'}{'data_type'};

  my $object  = $data_class->new($track_config);
  my $data    = $object->get_data;
  return undef unless $data;

  ## Render it
  my $style        = $data->select_style($self->{'my_config'}{'style'});
  return undef unless $style;
  my $output_class = 'EnsEMBL::Draw::Output::'.$style;

  my $track = $output_class->new($data, $track_config);

  ## Pass rendered image back to DrawableContainer
  return $track->render;
}

### Override some built-in Perl functions because...well, because we can

sub shift {
  my ($self) = @_;
  return CORE::shift @{$self->{'glyphs'}};
}

sub pop {
  my ($self) = @_;
  return CORE::pop @{$self->{'glyphs'}};
}


sub push {
  my ($self, @glyphs) = @_;
  my ($gx, $gx1, $gy, $gy1);

  foreach (@glyphs) {
    CORE::push @{$self->{'glyphs'}}, $_;

    $gx  = $_->x() || 0;
    $gx1 = $gx + ($_->width() || 0);
    $gy  = $_->y() || 0;
    $gy1 = $gy + ($_->height() || 0);

    ## track max and min dimensions
    $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
    $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
    $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
    $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
  }
}

sub unshift {
  my ($self, @glyphs) = @_;

  my ($gx, $gx1, $gy, $gy1);

  foreach (reverse @glyphs) {
    CORE::unshift @{$self->{'glyphs'}}, $_;

    $gx  = $_->x();
    $gx1 = $gx + $_->width();
    $gy  = $_->y();
    $gy1 = $gy + $_->height();

    $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
    $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
    $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
    $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
  }
}

### Manage overall dimensions

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

sub height {
  my $self = CORE::shift;
  return int(abs($self->{'maxy'}-$self->{'miny'}) + 0.5);
}

sub width {
  my $self = CORE::shift;
  return abs($self->{'maxx'}-$self->{'minx'});
}

sub length {
  my $self = CORE::shift;
  return scalar @{$self->{'glyphs'}};
}

sub transform {
  my $self = CORE::shift;
  my $T = $self->{'config'}->{'transform'};
  foreach( @{$self->{'glyphs'}} ) {
    $_->transform($T);
  }
}

## Accessors

sub error { 
  my $self = CORE::shift; 
  $self->{'error'} = @_ if @_; 
  return $self->{'error'};
}

sub error_track_name { 
  my $self = CORE::shift; 
  return $self->my_config('caption');
}

sub section {
  my $self = CORE::shift;
  return $self->my_config('section') || '';
}

sub section_height {
  my $self = CORE::shift;
  return $self->{'section_text'} ? 24 : 0;
}

sub section_zmenu { 
  my $self = CORE::shift;
  return $self->my_config('section_zmenu'); 
}

sub section_no_text { 
  my $self = CORE::shift;
  $self->my_config('no_section_text'); 
}

sub section_text {
  my ($self, $text) = @_;
  $self->{'section_text'} = $text if $text;
  return $self->{'section_text'};
}

sub label {
  my ($self, $text) = @_;
  $self->{'label'} = $text if(defined $text);
  return $self->{'label'};
}

sub label_img {
  my ($self, $text) = @_;
  $self->{'label_img'} = $text if(defined $text);
  return $self->{'label_img'};
}

sub label_text {
  my $self = CORE::shift;
  return join(' ',map { $_->{'text'} } @{$self->_label_glyphs});
}

sub max_label_rows { 
  my $self = CORE::shift;
  return $self->my_config('max_label_rows') || 1; 
}

sub recast_label {
  # XXX we should see which of these args are used and also pass as hash
  my ($self, $pixperbp, $width, $rows, $text, $font, $ptsize, $colour) = @_;

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
    $rows = $good_rows;
  }

  my $max_width = max(map { $_->[1] } @$rows);

  my $composite = $self->_composite({
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

sub _label_glyphs {
  my $self = CORE::shift;
  my $label = $self->label;
  return [] unless $label;

  my $glyphs = [$label];
  if ($label->can('glyphs')) {
    $glyphs = [ $self->{'label'}->glyphs ];
  }
  return $glyphs;
}

sub _split_label {
# Text wrapping is a job for the human eye. We do the best we can:
# wrap on word boundaries but don't have <6 trailing characters.
  my ($self, $text, $width, $font, $ptsize, $chop) = @_;

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


ech my $word (@words) {
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
  return (\@split, $text, 0);
}

## Wrappers around the basic glyphsets, needed for labels

sub Text {
  my $self = CORE::shift; 
  return EnsEmBL::Draw::Glyph->new(@_);  
}

sub Line {
  my $self = CORE::shift; 
  return EnsEmBL::Draw::Glyph->new(@_);  
}

sub _composite  { 
  my $self = CORE::shift; 
  return EnsEmBL::Draw::Glyph::Composite->new(@_);  
}

sub _colour_background { return 1; }

1;
