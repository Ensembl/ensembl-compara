package EnsEMBL::Web::ImageConfig::TSV_transcript;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 32;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'_add_labels' }  = 1;
  $self->{'general'}->{'TSV_transcript'} = {
   '_artefacts' => [qw( transcriptexon_bgtrack spacer snp_join )],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'show_labels' => 'no',
      'width'   => 800,
      'opt_zclick'     => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'spacer' => { 'on'=>'on','pos'=>1e6, 'height' => 20, 'str' => 'r' },

    'snp_join' => {
      'tag' => 1,
      'on'  => 'on',
      'pos' => 4600,
      'str' => 'b',
      'available'=> 'databases DATABASE_VARIATION',
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')},
    },
    'ruler' => {
      'on'          => "on",
      'pos'         => '10000',
      'col'         => 'black',
    },
    'stranded_contig' => {
      'on'          => "on",
      'pos'         => '0',
      'navigation'  => 'off'
    },
    'scalebar' => {
      'on'          => "on",
      'nav'         => "off",
      'pos'         => '8000',
      'col'         => 'black',
      'str'         => 'r',
      'abbrev'      => 'on',
      'navigation'  => 'off'
    },
    'transcriptexon_bgtrack' => {
      'on'          => "on",
      'pos'         => '5000',
      'str'         => 'b',
      'src'         => 'all', # 'ens' or 'all'
      'col'         => 'bisque',
      'tag'         => 1
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
  $self->ADD_ALL_TRANSCRIPTS( );
}
1;
