package EnsEMBL::Web::UserConfig::transview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;

  $self->{'fakecore'} = 1;
  $self->{'_userdatatype_ID'} = 3;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'transview'} = {
     '_artefacts' => [qw( 
       ruler scalebar
     )],
     '_options'  => [qw(pos col known unknown)],
    'fakecore' => 1,
    '_settings' => {
      'show_labels'    => 'no',
      'show_buttons'  => 'no',
      'width'   => 800,
      'opt_zclick'     => 1,
      'opt_lines' => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'snp' => {
      'on'  => "on",
      'pos' => '31',
      'colours' => {$self->{'_colourmap'}->colourSet( 'snp' )},
    },
    'ruler' => {
      'on'  => "on",
      'pos' => '99999',
      'str'   => 'r',
      'col' => 'black',
    },
    'scalebar' => {
      'on'  => "on",
      'pos' => '100000',
      'col' => 'black',
      'max_divisions' => '6',
      'str' => 'b',
      'subdivs' => 'on',
      'abbrev' => 'on',
    },
  };
  $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'off', 'compact'     => 0 );
  $self->ADD_ALL_PREDICTIONTRANSCRIPTS( 0, 'on' => 'off', 'compact'     => 0 );

}
1;
