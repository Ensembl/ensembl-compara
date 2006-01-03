package EnsEMBL::Web::UserConfig::Vega::altsplice;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
    my ($self) = @_;
    $self->{'_userdatatype_ID'} = 12;
    $self->{'_transcript_names_'} = 'yes';
    $self->{'general'}->{'altsplice'} = {
	'_artefacts' => [qw(
	    ruler
            contig
            glovar_snp
	)],
	
	'_options' => [qw(pos col known unknown)],
        '_settings'     => {
            'features' => [
                [ 'glovar_snp'                  => 'SNPs'               ],
            ],
            'show_labels' => 'yes',
	    'show_buttons'=> 'no',
	    'opt_shortlabels'     => 1,
            'opt_zclick'     => 1,
	    'width'       => 600,
	    'bgcolor'     => 'background1',
	    'bgcolour1'   => 'background1',
	    'bgcolour2'   => 'background1',
	},  

        'glovar_snp' => {
            'on'  => "on",
            'bump_width' => 0,
            'dep' => 0.1,
            'pos' => '90000',
            'str' => 'r',
            'col' => 'blue',
            'colours' => {$self->{'_colourmap'}->colourSet('snp')},
        },

	'ruler' => {
	    'on'  => "on",
	    'pos' => '11',
	    'str'   => 'r',
	    'col' => 'black',
	},
        
        'contig' => {
	    'on'  => "on",
	    'pos' => '0',
	    'col' => 'black',
	    'navigation'  => 'off',
        }
    };
    
    $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'on' );
}

1;
