=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Utils::Text;

### Simple library for getting text dimensions from GD

use strict;

use GD::Simple;

use Exporter qw(import);
our @EXPORT_OK = qw(get_text_info get_text_width get_font_details);

sub get_text_info {
  my ($cache, $image_config, $width, $text, $short_text, %parameters) = @_;
     $text = 'X' if length $text == 1 && $parameters{'font'} =~ /Cour/i;               # Adjust the text for courier fonts
  my $key  = "$width--$text--$short_text--$parameters{'font'}--$parameters{'ptsize'}"; # Look in the cache for a previous entry 

  my @res = @{$cache->get($key)||[]};
  return @res if scalar(@res);

  my $gd = &_get_gd($cache, $image_config, $parameters{'font'}, $parameters{'ptsize'});

  return unless $gd;

  # Use the text object to determine height/width of the given text;
  $width ||= 1e6; # Make initial width very big by default

  my ($w, $h) = $gd->stringBounds($text);

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

  $cache->set($key, \@res); # Update the cache

  return @res;
}

sub get_font_details {
  my ($config, $type, $hash) = @_;
  my $style  = $config->species_defs->ENSEMBL_STYLE;
  my $font   = $type =~ /fixed/i ? $style->{'GRAPHIC_FONT_FIXED'} : $style->{'GRAPHIC_FONT'};
  my $ptsize = $style->{'GRAPHIC_FONTSIZE'} * ($style->{'GRAPHIC_' . uc $type} || 1);

  return $hash ? (font => $font, ptsize => $ptsize) : ($font, $ptsize);
}

sub get_text_width {
  my ($cache, $image_config, $width, $text, $short_text, %parameters) = @_;
     $text = 'X' if length $text == 1 && $parameters{'font'} =~ /Cour/i;               # Adjust the text for courier fonts
  my $key  = "$width--$text--$short_text--$parameters{'font'}--$parameters{'ptsize'}"; # Look in the cache for a previous entry 

  return @{$cache->{$key}} if exists $cache->{$key};

  my $gd = &_get_gd($cache, $image_config, $parameters{'font'}, $parameters{'ptsize'});

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

  $cache->set($key,\@res); # Update the cache

  return @res;
}

sub _get_gd {
  ### Returns the GD::Simple object appropriate for the given fontname
  ### and fontsize. GD::Simple objects are cached against fontname and fontsize.

  my ($cache, $image_config) = @_;
  my $font     = shift || 'Arial';
  my $ptsize   = shift || 10;
  my $font_key = "${font}--${ptsize}";

  my $gd = $cache->get($font_key);

  return $gd if $gd;

  my $fontpath = $image_config->species_defs->get_font_path."$font.ttf";
  $gd = GD::Simple->new(400, 400);

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

  $cache->set($font_key, $gd); # Update font cache

  return $gd;
}


1;
