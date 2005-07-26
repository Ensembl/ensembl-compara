package EnsEMBL::Web::UserConfig::genesnpview_0;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 31;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'_add_labels'} = 'yes';
  $self->{'general'}->{'genesnpview_0'} = {
    '_artefacts' => [qw(stranded_contig ruler scalebar snp_lite transcript_lite haplotype geneexon_bgtrack spacer snp_join)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'show_labels' => 'yes',
      'width'   => 900,
      'opt_zclick'     => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
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
    },
    'stranded_contig' => {
      'on'          => "on",
      'pos'         => '0',
      'navigation'  => 'off'
    },
    'spacer' => { 'on'=>'on','pos'=>1e6, 'height' => 50, 'str' => 'r' },
    'snp_join' => {
      'tag'=>0,
      'on'=>'on','pos'=>4600,
      'available'=> 'database_tables ENSEMBL_LITE.snp',
      'colours'=>{$self->{'_colourmap'}->colourSet('snp')}, 'str' => 'r'
    },
    'transcript_lite' => {
      'on'          => "on",
      'pos'         => '21',
      'str'         => 'b',
      'src'         => 'all', # 'ens' or 'all'
      'colours' => {$self->{'_colourmap'}->colourSet( 'core_gene' )},
    },
    'geneexon_bgtrack' => {
      'on'          => "on",
      'pos'         => '5000',
      'str'         => 'b',
      'src'         => 'all', # 'ens' or 'all'
      'col'         => 'bisque',
      'tag'         => 0,
    }, 
    'snp_lite' => {
      'on'          => "on",
      'pos'         => '4520',
      'str'         => 'r',
      'bump_width'  => 0,
      'dep'         => '0.1',
      'col'         => 'blue',
      'track_height'=> 7,
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('snp')},
      'available'=> 'database_tables ENSEMBL_LITE.snp', 
    },
    'haplotype' => {
      'on'          => "on",
      'pos'         => '2000',
      'str'         => '6',
      'dep'         => 6,
      'col'         => 'darkgreen',
      'lab'         => 'black',
      'available'=> 'databases ENSEMBL_HAPLOTYPE',
    },
  };
}
1;
