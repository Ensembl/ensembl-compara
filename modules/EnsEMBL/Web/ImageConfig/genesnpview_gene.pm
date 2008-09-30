package EnsEMBL::Web::ImageConfig::genesnpview_gene;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Transcript slice',
    'show_buttons'  => 'yes',   # show +/- buttons
    'button_width'  => 8,       # width of red "+/-" buttons
    'show_labels'   => 'yes',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,       # margin
    'spacing'       => 2,       # spacing
    'opt_halfheight'   => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks' => 0,    # include empty tracks..
  });
  $self->create_menus(
    'sequence'        => 'Sequence',
    'gsv_transcript'  => 'Transcripts',
    'gsv_domain'    => 'Protein domains',
    'gsv_variations'   => 'Variations',
    'other'           => 'Other'
  );
  $self->load_tracks();

  $self->add_tracks( 'gsv_variation',
    [ 'variation',             '',     'gsv_variations',          { 'display' => 'normal',  'strand' => 'r', 'menu' => 'no'         } ]
  );
  $self->add_tracks( 'other',
    [ 'geneexon_bgtrack', '',     'geneexon_bgtrack',  { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
    [ 'draggable',        '',     'draggable',         { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
    [ 'snp_join',         '',     'snp_join',          { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
    [ 'spacer',           '',     'spacer',            { 'display' => 'normal',  'strand' => 'r', 'menu' => 'no'         } ],
  );
  $self->modify_configs(
    [qw(gsv_transcript variation)],
    {'on'=>'off'}
  );
}

1;
__END__
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
