package EnsEMBL::Web::UserConfig::Vkar2view;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_label'}             = 'below',
  $self->{'_band_labels'}       = 'off',
  $self->{'_image_height'}      = 200,
  $self->{'_top_margin'}        = 5,
  $self->{'_rows'}              = 4,
  $self->{'_userdatatype_ID'}   = 255;
  $self->{'_all_chromosomes'}   = 'yes';

  $self->{'general'}->{'Vkar2view'} = {
    '_artefacts'    => [qw(Videogram)],
    '_options'      => [],
    '_settings'     => {
      'opt_zclick'  => 1,
      'bgcolor'     => 'background1',
      'labels'      => 0,
      'width'       => 250 # really height <g> 255
    },
    'Videogram'     => {
      'on'          => 'on',
      'totalwidth'  => 15,
      'pos'         => '1',
      'width'       => 12,
      'padding'     => 3,
    },
  };
}
1;
