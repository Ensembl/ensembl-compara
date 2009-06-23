package EnsEMBL::Web::ImageConfig::Vmap2view;

use warnings;
no warnings 'uninitialized';
use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_label'}           = 'above',
  $self->{'_band_labels'}     = 'on',
  $self->{'_image_height'}    = 450,
  $self->{'_top_margin'}      = 40,
  $self->{'_band_links'}      = 'yes',
  $self->{'_userdatatype_ID'} = 109;

  $self->{'general'}->{'Vmap2view'} = {
    '_artefacts'   => [qw(Vsnps Vpercents Vgenes Vsupercontigs Videogram)],
    '_options'   => [],

    '_settings' => {
      'opt_zclick'  => 1,
      'width'       => 500, # really height <g>
      'bgcolor'     => 'background1',
      'bgcolour1'   => 'background1',
      'bgcolour2'   => 'background1',
      'labels'      => 1
     },
    'Vgenes' => {
      'on'          => 'off',
      'pos'         => '100',
      'width'       => 60,
      'col_genes'   => 'black',
      'col_xref'    => 'rust',
      'col_pred'    => 'black',
      'col_known'   => 'rust',
      'logicname' => 'knownGeneDensity geneDensity'

    },
    'Vrefseqs' => {
      'on'          => 'off',
      'pos'         => '110',
      'width'       => 60,
      'col'         => 'blue',
      'logicname' => 'refseqs'

    },        
    'Vpercents' => {
      'on'          => 'off',
      'pos'         => '200',
      'width'       => 60,
      'col_gc'      => 'red',
      'col_repeat'  => 'black',
      'logicname'   => 'PercentageRepeat PercentGC'
    },    
    'Vsnps' => {
      'on'          => 'off',
      'pos'         => '300',
      'width'       => 60,
      'col'         => 'blue',
      'logicname' => 'snpDensity'
    },        
    'Videogram' => {
      'on'          => "on",
      'pos'         => '1000',
      'width'       => 24,
      'bandlabels'  => 'on',
      'totalwidth'  => 100,
      'col'         => 'g',
      'padding'     => 6,
    },
    'Vsupercontigs' => {
       'on'          => 'off',
       'pos'         => '400',
       'width'       =>  20,
       'totalwidth'  =>  100,
       'padding'     =>  6,
       'col'         => 'blue',
       'col_ctgs1'    => 'green',
       'col_ctgs2'    => 'darkgreen',
       'lab'         => 'black',
       'available'   => 'features MAPSET_SUPERCTGS',

    }

  };
}
1;
