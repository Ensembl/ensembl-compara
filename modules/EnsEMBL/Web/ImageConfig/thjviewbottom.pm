package EnsEMBL::Web::ImageConfig::thjviewbottom;

use warnings;
no warnings 'uninitialized';
use strict;
no strict 'refs';

use base qw(EnsEMBL::Web::ImageConfig);

my $reg = "Bio::EnsEMBL::Registry";

sub TRIM   { return sub { return $_[0]=~/(^[^\.]+)\./ ? $1 : $_[0] }; }

sub init {
  my ($self ) = @_;
  $self->{'_das_offset'} = '5800';

  $self->{'_userdatatype_ID'} = 240;
  $self->{'_add_labels'} = 'yes';
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'thjviewbottom'} = {
    '_artefacts' => [
## The following are the extra fugu bits... 
## Only features whose key is in this array gets displayed as a track....
       qw( blast_new repeat_lite ),
       qw( stranded_contig ruler scalebar navigation assemblyexception), # quote),
       qw( all_affy
        variation trna cpg eponine marker operon rnai ex_profile qtl first_ef qtl
       ),
    ],
    '_options'  => [qw(on pos col hi low dep str src known unknown ext)],
    '_names'   => {
      'on'    => 'activate',
      'pos'   => 'position',
      'col'   => 'colour',
      'dep'   => 'depth',
      'str'   => 'strand',
      'hi'    => 'highlight colour',
      'src'   => 'source',
      'known'   => 'known colour',
      'unknown' => 'unknown colour',
      'ext'   => 'external colour',
    },
    '_settings' => {
## Image size configuration...
      'spritelib' => { 'default' => $self->{'species_defs'}->ENSEMBL_SERVERROOT.'/htdocs/img/sprites' },
      'width'         => 800,
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
      'zoom_width' => 100,
      
      'URL'       => '',
      'show_thjview' => 'yes',
      'show_multicontigview' => 'yes',
      'name'      => qq(ContigView Detailed Window),
## Other stuff...
      'draw_red_box'  => 'no',
      'default_vc_size' => 100000,
      'main_vc_width'   => 100000,
      'imagemap'    => 1,
    'opt_pdf' => 0, 'opt_svg' => 0, 'opt_postscript' => 0,
      'opt_match'       => 1,
      'opt_hcr'         => 1,
      'opt_tblat'       => 1,
      'opt_join_transcript'  => 1,
      'opt_join_match'  => 1,
      'opt_join_hcr'    => 1,
      'opt_join_tblat'  => 1,
      'opt_group_match'  => 0,
      'opt_group_hcr'    => 0,
      'opt_group_tblat'  => 0,
      'opt_join_lines'      => 1,
      'opt_lines'      => 1,
      'opt_empty_tracks' => 0,
      'opt_daswarn'    => 0,
      'opt_show_bumped'  => 0,
      'opt_zmenus'     => 1,
      'opt_zclick'     => 1,
      'opt_halfheight'     => 0,
      'opt_shortlabels'     => 1,
      'bgcolor'     => 'background1',
      'bgcolour1'     => 'background2',
      'bgcolour2'     => 'background3',
      'zoom_gifs'     => {
        zoom1   =>  1000,   zoom2   =>  5000,   zoom3   =>  10000,  zoom4   =>  50000,
        zoom5   =>  100000, zoom6   =>  200000, zoom7   =>  500000, zoom8   =>  1000000
      },
      'navigation_options' => [ '2mb', '1mb', 'window', 'half', 'zoom' ],
      'features' => [
         # 'name'          => 'caption'       
## SIMPLE FEATURES ##
         [ 'variation'        => 'SNPs'        ],
         [ 'trna'            => 'tRNA'        ],
         [ 'cpg'             => 'CpG Islands'     ],
         [ 'eponine'         => 'Eponine Regions'   ],
         [ 'first_ef'        => 'First EF'    ],
         [ 'marker'          => 'Markers'       ],
         [ 'qtl'             => 'QTLs'     ],
         [ 'operon'          => 'Operon'      ],
         [ 'rnai'            => 'RNAi'        ],
         [ 'ex_profile'      => 'Exp. profile'    ],
      ],
      'compara' => [ 
        ['opt_match'            => 'Blastz net'],
        ['opt_tblat'            => 'Translated BLAT'],
        ['opt_join_match'       => 'Join Blastz net'],
        ['opt_join_tblat'       => 'Join tr. BLAT'],
        ['opt_join_transcript'  => 'Join transcripts'],
        ['opt_group_match'      => 'Group Blastz net'],
      ],
      'options' => [
         # 'name'            => 'caption'
         [ 'stranded_contig' => 'Contigs'       ],
         [ 'opt_lines'       => 'Show register lines' ],
         [ 'opt_empty_tracks' => 'Show empty tracks' ],
         [ 'opt_zmenus'      => 'Show popup menus'  ],
         [ 'opt_zclick'      => '... popup on click'  ],
         [ 'opt_halfheight'  => 'Half-height glyphs'  ],
         [ 'opt_show_bumped' => 'Show # bumped glyphs'  ],
         [ 'info'            => 'Information track' ],
      ],
      'menus' => [ qw( features compara repeats options jumpto export resize )]
    },

## Stranded contig is the central track so should always have pos set to 0...
  
    'stranded_contig' => {
      'on'  => "on",
      'navigation' => 'on',
      'pos' => '0',
    },

## Blast and SSAHA tracks displayed if linked to from Blast/SSAHA...
## These get put beside the central track and so are numbered 4 and 6

    'blast_new' => {
      'on'  => "on",
      'pos' => '7',
      'col' => 'red',
      'dep' => '6',
      'str' => 'b',
      'force_cigar' => 'yes',
    },
  
    'blast' => {
      'on'  => "on",
      'pos' => '5',
      'col' => 'red',
      'str' => 'b',
    },
  
    'ssaha' => {
      'on'  => "on",
      'pos' => '6',
      'col' => 'red',
      'str' => 'b',
    },

## Now for the simple features....
    'trna' => {
      'on'  => "off",
      'pos' => '2500',
      'str'   => 'b',
      'col' => 'gold3',
      'available'=> 'features tRNAscan', 
    },
    'eponine' => {
      'on'  => "off",
      'pos' => '2520',
      'str' => 'b',
      'col' => 'red',
      'available'=> 'features Eponine', 
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

    'marker' => {
      'on'  => "off",
      'pos' => '4100',
      'col' => 'magenta',
      'str' => 'r',
      'colours' => {$self->{'_colourmap'}->colourSet( 'marker' )},
      'available'=> 'features markers', 
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
    'variation' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4520',
      'str' => 'r',
      'col' => 'blue',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases DATABASE_VARIATION', 
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

    'haplotype' => {
      'on'  => "off",
      'pos' => '4525',
      'str' => 'r',
      'dep' => 6,
      'col' => 'red',
      'lab' => 'black',
      'available'=> 'databases ENSEMBL_HAPLOTYPE', 
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
      'pos'       => '8498932',
      'dep' => 6,
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
      'dep'       => 6,
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
      'max_division'  => '12',
      'label'     => 'on',
      'str'       => 'b',
      'subdivs'     => 'on',
      'abbrev'    => 'on',
      'navigation'  => 'on'
    },
    
## "Clone" level structural tracks

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

## and legend....    
    'gene_legend' => {
      'on'      => "on",
      'str'       => 'r',
      'pos'       => '9999',
    },
    'snp_legend' => {
      'on'      => "on",
      'str'       => 'r',
      'type'      => 'square',
      'pos'       => '10000',
      'available'   => 'databases EMSEMBL_VARIATION'
    },
    'missing' => {
      'on'      => "on",
      'str'       => 'r',
      'pos'       => '10001',
    },
    'info' => {
      'on'      => "off",
      'str'       => 'r',
      'pos'       => '10003',
    },
    'mod' => {
      'on'      => "on",
      'str'       => 'f',
      'pos'       => '10002',
    },
    'preliminary' => {
      'on'      => "on",
      'str'       => 'f',
      'pos'       => '1',
    },

    'navigation' => {
      'on' => 'on',
      'str' => 'r',
      'pos' => 1e9
    },
    'quote' => {
      'on' => 'on',
      'str' => 'r',
      'pos' => 1.1e9
    },
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

  };

  my $POS = $self->ADD_ALL_TRANSCRIPTS( 0 );
## Loop through registry for additional transcript tracks...
  $reg->add_new_tracks($self,$POS);
  $self->ADD_ALL_PREDICTIONTRANSCRIPTS( 0, 'on' => 'off' );
  $self->ADD_ALL_PROTEIN_FEATURES( 0, 'on' => 'off' );
  $self->ADD_ALL_DNA_FEATURES( 0, 'on' => 'off' );
  $self->ADD_ALL_EST_FEATURES( 0, 'on' => 'off' );
  $self->ADD_ALL_OLIGO_TRACKS( 0, 'on' => 'off' );
  $self->ADD_SIMPLE_TRACKS( );
}

sub mult {
  my $self = shift;
  my @species = @{$self->{'species_defs'}->valid_species};
  my $compara = 3000;
  my @methods = (
    [ 'BLASTZ_NET'           ,'pink',  'cons',  'darkseagreen1', -20  ],
    [ 'BLASTZ_NET_TIGHT'     ,'pink3', 'high cons','darkolivegreen2', -19   ],
    [ 'BLASTZ_GROUP'         ,'pink',  'cons', 'darkseagreen1', -20  ],
    [ 'BLASTZ_GROUP_TIGHT'   ,'pink3', 'high cons','darkolivegreen2', -19   ],
    [ 'PHUSION_BLASTN'       ,'pink',  'cons', 'darkseagreen1', -20  ],
    [ 'PHUSION_BLASTN_TIGHT' ,'pink3', 'high cons','darkolivegreen2', -19   ],
    [ 'BLASTZ_RECIP_NET'     ,'pink',  'cons', 'darkseagreen1', -20  ],
    [ 'TRANSLATED_BLAT'      ,'orchid1', 'trans BLAT','chartreuse', -18 ],
  );

  foreach my $METHOD (@methods) {
    foreach my $SPECIES (@species) {
      (my $species = $SPECIES ) =~ s/_\d+//;
      (my $short = $species ) =~ s/^(\w)\w+_(\w)\w+$/\1\2/g;
      $compara++;
      my $KEY = lc($SPECIES).'_'.lc($METHOD->[0]).'_match';
      $self->{'general'}->{'thjviewbottom'}{$KEY} = {
        'glyphset' => 'generic_alignment',
        'species'  => $species,
        'on'       => 'off',
        'compact'  => 'yes',
        'dep'      => 6,
        'pos'      => $compara+300,
        'col'      => $METHOD->[1],
        'join' => 0,
        'join_col' => $METHOD->[3],
        'join_z'   => $METHOD->[4],
        'str'      => 'f',
        'available'=> "multi ".$METHOD->[0]."|$species",
        'method'   => $METHOD->[0],
        'label'    => "$short $METHOD->[2]",
      };
      push @{ $self->{'general'}->{'thjviewbottom'}{ '_artefacts'} }, $KEY;
    }
  }
}
1;
