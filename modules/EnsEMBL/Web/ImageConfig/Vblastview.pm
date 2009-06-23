package EnsEMBL::Web::ImageConfig::Vblastview;

use warnings;
no warnings 'uninitialized';
use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_label'}             = 'below',
  $self->{'_band_labels'}       = 'off',
  $self->{'_image_height'}      = 200,
  $self->{'_top_margin'}        = 5,
  $self->{'_rows'}              = 2,
  $self->{'_userdatatype_ID'}   = 255;
  $self->{'_all_chromosomes'}   = 'yes';
  $self->{'general'}->{'Vkaryotype'} = {
    '_artefacts'    => [qw(Videogram)],
    '_options'      => [],
    '_settings'     => {
      'opt_zclick'  => 1,
      'bgcolor'     => 'background1',
      'width'       => 225 # really height <g>
    },
    'Videogram'     => {
      'on'          => 'on',
      'totalwidth'  => 16,
      'pos'         => '1',
      'width'       => 10,
      'padding'     => 5,
    },
  };
}
1;
