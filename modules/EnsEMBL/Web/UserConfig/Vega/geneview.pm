package EnsEMBL::Web::UserConfig::Vega::geneview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
    my ($self) = @_;
    $self->{'_userdatatype_ID'} = 11; 

    $self->{'general'}->{'geneview'} = {
	'_artefacts' => [qw( ruler )],
	
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

        'ruler' => {
            'on' => 'on',
	    'str'   => 'r',
            'pos' => '10',
            'col' => 'black',
        },
    };
    
    $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'on' );
    $self->ADD_ALL_PREDICTIONTRANSCRIPTS( 1000, 'on' => 'off' );
}
1;
