#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::Renderer::png;
use strict;
use base qw(Sanger::Graphics::Renderer::gif);

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $self->{'im_width'}  = $im_width;
  $self->{'im_height'} = $im_height;
  my $canvas = GD::Image->newTrueColor($im_width, $im_height);

  my $SD = $self->{'config'}->can('species_defs') ?  $self->{'config'}->species_defs : undef;
  my $ST = $SD ? $SD->ENSEMBL_STYLE : undef;
  my $font_path;
  $font_path = $ST->{'GRAPHIC_TTF_PATH'} if $ST;
  $font_path ||= "/usr/local/share/fonts/ttfonts/";
  $self->{'ttf_path'}  = $font_path;
  $self->canvas($canvas);
  my $bgcolor = $self->colour($config->bgcolor);
  $self->{'canvas'}->filledRectangle(0,0, $im_width, $im_height, $bgcolor );
  $SD->{'timer'}->push( "CANVAS INIT", 9 ) if $SD->{'timer'};
}

sub canvas {
    my ($self, $canvas) = @_;
  my $SD = $self->{'config'}->can('species_defs') ?  $self->{'config'}->species_defs : undef;
  $SD->{'timer'}->push( "CANVAS CALLED", 9 ) if $SD->{'timer'};

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
    my $libref = $config->get_parameter(  "spritelib");
    my $lib    = $libref->{$glyph->{'spritelib'} || "default"};
    my $fn     = "$lib/$spritename.png";
    unless( -r $fn ){ 
      warn( "$fn is unreadable by uid/gid" );
      return;
    }
    eval {
      $config->{'_spritecache'}->{$spritename} = GD::Image->newFromPng($fn);
    };
    if( $@ || !$config->{'_spritecache'}->{$spritename} ) {
      eval {
        $config->{'_spritecache'}->{$spritename} = GD::Image->newFromPng("$lib/missing.png");
      };
    }
  }

  return $self->SUPER::render_Sprite($glyph);
}

1;
