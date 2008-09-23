package EnsEMBL::Web::ImageConfig::genesnpview_gene;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 32;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'genesnpview_gene'} = {
    '_artefacts' => [qw( geneexon_bgtrack spacer snp_join)],
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
      'tag' => 1,
      'on'=>'on','pos'=>4600,
      'available'=> 'databases DATABASE_VARIATION',
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')}, 'str' => 'b'
    },
    'geneexon_bgtrack' => {
      'on'          => "on",
      'pos'         => '5000',
      'str'         => 'b',
      'src'         => 'all', # 'ens' or 'all'
      'col'         => 'bisque',
      'tag'         => 1
    }, 
  };
  $self->ADD_ALL_TRANSCRIPTS( );
}
1;
