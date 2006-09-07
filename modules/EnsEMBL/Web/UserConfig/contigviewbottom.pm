package EnsEMBL::Web::UserConfig::contigviewbottom;
use strict;
no strict 'refs';
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
use Bio::EnsEMBL::Registry;
my $reg = "Bio::EnsEMBL::Registry";
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self ) = @_;
  $self->{'_das_offset'} = '5800';

  $self->{'no_image_frame'} = 1;
  $self->{'_userdatatype_ID'} = 1;
  $self->{'_add_labels'} = 'yes';
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'contigviewbottom'} = {
    '_artefacts' => [
## The following are the extra fugu bits... 
## Only features whose key is in this array gets displayed as a track....
       qw( blast_new ),
       qw( tp32k assemblyexception
        repeat_lite 
        variation variation_affy100 variation_affy500
        genotyped_variation_line 
        histone_modifications
        signal_map
        trna   cpg eponine marker operon rnai ex_profile qtl ep1_h ep1_s
        first_ef
        all_affy 

        alternative_assembly
        matepairs  bacends 
        ruler     scalebar  stranded_contig
        sequence  codonseq  codons gap gcplot encode
	encode_region regulatory_search_regions regulatory_regions
#       redbox
        restrict),
    # qw( zfish_est ),
     qw(glovar_snp)
    ],
    '_settings' => {
## Image size configuration...
      'width'         => 900,
      'spacing'       => 2,
      'margin'        => 5,
      'label_width'   => 100,
      'button_width'  => 8,
      'show_buttons'  => 'yes',
      'show_labels'   => 'yes',
## Parameters for "zoomed in display"
      'squished_features' => 'yes', 
      'zoom_zoom_gifs'     => {
        zoom1   =>  25,   zoom2   =>  50,
        zoom3   =>  100,  zoom4   =>  200,
        zoom5   =>  300,  zoom6   => 500
      },
      'show_zoom_contigview' => 'yes',
      'zoom_width' => 100,
      
      'URL'       => '',
      'show_contigview' => 'yes',
      'name'      => qq(ContigView Detailed Window),
## Other stuff...
      'clone_based'   => 'no',
      'clone_start'   => '1',
      'clone'       => 1,
#      'draw_red_box'  => 'no',
      'default_vc_size' => 100000,
      'main_vc_width'   => 100000,
      'imagemap'    => 1,
      'opt_pdf' => 0, 'opt_svg' => 0, 'opt_postscript' => 0,
      'opt_lines'      => 1,
      'opt_empty_tracks' => 0,
      'opt_show_bumped' => 0,
      'opt_daswarn'    => 0,
      'opt_zmenus'     => 1,
      'opt_zclick'     => 1,
      'opt_halfheight'     => 0,
      'opt_shortlabels'     => 0,
      'opt_restrict_zoom' => 1,
      'bgcolor'     => 'background1',
      'bgcolour1'     => 'background2',
      'bgcolour2'     => 'background3',
      'show_bands_nav' => 'yes',
      'zoom_gifs'     => {
        zoom1   =>  1000,   zoom2   =>  5000,   zoom3   =>  10000,  zoom4   =>  50000,
        zoom5   =>  100000, zoom6   =>  200000, zoom7   =>  500000, zoom8   =>  1000000
      },
      'navigation_options' => [ '5mb', '2mb', '1mb', 'window', 'half', 'zoom' ],
      'features' => [
         # 'name'          => 'caption'       
## TRANSCRIPT STYLE TRACKS ##
## PREDICTION TRACKS ##
## PROTEIN TRACKS ##
## CDNA/MRNA TRACKS ##
## EST TRACKS ##
## OTHER (SIMPLE) FEATURES ##
         [ 'variation'                => 'SNPs'  ],
         [ 'genotyped_variation_line' => 'Genotyped SNPs'  ],
         [ 'variation_affy100'        => 'Affy 100k SNP'  ],
         [ 'variation_affy500'        => 'Affy 500k SNP'  ],
         [ 'histone_modifications'       => 'Histone modifications'  ],
         [ 'signal_map'               => 'Signal map'  ],
         [ 'glovar_snp'               => 'Glovar SNPs' ], ## not ready for prime time yet
        #[ 'glovar_trace'   => 'Glovar traces'], ## not ready for prime time yet
         [ 'trna'                     => 'tRNA'        ],
         [ 'cpg'                      => 'CpG islands'     ],
         [ 'eponine'                  => 'Eponine regions'   ],
         [ 'ep1_h'                    => 'Ecore (Human)'   ],
         [ 'ep1_s'           => 'Ecore (Mouse)'   ],
         [ 'first_ef'        => 'First EF'    ],
         [ 'marker'          => 'Markers'       ],
         [ 'qtl'             => 'QTLs'     ],
         [ 'operon'          => 'Operon'      ],
         [ 'regulatory_regions'       => 'Regulatory features'  ],
         [ 'regulatory_search_regions'=> 'Regulatory search regions'  ],
         [ 'rnai'            => 'RNAi'        ],
         [ 'ex_profile'      => 'Exp. profile'    ],
         [ 'alternative_assembly'     => 'Vega assembly' ],
### Other ###
         [ 'encode_region'   => 'ENCODE' ],
## MICROARRAY TRACKS ##
         [ 'all_affy'                => 'All-Probe-Sets' ],
## Matches ##
      ],
      'compara' => [ ],
      'options' => [
         # 'name'            => 'caption'
         # [ 'assemblyexception' => 'Assembly exceptions' ],
         [ 'sequence'        => 'Sequence'      ],
         [ 'codonseq'        => 'Codons'      ],
         [ 'codons'          => 'Start/Stop codons' ],
         [ 'stranded_contig' => 'Contigs'       ],
         [ 'ruler'           => 'Ruler'       ],
         [ 'scalebar'        => 'Scale Bar'     ],
         [ 'encode'          => 'Encode regions' ],
         [ 'gcplot'          => '%GC'         ],
         [ 'opt_lines'       => 'Show register lines' ],
         [ 'opt_empty_tracks' => 'Show empty tracks' ],
         [ 'opt_zmenus'      => 'Show popup menus'  ],
#         [ 'opt_zclick'      => '... popup on click'  ],
         [ 'opt_show_bumped' => 'Show # bumped glyphs'  ],
         [ 'opt_halfheight'  => 'Half-height glyphs'  ],
	 [ 'opt_shortlabels' => 'Concise labels' ],
         [ 'matepairs'       => 'Bad Matepairs' ],
	 [ 'gap'             => 'Gaps' ],
         [ 'restrict'        => 'Rest.Enzymes' ],
         [ 'opt_restrict_zoom'   => 'Rest.Enzymes on zoom' ],
      #   [ 'vegaclones'     => 'Vega clones' ],
         [ 'bacends'         => 'BAC ends' ],
      ],
      'menus' => [ qw( features DAS options repeats export jumpto resize )]
    },

## Stranded contig is the central track so should always have pos set to 0...
  
    'stranded_contig' => {
      'on'  => "on",
      'navigation' => 'on',
      'pos' => '0',
    },

## Blast and SSAHA tracks displayed if linked to from Blast/SSAHA...
## These get put beside the central track and so are numbered 4 and 6
#    'redbox' => {
#      'on' => 'off',
#      'pos' => '1000000',
#      'col' => 'red',
#      'zindex' => -20,
#   },
    'blast_new' => {
      'on'  => "on",
      'pos' => '8',
      'col' => 'red',
      'dep' => '6',
      'str' => 'b',
      'force_cigar' => 'yes',
    },
  
    'blast' => {
      'on'  => "on",
      'pos' => '6',
      'col' => 'red',
      'str' => 'b',
    },
  
    'ssaha' => {
      'on'  => "on",
      'pos' => '7',
      'col' => 'red',
      'str' => 'b',
    },

## Transcript tracks are in the middle...
  
### Now we will follow by the "grouped features" tracks
### 
    'all_affy' => {
      'on' => 'off',
      'pos' => '4030',
      'col' => 'springgreen4',
      'src' => 'all',
      'dep' => '6',
      'str' => 'b',
      'compact'   => 0,
      'available' => 'features mapset_all_affy',
      'glyphset'  => 'generic_microarray',
      'FEATURES'  => 'All_Affy',
    },
## Now for the simple features....
    'trna' => {
      'on'  => "off",
      'pos' => '2500',
      'str'   => 'b',
      'col' => 'gold3',
      'available'=> 'features tRNAscan', 
    },
    'e2' => {
      'on'  => "off",
      'pos' => '2519',
      'str' => 'b',
      'col' => 'purple',
      'glyphset' => 'generic_simplest',
      'label'    => 'Eponine 2',
      'description' => 'Eponine regions<br />This is a <br />test',
      'code'     => 'tRNAscan',
      'available'=> 'features tRNAscan', 
    },
    'eponine' => {
      'on'  => "off",
      'pos' => '2520',
      'str' => 'b',
      'col' => 'red',
      'available'=> 'features Eponine', 
    },

    'ep1_h' => {
      'on'  => "off",
      'pos' => '2522',
      'str' => 'b',
      'col' => 'darkgreen',
      'available'=> 'features ep1_h', 
    },
    'ep1_s' => {
      'on'  => "off",
      'pos' => '2523',
      'str' => 'b',
      'col' => 'darkgreen',
      'available'=> 'features ep1_s', 
    },

  # col is for colours. Not needed here as overwritten in Glyphset
   'regulatory_regions' => {
      'on'  => "off",
      'pos' => '12',
      'str' => 'b',
      'available'=> 'database_tables ENSEMBL_DB.regulatory_feature', 
    },

   'regulatory_search_regions' => {
      'on'  => "off",
      'pos' => '13',
      'str' => 'b',
      'available'=> 'database_tables ENSEMBL_DB.regulatory_search_region',
    },

    'first_ef'   => {
      'on'       => "off",
      'pos'      => '2521',
      'str'      => 'b',
      'col'      => 'red',
      'available'=> 'features FirstEF', 
    },
## Markers and other features...
    'codons' => {
      'on'  => "off",
      'pos' => '4010',
      'str' => 'b',
      'col' => 'purple1',
      'threshold' => '50'
    },
  'bacends' => {
    'on'      => "off",
    'pos'       => '4090',
    'col'      => 'red',
    'lab'      => 'black',
    'available'   => 'features bacends',
    'dep' => 6,
    'str' => 'r'
  },

  'misc_bacends' => {
    'on'      => "off",
    'pos'       => '4091',
    'col'      => 'red',
    'lab'      => 'black',
    'available'   => 'features mapset_bacends',
    'dep' => 10,
    'str' => 'r'
  },

  'encode_region' => {
    'on'      => "off",
    'pos'       => '4092',
    'col'      => 'sienna1',
    'lab'      => 'black',
    'available'   => 'features mapset_encode_regions',
    'dep' => 10,
    'str' => 'r'
  },

    'marker' => {
      'on'  => "on",
      'pos' => '4100',
      'col' => 'magenta',
      'str' => 'r',
      'colours' => {$self->{'_colourmap'}->colourSet( 'marker' )},
      'labels' => 'on',
      'available'=> 'database_tables ENSEMBL_DB.marker_feature',
    },

    'qtl' => {
      'on' => 'on',
      'pos' => '4102',
      'col' => 'lightcoral',
      'lab' => 'black',
      'available' => 'features qtl',
      'dep' => '99999',
      'str' => 'r',
    },

     'operon' => {
      'on'  => "off",
      'pos' => '4511',
      'str' => 'r',
      'col' => 'lightseagreen',
      'available'=> 'features operon', 
    },
     'rnai' => {
      'on'  => "off",
      'pos' => '4512',
      'str' => 'r',
      'col' => 'lightseagreen',
      'available'=> 'features RNAi', 
    },
     'ex_profile' => {
      'on'  => "off",
      'pos' => '4513',
      'str' => 'r',
      'col' => 'lightseagreen',
      'available'=> 'features Expression_profile', 
    },
    
## Strand independent tracks...

     'cpg' => {
      'on'  => "off",
      'pos' => '4510',
      'str' => 'r',
      'col' => 'purple4',
      'available'=> 'features CpG', 
    },

    'glovar_snp' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4521',
      'str' => 'r',
      'col' => 'blue',
      'colours' => {$self->{'_colourmap'}->colourSet('snp')},
      'available'=> 'databases ENSEMBL_GLOVAR', 
    },

    'glovar_trace' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 50,
      'pos' => '4522',
      'str' => 'r',
      'col' => 'blue',
      'colours' => {$self->{'_colourmap'}->colourSet('snp')},
      'available'=> 'databases ENSEMBL_GLOVAR', 
    },

    'variation' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4523',
      'str' => 'r',
      'col' => 'blue',
      'threshold' => '50',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases ENSEMBL_VARIATION', 
    },
    'variation_affy100' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4525',
      'str' => 'r',
      'col' => 'blue',
      'track_label' => 'Affy 100k SNP',
      'key'         => 50,
      'glyphset'    => 'variation_affy',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'species Homo_sapiens', 
    },
    'variation_affy500' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4526',
      'str' => 'r',
      'col' => 'blue',
      'track_label' => 'Affy 500k SNP',
      'key'         => 250,
      'glyphset'    => 'variation_affy',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'species Homo_sapiens',  
    }, 

    'histone_modifications' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4527',
      'str' => 'r',
      'col' => 'blue',
      'threshold' => '50',
      'track_label' => 'Histone modifications',
      'glyphset'    => 'histone_modifications',
      'available'=> 'databases ENSEMBL_FUNCGEN',  
    }, 

   'signal_map' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4528',
      'str' => 'r',
      'col' => 'blue',
      'key' => 'Nimblegen_CHIP2_data',  # name of a subset of experimental chips
      'track_label' => 'Signal map',
      'glyphset'    => 'signal_map',
      'available'=> 'databases ENSEMBL_FUNCGEN', 
    }, 

   'genotyped_variation_line' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4524',
      'str' => 'r',
      'col' => 'blue',
      'threshold' => '100',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'database_tables ENSEMBL_VARIATION.population_genotype', 
    },
