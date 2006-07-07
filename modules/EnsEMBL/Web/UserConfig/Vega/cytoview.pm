package EnsEMBL::Web::UserConfig::Vega::cytoview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self ) = @_;
  $self->{'_userdatatype_ID'} = 20;
  $self->{'_das_offset'} = '5080';

  $self->{'general'}->{'cytoview'} = {
    '_artefacts' => [qw(
        chr_band
        scalebar
        ruler
        stranded_contig
        annotation_status
        gene_legend
        marker
		encode
		alternative_assembly
        ntcontigs
        cloneset
        bac_map
        supercontigs
        tilepath
        bacends
        bacs
        nod_bacs
        bac_bands
        qtl 
        repeat_lite
        tilepath2
        missing 
        haplotype_links gap
        assemblyexception
      ) ],
    '_options'  => [],
    '_settings' => {
      'URL'       => '',
      'width'      => 700,
      'default_vc_size'  => 5000000,
      'band_box'     => 'show',
      'show_cytoview'  => 'yes',
      'opt_pdf' => 0, 
      'opt_svg' => 0, 
      'opt_postscript' => 0,
      'imagemap'     => 1,
      'opt_lines' => 1,
      'opt_empty_tracks' => 0,
      'opt_zmenus'     => 1,
      'opt_zclick'     => 1,
      'bgcolor'      => 'background1',
      'bgcolour1'    => 'background2',
      'bgcolour2'    => 'background3',
      'zoom_gifs'     => {
        zoom1   =>  200000, zoom2   =>   500000, zoom3   =>  1000000, zoom4   =>  2000000,
        zoom5   => 5000000, zoom6   => 10000000, zoom7   => 20000000, zoom8   => 50000000
      },
      'navigation_options' => [ '2mb', '1mb', 'window', 'half', 'zoom' ],
      'features' => [
        [ 'marker'       =>  'Markers'      ],
        [ 'qtl'          =>  'QTLs'        ],
        [ 'alternative_assembly'     => 'Ensembl assembly' ],
      ],
      'options' => [
  		[ 'encode'              => 'Encode regions' ],
        [ 'assemblyexception' => 'Assembly exceptions' ],
        [ 'bac_map'     => 'BAC map' 		],
        [ 'nod_bacs'    => 'Nod BACs'       ],
        [ 'bac_bands'     => 'Band BACs'       ],
        [ 'haplotype_links'    => 'Haplotype blocks'       ],
        [ 'bacs'     => 'BACs'       ],
        [ 'bacends'     => 'BACends'       ],
        [ 'supercontigs'  => 'FPC Contigs'     ],
        [ 'ntcontigs'     => 'NT Contigs'    ],
        [ 'chr_band'       => 'Chromosome bands'       ],
        [ 'stranded_contig' => 'Contigs'       ],
        [ 'ruler'       => 'Ruler'       ],
        [ 'scalebar'    => 'Scale Bar'     ],
        [ 'cloneset'    => '1Mb Cloneset'    ],
        [ 'tilepath'    => 'Tilepath'      ],
        [ 'tilepath2'     => 'Tilepath'     ],
        [ 'opt_lines'     => 'Show register lines' ],
        [ 'opt_empty_tracks'=> 'Show empty tracks' ],
        [ 'opt_zmenus'    => 'Show popup menus'  ],
        [ 'opt_zclick'    => '... popup on click'  ],
        [ 'gap'        => 'Gaps' ],
      ],
      'menus' => [ qw(features DAS options repeats export jumpto resize) ]
    },

    'stranded_contig' => {
      'on'  => "on",
      'pos' => '0',
      'col' => 'black',
      'threshold_navigation' => '10000'
    },
    'cloneset' => {
      'on'  => "on",
      'pos' => '1005',
      'colours' => {
        'col_MISMATCH'  => 'red',
        'col_DIFFERENT' => 'grey50',
        'col_SKNIGHT'   => 'orange',
        'col_GP'        => 'yellow',
        'col_SI_ENDSEQ' => 'gold',
        'col_EMBL'      => 'blue',
        'col_ENSEMBL'   => 'chartreuse',
        'col_ENSEMBL_NEW' => 'darkgreen',
        'col_'          => 'grey70',
        'lab_MISMATCH'  => 'white',
        'lab_DIFFERENT' => 'black',
        'lab_SKNIGHT'   => 'black',
        'lab_GP'        => 'black',
        'lab_SI_ENDSEQ' => 'black',
        'lab_EMBL'      => 'white',
        'lab_ENSEMBL'   => 'black',
        'lab_ENSEMBL_NEW' => 'white',
        'lab_'          => 'white',
        'seq_len' => 'black',
        'fish_tag' => 'black',
      },
      'str' => 'r',
      'dep' => '9999',
      'threshold_navigation' => '10000000',
      'fish' => 'FISH',
      'available' => 'features mapset_cloneset',
    },

    'haplotype_links' => {
      'on'  => "on",
      'pos' => '999',
      'col' => 'red',
      'lab' => 'white',
      'available' => 'features mapset_haplotype',
      'str' => 'r',
      'dep' => '9999999',
      'threshold_navigation' => '10000000',
      'outline_threshold'  => '35000000'
    },

    'encode' => {
      'on' => 'on',
      'pos' => '4000',
      'colour' => 'salmon',
      'label'  => 'black',
      'str' => 'r',
      'dep' => '9999',
      'threshold_navigation' => '10000000',
      'available' => 'features mapset_encode'
    },

    'alternative_assembly' => {
        'on'      => "off",
        'pos'       => '6',
        'dep'       => '6',
        'str'       => 'b',
        'other'     => 'Ensembl',
        'col'       => 'chartreuse3',
        'available' => 'features alternative_assembly',
    },

    'nod_bacs' => {
      'on'  => "on",
      'pos' => '997',
      'col' => 'red',
      'lab' => 'black',
      'available' => 'features mapset_nod_bacs',
      'str' => 'r',
      'dep' => '9999999',
      'threshold_navigation' => '100000',
      'outline_threshold'  => '350000'
    },
    'bac_bands' => {
      'on'      => "on",
      'pos'       => '996',
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
      'outline_threshold'  => '350000'
    },

    'bac_map' => {
      'on'  => "on",
      'pos' => '995',
      'col' => 'green',
      'lab' => 'black',
      'available' => 'features mapset_bac_map',
      'colours' => {
        'col_Free'        => 'gray80',
        'col_Phase0Ac'    => 'thistle2',
        'col_Committed'   => 'mediumpurple1',
        'col_PreDraftAc'  => 'plum',
        'col_Redundant'   => 'gray80',
        'col_Reserved'    => 'gray80',
        'col_DraftAc'     => 'gold2',
        'col_FinishAc'    => 'gold3',
        'col_Abandoned'   => 'gray80',
        'col_Accessioned' => 'thistle2',
        'col_Unknown'     => 'gray80',
        'col_'            => 'gray80',
        'lab_Free'        => 'black',
        'lab_Phase0Ac'    => 'black',
        'lab_Committed'   => 'black',
        'lab_PreDraftAc'  => 'black',
        'lab_Redundant'   => 'black',
        'lab_Reserved'    => 'black',
        'lab_DraftAc'     => 'black',
        'lab_FinishAc'    => 'black',
        'lab_Abandoned'   => 'black',
        'lab_Accessioned' => 'black',
        'lab_Unknown'     => 'black',
        'lab_'            => 'black',
        'bacend'          => 'black',
        'seq_len'         => 'black',
      },
      'str' => 'r',
      'dep' => '9999999',
      'threshold_navigation' => '100000',
      'full_threshold'     => '50000',
      'outline_threshold'  => '350000'
    },

    'supercontigs' => {
      'on'  => "on",
      'pos' => '990',
      'col' => 'green',
      'lab' => 'black',
      'available' => 'features mapset_superctgs',
      'colours' => {
        'col1' => 'darkgreen',
        'col2' => 'green',
        'lab1' => 'white',
        'lab2' => 'black',
      },
      'str' => 'r',
      'dep' => '9999999',
      'threshold_navigation' => '10000000'
    },

    'ntcontigs' => {
      'on'  => "on",
      'pos' => '991',
      'col' => 'green',
      'lab' => 'black',
      'available' => 'features mapset_ntctgs',
      'colours' => {
        'col1' => 'darkgreen',
        'col2' => 'green',
        'lab1' => 'black',
        'lab2' => 'black',
      },
      'str' => 'r',
      'dep' => '0',
      'threshold_navigation' => '10000000'
    },

    'tilepath2' => {
      'on'  => "on",
      'pos' => '985',
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

    'tilepath' => {
      'on'  => "on",
      'pos' => '1010',
      'col' => 'green',
      'lab' => 'black',
      'available' => 'features mapset_tilepath',
      'colours' => {
        'col1'    => 'red',
        'col2'    => 'orange',
        'lab1'    => 'black',
        'lab2'    => 'black',
        'fish_tag' => 'black',
      },
      'fish' => 'FISH',
      'str' => 'r',
      'dep' => '9999999',
      'threshold_navigation' => '10000000',
      'outline_threshold'  => '350000'
    },

    'annotation_status' => {
      'on'      => "on",
      'pos'       => '9999',
      'str'       => 'x',
      'lab'       => 'black',
      'label' => 'Annotation status',
      'navigation'  => 'on',
      'available' => 'features mapset_noannotation',
    },
    
    'marker' => {
      'on'  => "on",
      'pos' => '1501',
      'str' => 'r',
      'colours' => {$self->{'_colourmap'}->colourSet( 'marker' )},
      'available'=> 'features markers', 
    },
    'marker_label' => {
      'on'  => "on",
      'pos' => '1502',
      'col' => 'magenta',
      'available' => 'features markers'
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
    'qtl' => {
      'on' => 'on',
      'pos' => '1504',
      'col' => 'lightcoral',
      'lab' => 'black',
      'available' => 'features qtl',
      'dep' => '99999',
      'str' => 'r',
    },

    'scalebar' => {
      'on'   => "on",
      'nav'  => "on",
      'pos'  => '8000',
      'col'  => 'black',
      'str'  => 'b',
      'abbrev' => 'on',
      'navigation' => 'on'
    },
    'chr_band' => {
      'on'  => "on",
      'pos' => '9000',
    },
    'repeat_lite' => {
      'on'  => "on",
      'pos' => '4086',
      'str' => 'r',
      'col' => 'gray50',
      'threshold' => '1000',
      'navigation_threshold' => '1000',
      'navigation' => 'on'
    }, 
    'sub_repeat' => {
      'on'  => "on",
      'pos' => '4087',
      'str' => 'r',
      'col' => 'gray50',
      'threshold' => '2000',
      'navigation_threshold' => '1000',
      'navigation' => 'on'
    }, 
    'ruler' => {
      'on'  => "on",
      'pos' => '9010',
      'col' => 'black',
    },
    'gene_legend' => {
      'on'    => "on",
      'str'   => 'r',
      'pos'   => '100000',
      'src'   => 'all', # 'ens' or 'all'
        'dep'   => '6',
    },
    'missing' => {
      'on'    => "on",
      'str'   => 'r',
      'pos'   => '100001',
      'src'   => 'all', # 'ens' or 'all'
        'dep'   => '6',
    },
    'bacends' => {
      'on'      => "off",
      'pos'       => '1025',
      'col'      => 'red',
      'lab'      => 'black',
      'available'   => 'features bacends',
      'dep' => 6,
      'str' => 'r'
    },
    'urlfeature' => {
      'on'      => "on",
      'pos'       => '7099',
      'str'       => 'b',
      'col'       => 'red',
      'force_cigar' => 'yes',
      'dep'       => 6,
      'navigation'  => 'on',
      'navigation_threshold' => '2000',
      'threshold'   => '2000',
    },

    'bacs' => {
      'on'      => "off",
      'pos'       => '1026',
      'col'      => 'red',
      'lab'      => 'black',
      'available'   => 'features mapset_bacs',
      'colours'     => {
        'col_unmapped' => 'cadetblue3',
        'col_conflict' => 'firebrick1',
        'col_consistent' => 'darkgreen',
        'lab_unmapped' => 'white',
        'lab_conflict' => 'white',
        'lab_consistent' => 'white'
      },
      'dep'       => '9999',
      'str'       => 'r',
      'outline_threshold'  => '350000'
    },
    'assemblyexception' => {
      'on'      => "on",
      'pos'       => '9998',
      'str'       => 'x',
      'dep'       => '10000',
      'lab'       => 'black',
      'navigation'  => 'on',
    },


  };
  
  $self->ADD_GENE_TRACKS();
}
1;
