package EnsEMBL::Web::UserConfig::geneview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 11; 
  $self->{'fakecore'} = 1;

  $self->{'general'}->{'geneview'} = {
    '_artefacts' => [qw(ruler)],
    '_options'  => [qw(pos col known unknown)],
    'fakecore' => 1,
    '_settings' => {
      'show_labels'    => 'no',
      'show_buttons'  => 'no',
      'width'   => 500,
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
  $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'off' );
  $self->ADD_ALL_PREDICTIONTRANSCRIPTS( 0, 'on' => 'off' );
}
1;
