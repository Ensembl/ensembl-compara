package EnsEMBL::Web::ImageConfig::Vsynteny;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_label'}             = 'above',
  $self->{'_band_labels'}       = 'off',
  $self->{'_userdatatype_ID'}   = 22;
  $self->{'_image_height'}      = 500,
  $self->{'_top_margin'}        = 20,
  $self->{'general'}->{'Vsynteny'} = {
    '_artefacts'   => [qw(Vsynteny)],
    '_options'     => [],
    '_settings'    => {
      'opt_zclick' => 1,
      'bgcolor'    => 'background1',
      'width'      => 550 # really height <g>
    },
    'Vsynteny' => {
      '_image_height'    => 500,
      '_top_margin'      => 20,
      'on'               => 'on',
      'pos'              => '1',
      '_main_width'      => 30,
      '_secondary_width' => 12,
      '_padding'         => 4,
      '_spacing'         => 20,
      '_inner_padding'   => 140,
      '_outer_padding'   => 20,
    },
  };
}
1;
