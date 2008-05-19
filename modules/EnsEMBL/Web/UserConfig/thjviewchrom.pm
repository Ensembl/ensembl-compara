package EnsEMBL::Web::UserConfig::thjviewchrom;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;

  $self->{'_userdatatype_ID'} = 241;
  $self->{'no_image_frame'} = 1;

  $self->{'general'}->{'thjviewchrom'} = {
    'no_image_frame' => 1,
    '_artefacts' => [qw(ideogram )],
    '_options'  => [],
    '_settings' => {
      'width'   => 800,
      'show_thjview'          => 'yes',
      'show_multicontigview'  => 'yes',
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'ideogram' => {
      'on'  => "on",
      'pos' => '6',
    }
    };
}
1;
