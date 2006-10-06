package EnsEMBL::Web::UserConfig::cytoview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
my ($self ) = @_;
$self->{'_userdatatype_ID'} = 20;
$self->{'_das_offset'} = '5080';

$self->{'general'}->{'cytoview'} = {
 '_artefacts' => [qw(chr_band scalebar ruler stranded_contig gene_legend marker
      ntcontigs supercontigs encode bacends qtl
      repeat_lite missing 
      haplotype_links gap 
      assemblyexception
      blast_new redbox ) ],
  '_settings' => {
    'URL'       => '',
    'width'      => 900,
    'default_vc_size'  => 5000000,
    'band_box'     => 'show',
    'show_cytoview'  => 'yes',
    'imagemap'     => 1,
    'opt_pdf' => 0, 'opt_svg' => 0, 'opt_postscript' => 0,
    'opt_lines' => 1,
    'opt_empty_tracks' => 0,
    'opt_gene_labels' => 1,
    'opt_zmenus'     => 1,
    'opt_zclick'     => 1,
    'bgcolor'      => 'background1',
    'bgcolour1'    => 'background2',
    'bgcolour2'    => 'background3',
    'show_bands_nav' => 'yes',
    'zoom_gifs'     => {
       zoom1   =>  200000, zoom2   =>   500000, zoom3   =>  1000000, zoom4   =>  2000000,
       zoom5   => 5000000, zoom6   => 10000000, zoom7   => 20000000, zoom8   => 50000000
    },
    'navigation_options' => [ '2mb', '1mb', 'window', 'half', 'zoom' ],
    'compara' => [ ],
    'features' => [
      [ 'marker'       =>  'Markers'      ],
      [ 'qtl'          =>  'QTLs'        ],
      # [ 'decipher'     =>  'DECIPHER'    ],
    ],
    'options' => [
#      [ 'bac_map'     => 'BAC map' 		],
      [ 'haplotype_links'    => 'Haplotype blocks'       ],
      [ 'bacends'     => 'BACends'       ],
      [ 'supercontigs'  => 'FPC Contigs'     ],
      [ 'ntcontigs'     => 'NT Contigs'    ],
      [ 'chr_band'       => 'Chromosome bands'       ],
      [ 'stranded_contig' => 'Contigs'       ],
      [ 'ruler'       => 'Ruler'       ],
      [ 'scalebar'    => 'Scale Bar'     ],
      [ 'encode'       => 'Encode regions'  ],
      [ 'opt_gene_labels'     => 'Show gene labels' ],
      [ 'opt_lines'     => 'Show register lines' ],
      [ 'opt_empty_tracks'=> 'Show empty tracks' ],
      [ 'opt_zmenus'    => 'Show popup menus'  ],
#      [ 'opt_zclick'    => '... popup on click'  ],
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

## Blast and SSAHA tracks displayed if linked to from Blast/SSAHA...
## These get put beside the central track and so have low pos

    'redbox' => {
      'on' => 'off',
      'pos' => '1000000',
      'col' => 'gold',
      'zindex' => -20,
    },

    'blast_new' => {
      'on'  => "on",
      'pos' => '7',
      'col' => 'red',
      'dep' => '6',
      'str' => 'b',
      'force_cigar' => 'yes',
    },

  'cloneset_1mb' => {
    'on'  => "on",
    'pos' => '1005',
    'colours' => {
 'col_CES_AVC_MISMATCH' => 'red',
 'col_CES_ONLY' => 'grey50' ,
 'col_CES_UNVERIFIED' => 'grey50' ,
 'col_CLONE_ACCESSION' => 'gold' ,
 'col_CLONE_ACCESSION_END_SEQ_UCSC' => 'gold' ,
 'col_END_SEQ_UCSC' => 'gold' ,
 'col_REPICK_CLONE_ACCESSION' => 'orange' ,
 'col_REPICK_CLONE_ACCESSION' => 'orange' ,
 'col_REPICK_END_CLONE_ACCESSION' => 'orange' ,
 'col_REPICK_END_CLONE_ACCESSION_END_SEQ_UCSC' => 'orange' ,
 'col_REPICK_END_ONLY_CLONE_ACCESSION' => 'orange' ,
 'col_REPICK_END_ONLY_CLONE_ACCESSION_END_SEQ_UCSC' => 'orange' ,
 'col_REPICK_END_SEQ_UCSC' => 'orange' ,
 'col_SSAHA2' => 'contigblue2',
 'col_TELOMERE' => 'grey50' ,
 'col_TPF_CLONE_ACCESSION' => 'gold' ,
 'col_TPF_CLONE_ACCESSION_2' => 'gold' ,
 'lab_CES_AVC_MISMATCH' => 'white',
 'lab_CES_ONLY' => 'black' ,
 'lab_CES_UNVERIFIED' => 'black' ,
 'lab_CLONE_ACCESSION' => 'black' ,
 'lab_CLONE_ACCESSION_END_SEQ_UCSC' => 'black' ,
 'lab_END_SEQ_UCSC' => 'black' ,
 'lab_REPICK_CLONE_ACCESSION' => 'white' ,
 'lab_REPICK_CLONE_ACCESSION' => 'white' ,
 'lab_REPICK_END_CLONE_ACCESSION' => 'white' ,
 'lab_REPICK_END_CLONE_ACCESSION_END_SEQ_UCSC' => 'white' ,
 'lab_REPICK_END_ONLY_CLONE_ACCESSION' => 'white' ,
 'lab_REPICK_END_ONLY_CLONE_ACCESSION_END_SEQ_UCSC' => 'white' ,
 'lab_REPICK_END_SEQ_UCSC' => 'white' ,
 'lab_SSAHA2' => 'black',
 'lab_TELOMERE' => 'black' ,
 'lab_TPF_CLONE_ACCESSION' => 'black' ,
 'lab_TPF_CLONE_ACCESSION_2' => 'black' ,
      'seq_len' => 'black',
      'fish_tag' => 'black',
    },
    'str' => 'r',
    'dep' => '9999',
    'threshold_navigation' => '10000000',
    'fish' => 'FISH',
    'available' => 'features mapset_cloneset_1mb',
  },
  'cloneset_37k' => {
    'on'  => "on",
    'pos' => '1006',
    'colours' => {
 'col_CES_AVC_MISMATCH' => 'red',
 'col_CES_ONLY' => 'grey50' ,
 'col_CES_UNVERIFIED' => 'grey50' ,
 'col_CLONE_ACCESSION' => 'gold' ,
 'col_CLONE_ACCESSION_END_SEQ_UCSC' => 'gold' ,
 'col_END_SEQ_UCSC' => 'gold' ,
 'col_REPICK_CLONE_ACCESSION' => 'orange' ,
 'col_REPICK_CLONE_ACCESSION' => 'orange' ,
 'col_REPICK_END_CLONE_ACCESSION' => 'orange' ,
 'col_REPICK_END_CLONE_ACCESSION_END_SEQ_UCSC' => 'orange' ,
 'col_REPICK_END_ONLY_CLONE_ACCESSION' => 'orange' ,
 'col_REPICK_END_ONLY_CLONE_ACCESSION_END_SEQ_UCSC' => 'orange' ,
 'col_REPICK_END_SEQ_UCSC' => 'orange' ,
 'col_SSAHA2' => 'contigblue2',
 'col_TELOMERE' => 'grey50' ,
 'col_TPF_CLONE_ACCESSION' => 'gold' ,
 'col_TPF_CLONE_ACCESSION_2' => 'gold' ,
 'lab_CES_AVC_MISMATCH' => 'white',
 'lab_CES_ONLY' => 'black' ,
 'lab_CES_UNVERIFIED' => 'black' ,
 'lab_CLONE_ACCESSION' => 'black' ,
 'lab_CLONE_ACCESSION_END_SEQ_UCSC' => 'black' ,
 'lab_END_SEQ_UCSC' => 'black' ,
 'lab_REPICK_CLONE_ACCESSION' => 'white' ,
 'lab_REPICK_CLONE_ACCESSION' => 'white' ,
 'lab_REPICK_END_CLONE_ACCESSION' => 'white' ,
 'lab_REPICK_END_CLONE_ACCESSION_END_SEQ_UCSC' => 'white' ,
 'lab_REPICK_END_ONLY_CLONE_ACCESSION' => 'white' ,
 'lab_REPICK_END_ONLY_CLONE_ACCESSION_END_SEQ_UCSC' => 'white' ,
 'lab_REPICK_END_SEQ_UCSC' => 'white' ,
 'lab_SSAHA2' => 'black',
 'lab_TELOMERE' => 'black' ,
 'lab_TPF_CLONE_ACCESSION' => 'black' ,
 'lab_TPF_CLONE_ACCESSION_2' => 'black' ,
      'seq_len' => 'black',
      'fish_tag' => 'black',
    },
    'str' => 'r',
    'dep' => '9999',
    'threshold_navigation' => '10000000',
    'fish' => 'FISH',
    'available' => 'features mapset_cloneset_37k',
  },

  'cloneset_32k' => {
    'on' => 'on',
    'pos' => '1007',
    'colour' => 'green',
    'str' => 'r',
    'dep' => '9999',
    'threshold_navigation' => '10000000',
    'available' => 'features mapset_cloneset_32k' 
  },

  'encode' => {
    'on' => 'on',
    'pos' => '1010',
    'colour' => 'salmon',
    'label'  => 'black',
    'str' => 'r',
    'dep' => '9999',
    'threshold_navigation' => '10000000',
    'available' => 'features mapset_encode'
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
    'pos' => '1011',
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

  'marker' => {
    'on'  => "on",
    'pos' => '1501',
    'str' => 'r',
    'colours' => {$self->{'_colourmap'}->colourSet( 'marker' )},
    'labels' => 'on',
    'available'=> 'features markers', 
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
    'navigation' => 'on',
    'available' => 'features ENSEMBL_DB.repeat_feature'
  }, 
  'sub_repeat' => {
    'on'  => "on",
    'pos' => '4087',
    'str' => 'r',
    'col' => 'gray50',
    'threshold' => '2000',
    'navigation_threshold' => '1000',
    'navigation' => 'on',
    'available' => 'features ENSEMBL_DB.repeat_feature'
  }, 
  'ruler' => {
    'on'  => "on",
    'pos' => '9010',
    'col' => 'black',
  },
  'gene_legend' => {
    'on'    => "on",
    'str'   => 'r',
    'pos'   => '2000100',
    'src'   => 'all', # 'ens' or 'all'
    'dep'   => '6',
  },
  'missing' => {
    'on'    => "on",
    'str'   => 'r',
    'pos'   => '3000100',
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
      'dep'       => 9999,
      'navigation'  => 'on',
      'navigation_threshold' => '2000',
      'threshold'   => '200000',
    },

  'bacs' => {
    'on'      => "off",
    'pos'       => '1020',
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
  #'decipher' => {
  #  'on'     => "on",
  #  'pos'    => '4000',
  #  'dep'    => 9999,
  #  'str'    => 'r'
  #},
    'assemblyexception' => {
      'on'      => "on",
      'pos'       => '9998',
      'str'       => 'x',
      'lab'       => 'black',
      'dep'       => 6,
      'navigation'  => 'on',
    },


};
$self->ADD_GENE_TRACKS();
$self->ADD_SYNTENY_TRACKS();
$self->ADD_ALL_CLONE_TRACKS(0,'on'=>'on');
}
1;
