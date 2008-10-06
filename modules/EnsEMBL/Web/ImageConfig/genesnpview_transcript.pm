package EnsEMBL::Web::ImageConfig::genesnpview_transcript;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);


sub init {
  my ($self) = @_;
  
  $self->set_parameters({
    'title'            => 'Transcript slice',
    'show_buttons'     => 'yes',   # show +/- buttons
    'button_width'     => 8,       # width of red "+/-" buttons
    'show_labels'      => 'yes',   # show track names on left-hand side
    'label_width'      => 100,     # width of labels on left-hand side
    'margin'           => 5,       # margin
    'spacing'          => 2,       # spacing
    'opt_halfheight'   => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks' => 0,    # include empty tracks..
  });

  $self->create_menus(
#    'gsv_variations'  => 'Variations',
    'other'           => 'Decorations',
    'gsv_domain'      => 'Protein Domains'    
 );


   $self->add_tracks( 'other',
    [ 'gsv_transcript',   '',     'gsv_transcript',   { 'display' => 'on', 'colours' => $self->species_defs->colour('gene'), 'src' => 'all',  'strand' => 'b', 'menu' => 'no'  } ],
   );

  $self->load_tracks();

#  $self->add_tracks( 'gsv_variations',
#    [ 'variation',             '',     'gsv_variations',          { 'display' => 'normal',  'strand' => 'r', 'menu' => 'no'         } ],
#  );
  $self->add_tracks( 'other',
    [ 'draggable',        '',     'draggable',         { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
 #   [ 'snp_join',         '',     'snp_join',          { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
    [ 'spacer',           '',     'spacer',            { 'display' => 'normal',  'strand' => 'r', 'menu' => 'no'         } ],
  );


 
  #switch off all transcript unwanted transcript tracks
  foreach my $child ( $self->get_node('gsv_transcript')->descendants ) {
    $child->set( 'display' => 'off' );
  }

  $self->modify_configs(
    [qw(gsv_domain)],
    {qw(display on) }
  );

}
1;

__END__
      'validation' => [
        [ 'opt_freq'       => 'By frequency' ],
        [ 'opt_cluster'    => 'By cluster' ],
        [ 'opt_doublehit'  => 'By doublehit' ],
        [ 'opt_submitter'  => 'By submitter' ],
        [ 'opt_hapmap'     => 'Hapmap' ],
        [ 'opt_noinfo'     => 'No information' ],
      ],
      'classes' => [
        [ 'opt_in-del'   => 'In-dels' ],
        [ 'opt_snp'      => 'SNPs' ],
        [ 'opt_mixed'    => 'Mixed variations' ],
        [ 'opt_microsat' => 'Micro-satellite repeats' ],
        [ 'opt_named'    => 'Named variations' ],
        [ 'opt_mnp'      => 'MNPs' ],
        [ 'opt_het'      => 'Hetrozygous variations' ],
        [ 'opt_'         => 'Unclassified' ],
      ],
      'types' => [
       [ 'opt_non_synonymous_coding' => 'Non-synonymous' ],
       [ 'opt_synonymous_coding'     => 'Synonymous' ],
       [ 'opt_frameshift_coding'     => 'Frameshift' ],
       [ 'opt_stop_lost',            => 'Stop lost' ],
       [ 'opt_stop_gained',          => 'Stop gained' ],
       [ 'opt_essential_splice_site' => 'Essential splice site' ],
       [ 'opt_splice_site'           => 'Splice site' ],
       [ 'opt_upstream'              => 'Upstream' ],
       [ 'opt_regulatory_region',    => 'Regulatory region' ],
       [ 'opt_5prime_utr'            => "5' UTR" ],
       [ 'opt_intronic'              => 'Intronic' ],
       [ 'opt_3prime_utr'            => "3' UTR" ],
       [ 'opt_downstream'            => 'Downstream' ],
       [ 'opt_intergenic'            => 'Intergenic' ], 
      ],
    'GSV_transcript' => {
      'on'          => "on",
      'pos'         => '100',
      'str'         => 'b',
      'src'         => 'all', # 'ens' or 'all'
      'colours' => {$self->{'_colourmap'}->colourSet( 'all_genes' )} ,
    },
    'GSV_snps' => {
      'on'          => "on",
      'pos'         => '200',
      'str'         => 'r',
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')},
    },

  };
  $self->ADD_ALL_PROTEIN_FEATURE_TRACKS_GSV;
} 
1;
