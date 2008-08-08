package EnsEMBL::Web::ImageConfig::dasconfview;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 201; 
  $self->{'fakecore'} = 1;

  $self->{'general'}->{'dasconfview'} = {
    '_artefacts' => [qw(ruler)],
    '_options'  => [qw(pos col known unknown)],
    'fakecore' => 1,
    '_settings' => {
      'show_labels'    => 'no',
      'show_buttons'  => 'no',
      'width'   => 600,
      'opt_zclick'     => 1,
      'show_empty_tracks' => 'yes',
      'show_empty_tracks' => 'yes',
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'ruler' => {
      'on'  => 'on',
      'str' => 'r',
      'pos' => '10',
      'col' => 'black',
    },
  };
}
1;