#    'blat' => {
#      'on'      => "off",
#      'pos'       => '80',
#      'col'       => 'pink',
#      'str'       => 'b',
#    },

## Repeats 
    'codonseq' => {
      'on'      => "off",
      'pos'       => '4',
      'str'       => 'b',
      'bump_width'   => 0,
      'lab'       => 'black',
      'dep'       => 3,
      'colours'     => {
# hydrophobic
'A' => 'darkseagreen1',  # Alanine
'G' => 'mediumseagreen',  # Glycine
'I' => 'greenyellow',  # Isoleucine
'L' => 'olivedrab1',  # Leucine
'M' => 'green',  # Methionine
'P' => 'springgreen1',  # Proline
'V' => 'darkseagreen3',  # Valine
# large hydrophobic
'F' => 'paleturquoise',  # Phenylalanine
'H' => 'darkturquoise',  # Histidine
'W' => 'skyblue',  # Tryptophan
'Y' => 'lightskyblue',  # Tyrosine
# Cysteine
'C' => 'khaki',  # Cysteine
# Negative charge
'D' => 'gold',  # Aspartic Acid
'E' => 'darkgoldenrod1',  # Glutamic Acid
# Positive charge
'K' => 'lightcoral',  # Lysine
'R' => 'rosybrown',  # Arginine
# Polar 
'N' => 'plum2',  # Asparagine
'Q' => 'thistle1',  # Glutamine
'S' => 'mediumpurple1',  # Serine
'T' => 'mediumorchid1',  # Threonine
# Stop codon...
'*' => 'red',  # Stop
    },
      'navigation'  => 'on',
      'navigation_threshold' => '0',
      'threshold'   => '0.5',
    }, 
    'assemblyexception' => {
      'on'      => "on",
      'dep'       => 6,
      'pos'       => '999999',
      'str'       => 'x',
      'lab'       => 'black',
      'navigation'  => 'on',
    },

    'sequence' => {
      'on'      => "off",
      'pos'       => '3',
      'str'       => 'b',
      'lab'       => 'black',
      'colours'     => {
         'G' => 'lightgoldenrod1',
         'T' => 'lightpink2',
         'C' => 'lightsteelblue',
         'A' => 'lightgreen',
      },
      'navigation'  => 'on',
      'navigation_threshold' => '0',
      'threshold'   => '0.2',
    }, 
    'repeat_lite' => {
      'on'      => "off",
      'pos'       => '5000',
      'str'       => 'r',
      'col'       => 'gray50',
      'navigation'  => 'on',
      'navigation_threshold' => '2000',
      'threshold'   => '2000',
    }, 
    'urlfeature' => {
      'on'      => "on",
      'pos'       => '7099',
      'str'       => 'b',
      'col'       => 'red',
      'force_cigar' => 'yes',
      'dep'       => 9999,
      'navigation'  => 'on',
      'navigation_threshold' => '2000',
      'threshold'   => '2000',
    }, 
    'sub_repeat' => {
      'on'      => "on",
      'pos'       => '5010',
      'str'       => 'r',
      'col'       => 'gray50',
      'navigation'  => 'on',
      'navigation_threshold' => '2000',
      'threshold'   => '2000',
    }, 
