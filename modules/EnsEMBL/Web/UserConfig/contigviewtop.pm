package EnsEMBL::Web::UserConfig::contigviewtop;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 2;
  $self->{'no_image_frame'} = 1;
  $self->{'general'}->{'contigviewtop'} = {
    '_artefacts'   => [  ],
    '_settings'    => {
      'width'             => 800,
#      'draw_red_box'      => 'yes',
      'default_vc_size'   => 1000000,
      'opt_zclick'     => 1,
      'show_contigview'   => 'yes',
      'imagemap'          => 1,
      'bgcolor'           => 'background1',
      'bgcolour1'         => 'background1',
      'bgcolour2'         => 'background1',
    }
  };

  $self->add_track( 'draggable', 'on'  => "on", 'pos' => 8000);

  $self->ADD_GENE_TRACKS();
  $self->ADD_SYNTENY_TRACKS( 0, 'on' => 'on' );
  my $POS = 0;
  
  $self->add_track( 'contig',   'on'=>'on', 'pos' => $POS++, 'h' => 6 );
  $self->add_track( 'scalebar', 'on'=>'on', 'pos' => $POS++, 'str' => 'f', 'abbrev' => 'on' );
  $self->add_track( 'marker',   'on'=>'on', 'pos' => $POS++,
                    'col' => 'magenta', 'colours' => {$self->{'_colourmap'}->colourSet( 'marker' )},
                    'labels'    => 'on',
                    'available' => 'features markers'
                  ),
  $self->add_track( 'chr_band', 'on'=>'on', 'pos' => 999999 );

  $self->add_track( 'assemblyexception' =>
      'on'      => "on", 'pos'       => '9998', 'str'       => 'x', 'height'         => 1, 'dep'         => 6,
      'lab'       => 'black', 'navigation'  => 'on', );

#  $self->add_track( 'redbox', 'on'=>'off', 'col' => 'red', 'zindex' => -20, 'pos' => 1000100 );
  $POS = 2000100;
  $self->add_track( 'gene_legend', 'str' => 'r', 'on'=>'on', 'pos' => $POS++ );
}

1;
