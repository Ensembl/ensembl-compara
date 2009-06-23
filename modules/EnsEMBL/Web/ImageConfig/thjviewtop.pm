package EnsEMBL::Web::ImageConfig::thjviewtop;

use warnings;
no warnings 'uninitialized';
use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 242;
  $self->{'no_image_frame'} = 1;
  $self->{'general'}->{'thjviewtop'} = {
    '_artefacts' => [qw(
      chr_band contig
      scalebar
    ) ],
    'no_image_frame' => 1,
    '_options'  => [],
    '_settings' => {
    'width'      => 800,
    'draw_red_box'   => 'yes',
    '_clone_start_at_0'=> 'yes',
    'default_vc_size'  => 1000000,
    'clone_based'    => 'no',
    'clone_start'    => 1,
    'clone'      => '',
    'show_thjview'  => 'no',
    'show_multicontigview'  => 'no',
      'imagemap'     => 1,
      'bgcolor'      => 'background1',
      'bgcolour1'    => 'background1',
      'bgcolour2'    => 'background1',
    },
    'contig' => {
      'on'  => "on",
      'pos' => '0',
      'col' => 'black',
    },
    'marker' => {
      'on'  => "on",
      'pos' => '1',
      'col' => 'magenta',
      'colours' => {$self->{'_colourmap'}->colourSet( 'marker' )},
      'labels' => 'on',
      'available'=> 'features markers', 
    },
    'gene_legend' => {
      'on'    => "on",
      'str'   => 'r',
      'pos'   => '100000',
      'src'   => 'all', # 'ens' or 'all'
      'dep'   => '6',
    },
    'scalebar' => {
      'on'   => "on",
      'pos'  => '100001',
      'col'  => 'black',
      'str'  => 'r',
      'abbrev' => 'on',
    },
    'chr_band' => {
      'on'  => "on",
      'pos' => '100000',
    },
  };
  $self->ADD_GENE_TRACKS();
  $self->ADD_SYNTENY_TRACKS();
}

1;
