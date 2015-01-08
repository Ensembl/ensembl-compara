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

package EnsEMBL::Draw::GlyphSet;

### Base package for drawing a discreet section of a genomic image,
### such as a section of assembly, feature track, scalebar or track legend
### Uses GD and the Sanger::Graphics::Glyph codebase

use strict;

use GD;
use GD::Simple;
use URI::Escape qw(uri_escape);
use POSIX qw(floor ceil);

use Sanger::Graphics::Glyph::Bezier;
use Sanger::Graphics::Glyph::Circle;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Diagnostic;
use Sanger::Graphics::Glyph::Ellipse;
use Sanger::Graphics::Glyph::Intron;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Triangle;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Sprite;
use Sanger::Graphics::Glyph::Text;

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Utils::RandomString qw(random_string);

use base qw(Sanger::Graphics::GlyphSet);

our %cache;

sub new {
  my $class = shift;
  my $data  = shift;
  
  if (!$class) {
    warn 'EnsEMBL::GlyphSet::failed at: ' . gmtime() . " in /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}";
    warn 'EnsEMBL::GlyphSet::failed with a call of new on an undefined value';
    return undef;
  }
  
  my $self = {
    glyphs     => [],
    x          => undef,
    y          => undef,
    width      => undef,
    minx       => undef,
    miny       => undef,
    maxx       => undef,
    maxy       => undef,
    label      => undef,
    label2     => undef,
    bumped     => undef,
    error      => undef,
    highlights => $data->{'highlights'},
    strand     => $data->{'strand'},
    container  => $data->{'container'},
    config     => $data->{'config'},
    my_config  => $data->{'my_config'},
    display    => $data->{'display'} || 'off',
    legend     => $data->{'legend'}  || {},
    extras     => $data->{'extra'}   || {}
  };
  
  bless $self, $class;
  
  $self->init_label;

  return $self;
}

sub species            { return $_[0]->{'config'}{'species'} || $_[0]->{'container'}{'web_species'};                                                             }
sub species_defs       { return $_[0]->{'config'}->species_defs;                                                                                                 }
sub get_parameter      { return $_[0]->{'config'}->get_parameter($_[1]);                                                                                         }
sub core               { return $_[0]->{'config'}->hub->core_params->{$_[1]};                                                                                    }
sub scalex             { return $_[0]->{'config'}->transform->{'scalex'};                                                                                        }
sub image_width        { return $_[0]->{'config'}->get_parameter('panel_width') || $_[0]->{'config'}->image_width;                                               }
sub timer_push         { return shift->{'config'}->species_defs->timer->push(shift, shift || 3, shift || 'draw');                                                }
sub dbadaptor          { shift; return Bio::EnsEMBL::Registry->get_DBAdaptor(@_);                                                                                }
sub error              { my $self = shift; $self->{'error'} = @_ if @_; return $self->{'error'};                                                                 }
sub error_track_name   { return $_[0]->my_config('caption');                                                                                                     }
sub my_label           { return $_[0]->my_config('caption');                                                                                                     }
sub my_label_caption   { return $_[0]->my_config('labelcaption');                                                                                                }
sub depth              { return $_[0]->my_config('depth');                                                                                                       }
sub get_colour         { my $self = shift; return $self->my_colour($self->colour_key(shift), @_);                                                                }
sub _url               { my $self = shift; return $self->{'config'}->hub->url('ZMenu', { %{$_[0]}, config => $self->{'config'}{'type'}, track => $self->type }); }
sub my_config          { return $_[0]->{'my_config'}->get($_[1]);                                                                                                }
sub type               { return $_[0]->{'my_config'}{'id'};                                                                                                      }
sub _pos               { return $_[0]->{'config'}{'_pos'}++;                                                                                                     }
sub _colour_background { return 1;                                                                                                                               }
sub colour_key         { return 'default';                                                                                                                       }
sub feature_label      { return '';                                                                                                                              }
sub title              { return '';                                                                                                                              }
sub href               { return undef;                                                                                                                           }
sub tag                { return ();                                                                                                                              }
sub label_overlay      { return undef;                                                                                                                           }

