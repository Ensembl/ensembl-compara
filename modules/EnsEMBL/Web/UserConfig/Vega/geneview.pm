package EnsEMBL::Web::UserConfig::Vega::geneview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
    my ($self) = @_;
    $self->{'_userdatatype_ID'} = 11; 
    $self->{'general'}->{'genetranscript'} = {
	'_artefacts' => [qw(
	    ruler
            vega_transcript
	)],
	
	'_options'  => [qw(pos col known unknown)],
	
	'_settings' => {
            'show_labels'  => 'no',
            'show_buttons' => 'no',
            'opt_zclick'     => 1,
	    'width'     => 600,
	    'bgcolor'   => 'background1',
	    'bgcolour1' => 'background1',
	    'bgcolour2' => 'background1',
	},

	'vega_transcript' => {
	    'on'      => "on",
	    'pos'     => '23',
	    'str'     => 'b',
	    'src'     => 'all', # 'ens' or 'all
            'colours' => {$self->{'_colourmap'}->colourSet( 'vega_gene' )},
            'label'   => "Vega trans.",
            'zmenu_caption' => "Vega Gene",
	},

        'ruler' => {
            'on' => 'on',
	    'str'   => 'r',
            'pos' => '10',
            'col' => 'black',
        },
    };
}
1;
