package EnsEMBL::Web::ImageConfig::protview;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->_add_track_sets( qw(
    protein_decorations
    protein_domains
    protein_features
    legends
  ));
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