## The measurement decorations    
    'ruler' => {
      'on'      => "on",
      'pos'       => '7000',
      'col'       => 'black',
    },
    'scalebar' => {
      'on'      => "on",
      'pos'       => '7010',
      'col'       => 'black',
      'label'     => 'on',
      'max_division'  => '12',
      'str'       => 'b',
      'subdivs'     => 'on',
      'abbrev'    => 'on',
      'navigation'  => 'on'
    },
    
## "Clone" level structural tracks

    'alternative_assembly' => {
        'on'      => "off",
        'pos'       => '5',
        'dep'       => '6',
        'str'       => 'b',
        'other'     => 'Vega',
        'col'       => 'chartreuse3',
        'available' => 'features alternative_assembly',
    },
    
    'tp32k' => {
      'on'  => "on",
      'pos' => '8014',
      'col' => 'gold3',
      'lab' => 'black',
      'available' => 'features mapset_tp32k',
      'colours' => {
        'col'    => 'gold3',
        'lab'    => 'black',
      },
      'str' => 'r',
      'dep' => '9999999',
      'threshold_navigation' => '10000000',
      'outline_threshold'  => '350000'
    },

    'tilepath2' => {
      'on'  => "on",
      'pos' => '8015',
      'col' => 'green',
      'lab' => 'black',
      'available' => 'features mapset_acc_bac_map',
      'colours' => {
        'col1'    => 'red',
        'col2'    => 'orange',
        'lab1'    => 'black',
        'lab2'    => 'black',
        'bacend'  => 'black',
        'seq_len'   => 'black',
      },
      'str' => 'r',
      'dep' => '9999999',
      'threshold_navigation' => '10000000',
      'outline_threshold'  => '350000'
    },

   'encode' => {
      'on' => 'on',
      'pos' => '8040',
      'colour' => 'salmon',
      'label'  => 'black',
      'str' => 'r',
      'dep' => '9999',
      'threshold_navigation' => '10000000',
      'available' => 'features mapset_encode'
    },

    'tilepath' => {
      'on'  => "on",
      'pos' => '8016',
      'fish'      => 'no-fish',
      'col' => 'green',
      'lab' => 'black',
      'available' => 'features mapset_tilepath',
      'colours' => {
        'col1'    => 'red',
        'col2'    => 'orange',
        'lab1'    => 'black',
        'lab2'    => 'black',
      },
      'str' => 'r',
      'dep' => '9999999',
      'threshold_navigation' => '10000000',
      'outline_threshold'  => '350000'
    },

    'matepairs' => {
      'on'      => "off",
      'pos'       => '8025',
      'col'      => 'blue',
      'lab'      => 'black',
      'available'   => 'features mapset_matepairs',
      'colours' => {
       'col_LeftLeft' => 'gold',
       'col_RightRight' => 'gold',
       'col_Outie' => 'darkred',
       'col_WrongDistance' => 'orange',
       'lab_LeftLeft' => 'black',
       'lab_RightRight' => 'black',
       'lab_Outie' => 'white',
       'lab_WrongDistance' => 'black',
       },
    'dep'       => '9999',
      'str'       => 'r',
    },
  'fosmid_map' => {
    'on' => 'on',
    'height' => 5,
    'pos' => '8028',
    'col' => 'purple2',
    'lab' => 'black',
    'available' => 'features mapset_fosmid_map',
    'colours' => {
      'col' => 'purple2',
      'lab' => 'black'
    },
    'str' => 'r',
    'dep' => '9999999',
    'threshold_navigation' => '100000',
    'full_threshold'     => '50000',
    'outline_threshold'  => '350000'
  },

    'bacs' => {
      'on'      => "off",
      'pos'       => '8026',
      'col'      => 'red',
      'lab'      => 'black',
      'available'   => 'features mapset_bacs',
      'colours'     => {
         'col_unmapped' => 'contigblue1',
         'col_conflict' => 'darkblue',
         'col_consistent' => 'darkgreen',
         'lab_unmapped' => 'white',
         'lab_conflict' => 'white',
         'lab_consistent' => 'white'
      },
	  'dep'       => '9999',
      'str'       => 'r',
    },
	  'bac_bands' => {
      'on'      => "on",
      'pos'       => '8027',
      'col'      => 'darkred',
      'lab'      => 'black',
      'available'   => 'features mapset_bacs_bands',
      'colours'     => {
         'col_unmapped' => 'contigblue2',
         'col_conflict' => 'darkslateblue',
         'col_consistent' => 'springgreen4',
         'lab_unmapped' => 'white',
         'lab_conflict' => 'white',
         'lab_consistent' => 'white'
      },
    'dep'       => '9999',
      'str'       => 'r',
    },
    'gap' => {
      'on'      => "off",
      'pos'       => '8020',
      'col1'      => 'red',
      'col2'      => 'orange',
      'lab1'      => 'black',
      'lab2'      => 'black',
      'available'   => 'features mapset_gap',
      'str'       => 'r',
    },
    'restrict' => {
      'on'      => "off",
      'pos'       => '5990',
      'lab1'      => 'black',
      'lab2'      => 'black',
      'str'       => 'r',
      'threshold'   => 2 
    },
