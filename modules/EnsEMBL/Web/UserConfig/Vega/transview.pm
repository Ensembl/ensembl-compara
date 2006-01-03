package EnsEMBL::Web::UserConfig::Vega::transview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
    my ($self) = @_;

    $self->{'_userdatatype_ID'} = 3;
    $self->{'_transcript_names_'} = 'yes';
    $self->{'general'}->{'transview'} = {
	'_artefacts' => [qw(
	    ruler
	    scalebar
	)],
	
	'_options'  => [qw(pos col known unknown)],
	
	'_settings' => {
            'show_labels'  => 'no',
            'show_buttons' => 'no',
	    'width'     => 500,
	    'opt_lines' => 1,
            'opt_zclick'     => 1,
	    'bgcolor'   => 'background1',
	    'bgcolour1' => 'background1',
	    'bgcolour2' => 'background1',
	},

        'ruler' => {
            'on'  => "on",
            'pos' => '99999',
            'col' => 'black',
            'str' => 'r',
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
    
    $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'on' );
    $self->ADD_ALL_PREDICTIONTRANSCRIPTS( 1000, 'on' => 'off' );

}
1;
