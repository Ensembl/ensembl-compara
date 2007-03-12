package EnsEMBL::Web::UserConfig::Vega::contigviewbottom;
use strict;
no strict 'refs';
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
use  Bio::EnsEMBL::Registry;
my $reg = "Bio::EnsEMBL::Registry";
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self ) = @_;

  $self->{'_das_offset'} = '5800';

  $self->{'_userdatatype_ID'} = 1;
  $self->{'_add_labels'} = 'yes';
  $self->{'_transcript_names_'} = 'yes';

  $self->{'general'}->{'contigviewbottom'} = {
    '_artefacts' => [
## The following are the extra fugu bits... 
## Only features whose key is in this array gets displayed as a track....
           qw( blast blast_new ssaha ),
           qw( mod preliminary info tp32k assemblyexception annotation_status
             polyA_site polyA_signal pseudo_polyA eucomm rss
             
             repeat_lite snp_lite haplotype 
             refseq_mouse trna   cpg eponine marker operon rnai ex_profile qtl
             first_ef

             ensemblclones alternative_assembly assembly_tag
             matepairs   bacs  bac_bands  tilepath  tilepath2  bacends
             ruler     scalebar  stranded_contig  
             sequence  codonseq  codons gap gcplot    
             encode
             gene_legend missing
             restrict redbox ),

           qw(glovar_snp glovar_haplotype glovar_sts)
          ],
  '_settings' => {
## Image size configuration...
          'width'         => 700,
          'spacing'       => 2,
          'margin'        => 5,
          'label_width'   => 100,
          'button_width'  => 8,
          'show_buttons'  => 'yes',
          'show_labels'   => 'yes',
## Parameters for "zoomed in display"
          'squished_features' => 'yes', 
          'zoom_zoom_gifs'       => {
                       zoom1   =>  25,     zoom2   =>  50,
                       zoom3   =>  100,    zoom4   =>  200,
                       zoom5   =>  300,    zoom6   => 500
                      },
          'show_zoom_contigview' => 'yes',
          'zoom_width' => 100,
          
          'URL'             => '',
          'show_contigview' => 'yes',
          'name'            => qq(ContigView Detailed Window),
          ## Other stuff...
          'clone_based'     => 'no',
          'clone_start'     => '1',
          'clone'           => 1,
          'draw_red_box'    => 'no',
          'default_vc_size' => 100000,
          'main_vc_width'   => 100000,
          'imagemap'        => 1,
          'opt_pdf' => 0, 'opt_svg' => 0, 'opt_postscript' => 0,
          'opt_lines'       => 1,
          'opt_empty_tracks' => 0,
          'opt_daswarn'      => 0,
          'opt_zmenus'       => 1,
          'opt_zclick'       => 1,
          'opt_halfheight'   => 0,
          'opt_shortlabels'  => 1,
          'bgcolor'         => 'background1',
          'bgcolour1'       => 'background2',
          'bgcolour2'       => 'background3',
          'zoom_gifs'       => {
                    zoom1   =>  1000,
                    zoom2   =>  5000,
                    zoom3   =>  10000,
                    zoom4   =>  50000,
                    zoom5   =>  100000,
                    zoom6   =>  200000,
                    zoom7   =>  500000,
                    zoom8   =>  1000000
                     },
          'navigation_options' => [ '2mb', '1mb', 'window', 'half', 'zoom' ],
          'features' => [
                                      # 'name'          => 'caption'       
## TRANSCRIPT STYLE TRACKS ##
## PREDICTION TRACKS ##
## PROTEIN TRACKS ##
## CDNA/MRNA TRACKS ##
## EST TRACKS ##
## OTHER (SIMPLE) FEATURES ##
                 [ 'snp_lite'            => 'SNPs'               ],
                 [ 'glovar_snp'          => 'SNPs'        ],
                 [ 'glovar_sts'          => 'STSs'         ],
                 [ 'glovar_haplotype'    => 'Haplotypes'  ],
                 #[ 'glovar_trace'        => 'Glovar Traces'      ],
                 [ 'trna'                => 'tRNA'               ],
                 [ 'cpg'                 => 'CpG Islands'        ],
                 [ 'eponine'             => 'Eponine Regions'    ],
                 [ 'haplotype'           => 'Haplotypes'         ],
                 [ 'first_ef'        => 'First EF'    ],
                 [ 'marker'              => 'Markers'            ],
                 [ 'qtl'             => 'QTLs'     ],
                 [ 'operon'          => 'Operon'      ],
                 [ 'rnai'            => 'RNAi'        ],
                 [ 'ex_profile'      => 'Exp. profile'    ],
                 [ 'polyA_site'          => 'PolyA sites'        ],
                 [ 'polyA_signal'        => 'PolyA signals'        ],
                 [ 'eucomm'          => 'EUCOMM Critical exons'        ],
				 [ 'rss'             => 'T-Cell RSS Motif.'],
                 [ 'pseudo_polyA'        => 'Pseudo PolyA'        ],
                 [ 'ensemblclones'       => 'Ensembl clones' ],
                 [ 'alternative_assembly'     => 'Ensembl assembly' ],
                 [ 'assembly_tag'        => 'Assembly tags' ],
  

    ## Matches ##
                ],
          'compara' => [ ],
          'options' => [
                # 'name'            => 'caption'
    			[ 'encode'              => 'Encode regions' ],
                [ 'assemblyexception'   => 'Assembly exceptions' ],
                [ 'sequence'            => 'Sequence'           ],
                [ 'codonseq'            => 'Codons'             ],
                [ 'codons'              => 'Start/Stop Codons'  ],
                [ 'stranded_contig'     => 'Contigs'            ],
                [ 'ruler'               => 'Ruler'              ],
                [ 'scalebar'            => 'Scale Bar'          ],
                [ 'tp32k'               => '32K Tilepath'      ],
                [ 'tilepath'            => 'Tilepath'           ],
                [ 'tilepath2'           => 'Acc. Clones'        ],
                [ 'gcplot'              => '%GC'                ],
                [ 'opt_lines'       => 'Show register lines' ],
                [ 'opt_empty_tracks'    => 'Show empty tracks'  ],
                [ 'opt_zmenus'          => 'Show popup menus'   ],
                [ 'opt_zclick'          => '... popup on click' ],
                [ 'opt_halfheight'      => 'Half-height glyphs' ],
                [ 'opt_shortlabels' => 'Concise labels' ],
                [ 'gene_legend'    => 'Gene legend'        ],
                [ 'matepairs'           => 'Matepairs'          ],
                [ 'bacends'         => 'BACends' ],
                [ 'bacs'                => 'BACs'               ],
                [ 'bac_bands'       =>  'BAC band' ],
                [ 'gap'                 => 'Gaps'               ],
                [ 'restrict'            => 'Rest.Enzymes'       ],
                [ 'info'                => 'Information track'  ],
	                 ],
          'menus' => [ qw( features DAS options repeats export jumpto resize )]
         },

## Stranded contig is the central track so should always have pos set to 0...
    'stranded_contig' => {
      'on'  => "on",
      'navigation' => 'on',
      'pos' => '0',
    },

    'redbox' => {
      'on' => 'off',
      'pos' => '1000000',
      'col' => 'red',
    },


## Blast and SSAHA tracks displayed if linked to from Blast/SSAHA...
## These get put beside the central track and so are numbered 5 and 7
    'blast' => {
      'on'  => "off",
      'pos' => '15',
      'col' => 'red',
      'str' => 'b',
    },
    'blast_new' => {
       'on'  => "on",
       'pos' => '17',
       'col' => 'red',
       'str' => 'b',
    },
    'ssaha' => {
      'on'  => "on",
      'pos' => '16',
      'col' => 'red',
      'str' => 'b',
    },

### Now we will follow by the "grouped features" tracks

### Now for the simple features....
    'trna' => {
      'on'  => "off",
      'pos' => '2500',
      'str'     => 'b',
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
    'rss' => {
        'on' => "on",
        'pos' => '1030',
        'str' => 'b',
        'col' => 'darkolivegreen4',
        'label' => 'T-cell RSS motif.',
        'logic_name' => 'rss',
        'glyphset' => 'rss',
        'available' => 'features rss',
    },
    'polyA_site' => {
        'on' => "on",
        'pos' => '1027',
        'str' => 'b',
        'col' => 'red3',
        'label' => 'PolyA site',
        'logic_name' => 'polyA_site',
        'glyphset' => 'polyA',
        'available' => 'features polyA_site',
    },
    'polyA_signal' => {
        'on' => "on",
        'pos' => '1028',
        'str' => 'b',
        'col' => 'red4',
        'label' => 'PolyA signal',
        'logic_name' => 'polyA_signal',
        'glyphset' => 'polyA',
        'available' => 'features polyA_signal',
    },
    'pseudo_polyA' => {
        'on' => "on",
        'pos' => '1029',
        'str' => 'b',
        'col' => 'red2',
        'label' => 'Pseudo PolyA',
        'logic_name' => 'pseudo_polyA',
        'glyphset' => 'polyA',
        'available' => 'features polyA_site',
    },
   'eucomm' => {
        'on' => "on",
        'pos' => '1031',
        'str' => 'b',
        'col' => 'gray33',
        'label' => 'Critical exons',
        'logic_name' => 'EUCOMM',
        'glyphset' => 'eucomm',
        'available' => 'features EUCOMM',
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
      'on'  => "on",
      'pos' => '4100',
      'col' => 'magenta',
      'str' => 'r',
      'colours' => {$self->{'_colourmap'}->colourSet( 'marker' )},
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
      'on'  => "on",
      'pos' => '4510',
      'str' => 'r',
      'col' => 'purple4',
      'available'=> 'features CpG', 
    },

## Repeats 
    'codonseq' => {
      'on'            => "off",
      'pos'           => '4',
      'str'           => 'b',
      'bump_width'     => 0,
      'lab'           => 'black',
      'dep'           => 3,
      'colours'       => {
              # hydrophobic
              'A' => 'darkseagreen1',    # Alanine
              'G' => 'mediumseagreen',    # Glycine
              'I' => 'greenyellow',    # Isoleucine
              'L' => 'olivedrab1',    # Leucine
              'M' => 'green',    # Methionine
              'P' => 'springgreen1',    # Proline
              'V' => 'darkseagreen3',    # Valine
              # large hydrophobic
              'F' => 'paleturquoise',    # Phenylalanine
              'H' => 'darkturquoise',    # Histidine
              'W' => 'skyblue',    # Tryptophan
              'Y' => 'lightskyblue',    # Tyrosine
              # Cysteine
              'C' => 'khaki',    # Cysteine
              # Negative charge
              'D' => 'gold',    # Aspartic Acid
              'E' => 'darkgoldenrod1',    # Glutamic Acid
              # Positive charge
              'K' => 'lightcoral',    # Lysine
              'R' => 'rosybrown',    # Arginine
              # Polar 
              'N' => 'plum2',    # Asparagine
              'Q' => 'thistle1',    # Glutamine
              'S' => 'mediumpurple1',    # Serine
              'T' => 'mediumorchid1',    # Threonine
              # Stop codon...
              '*' => 'red',    # Stop
        },
        'navigation'    => 'on',
        'navigation_threshold' => '0',
        'threshold'     => '0.5',
    }, 

    'assemblyexception' => {
        'on'      => "on",
        'dep'       => 6,
        'pos'       => '9997',
        'str'       => 'x',
        'lab'       => 'black',
        'navigation'  => 'on',
    },

    'sequence' => {
        'on'            => "off",
        'pos'           => '3',
        'str'           => 'b',
        'lab'           => 'black',
        'colours'       => {
            'G' => 'lightgoldenrod1',
            'T' => 'lightpink2',
            'C' => 'lightsteelblue',
            'A' => 'lightgreen',
        },
        'navigation'    => 'on',
        'navigation_threshold' => '0',
        'threshold'     => '0.2',
    }, 
    'repeat_lite' => {
        'on'            => "off",
        'pos'           => '5000',
        'str'           => 'r',
        'col'           => 'gray50',
        'navigation'    => 'on',
        'navigation_threshold' => '2000',
        'threshold'     => '2000',
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
        'on'            => "on",
        'pos'           => '5010',
        'str'           => 'r',
        'col'           => 'gray50',
        'navigation'    => 'on',
        'navigation_threshold' => '2000',
        'threshold'     => '2000',
    }, 

## The measurement decorations        
    'ruler' => {
        'on'            => "on",
        'pos'           => '7000',
        'col'           => 'black',
    },
    'scalebar' => {
        'on'            => "on",
        'pos'           => '7010',
        'col'           => 'black',
        'max_division'  => '12',
        'str'           => 'b',
        'subdivs'       => 'on',
        'abbrev'        => 'on',
        'navigation'    => 'on'
    },

## "Clone" level structural tracks
    'ensemblclones' => {
        'on'      => "off",
        'pos'       => '5',
        'dep'       => '6',
        'str'       => 'f',
        'other'     => 'Ensembl',
        'colours' => {
            'col_older' => 'brown2',
            'col_newer' => 'chartreuse3',
            'col_same'  => 'grey70',
            'lab'       => 'black',
        },
        'dsn'       => 'das_ENSEMBLCLONES',
        'available'     => 'das_source das_ENSEMBLCLONES',
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
    
    'assembly_tag' => {
        'on'        => "off",
        'pos'       => '7',
        'dep'       => '6',
        'str'       => 'b',
        'col'       => 'hotpink2',
        'available' => 'features mapset_assemblytag',
    },
    
    'annotation_status' => {
        'on'      => "on",
        'pos'       => '9998',
        'str'       => 'x',
        'lab'       => 'black',
        'label' => 'Annotation status',
        'navigation'  => 'on',
        'available' => 'features mapset_noannotation',
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
            'col1'      => 'red',
            'col2'      => 'orange',
            'lab1'      => 'black',
            'lab2'      => 'black',
            'bacend'    => 'black',
            'seq_len'   => 'black',
        },
        'str' => 'r',
        'dep' => '9999999',
        'threshold_navigation' => '10000000',
        'outline_threshold'    => '350000'
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
        'fish'          => 'no-fish',
        'col' => 'green',
        'lab' => 'black',
        'available' => 'features mapset_tilepath',
        'colours' => {
            'col1'      => 'red',
            'col2'      => 'orange',
            'lab1'      => 'black',
            'lab2'      => 'black',
        },
        'str' => 'r',
        'dep' => '9999999',
        'threshold_navigation' => '10000000',
        'outline_threshold'    => '350000'
    },
    'matepairs' => {
        'on'            => "off",
        'pos'           => '8025',
        'col'          => 'blue',
        'lab'          => 'black',
        'available'     => 'features mapset_matepairs',
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
        'dep'           => '9999',
        'str'           => 'r',
    },
    'bacs' => {
        'on'            => "off",
        'pos'           => '8026',
        'col'          => 'red',
        'lab'          => 'black',
        'available'     => 'features mapset_bacs',
        'colours'       => {
            'col_unmapped' => 'contigblue1',
            'col_conflict' => 'darkblue',
            'col_consistent' => 'darkgreen',
            'lab_unmapped' => 'white',
            'lab_conflict' => 'white',
            'lab_consistent' => 'white'
        },
        'dep'           => '9999',
        'str'           => 'r',
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
        'on'            => "off",
        'pos'           => '8020',
        'col1'          => 'red',
        'col2'          => 'orange',
        'lab1'          => 'black',
        'lab2'          => 'black',
        'available'     => 'features mapset_gap',
        'str'           => 'r',
    },
    'restrict' => {
        'on'            => "off",
        'pos'           => '5990',
        'lab1'          => 'black',
        'lab2'          => 'black',
        'str'           => 'r',
        'threshold'     => 2 
    },

## DAS-based data for manually annotated clones from Vega        
    'assembly_contig' => {
        'on'            => "on",
        'pos'           => '8030',
        'colours'       => {
            'col1'          => 'contigblue1',
            'col2'          => 'contigblue2',
            'lab1'          => 'white',
            'lab2'          => 'white',
        },
        'str'           => 'r',
        'dep'           => '0',
        'available'     => 'features mapset_assembly', 
    },

## And finally the GC plot track        
    'gcplot'  => {
        'on'            => "off",
        'pos'           => '9010',
        'str'           => 'r',
        'col'           => 'gray50',
        'line'          => 'red',
        'hi'            => 'black',
        'low'           => 'black',
    },

## and legend....
    'gene_legend' => {
        'on'      => "on",
        'str'     => 'r',
        'pos'       => '9999',
        'databases' => 'vega',
    },
    'missing' => {
        'on'            => "on",
        'str'           => 'r',
        'pos'           => '10001',
    },
    'info' => {
        'on'      => "off",
        'str'       => 'r',
        'pos'       => '10003',
    },
    'mod' => {
        'on'            => "on",
        'str'           => 'f',
        'pos'           => '10002',
    },
    'preliminary' => {
        'on'            => "on",
        'str'           => 'f',
        'pos'           => '1',
    },

  };

  my $POS = $self->ADD_ALL_TRANSCRIPTS();
  ## Loop through registry for additional transcript tracks...
  $reg->add_new_tracks($self,$POS);
  $self->ADD_ALL_PREDICTIONTRANSCRIPTS();
  $self->ADD_ALL_PROTEIN_FEATURES();
  $self->ADD_ALL_DNA_FEATURES();
  $self->ADD_ALL_EST_FEATURES();

  ## And finally the multispecies tracks....
  my @species = @{$self->{'species_defs'}->ENSEMBL_SPECIES};
  my $compara = 3000;
  my @methods = (
         [ 'BLASTZ_RAW'           ,'pink',  'cons bz' ],
         [ 'BLASTZ_CHAIN'         ,'pink',  'cons bz chain' ],
        );
  foreach my $METHOD (@methods) {
    foreach my $SPECIES (@species) {
      (my $species = $SPECIES ) =~ s/_\d+//;
      (my $short = $species ) =~ s/^(\w)\w+_(\w)\w+$/\1\2/g;
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
                              'label'    => "$short $METHOD->[2]",
                               };
      push @{ $self->{'general'}->{'contigviewbottom'}{ '_artefacts'} }, $KEY;
      push @{ $self->{'general'}->{'contigviewbottom'}{'_settings'}{'compara'} },  [ $KEY , "$short $METHOD->[2]" ];
    }
  }
}


1;
