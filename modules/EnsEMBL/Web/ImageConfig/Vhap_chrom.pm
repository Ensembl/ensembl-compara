package EnsEMBL::Web::ImageConfig::Vhap_chrom;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_label'}           = 'above',
  $self->{'_band_labels'}     = 'on',
  $self->{'_image_height'}    = 150,
  $self->{'_top_margin'}      = 25,
  $self->{'_band_links'}      = 'yes',
  $self->{'_userdatatype_ID'} = 99;

  $self->{'general'}->{'Vhap_chrom'} = {
    '_artefacts'   => [qw(Videogram )],
    '_options'   => [],

    '_settings' => {
      'width'       => 180, # really height <g>
      'bgcolor'     => 'background1',
      'bgcolour1'   => 'background1',
      'bgcolour2'   => 'background1',
     },
    'Videogram' => {
      'on'          => "on",
      'pos'         => '5',
      'width'       => 8,
      'bandlabels'  => 'on',
      'totalwidth'  => 90,
      'col'         => 'g',
      'padding'     => 4,
    }
  };
}
1;
