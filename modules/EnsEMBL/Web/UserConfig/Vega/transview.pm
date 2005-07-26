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
	    vega_transcript
	    ruler
	    scalebar
	)],
	
	'_options'  => [qw(pos col known unknown)],
	
	'_settings' => {
            'show_labels'  => 'no',
            'show_buttons' => 'no',
	    'width'     => 320,
	    'opt_lines' => 1,
            'opt_zclick'     => 1,
	    'bgcolor'   => 'background1',
	    'bgcolour1' => 'background1',
	    'bgcolour2' => 'background1',
	},

	'vega_transcript' => {
	    'on'      => "on",
	    'pos'     => '1020',
	    'str'     => 'b',
	    'src'     => 'all', # 'ens' or 'all',
            'colours' => {$self->{'_colourmap'}->colourSet( 'vega_gene' )},
            'label'   => "Vega trans.",
            'zmenu_caption' => "Vega Gene",
	},
        
        'ruler' => {
            'on'  => "on",
            'pos' => '11',
            'col' => 'black',
            'str' => 'r',
        },

	'scalebar' => {
            'on'  => "on",
            'pos' => '1041',
            'col' => 'black',
            'max_divisions' => '6',
            'str' => 'b',
            'subdivs' => 'on',
            'abbrev' => 'on',
	},
    };

}
1;
