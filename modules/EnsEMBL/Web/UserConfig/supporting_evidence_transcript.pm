package EnsEMBL::Web::UserConfig::supporting_evidence_transcript;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
	my ($self) = @_;
	$self->{'_userdatatype_ID'} = 50;
	$self->{'_transcript_names_'} = 'yes';
	$self->{'_add_labels' }  = 1;
	$self->{'general'}->{'supporting_evidence_transcript'} = {
		'_artefacts' => [qw(TSE_transcript TSE_generic_match SE_generic_match)],
		'_options'  => [],
		'_settings' => {
			'opt_pdf' => 0, 'opt_svg' => 0, 'opt_postscript' => 0,
			'opt_zclick'     => 1,
			'show_labels' => 'yes',
			'width'   => 1000,
			'bgcolor'   => 'background1',
			'bgcolour1' => 'background1',
			'bgcolour2' => 'background1',
			'validation' => [ ],
			'classes' => [ ],
			'types' => [ ],
			'features' => [],
		},
		'ruler' => {
			'on'      => "on",
			'pos'       => '7000',
			'col'       => 'black',
		},
		'TSE_transcript' => {
			'on'          => "on",
			'pos'         => '200',
			'str'         => 'f',
			'src'         => 'all', # 'ens' or 'all'
			'colours' => {$self->{'_colourmap'}->colourSet( 'all_genes' )} ,
		},
		'TSE_generic_match' => {
			'on'          => "on",
			'pos'         => '100',
			'str'         => 'f',
			'src'         => 'all', # 'ens' or 'all'
			'colours' => {$self->{'_colourmap'}->colourSet( 'all_genes' )} ,
		},
		'SE_generic_match' => {
			'on'          => "on",
			'pos'         => '50',
			'str'         => 'f',
			'src'         => 'all', # 'ens' or 'all'
			'colours' => {$self->{'_colourmap'}->colourSet( 'all_genes' )} ,
		},
	};	
}
1;
