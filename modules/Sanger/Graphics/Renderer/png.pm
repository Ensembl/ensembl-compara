#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::Renderer::png;
use strict;
use Sanger::Graphics::Renderer::gif;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::Renderer::gif);

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->png();
    }
}

sub render_Sprite {
  my ($self, $glyph) = @_;
  my $spritename     = $glyph->{'sprite'} || "unknown";
  my $config         = $self->config();

  unless(exists $config->{'_spritecache'}->{$spritename}) {
    my $libref = $config->get("_settings", "spritelib");
    my $lib    = $libref->{$glyph->{'spritelib'} || "default"};
    my $fn     = "$lib/$spritename.png";
    $config->{'_spritecache'}->{$spritename} = GD::Image->newFromPng($fn);
  }

  return $self->SUPER::render_Sprite($glyph);
}

1;
