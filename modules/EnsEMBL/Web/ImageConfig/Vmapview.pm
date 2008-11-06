package EnsEMBL::Web::ImageConfig::Vmapview;
use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Chromosome panel',
    'label'         => 'above',     # margin
    'band_labels'   => 'on',
    'image_height'  => 450,
    'image_width'   => 500,
    'top_margin'    => 40,
    'band_links'    => 'yes',
    'spacing'       => 10
  });

  $self->create_menus( 'features' => 'Features' );

  $self->add_tracks( 'features',
    [ 'drag_left', '', 'Vdraggable', { 'display' => 'normal', 'part' => 0, 'menu' => 'no' } ],
    [ 'Videogram', 'Ideogram', 'Videogram', {
      'display'   => 'normal',
      'renderers' => [qw(off Off compact On)],
      'colourset' => 'ideogram'
    } ],
    [ 'Vgenes',    'Genes',    'Vdensity', {
      'same_scale' => 1,
      'display'   => 'normal',
      'renderers' => [qw(off Off histogram Histogram)],
      'keys'      => [qw(knownGeneDensity geneDensity)],
      'colourset' => 'densities'
    }],
    [ 'Vpercents',  'Percent GC/Repeats',    'Vdensity', {
      'same_scale' => 1,
      'display'   => 'normal',
      'colourset' => 'densities',
      'renderers' => [qw(off Off histogram Histogram)],
      'keys'      => [qw(PercentGC PercentageRepeat)]
    }],
    [ 'Vsnps',      'Variations',    'Vdensity', {
      'display'   => 'normal',
      'colourset' => 'densities',
      'renderers' => [qw(off Off histogram Histogram)],
      'keys'      => [qw(snpDensity)]
    }],
    [ 'drag_right', '', 'Vdraggable', { 'display' => 'normal', 'part' => 1, 'menu' => 'no' } ],
  );
}

1;
__END__
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_label'}           = 'above',
  $self->{'_band_labels'}     = 'on',
  $self->{'_image_height'}    = 450,
  $self->{'_top_margin'}      = 40,
  $self->{'_band_links'}      = 'yes',
  $self->{'_userdatatype_ID'} = 109;

  $self->{'general'}->{'Vmapview'} = {
    #'_artefacts'   => [qw(Vsnps Vpercents Vgenes Vsupercontigs Videogram Vrefseqs)],
    ## TODO - add supercontigs back in, when their absence is detected correctly
    '_artefacts'   => [qw(Vsnps Vpercents Vgenes Videogram Vrefseqs)],
    '_options'   => [],

    '_settings' => {
      'opt_zclick'  => 1,
      'width'       => 500, # really height <g>
      'bgcolor'     => 'background1',
      'bgcolour1'   => 'background1',
      'bgcolour2'   => 'background1',
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
      'logicname' => 'PercentageRepeat PercentGC'

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
       'include_labelling' => 1,
       'available'   => 'features MAPSET_SUPERCTGS',

    }

  };
}
1;
