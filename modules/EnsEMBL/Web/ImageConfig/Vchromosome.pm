package EnsEMBL::Web::ImageConfig::Vchromosome;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_label'}           = 'above',
  $self->{'_band_labels'}     = 'on',
  $self->{'_image_height'}    = 450,
  $self->{'_top_margin'}      = 40,
  $self->{'_band_links'}      = 'yes',
  $self->{'_userdatatype_ID'} = 10;

  $self->{'general'}->{'Vchromosome'} = {
    '_artefacts'   => [qw(Videogram )],
    '_options'   => [],

    '_settings' => {
      'width'       => 500, # really height <g>
      'bgcolor'     => 'background1',
      'bgcolour1'   => 'background1',
      'bgcolour2'   => 'background1',
     },
    'Videogram' => {
      'on'          => "on",
      'pos'         => '5',
      'width'       => 24,
      'bandlabels'  => 'on',
      'totalwidth'  => 100,
      'col'         => 'g',
      'padding'     => 6,
    }
  };
}
1;
