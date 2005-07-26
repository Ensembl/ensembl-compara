package EnsEMBL::Web::UserConfig::genesnpview_snps;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 38;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'genesnpview_snps'} = {
    '_artefacts' => [qw( snp_fake variation_legend)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'show_labels' => 'no',
      'width'   => 900,
      'opt_zclick'     => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'spacer' => { 'on'=>'on','pos'=>0, 'height' => 50, 'str' => 'r' },

    'snp_fake' => {
      'str' => 'f',
      'tag' => 3,
      'on'=>'on',
      'pos'=>50,
      'available'=> 'databases ENSEMBL_VARIATION', 
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')}, 
    },

    'variation_legend' => {
      'on'          => "on",
      'str'         => 'r',
      'pos'         => '9999',
    },
  };
}
1;
