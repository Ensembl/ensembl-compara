package EnsEMBL::Web::UserConfig::Vega::chromosome;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;

  $self->{'_userdatatype_ID'} = 6;

  $self->{'general'}->{'chromosome'} = {
    '_artefacts' => [qw(ideogram assemblyexception annotation_status hap_clone_matches)],
    '_options'  => [],
    '_settings' => {
      'simplehap' => 1,
      'width'   => 900,
      'show_thjview' => 'yes',
      'show_contigview' => 'yes',
      'show_cytoview'   => 'yes',
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'ideogram' => {
      'on'  => "on",
      'pos' => '6',
    },
    'assemblyexception' => {
      'on'      => "on",
      'pos'       => '9998',
      'str'       => 'x',
      'height'         => 1,
      'label'       => 'off',
      'navigation'  => 'on',
    },
    'annotation_status' => {
      'on'      => "on",
      'pos'       => '9999',
      'str'       => 'x',
      'lab'       => 'black',
      'label' => '',
      'height'  => 1,
      'navigation'  => 'on',
      'available' => 'features mapset_noannotation',
    },

	'hap_clone_matches', => {
	  'on' => "on", 
      'pos' => '10000', 
      'colour' => 'gold1', 
      'label'  => '',
      'height' => 1,
      'navigation' => 'on',
      'str' => 'r',
      'available' => 'features mapset_hclone',
	},

    };
}
1;