## DAS-based data for manually annotated clones from Vega    
    'vegaclones' => {
      'on'      => "off",
      'pos'       => '6000',
      'colours'     => {
        'col1'      => 'red3',
        'col2'      => 'seagreen',
        'col3'      => 'gray50',
        'lab1'      => 'red3',
        'lab2'      => 'seagreen',
        'lab3'      => 'gray50',
      },
      'str'       => 'r',
      'dep'       => '0',
    },
    'assembly_contig' => {
      'on'      => "on",
      'pos'       => '8030',
      'colours'     => {
        'col1'      => 'contigblue1',
        'col2'      => 'contigblue2',
        'lab1'      => 'white',
        'lab2'      => 'white',
      },
      'str'       => 'r',
      'dep'       => '0',
      'available'   => 'features mapset_assembly', 
    },
    
## And finally the GC plot track    
    'gcplot'  => {
      'on'      => "off",
      'pos'       => '9010',
      'str'       => 'r',
      'col'       => 'gray50',
      'line'      => 'red',
      'hi'      => 'black',
      'low'       => 'black',
    },

  };

  my $POS = $self->ADD_ALL_TRANSCRIPTS();
## Loop through registry for additional transcript tracks...
  $reg->add_new_tracks($self,$POS);
  $self->ADD_ALL_PREDICTIONTRANSCRIPTS();
  $self->ADD_ALL_PROTEIN_FEATURES();
  $self->ADD_ALL_DNA_FEATURES();
  $self->ADD_ALL_EST_FEATURES();
  $self->ADD_SIMPLE_TRACKS();
  $self->ADD_ALL_CLONE_TRACKS();
