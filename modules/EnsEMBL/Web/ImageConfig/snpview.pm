package EnsEMBL::Web::ImageConfig::snpview;
use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Overview panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'button_width'  => 8,     # width of red "+/-" buttons
    'show_labels'   => 'yes', # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing

## Now let us set some of the optional parameters....
    'opt_halfheight'    => 1, # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks'  => 0, # include empty tracks..
    'opt_lines'         => 1, # draw registry lines
    'opt_restrict_zoom' => 1, # when we get "zoom" working draw restriction enzyme info on it!!
  });



  $self->create_menus(
    'transcript' => 'Genes',
    'prediction' => 'Prediction transcripts',
    'sequence'   => 'Sequence',
    'variation'  => 'Variation',
    'other'      => 'Decorations',
  );


  $self->add_tracks( 'sequence',
    [ 'contig',    'Contigs',              'stranded_contig', { 'display' => 'normal',  'strand' => 'r'  } ],
  );

  $self->add_tracks( 'other',
    [ 'ruler',     '',            'ruler',           { 'display' => 'on',  'strand' => 'b', 'name' => 'Ruler'      } ],
    [ 'scalebar',  '',            'scalebar',        { 'display' => 'on',  'strand' => 'r', 'name' => 'Scale bar'  } ],
  );


  $self->load_tracks();

  $self->modify_configs(
    [qw(variation)],
    {qw(style box)}
  );

  $self->modify_configs(
    [qw(variation_feature_variation)],
    {qw(display normal)}
  );



}

1;
__END__
sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 30;
  $self->{'_transcript_names_'} = 'yes';
  #$self->{'_no_label'} = 'true';
  $self->{'general'}->{'snpview'} = {
    '_artefacts' => [qw( 
                       stranded_contig
                       ruler
                       scalebar
		       variation_box
                       genotyped_variation
		       ld_r2
                       ld_d_prime 
                       haplotype
                       variation_legend
	   	       TSV_missing

                    )],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
     'features' => [
                     [ 'variation_box'            => "SNPs"          ],
                     [ 'variation_legend'         => "SNP legend"    ],
                     [ 'genotyped_variation'      => "Genotyped SNPs"],
                     [ 'ld_r2'      => "LD (r2)"],
                     [ 'ld_d_prime' => "LD (d')"],
                    ],
      'options' => [
                    [ 'opt_empty_tracks' => 'Show empty tracks' ],
                    [ 'opt_zmenus'      => 'Show popup menus'  ],
                    [ 'opt_zclick'      => '... popup on click'  ],
                   ],
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
       [ 'opt_non_synonymous_coding' => 'Non-synonymous SNPs' ],
       [ 'opt_synonymous_coding'     => 'Synonymous SNPs' ],
       [ 'opt_frameshift_coding'     => 'Frameshift variations' ],
       [ 'opt_stop_lost',            => 'Stop lost' ],
       [ 'opt_stop_gained',          => 'Stop gained' ],
       [ 'opt_essential_splice_site' => 'Essential splice site' ],
       [ 'opt_splice_site'           => 'Splice site' ],
       [ 'opt_upstream'              => 'Upstream variations' ],
       [ 'opt_regulatory_region',    => 'Regulatory region variations' ],
       [ 'opt_5prime_utr'            => "5' UTR variations" ],
       [ 'opt_intronic'              => 'Intronic variations' ],
       [ 'opt_3prime_utr'            => "3' UTR variations" ],
       [ 'opt_downstream'            => 'Downstream variations' ],
       [ 'opt_intergenic'            => 'Intergenic variations' ], 
      ],
    'snphelp' => [
        [ 'snpview'  => 'SNPView' ],
      ],

     'opt_empty_tracks' => 1,
      'opt_zmenus'     => 1,
      'opt_zclick'     => 1,
      'show_buttons'  => 'yes',
      'show_labels'      => 'yes',
      'width'     => 650,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background3',
      'bgcolour2' => 'background1',
    },
    'ruler' => {
      'on'          => "on",
      'pos'         => '1000',
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

   'variation_box' => {
      'on'          => "on",
      'pos'         => '4522',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_label' => "Variations",
      'track_height'=> 7,
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases DATABASE_VARIATION', 
    },

    'genotyped_variation' => {
      'on'          => "on",
      'pos'         => '4523',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'track_label' => "Genotyped variation",
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases DATABASE_VARIATION',
    },

    'ld_r2' => {
      'on'          => "off",
      'pos'         => '4550',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'track_label' => "LD(r2) for Global Pop.",
      'hi'          => 'black',
      'key'         => 'r2',
      'glyphset'    => 'ld',
      'colours'     => {$self->{'_colourmap'}->colourSet('variation')},
      'available'   => 'databases DATABASE_VARIATION',
    },
    'ld_d_prime' => {
      'on'          => "off",
      'pos'         => '4555',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'key'         => 'd_prime',
      'track_label' => "Linkage disequilibrium (d')" ,
      'hi'          => 'black',
      'glyphset'    => 'ld',
      'colours'     => {$self->{'_colourmap'}->colourSet('variation')},
      'available'   => 'databases DATABASE_VARIATION',
    },

     'TSV_missing' => {
      'on'  => "on",
      'dep' => 0.1,
      'pos' => '4500',
      'str' => 'r',
      'col' => 'blue',
    },

   'variation_legend' => {
      'on'          => "on",
      'str'         => 'r',
      'pos'         => '4525',
    },
  };

  # Make squished genes
  $self->ADD_ALL_TRANSCRIPTS(2000, compact => 1);  #first is position
}



1;


__END__


=head1 ImageConfig::snpview

=head2 SYNOPSIS

=head2 DESCRIPTION

=head2 METHODS

 Artefacts contains what is turned on.

 Settings: configures what is in the drop down yellow menus
 
 bgcolour: configures the background colours of the tracks. Alternate them to get differing shades: e.g.
     'bgcolor'   => 'background1',
      'bgcolour1' => 'background3',
      'bg

=head2 OPTIONS


=head3 B<strand>

Description: Configures this track on the forward (forward :   'str' => 'f') or reverse (reverse :   'str' => 'r',) strand 

=head3 B<position>

Example: 'pos'         => '4525',

Description: Position of the track within the drawable container and in comparison with all other tracks configured in this imageconfig.

=head3 B<on/off>

  Example:   'on' => 'on',
             'on' => 'off',

  Description: Whether this track is displayed by default ('on' => 'on'), or off by default ('on' => 'off').


=head3 B<available>

  Description: This track only displays if the availability criteria is met.  For example checking the database is there (e.g. 'databases DATABASE_VARIATION' ) or a specific table is there.

