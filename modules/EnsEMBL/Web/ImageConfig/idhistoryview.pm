package EnsEMBL::Web::ImageConfig::idhistoryview;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 160;
  $self->{'general'}->{'idhistoryview'} = {
    '_artefacts'   => [
		       qw( idhistorytree)
		       ],
    '_settings'    => {
      'image_width'             => 800,
      'width'             => 800,
      'default_vc_size'   => 1000000,
      'show_alignsliceview'   => 'no',
#      'imagemap'          => 'yes',
      'show_labels' => 'no',
      'opt_zclick'     => 1,
      'show_buttons' => 'no',
      'bgcolor'           => 'background1',
      'bgcolor1'         => 'background2',
      'bgcolor2'         => 'bisque',
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
