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
		'_artefacts' => [qw(TSE_background_exon TSE_transcript TSE_generic_match_label TSE_generic_match SE_generic_match SE_generic_match_label non_can_intron spacer1)],
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

		'TSE_transcript' => {
			'on'          => "on",
			'pos'         => '300',
			'str'         => 'f',
			'src'         => 'all',
			'colours' => {$self->{'_colourmap'}->colourSet( 'all_genes' )} ,
#			'col'         => 'd8ddff',
			'col'         => 'bisque',
		},

		'spacer1' => { 'on'=>'on','pos'=>280, 'height' => 30, 'str' => 'b', 'glyphset' => 'spacer' },

		'non_can_intron' => {
			'on'          => "on",
			'pos'         => '260',
			'str'         => 'f',
			'src'         => 'all',
			'col'         => 'red',
		},

		'TSE_generic_match_label' => {
			'on'          => "on",
			'pos'         => '201',
			'str'         => 'f',
			'src'         => 'all', # 'ens' or 'all'
		},

		'TSE_generic_match' => {
			'on'          => "on",
			'pos'         => '200',
			'str'         => 'f',
			'src'         => 'all', # 'ens' or 'all'
			'colours' => {$self->{'_colourmap'}->colourSet( 'all_genes' )} ,
		},

		'SE_generic_match_label' => {
			'on'          => "on",
			'pos'         => '101',
			'str'         => 'f',
			'src'         => 'all', # 'ens' or 'all'
			'colours' => {$self->{'_colourmap'}->colourSet( 'all_genes' )} ,
		},

		'SE_generic_match' => {
			'on'          => "on",
			'pos'         => '100',
			'str'         => 'f',
			'src'         => 'all', # 'ens' or 'all'
			'colours' => {$self->{'_colourmap'}->colourSet( 'all_genes' )} ,
		},
		'TSE_background_exon' => {
			'on'          => "on",
			'pos'         => '0',
			'str'         => 'f',
			'src'         => 'all',
#			'col'         => 'd8ddff',
			'col'         => 'bisque',
			'tag'         => 1,
			'flag'        => 1,
			'glyphset'    => 'TSE_background_exon',
		},
	};	
}
1;