### Helper functions to wrap round Glyphs
sub Bezier     { my $self = shift; return Sanger::Graphics::Glyph::Bezier->new(@_);     }
sub Circle     { my $self = shift; return Sanger::Graphics::Glyph::Circle->new(@_);     }
sub Composite  { my $self = shift; return Sanger::Graphics::Glyph::Composite->new(@_);  }
sub Diagnostic { my $self = shift; return Sanger::Graphics::Glyph::Diagnostic->new(@_); }
sub Ellipse    { my $self = shift; return Sanger::Graphics::Glyph::Ellipse->new(@_);    }
sub Intron     { my $self = shift; return Sanger::Graphics::Glyph::Intron->new(@_);     }
sub Line       { my $self = shift; return Sanger::Graphics::Glyph::Line->new(@_);       }
sub Poly       { my $self = shift; return Sanger::Graphics::Glyph::Poly->new(@_);       }
sub Rect       { my $self = shift; return Sanger::Graphics::Glyph::Rect->new(@_);       }
sub Space      { my $self = shift; return Sanger::Graphics::Glyph::Space->new(@_);      }
sub Sprite     { my $self = shift; return Sanger::Graphics::Glyph::Sprite->new(@_);     }
sub Text       { my $self = shift; return Sanger::Graphics::Glyph::Text->new(@_);       }
sub Triangle   { my $self = shift; return Sanger::Graphics::Glyph::Triangle->new(@_);   }

sub render {
  my $self   = shift;
  my $method = "render_$self->{'display'}";
  
  $self->{'text_export'} = $self->{'config'}->get_parameter('text_export');
  
  my $text_export = $self->can($method) ? $self->$method(@_) : $self->render_normal;
  
  return $self->{'text_export'} ? $text_export : undef;
}

sub render_normal {
  my $self = shift;
  my $rtn  = $self->_init(@_);
  return $self->{'text_export'} && $self->can('render_text') ? $rtn : undef;
}

sub _render_text {
  my $self = shift;
  my ($feature, $feature_type, $extra, $defaults) = @_;
  
  return unless $feature;
  
  $extra      = { headers => [], values => [] } unless keys %$extra;
  $defaults ||= {};
  
  my $format = $self->{'text_export'};
  my $header;
  
  if (!$self->{'export_header'}) {
    my @default_fields = qw(seqname source feature start end score strand frame);
       $header         = join ("\t", @default_fields, @{$extra->{'headers'}}) . "\r\n" if $format ne 'gff';
       
    $self->{'export_header'} = 1;
  }
  
  my $score   = $defaults->{'score'}  || ($feature->can('score') ? $feature->score : undef) || '.';
  my $frame   = $defaults->{'frame'}  || ($feature->can('frame') ? $feature->frame : undef) || '.';
  my $source  = $defaults->{'source'} || ($feature->can('source') ? $feature->source : $self->my_config('db') eq 'vega' ? 'Vega' : 'Ensembl');
  my $seqname = $defaults->{'seqname'};
  my $strand  = $defaults->{'strand'};
  my $start   = $defaults->{'start'};
  my $end     = $defaults->{'end'};
  
  $feature_type ||= $feature->can('primary_tag') ? $feature->primary_tag : '.';
  
  $seqname ||= 
    ($feature->can('seq_region_name') ? $feature->seq_region_name : undef) || 
    ($feature->can('entire_seq') && $feature->entire_seq ? $feature->entire_seq->name : $feature->can('seqname') ? $feature->seqname : undef) ||
    'SEQ';
  
  $strand ||= 
    ($feature->can('seq_region_strand') ? $feature->seq_region_strand : undef) || 
    ($feature->can('strand')            ? $feature->strand            : undef) ||
    '.';
  
  $start ||= ($feature->can('seq_region_start') ? $feature->seq_region_start : undef) || ($feature->can('start') ? $feature->start : undef);
  $end   ||= ($feature->can('seq_region_end')   ? $feature->seq_region_end   : undef) || ($feature->can('end')   ? $feature->end   : undef);
  
  $feature_type =~ s/\s+/ /g;
  $source       =~ s/\s+/ /g;
  $seqname      =~ s/\s+/ /g;
  $source       = ucfirst $source;
  $strand       = '+' if $strand == 1;
  $strand       = '-' if $strand == -1;
  
  my @results = ($seqname, $source, $feature_type, $start, $end, $score, $strand, $frame);
  
  if ($format eq 'gff') {
    my @ex;
    
    for (0..scalar @{$extra->{'headers'}}-1) {
      push @ex, "$extra->{'headers'}->[$_]=$extra->{'values'}->[$_]" if $extra->{'values'}->[$_];
    }
    
    push @results, join '; ', @ex;
  } else {
    push @results, @{$extra->{'values'}};
  }
  
  return $header . join ("\t", @results) . "\r\n";
}

