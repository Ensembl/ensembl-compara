package Bio::EnsEMBL::VRenderer::png;
use strict;
use base qw(Bio::EnsEMBL::VRenderer::gif);

sub canvas {
  my ($self, $canvas) = @_;
  if(defined $canvas) {
    $self->{'canvas'} = $canvas;
  } else {
    return $self->{'canvas'}->png();
  }
}

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $self->{'im_width'}  = $im_width;
  $self->{'im_height'} = $im_height;

  my $canvas = GD::Image->newTrueColor($im_height, $im_width);

  my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  $self->{'ttf_path'} = "/usr/local/share/fonts/ttfonts/";
  $self->{'ttf_path'} = $ST->{'GRAPHIC_TTF_PATH'} if $ST && $ST->{'GRAPHIC_TTF_PATH'};

  $self->canvas($canvas);
  my $bgcolor = $self->colour($config->bgcolor);
  $self->{'canvas'}->filledRectangle(0,0, $im_height, $im_width, $bgcolor );

  $self->{'config'}->species_defs->timer_push( "CANVAS INIT", 1, 'draw' );
}

1;
