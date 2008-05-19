package EnsEMBL::Web::UserConfig::genesnpview_transcripts_top;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 36;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'_add_labels' }  = 1;
  $self->{'general'}->{'genesnpview_transcripts_top'} = {
    '_artefacts' => [qw(geneexon_bgtrack snp_join)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'show_labels' => 'no',
      'width'   => 800,
      'opt_zclick'     => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'snp_join' => {
      'tag'=>2, 'context'=>50,
      'on'=>'on','pos'=>4600,
      'str' => 'f',
      'available'=> 'databases ENSEMBL_VARIATION',
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')}
    },
    'geneexon_bgtrack' => {
      'on'          => "on",
      'pos'         => '5000',
      'str'         => 'f',
      'src'         => 'all', # 'ens' or 'all'
      'col'         => 'bisque',
      'tag'         => 2 
    }, 
  };
}
1;
