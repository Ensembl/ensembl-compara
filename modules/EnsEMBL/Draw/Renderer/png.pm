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

package EnsEMBL::Draw::Renderer::png;
use strict;
use base qw(EnsEMBL::Draw::Renderer::gif);

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $self->{'im_width'}  = $im_width  ||= 10;
  $self->{'im_height'} = $im_height ||= 10;
  my $canvas = GD::Image->newTrueColor($self->{sf} * $im_width, $self->{sf} * $im_height);

  if( $self->{'config'}->can('species_defs') ) {
    $self->{'ttf_path'} ||= $self->{'config'}->species_defs->get_font_path;
  }
  $self->{'ttf_path'}   ||= '/usr/local/share/fonts/ttfonts/';

  $self->canvas($canvas);
  my $bgcolor = $self->colour($config->get_parameter('bgcolor'));
  $self->{'canvas'}->filledRectangle(0,0, $self->{sf} * $im_width, $self->{sf} * $im_height, $bgcolor );
}

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
