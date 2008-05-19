package EnsEMBL::Web::UserConfig::protview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;

  $self->{'_das_offset'} = 2100;
  $self->{'_userdatatype_ID'} = 4;
  $self->{'general'}->{'protview'} = {
    '_artefacts' => [qw(Pprot_scalebar Pprotein Pprot_snp Psnp_legend)],
    '_options'   => [qw(on pos col hi known unknown)],
    '_names'   => {
      'on'  => 'activate',
      'pos' => 'position',
      'col' => 'colour',
      'dep' => 'bumping depth',
      'str' => 'strand',
      'hi'  => 'highlight colour',
    },
    '_settings' => {
      'width'   => 800,
      'opt_zclick'   => 1,
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
      'col1'    => 'mediumorchid2',
      'col2'    => 'darkorchid4',
    },
    'Pintron' => {
      'on'      => "on",
      'pos'     => '4' + 10000,
      'hi'      => 'green',
      'col'     => 'purple1',
    },
	'Pprot_snp' => {
	    'on'      => "on",
	    'pos'     => '2' + 10000,
	    'dep'     => '6',
	    'hi'      => 'green',
	    'col'     => 'contigblue1',
		'c0'	  => 'white',
		'syn'	  => 'chartreuse2',
		'insert'  => 'skyblue2',
		'delete'  => 'skyblue2',
		'snp'	  => 'gold',
	},
	'Psnp_legend' => {
	    'on'      => "on",
	    'pos'     => '0',
	    'dep'     => '6',
		'syn'	  => 'chartreuse2',
		'in-del'  => 'skyblue2',
		'non-syn' => 'gold',
	},
  };
  $self->ADD_ALL_PROTEIN_FEATURE_TRACKS();
}
1;