## Additional tracks... on the forward strand ( top );
  $self->add_track( 'preliminary', 'on' => 'on', 'pos' => 1, 'str' => 'f' );
  $self->add_track( 'mod',         'on' => 'off', 'pos' => 3000200, 'str' => 'f' );
## Additional tracks... on the reverse strand ( bottom );
  $self->add_track( 'info',        'on' => 'on', 'str' => 'r', 'pos' => 3000300, '_menu' => 'options', 'caption' => 'Information track' );
  $self->add_track( 'missing',     'on' => 'on', 'str' => 'r', 'pos' => 3000100 );
  $self->add_track( 'gene_legend', 'on' => 'on', 'str' => 'r', 'pos' => 2000000,  '_menu' => 'options', 'caption' => 'Gene legend' );
  $self->add_track( 'variation_legend',  'on' => 'on', 'str' => 'r', 'pos' => 2000100, '_menu' => 'options', 'caption' => 'SNP legend'  );

  $self->ADD_ALL_OLIGO_TRACKS();

## And finally the multispecies tracks....
  my @species = @{$self->{'species_defs'}->ENSEMBL_SPECIES};
  my $compara = 3000;
  my @methods = (
    [ 'TRANSLATED_BLAT'      ,'orchid1', 'trans BLAT',   'translated BLAT' ],
    [ 'PHUSION_BLASTN_TIGHT' ,'pink3',   'high cons bp', 'highly conserved PHUSION BLAST' ],
    [ 'BLASTZ_GROUP_TIGHT'   ,'pink3',   'high cons bz', 'highly conserved BLASTz (group)' ],
    [ 'BLASTZ_NET_TIGHT'     ,'pink3',   'high cons bz', 'highly conserved BLASTz (net)' ],
    [ 'PHUSION_BLASTN'       ,'pink',    'pblast',      'PHUSION BLAST'  ],
    [ 'BLASTZ_GROUP'         ,'pink',    'blastz',      'BLASTz (group)'  ],
    [ 'BLASTZ_NET'           ,'pink',    'blastz',      'BLASTz (net)'  ],
    [ 'BLASTZ_RECIP_NET'     ,'pink',    'blastz',      'BLASTz (recip. net)'  ],
  );
  foreach my $METHOD (@methods) {
    foreach my $SPECIES (@species) {
      (my $species = $SPECIES ) =~ s/_\d+//;
      my $short = $self->{'species_defs'}->other_species( $species, 'SPECIES_COMMON_NAME' );
      (my $abbrev = $species ) =~ s/^(\w)\w+_(\w)\w+$/\1\2/g;
      $compara++;
      my $KEY = lc($SPECIES).'_'.lc($METHOD->[0]).'_match';
      $self->{'general'}->{'contigviewbottom'}{$KEY} = {
        'glyphset' => 'generic_alignment',
        'species'  => $species,
        'on'       => 'off',
        'compact'  => 1,
        'dep'      => 6,
        'pos'      => $compara+300,
        'col'      => $METHOD->[1],
        'str'      => 'f',
        'available'=> "multi ".$METHOD->[0]."|$species",
        'method'   => $METHOD->[0],
	'method_id' => $METHOD->[4] || 0,
        'label'    => "$abbrev $METHOD->[2]",
        'title'    => "$short  $METHOD->[3]",
      };
      push @{ $self->{'general'}->{'contigviewbottom'}{ '_artefacts'} }, $KEY;
      push @{ $self->{'general'}->{'contigviewbottom'}{'_settings'}{'compara'} },  [ $KEY , "$short $METHOD->[3]" ];
    }
  }