sub init_label {
  my $self = shift;
  
  return $self->label(undef) if defined $self->{'config'}->{'_no_label'};
  
  my $text = $self->my_config('caption');
  
  my $img = $self->my_config('caption_img');
  $img = undef if $SiteDefs::ENSEMBL_NO_LEGEND_IMAGES;
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

sub get_text_simple {
### Simple function which calls the get_font_details and caches the result!!
  my ($self, $text, $text_size) = @_;
  $text      ||= 'X';
  $text_size ||= 'text';
  my ($f, $fs) = $self->get_font_details($text_size);
  my @t        = $self->get_text_width(0, $text, '', ptsize => $fs, font => $f);

  return {
    original => $text,
    text     => $t[0],
    bit      => $t[1],
    width    => $t[2],
    height   => $t[3],
    font     => $f,
    fontsize => $fs
  };
}

sub get_font_details {
  my ($self, $type, $hash) = @_;
  my $style  = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  my $font   = $type =~ /fixed/i ? $style->{'GRAPHIC_FONT_FIXED'} : $style->{'GRAPHIC_FONT'};
  my $ptsize = $style->{'GRAPHIC_FONTSIZE'} * ($style->{'GRAPHIC_' . uc $type} || 1);
  
  return $hash ? (font => $font, ptsize => $ptsize) : ($font, $ptsize);
}

sub get_text_width {
  my ($self, $width, $text, $short_text, %parameters) = @_;
     $text = 'X' if length $text == 1 && $parameters{'font'} =~ /Cour/i;               # Adjust the text for courier fonts
  my $key  = "$width--$text--$short_text--$parameters{'font'}--$parameters{'ptsize'}"; # Look in the cache for a previous entry 
  
  return @{$cache{$key}} if exists $cache{$key};

  my $gd = $self->get_gd($parameters{'font'}, $parameters{'ptsize'});
  
  return unless $gd;
  
  # Use the text object to determine height/width of the given text;
  $width ||= 1e6; # Make initial width very big by default
  
  my ($w, $h) = $gd->stringBounds($text); 
  my @res;
  
  if ($w < $width) { 
    @res = ($text, 'full', $w, $h);
  } elsif ($short_text) {
    ($w, $h) = $gd->stringBounds($text);
    @res = $w < $width ? ($short_text, 'short', $w, $h) : ('', 'none', 0, 0);
  } elsif ($parameters{'ellipsis'}) {
    my $string = $text;
    
    while ($string) {
      chop $string;
      
      ($w, $h) = $gd->stringBounds("$string...");
      
      if ($w < $width) { 
        @res = ("$string...", 'truncated', $w, $h);
        last;
      }
    }
  } else {
    @res = ('', 'none', 0, 0);
  }
  
  $self->{'_cache_'}{$key} = $cache{$key} = \@res; # Update the cache
  
  return @res;
}

sub get_gd {
  ### Returns the GD::Simple object appropriate for the given fontname
  ### and fontsize. GD::Simple objects are cached against fontname and fontsize.
  
  my $self     = shift;
  my $font     = shift || 'Arial';
  my $ptsize   = shift || 10;
  my $font_key = "${font}--${ptsize}"; 
  
  return $cache{$font_key} if exists $cache{$font_key};
  
  my $fontpath = $self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_TTF_PATH'}. "/$font.ttf";
  my $gd       = GD::Simple->new(400, 400);
  
  eval {
    if (-e $fontpath) {
      $gd->font($fontpath, $ptsize);
    } elsif ($font eq 'Tiny') {
      $gd->font(gdTinyFont);
    } elsif ($font eq 'MediumBold') {
      $gd->font(gdMediumBoldFont);
    } elsif ($font eq 'Large') {
      $gd->font(gdLargeFont);
    } elsif ($font eq 'Giant') {
      $gd->font(gdGiantFont);
    } else {
      $font = 'Small';
      $gd->font(gdSmallFont);
    }
  };
  
  warn $@ if $@;

  return $cache{$font_key} = $gd; # Update font cache
}

sub bp_to_nearest_unit {
  my ($self, $bp, $dp) = @_;

  $dp = 1 unless defined $dp;

  my @units = qw( bp kb Mb Gb Tb );
  my $power = int((length(abs $bp) - 1) / 3);

  my $unit = $units[$power];

  my $value = int($bp / (10 ** ($power * 3)));

  $value = sprintf "%.${dp}f", $bp / (10 ** ($power * 3)) if $unit ne 'bp';

  return "$value $unit";
}

sub commify {
  ### Puts commas into numbers over 1000
  my ($self, $val) = @_;
  return $val if $val < 1000;
  $val = reverse $val;
  $val =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return reverse $val;
}

sub slice2sr {
  my ($self, $s, $e) = @_;

  return $self->{'container'}->strand < 0 ?
    ($self->{'container'}->end   - $e + 1, $self->{'container'}->end   - $s + 1) : 
    ($self->{'container'}->start + $s - 1, $self->{'container'}->start + $e - 1);
}

sub sr2slice {
  my ($self, $s, $e) = @_;

  return $self->{'container'}->strand < 0 ? 
    ( $self->{'container'}->end   - $e + 1,  $self->{'container'}->end   - $s + 1) :
    (-$self->{'container'}->start + $s + 1, -$self->{'container'}->start + $e + 1);
}

sub label2 {
  my ($self, $val) = @_;
  $self->{'label2'} = $val if defined $val;
  return $self->{'label2'};
}

sub cache {
  my $self = shift;
  my $key  = shift;
  $self->{'config'}{'_cache'}{$key} = shift if @_;
  return $self->{'config'}{'_cache'}{$key};
}

sub my_colour {
  my ($self, $colour, $part, $default) = @_;
  
  $self->{'colours'} ||= $self->my_config('colours') || {};
  
  if ($part eq 'text' || $part eq 'style') {
    if ($self->{'colours'}) {
      return $self->{'colours'}->{$colour  }{$part} if exists $self->{'colours'}->{$colour  }{$part};
      return $self->{'colours'}->{'default'}{$part} if exists $self->{'colours'}->{'default'}{$part};
    }
    
    return defined $default ? $default : 'Other (unknown)' if $part eq 'text';
    return '';
  }
  
  if ($self->{'colours'}) {
    return $self->{'colours'}->{$colour  }{$part}     if exists $self->{'colours'}->{$colour  }{$part    };
    return $self->{'colours'}->{'default'}{$part}     if exists $self->{'colours'}->{'default'}{$part    };
    return $self->{'colours'}->{$colour  }{'default'} if exists $self->{'colours'}->{$colour  }{'default'};
    return $self->{'colours'}->{'default'}{'default'} if exists $self->{'colours'}->{'default'}{'default'};
  }
  
  return defined $default ? $default : 'black';
}

sub draw_cigar_feature {
  my ($self, $params) = @_;
  my ($composite, $f, $h) = map $params->{$_}, qw(composite feature height);
  my $ref    = ref $f;
  my $length = $self->{'container'}->length;
  my $cigar;
  my $inverted = $params->{'inverted'} || 0;

  my $match_colour = $params->{'feature_colour'};
  if($inverted) {
    # Wash out matches when mismatches are to be emphasised
    $match_colour = $self->{'config'}->colourmap->mix($match_colour,'white',0.9);
  }
 
  if (!$ref) {
    warn sprintf 'DRAWINGCODE_CIGAR < %s > %s not a feature', $f, $self->label->text;
  } elsif ($ref eq 'SCALAR') {
    warn sprintf 'DRAWINGCODE_CIGAR << %s >> %s not a feature', $$f, $self->label->text;
  } elsif ($ref eq 'HASH') {
    warn sprintf 'DRAWINGCODE_CIGAR { %s } %s not a feature', join('; ', keys %$f), $self->label->text;
  } elsif ($ref eq 'ARRAY') { 
    warn sprintf 'DRAWINGCODE_CIGAR [ %s ] %s not a feature', join('; ', @$f), $self->label->text;
  }

  if ($ref eq 'Bio::EnsEMBL::Funcgen::ProbeFeature') {
    $f = Bio::EnsEMBL::DnaDnaAlignFeature->new(
      -slice        => $f->slice,
      -start        => $f->start,
      -end          => $f->end,
      -strand       => $self->strand,
      -hstart       => $f->start,
      -hend         => $f->end,
      -cigar_string => $f->cigar_string
    );
  }
  
  eval { $cigar = $f->cigar_string; };
  
  if ($@ || !$cigar) {
    my ($s, $e) = ($f->start, $f->end);
    $s = 1       if $s < 1;
    $e = $length if $e > $length; 
    
    $composite->push($self->Rect({
      x         => $s - 1,
      y         => $params->{'y'} || 0,
      width     => $e - $s + 1,
      height    => $h,
      colour    => $match_colour,
    }));
    
    return;
  }
  
  my $strand  = $self->strand;
  my $fstrand = $f->strand;
  my $hstrand = $f->hstrand;
  my $start   = $f->start;
  my $hstart  = $f->hstart;
  my $hend    = $f->hend;
  my ($slice_start, $slice_end, $tag1, $tag2, @delete);
  
  if ($f->slice) {
    $slice_start = $f->slice->start;
    $slice_end   = $f->slice->end;
    $tag1        = join ':', $f->species, $f->slice->seq_region_name;
    $tag2        = join ':', $f->hspecies, $f->hseqname;
  } else {
    $slice_start = $f->seq_region_start;
    $slice_end   = $f->seq_region_end;
    $tag1        = $f->seqname;
  }

  # Parse the cigar string, splitting up into an array
  # like ('10M','2I','30M','I','M','20M','2D','2020M');
  # original string - "10M2I30MIM20M2D2020M"
  my @cigar = $f->cigar_string =~ /(\d*[MDImUXS=])/g;
     @cigar = reverse @cigar if $fstrand == -1;
  
  my $last_e = -1;
  foreach (@cigar) {
    # Split each of the {number}{Letter} entries into a pair of [ {number}, {letter} ] 
    # representing length and feature type ( 'M' -> 'Match/mismatch', 'I' -> Insert, 'D' -> Deletion )
    # If there is no number convert it to [ 1, {letter} ] as no-number implies a single base pair...
    my ($l, $type) = /^(\d+)([MDImUXS=])/ ? ($1, $2) : (1, $_);
    
    # If it is a D (this is a deletion) and so we note it as a feature between the end
    # of the current and the start of the next feature (current start, current start - ORIENTATION)
    # otherwise it is an insertion or match/mismatch
    # we compute next start sa (current start, next start - ORIENTATION) 
    # next start is current start + (length of sub-feature) * ORIENTATION 
    my $s = $start;
    my $e = ($start += ($type eq 'D' ? 0 : $l)) - 1;
    
    my $s1 = $fstrand == 1 ? $slice_start + $s - 1 : $slice_end - $e + 1;
    my $e1 = $fstrand == 1 ? $slice_start + $e - 1 : $slice_end - $s + 1;
    
    my ($hs, $he);
    
    if ($fstrand == 1) {
      $hs = $hstart;
      $he = ($hstart += ($type eq 'I' ? 0 : $l)) - 1;
    } else {
      $he = $hend;
      $hs = ($hend -= ($type eq 'I' ? 0 : $l)) + 1;
    }
    
    # If a match/mismatch - draw box
    if ($type =~ /^[MmU=X]$/) {
      ($s, $e) = ($e, $s) if $s > $e; # Sort out flipped features
      
      next if $e < 1 || $s > $length; # Skip if all outside the box
      
      $s = 1       if $s < 1;         # Trim to area of box
      $e = $length if $e > $length;
      
      my $box = $self->Rect({
        x         => $s - 1,
        y         => $params->{'y'} || 0,
        width     => $e - $s + 1,
        height    => $h,
        colour    => $match_colour,
      });
      
      if ($params->{'link'}) {
        my $tag = $strand == 1 ? "$tag1:$s1:$e1#$tag2:$hs:$he" : "$tag2:$hs:$he#$tag1:$s1:$e1";
        my $x;
        
        if ($params->{'other_ori'} == $hstrand && $params->{'other_ori'} == 1) {
          $x = $strand == -1 ? 0 : 1; # Use the opposite value to normal to ensure alignments which are between different orientations by default do not display a cross-over join
        } else {
          $x = $strand == -1 ? 1 : 0;
        }
        
        $x ||= 1 if $fstrand == 1 && $hstrand * $params->{'other_ori'} == -1; # the feature has been flipped, so force x to the same value each time to achieve a cross-over join
        
        $self->join_tag($box, $tag, {
          x     => $x,
          y     => $strand == -1 ? 1 : 0 + ($params->{'y'} || 0),
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });
        
        $self->join_tag($box, $tag, {
          x     => !$x,
          y     => $strand == -1 ? 1 : 0 + ($params->{'y'} || 0),
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });
      }
      
      $composite->push($box);

      if($inverted && $last_e != -1) {
        $composite->push($self->Rect({
          x         => $last_e,
          y         => $params->{'y'} || 0,
          width     => $s - $last_e + 1,
          height    => $h,
          colour    => $params->{'feature_colour'},
        }));
        
      }
      $last_e = $e;

    } elsif ($type eq 'D') { # If a deletion temp store it so that we can draw after all matches
      ($s, $e) = ($e, $s) if $s < $e;
      
#      next if $e < 1 || $s > $length || $params->{'scalex'} < 1 ;  # Skip if all outside box
      next if $e < 1 || $s > $length;  # Skip if all outside box
      
      push @delete, $e;
    }
  }

  # Draw deletion markers
  foreach (@delete) {
    $composite->push($self->Rect({
      x         => $_,
      y         => $params->{'y'} || 0,
      width     => 0,
      height    => $h,
      colour    => $params->{'delete_colour'},
      absolutey => 1
    }));
  }
}

sub sort_features_by_priority {
  my ($self, %features) = @_;
  my @sorted     = keys %features;
  my $prioritize = 0;
  
  while (my ($k, $v) = each (%features)) {
    if ($v && @$v > 1 && ref($v->[1]) eq 'HASH' && $v->[1]{'priority'}) {
      $prioritize = 1;
      last;
    }
  }
  
  @sorted = sort { ($features{$b}->[1]{'priority'} || 0) <=> ($features{$a}->[1]{'priority'} || 0) } keys %features if $prioritize;
  
  return @sorted;
}

sub no_features {
  my $self  = shift;
  my $label;
  if($self->can('my_empty_label')) {
    $label = $self->my_empty_label;
  }
  $label ||= $self->my_label;
  $self->errorTrack($label) if $label && $self->{'config'}->get_option('opt_empty_tracks') == 1;
}

sub too_many_features {
  my $self  = shift;
  my $label = $self->my_label || 'features';
  $self->errorTrack("Too many $label in this region - please zoom in or select a histogram style");
}

sub no_track_on_strand {
  my $self = shift;
  return $self->errorTrack(sprintf 'No %s on %s strand in this region', $self->error_track_name, $self->strand == 1 ? 'forward' : 'reverse');
}

sub errorTrack {
  my ($self, $message, $x, $y,$mild) = @_;
  return if $self->error; ## Don't try to output more than one!
  $self->error(1);
  my %font   = $self->get_font_details('text', 1);
  my $length = $self->{'config'}->image_width;
  my @res    = $self->get_text_width(0, $message, '', %font);
  
  $self->push($self->Text({
    x             => $x || int(($length - $res[2]) / 2),
    y             => $y || 2,
    width         => $res[2],
    textwidth     => $res[2],
    height        => $res[3],
    halign        => 'center',
    colour        => $mild?'grey30':'red',
    text          => $message,
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    pixperbp      => $self->{'config'}->{'transform'}->{'scalex'},
    %font
  }));

  return $res[3];
}

#==============================================================================================================
# Bumping code support
#==============================================================================================================

# _init_bump <- initialise the bumping code to be able to pack track...
# moved from separate Bump module so that it can be used in an OO way!!
# parameter passed is the maximum number of rows to bump... (optional)

# Initialize bumping - single parameter - max depth - if undefined it is "infinite"
sub _init_bump {
  my $self = shift;
  my $key  = shift || '_bump';
  
  $self->{$key} = {
    length => $self->{'config'}->image_width,
    rows   => @_ ? shift : 1e8,
    array  => []
  };
}

sub _max_bump_row {
  my ($self, $key) = @_;
  return scalar @{$self->{$key || '_bump'}{'array'} || []};
}

# compute the row to bump the feature to.. parameters are start/end in drawing (pixel co-ordinates)
sub bump_row {
  my ($self, $start, $end, $truncate_if_outside, $key) = @_;
  $key         ||= '_bump';
  ($end, $start) = ($start, $end) if $end < $start;
  $start         = 1 if $start < 1;
  my $row_length = $self->{$key}{'length'};
  
  return -1 if $end > $row_length && $truncate_if_outside; # used to not display partial text labels
  
  $end   = $row_length if $end > $row_length;
  $start = floor($start);
  $end   = ceil($end);
  
  my $length  = $end - $start + 1;
  my $element = '0' x $row_length;
  my $row     = 0;

  substr($element, $start, $length) = '1' x $length;
  
  while ($row < $self->{$key}{'rows'}) {
    if (!$self->{$key}{'array'}[$row]) { # We have no entries in this row - so create a new row
      $self->{$key}{'array'}[$row] = $element;
      return $row;
    }
    
    if (($self->{$key}{'array'}[$row] & $element) == 0) { # We already have a row, but the element fits so include it
      $self->{$key}{'array'}[$row] |= $element;
      return $row;
    }
    
    $row++; # Can't fit in on this row go to the next row..
  }
  
  return 1e9; # If we get to this point we can't draw the feature so return a very large number!
}

sub bump_sorted_row {
  my ($self, $start, $end, $truncate_if_outside, $key) = @_;
  $key         ||= '_bump';
  ($end, $start) = ($start, $end) if $end < $start;
  $start         = 1 if $start < 1;
  my $row_length = $self->{$key}{'length'};

  return -1 if $end > $row_length && $truncate_if_outside; # used to not display partial text labels

  $end   = $row_length if $end > $row_length;
  $start = floor($start);
  $end   = ceil($end);
  $end   = $start if $start > $end;
  
  my $row       = 0;
  my $max_rows  = $self->{$key}{'rows'};
  my $array_ref = $self->{$key}{'array'};

  while ($row < $max_rows) {
    if (!$array_ref->[$row]) { # We have no entries in this row - so create a new row
      $array_ref->[$row] = $end;
      return $row;
    }

    if ($array_ref->[$row] < $start) {
      $array_ref->[$row] = $end;
      return $row;
    }
    
    $row++; # Can't fit in on this row go to the next row..
  }

  return 1e9; # If we get to this point we can't draw the feature so return a very large number!
}

sub max_label_rows { return $_[0]->my_config('max_label_rows') || 1; }

1;
