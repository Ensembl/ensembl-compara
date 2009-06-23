package EnsEMBL::Web::ImageConfig::Vkaryotype2;

use warnings;
no warnings 'uninitialized';
use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_label'}             = 'below',
  $self->{'_band_labels'}       = 'off',
  $self->{'_image_height'}      = 180,
  $self->{'_top_margin'}        = 5,
  $self->{'_rows'}              = 2,
  $self->{'_userdatatype_ID'}   = 255;
  $self->{'_all_chromosomes'} = 'yes';
  $self->{'general'}->{'Vkaryotype2'} = {
    '_artefacts'    => [qw(Videogram)],
    '_options'      => [],

    '_settings'     => {
      'opt_zclick'  => 1,
      'bgcolor'     => 'background1',
      'width'       => 204 # really height <g>
    },
    'Videogram'     => {
      'on'          => 'on',
      'totalwidth'  => 40,
      'pos'         => '1',
      'width'       => 12,
      'padding'     => 24,
    },
  };
}
1;