# Add multiple alignments tracks
  my @multimethods;
  my %alignments = $self->{'species_defs'}->multiX('ALIGNMENTS');
  my $species = $ENV{ENSEMBL_SPECIES};
  foreach my $id (
		  sort { 10 * ($alignments{$a}->{'type'} cmp $alignments{$b}->{'type'}) + ($a <=> $b) }
		  grep { $alignments{$_}->{'species'}->{$species} } 
		  keys (%alignments)) {


      my @species = grep {$_ ne $species} sort keys %{$alignments{$id}->{'species'}};

      next if ( scalar(@species) == 1);
      my $label = $alignments{$id}->{'name'};

      push @multimethods, [ $id, 'pink', $label, $label, $id ];
  }

  foreach my $METHOD (@multimethods) {
      $compara++;
      my $KEY = lc($METHOD->[0]).'_match';
      $self->{'general'}->{'contigviewbottom'}{$KEY} = {
        'glyphset' => 'multiple_alignment',
        'species'  => $species,
        'on'       => 'off',
        'compact'  => 1,
        'dep'      => 6,
        'pos'      => $compara+300,
        'col'      => $METHOD->[1],
        'str'      => 'f',
        'available'=> "multialignment ".$METHOD->[0],
        'method'   => $METHOD->[0],
	'method_id' => $METHOD->[4],
        'label'    => $METHOD->[2],
        'title'    => $METHOD->[3],
      };
      push @{ $self->{'general'}->{'contigviewbottom'}{ '_artefacts'} }, $KEY;
      push @{ $self->{'general'}->{'contigviewbottom'}{'_settings'}{'compara'} },  [ $KEY , $METHOD->[3] ];
  }


}
1;
