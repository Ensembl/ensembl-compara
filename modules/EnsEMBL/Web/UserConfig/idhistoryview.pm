package EnsEMBL::Web::UserConfig::idhistoryview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 160;
  $self->{'general'}->{'idhistoryview'} = {
    '_artefacts'   => [
		       qw( idhistorytree)
		       ],
    '_settings'    => {
      'image_width'             => 900,
      'width'             => 900,
      'draw_red_box'      => 'yes',
      'default_vc_size'   => 1000000,
      'show_alignsliceview'   => 'no',
#      'imagemap'          => 'yes',
      'show_labels' => 'no',
      'opt_zclick'     => 1,
      'show_buttons' => 'no',
      'bgcolor'           => 'background1',
      'bgcolour1'         => 'background1',
      'bgcolour2'         => 'background1',
    },

    'idhistorytree' => {
      'on'  => "on",
      'pos' => '0',
      'str' => 'f'
    },

  };
  my $POS = 0;
  $self->add_track( 'idhistorytree',   'on'=>'on', 'pos' => $POS++ );

}

1;
