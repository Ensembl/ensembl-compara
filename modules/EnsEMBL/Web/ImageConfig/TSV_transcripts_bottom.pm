package EnsEMBL::Web::ImageConfig::TSV_transcripts_bottom;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 36;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'_add_labels' }  = 1;
  $self->{'general'}->{'TSV_transcripts_bottom'} = {
    '_artefacts' => [qw(ruler transcriptexon_bgtrack spacer snp_join )],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'show_labels' => 'no',
      'width'   => 800,
      'opt_zclick'     => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'spacer' => { 'on'=>'on','pos'=>1e6, 'height' => 50, 'str' => 'r' },
    'snp_join' => {
      'tag'=>2, 'context'=>50,
      'on'=>'on','pos'=>4600,
      'str' => 'r',
      'available'=> 'databases DATABASE_VARIATION',
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')}, 
    },
    'ruler' => {
      'on'          => "on",
      'pos'         => '6000',
      'col'         => 'black',
      'str'         => 'r',
      'notext'      => 1,
    },
    'transcriptexon_bgtrack' => {
      'on'          => "on",
      'pos'         => '5000',
      'str'         => 'r',
      'src'         => 'all', # 'ens' or 'all'
      'col'         => 'bisque',
      'tag'         => 2 
    }, 

  };
}
1;
