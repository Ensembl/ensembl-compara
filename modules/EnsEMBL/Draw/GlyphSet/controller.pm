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

package EnsEMBL::Draw::GlyphSet::controller;

### A "dummy" glyphset that gathers data from an EnsEMBL::Web::Draw::Data 
### object and passes it to the appropriate EnsEMBL::Web::Draw::Output module,
### thus turning the drawing code into something resembling MVC

### Note that we do _not_ subclass EnsEMBL::Draw::GlyphSet, because we want
### to strip out all the cruft and retain only essential functionality

### All of this functionality could/should eventually be moved into
### DrawableContainer, which is the real controller

use strict;

use EnsEMBL::Draw::Glyph;
use EnsEMBL::Draw::Glyph::Composite;

use parent qw(EnsEMBL::Root);

sub new {
  my ($class, $args) = @_;
  
  my $self = {
                container  => $args->{'container'},
                config     => $args->{'config'},
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

  my $args = {
                container  => $self->{'container'},
                config     => $self->{'config'},
                my_config  => $self->{'my_config'},
                strand     => $self->{'strand'},
                extras     => $self->{'extra'},
                highlights => $self->{'highlights'},
                display    => $self->{'display'},
             };

  my $data;
  my $output_name = $self->track_config->get('style');
  my $data_type   = $self->track_config->get('data_type');

  ## Fetch the data (if any - some tracks are static
  if ($data_type) {
    my $data_class = 'EnsEMBL::Draw::Data::'.$data_type;

    if ($self->dynamic_use($data_class)) {
      my $object  = $data_class->new($args);
      $data       = $object->get_data;
      if ($data) {
        ## Map the renderer name to a real module
        $output_name = $object->select_output($output_name);
      }
    }
  }

  ## Render it
  my $output_class = 'EnsEMBL::Draw::Output::'.$output_name;
  if ($self->dynamic_use($output_class)) {
    my $track = $output_class->new($args, $data);

    ## Pass rendered image back to DrawableContainer
    return $track->render;
  }
  else {
    warn "!!! COULDN'T INSTANTIATE OUTPUT MODULE $output_class";
    return undef;
  }
}

sub image_config {
  my $self = CORE::shift;
  return $self->{'config'}; 
}

sub track_config {
  my $self = CORE::shift;
  return $self->{'my_config'}; 
}

##############################################################################################

### All the methods below are required to replicate current GlyphSet behaviour, 
### and should probably be revisited and refactored if/when we move this 
### functionality into DrawableContainer


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

sub my_config { 
  my ($self, $param) = @_;
  return $self->{'my_config'} ? $self->track_config->get($param) : undef;
}

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

sub init_label {
  my $self = shift;

  return $self->label(undef) if defined $self->{'config'}->{'_no_label'};

  my $text = $self->my_config('caption');

  my $img = $self->my_config('caption_img');
  if($img and $img =~ s/^r:// and $self->{'strand'} ==  1) { $img = undef; }
  if($img and $img =~ s/^f:// and $self->{'strand'} == -1) { $img = undef; }

  return $self->label(undef) unless $text;
  
  my $config    = $self->{'config'};
  my $hub       = $config->hub;
  my $name      = $self->my_config('name');
  my $desc      = $self->my_config('description');
  my $style     = $config->species_defs->ENSEMBL_STYLE;
  my $font      = $style->{'GRAPHIC_FONT'};
  my $fsze      = $style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'};
  my @res       = $self->get_text_width(0, $text, '', font => $font, ptsize => $fsze);
  my $track     = $self->type;
  my $node      = $config->get_node($track);
  my $component = $config->get_parameter('component');
  my $hover     = $component && !$hub->param('export') && $node->get('menu') ne 'no';
  my $class     = random_string(8);

  if ($hover) {
    my $fav       = $config->get_favourite_tracks->{$track};
    my @renderers = grep !/default/i, @{$node->get('renderers') || []};
    my $subset    = $node->get('subset');
    my @r;

    my $url = $hub->url('Config', {
      species  => $config->species,
      action   => $component,
      function => undef,
      submit   => 1
    });

    if (scalar @renderers > 4) {
      while (my ($val, $text) = splice @renderers, 0, 2) {
        push @r, { url => "$url;$track=$val", val => $val, text => $text, current => $val eq $self->{'display'} };
      }
    }

    $config->{'hover_labels'}->{$class} = {
      header    => $name,
      desc      => $desc,
      class     => "$class $track",
      component => lc($component . ($config->multi_species && $config->species ne $hub->species ? '_' . $config->species : '')),
      renderers => \@r,
      fav       => [ $fav, "$url;$track=favourite_" ],
      off       => "$url;$track=off",
      conf_url  => $self->species eq $hub->species ? $hub->url($hub->multi_params) . ";$config->{'type'}=$track=$self->{'display'}" : '',
      subset    => $subset ? [ $subset, $hub->url('Config', { species => $config->species, action => $component, function => undef, __clear => 1 }), lc "modal_config_$component" ] : '',
    };
  }

  my $ch = $self->my_config('caption_height') || 0;
  $self->label($self->Text({
    text      => $text,
    font      => $font,
    ptsize    => $fsze,
    colour    => $self->{'label_colour'} || 'black',
    absolutey => 1,
    height    => $ch || $res[3],
    class     => "label $class",
    alt       => $name,
    hover     => $hover,
  }));

  if($img) {
    $img =~ s/^([\d@-]+)://; my $size = $1 || 16;
    my $offset = 0;
    $offset = $1 if $size =~ s/@(-?\d+)$//;
    $self->label_img($self->Sprite({
        z             => 1000,
        x             => 0,
        y             => $offset,
        sprite        => $img,
        spritelib     => 'species',
        width         => $size,
        height         => $size,
        absolutex     => 1,
        absolutey     => 1,
        absolutewidth => 1,
        pixperbp      => 1,
        alt           => '',
    }));
  }
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

sub Sprite {
  my $self = CORE::shift; 
  return EnsEmBL::Draw::Glyph->new(@_);  
}

sub _composite  { 
  my $self = CORE::shift; 
  return EnsEMBL::Draw::Glyph::Composite->new(@_);  
}

sub _colour_background { return 1; }

1;
