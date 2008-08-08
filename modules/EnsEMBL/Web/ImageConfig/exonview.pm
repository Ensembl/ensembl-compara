package EnsEMBL::Web::ImageConfig::exonview;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'general'}->{'supporting_evidence'} = {
    '_artefacts' => [qw( supporting_evidence supporting_legend)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'opt_zclick' => 1,
      'show_labels'	=> 'no',
      'show_buttons'	=> 'no',
      'width'   => 1200,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
       
    'supporting_evidence' => {
      'on'          => "on",
      'pos'         => '1',
      'str'         => 'f',
      'dep'         => '10',      
      'track_height'=> 7,
      'hide_hits'	=> 0,
      '50' => $self->{'_colourmap'}->add_hex('899e7c'),
      '75' => $self->{'_colourmap'}->add_hex('738e63'),
      '90' => $self->{'_colourmap'}->add_hex('608749'),
      '97' => $self->{'_colourmap'}->add_hex('497c2b'),
      '99' => $self->{'_colourmap'}->add_hex('316d0e'),
      '100' => 'darkgreen',
      'low_score'    => 'grey',
			
     
    },    
    'supporting_legend' => {
	     'on'          => "on",
	     'str'         => 'f',
	     'pos'         => '2',
	    },
    };
}
1;
