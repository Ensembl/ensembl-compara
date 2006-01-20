package EnsEMBL::Web::UserConfig::protview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
    my ($self) = @_;

    $self->{'_userdatatype_ID'} = 4;
    $self->{'general'}->{'protview'} = {
	'_artefacts' => [qw(Pprot_scalebar Pprotein Pcoils Plow_complex Psignal_peptide
	Ptransmembrane Pprot_snp Psnp_legend)],
	'_options'   => [qw(on pos col hi known unknown)],
	'_names'     => {
	    'on'  => 'activate',
	    'pos' => 'position',
	    'col' => 'colour',
	    'dep' => 'bumping depth',
	    'str' => 'strand',
	    'hi'  => 'highlight colour',
	},
	'_settings' => {
	    'width'   => 500,
                  'opt_zclick'     => 1,

	    'bgcolor' => 'background1',
		'bgcolor2' => 'background3'
	},
	'Pprot_scalebar' => {
	    'on'  => "on",
	    'pos' => '1',
	    'col' => 'black',
	},
	'Pprotein' => {
	    'on'      => "on",
	    'pos'     => '3' + 10000,
	    'hi'      => 'green',
	    'col1'     => 'mediumorchid2',
		'col2'		=> 'darkorchid4',
	    'dep' => '6',
	},
	'Pintron' => {
	    'on'      => "on",
	    'pos'     => '4' + 10000,
	    'hi'      => 'green',
	    'col'     => 'purple1',
	    'dep' => '6',
	},
	'Pcoils' => {
	    'on'      => "on",
	    'pos'     => '5' + 10000,
	    'dep'     => '0',
	    'hi'      => 'green',
	    'col'     => 'darkblue',
	    'dep' => '6',
	},
	'Plow_complex' => {
	    'on'      => "on",
	    'pos'     => '7' + 10000,
	    'dep'     => '0',
	    'hi'      => 'green',
	    'col'     => 'gold2',
	    'dep' => '6',
	},
	'Psignal_peptide' => {
	    'on'      => "on",
	    'pos'     => '9' + 10000,
	    'dep'     => '6',
	    'hi'      => 'green',
	    'col'     => 'pink',
	    'dep' => '6',
	},
	'Ptransmembrane' => {
	    'on'      => "on",
	    'pos'     => '11' + 10000,
	    'dep'     => '6',
	    'hi'      => 'green',
	    'col'     => 'darkgreen',
	    'dep' => '6',
	},
	'Pprot_snp' => {
	    'on'      => "on",
	    'pos'     => '2' + 10000,
	    'dep'     => '6',
	    'hi'      => 'green',
	    'col'     => 'contigblue1',
		'c0'	  => 'white',
		'syn'	  => 'seagreen2',
		'insert'  => 'skyblue2',
		'delete'  => 'skyblue2',
		'snp'	  => 'hotpink2',
	},
	'Psnp_legend' => {
	    'on'      => "on",
	    'pos'     => '0',
	    'dep'     => '6',
		'syn'	  => 'seagreen2',
		'in-del' => 'skyblue2',
		'non-syn'	  => 'hotpink2',
	},
	'Ppdb' => {
	    'on'      => "on",
	    'pos'     => '21' + 10000,
	    'dep'     => '6',
	    'hi'      => 'blue',
	    'col'     => 'blue',
	},
    };
    $self->ADD_ALL_PROTEIN_FEATURE_TRACKS();
}
1;
