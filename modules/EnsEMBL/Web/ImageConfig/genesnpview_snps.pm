package EnsEMBL::Web::ImageConfig::genesnpview_snps;
use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'SNPs',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'show_labels'   => 'no',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing
    'bgcolor'       => 'background1',
    'bgcolour1'     => 'background3',
    'bgcolour2'     => 'background1',
  });
  $self->create_menus(
    'other'           => 'Other'
  );

  $self->add_tracks( 'other',
    [ 'ruler',     '', 'ruler',     { 'display' => 'normal',  'strand' => 'r', 'name' => 'Ruler' } ],
  );

  $self->load_tracks();

  $self->modify_configs(
    [qw(transcript prediction)],
    {qw(on off height 32 non_coding_scale 0.5)}
  );

}
1;

__END__
sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 38;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'genesnpview_snps'} = {
    '_artefacts' => [qw( snp_fake  snp_fake_haplotype variation_legend  TSV_haplotype_legend TSV_missing)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'show_labels' => 'no',
      'width'   => 800,
      'opt_zclick'     => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background3',
      'bgcolour2' => 'background1',
    },
    'spacer' => { 'on'=>'on','pos'=>0, 'height' => 50, 'str' => 'r' },

    'snp_fake' => {
      'str' => 'f',
      'tag' => 3,
      'on'=>'on',
      'pos'=>50,
      'available'=> 'databases DATABASE_VARIATION', 
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')}, 
    },

    'snp_fake_haplotype' => {
      'str' => 'r',
      'on'=>'off',
      'pos'=>10001,
      'available'=> 'databases DATABASE_VARIATION',
    },
   'TSV_missing' => {
      'on'  => "on",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '5523',
      'str' => 'r',
      'col' => 'blue',
    },

    'variation_legend' => {
      'on'          => "on",
      'str'         => 'r',
      'pos'         => '9999',
    },

    'TSV_haplotype_legend' => {
      'on'          => "off",
      'str'         => 'r',
      'pos'         => '10004',
     'available'    => 'databases DATABASE_VARIATION',
     'colours'      => {$self->{'_colourmap'}->colourSet('haplotype')}, 
				   },
  };
}
1;
