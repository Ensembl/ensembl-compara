package EnsEMBL::Web::ImageConfig::TSV_context;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 31;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'_add_labels'} = 'yes';
  $self->{'general'}->{'TSV_context'} = {
    '_artefacts' => [qw(stranded_contig ruler scalebar variation transcriptexon_bgtrack spacer snp_join)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'show_labels' => 'yes',
      'width'   => 800,
      'opt_zclick'     => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
      'features' => [],
      'button_width'  => 8,
      'show_buttons'  => 'yes',
   },
    'scalebar' => {
      'on'          => "on",
      'nav'         => "off",
      'pos'         => '12000',
      'col'         => 'black',
      'label'       => 'chr',
      'str'         => 'f',
      'abbrev'      => 'on',
      'navigation'  => 'off',
    },
    'ruler' => {
      'on'          => "on",
      'str'         => 'f',
      'pos'         => '10000',
      'col'         => 'black',
    'notext'      => 1,
    },
    'stranded_contig' => {
      'on'          => "on",
      'pos'         => '0',
      'navigation'  => 'off'
    },
    'spacer' => { 'on'=>'on','pos'=>1e6, 'height' => 10, 'str' => 'r' },
    'snp_join' => {
      'tag'=>0,
      'on'=>'on',
      'pos'=>4600,
      'vailable'=> 'database DATABASE_VARIATION',
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')}, 'str' => 'r'
    },
    'transcriptexon_bgtrack' => {
      'on'          => "on",
      'pos'         => '5000',
      'str'         => 'b',
      'src'         => 'all', # 'ens' or 'all'
      'col'         => 'bisque',
      'tag'         => 0,
    }, 
    'variation' => {
      'on'  => "on",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4523',
      'str' => 'r',
      'col' => 'blue',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases DATABASE_VARIATION',
    },
  };
  $self->ADD_ALL_TRANSCRIPTS(2000);  #first is position
}
1;
