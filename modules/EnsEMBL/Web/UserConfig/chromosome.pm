package EnsEMBL::Web::UserConfig::chromosome;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;

  $self->{'_userdatatype_ID'} = 6;
  $self->{'no_image_frame'} = 1;

  $self->{'general'}->{'chromosome'} = {
    '_artefacts' => [qw(ideogram assemblyexception)],
    '_options'  => [],
    '_settings' => {
      'simplehap' => 1,
      'width'   => 800,
      'label_width' => 113,
      'show_thjview' => 'yes',
      'show_contigview' => 'yes',
      'show_cytoview'   => 'yes',
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'ideogram' => {
      'on'  => "on",
      'pos' => '6',
    },
    'assemblyexception' => {
      'on'      => "on",
      'pos'       => '9998',
      'str'       => 'x',
      'height'         => 1,
      'dep'         => 6,
      'lab'       => 'black',
      'navigation'  => 'on',
    },

    };
    $self->add_track( 'draggable', 'on'=>'on','pos'=>8000,'col'=>'black');
##  $self->add_track( 'redbox', 'on'=>'off', 'col' => 'red', 'zindex' => -20, 'pos' => 1000100 );
}
1;
