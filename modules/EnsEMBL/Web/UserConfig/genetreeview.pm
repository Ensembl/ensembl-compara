package EnsEMBL::Web::UserConfig::genetreeview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 192;
  $self->{'general'}->{'genetrieview'} = {
    '_artefacts'   => [
		       qw( genetree genetree_legend )
		       ],
    '_names'   => {
      'on'    => 'activate',
      'pos'   => 'position',
      'col'   => 'colour',
      'dep'   => 'depth',
      'str'   => 'strand',
      'hi'    => 'highlight colour',
      'src'   => 'source',
      'known'   => 'known colour',
      'unknown' => 'unknown colour',
      'ext'   => 'external colour',
    },

    '_settings'    => {
      'image_width'             => 800,
      'width'             => 800,
      'draw_red_box'      => 'yes',
      'default_vc_size'   => 1000000,
      'show_alignsliceview'   => 'yes',
      'imagemap'          => 'yes',
      'show_labels' => 'no',
      'opt_zclick'     => 1,
      'show_buttons' => 'no',
      'bgcolor'           => 'background1',
      'bgcolour1'         => 'background1',
      'bgcolour2'         => 'background1',
    },

    'genetree' => {
      'on'  => "on",
      'pos' => '0',
      'str' => 'f'
    },

    'genetree_legend' => {
      'on'          => "on",
      'str'         => 'r',
      'pos'         => '9999',
    },


  };
  my $POS = 0;
  $self->add_track( 'genetree',   'on'=>'on', 'pos' => $POS++ );

}

1;
