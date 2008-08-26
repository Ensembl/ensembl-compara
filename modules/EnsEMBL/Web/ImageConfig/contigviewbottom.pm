package EnsEMBL::Web::ImageConfig::contigviewbottom;
use strict;
no strict 'refs';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self ) = @_;

  $self->set_parameters({
    'title'         => 'Detailed panel',
    'show_buttons'  => 'yes',   # show +/- buttons
    'button_width'  => 8,       # width of red "+/-" buttons
    'show_labels'   => 'yes',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,       # margin
    'spacing'       => 2,       # spacing

## Now let us set some of the optional parameters....
    'opt_halfheight'   => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks' => 0,    # include empty tracks..
    'opt_lines'        => 1,    # draw registry lines
    'opt_restrict_zoom' => 1,   # when we get "zoom" working draw restriction enzyme info on it!!

## Finally some colours... background image colors;
## and alternating colours for tracks...
    'bgcolor'       => 'background1',
    'bgcolour1'     => 'background2',
    'bgcolour2'     => 'background3',
  });

## First add menus in the order you want them for this display....
  $self->create_menus(
    'sequence'        => 'Sequence',
    'marker'          => 'Markers',
    'transcript'      => 'Genes',
    'prediction'      => 'Prediction Transcripts',
    'protein_align'   => 'Protein alignments',
    'dna_align_cdna'  => 'cDNA/mRNA alignments', # Separate menus for different cDNAs/ESTs...
    'dna_align_est'   => 'EST alignments',
    'dna_align_rna'   => 'RNA alignments',
    'dna_align_other' => 'Other DNA alignments', 
    'oligo'           => 'Oligo features',
    'ditag'           => 'Ditag features',
    'simple'          => 'Simple features',
    'misc_feature'    => 'Misc. regions',
    'repeat'          => 'Repeats',
    'variation'       => 'Variaton features',
    'synteny'         => 'Synteny',
    'multiple_align'  => 'Multiple alignments',
    'pairwise_blastz' => 'BLASTZ alignments',
    'pairwise_tblat'  => 'Translated blat alignments',
    'pairwise_other'  => 'Pairwise alignment',
    'user_data'       => 'User uploaded data', # DAS/URL tracks/uploaded data/blast responses
    'other'           => 'Additional decorations',
    'information'     => 'Information',
    'options'         => 'Options'
  );


## Note these tracks get added before the "auto-loaded tracks" get added...
  $self->add_tracks( 'sequence', 
    [ 'contig',    'Contigs',              'stranded_contig', { 'on' => 'on'  } ],
#   [ 'prelim',    'Preliminary release', 'preliminary',      { 'on' => 'off', 'menu' => 'no' } ],
    [ 'seq',       'Sequence',             'seq',             { 'on' => 'off' } ],
    [ 'codon_seq', 'Translated sequence',  'codonseq',        { 'on' => 'off' } ],
    [ 'codons',    'Start/stop codons',    'codons',          { 'on' => 'off' } ],
  );
  $self->add_tracks( 'other', 
    [ 'gc_plot',   '%GC',                  'gcplot',          { 'on' => 'on'  } ],
  );
  
## Add in additional
  $self->load_tracks();

## These tracks get added after the "auto-loaded tracks get addded...
  $self->add_tracks( 'information',
    [ 'mod',       'Message of the day',   'mod',             { 'on' => 'on', 'menu' => 'no' } ],
    [ 'missing',   'Missing data summary', 'missing',         { 'on' => 'on'  } ],
    [ 'info',      'Information',          'info',            { 'on' => 'on'  } ],
  );
  $self->add_tracks( 'other',  
    [ 'scalebar',  'Scale bar',            'scalebar',        { 'on' => 'on'  } ],
    [ 'ruler',     'Ruler',                'ruler',           { 'on' => 'on'  } ],
    [ 'draggable', 'Drag region',          'draggable',       { 'on' => 'on', 'menu' => 'no' } ],
  );

## Finally add details of the options to the options menu...
  $self->add_options(
    [ 'opt_halfheight',    'Half height glyphs?'          ],
    [ 'opt_empty_tracks',  'Show empty tracks?'           ],
    [ 'opt_lines',         'Show registry lines?'         ],
    [ 'opt_restrict_zoom', 'Restriction enzymes on zoom?' ],
  );
}

1;
__END__

      'features' => [
## SNP TRACKS      
         [ 'variation'                => 'SNPs'  ],
         [ 'genotyped_variation_line' => 'Genotyped SNPs'  ],
         [ 'variation_affy100'        => 'Affy 100k SNP'  ],
         [ 'variation_affy500'        => 'Affy 500k SNP'  ],
## REEG TRACKS...
         [ 'histone_modifications'    => 'Histone modifications'  ],
         [ 'fg_regulatory_features'   => 'Regulatory features' ],
         [ 'ctcf'                     => 'CTCF'],
         [ 'regulatory_regions'       => $reg_feat_label  ],
         [ 'regulatory_search_regions'=> 'cisRED search regions'  ],
## ALT ASSEMBLY...
         [ 'alternative_assembly'     => 'Vega assembly' ],
    },

  # col is for colours. Not needed here as overwritten in Glyphset
   'regulatory_regions' => {
      'on'  => "off",
      'pos' => '12',
      'str' => 'b',
      'bump_width' => 0,
      'dep' => 6,
      'available'=> 'database_tables ENSEMBL_FUNCGEN.feature_set', 
    },

   'regulatory_search_regions' => {
      'on'  => "off",
      'pos' => '13',
      'str' => 'b',
      'available'=> 'features REGFEATURES_CISRED',
    },

    'first_ef'   => {
      'on'       => "off",
      'pos'      => '2521',
      'str'      => 'b',
      'col'      => 'red',
      'available'=> 'features FirstEF', 
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
      'key'         => "100K",
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
      'key'         => "500K",
      'glyphset'    => 'variation_affy',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'species Homo_sapiens',  
    }, 

    'histone_modifications' => {
      'on'  => "off",
      'dep' => 0.1,
      'pos' => '4528',
      'str' => 'r',
      'col' => 'blue',
      'compact'  => 0,
      'threshold' => '500',
      'label' => 'Histone modifications',
      'glyphset'    => 'histone_modifications',
      'db_type'    => "funcgen",
      'wiggle_name' => 'tiling array data',
      'block_name' => 'predicted features',
      'available'=> 'species Mus_musculus',  

    }, 

    'fg_regulatory_features' => {
      'on'  => "on",
      'bump_width' => 0,
      'dep' => 6,
      'pos' => '4529',
      'str' => 'r',
      'col' => 'blue',
      'label' => 'FG Reg.features',
      'glyphset'    => 'fg_regulatory_features',
      'db_type'    => "funcgen",
      'colours' => {$self->{'_colourmap'}->colourSet('fg_regulatory_features')},
      'available'=> 'species Homo_sapiens',  
    },

      'ctcf' => {
      'on'  => "off",
      'dep' => 0.1,
      'pos' => '4530',
      'str' => 'r',
      'col' => 'blue',
      'compact'  => 0,
      'threshold' => '500',
      'label' => 'CTCF',
      'glyphset'    => 'ctcf',
      'db_type'    => "funcgen",
      'wiggle_name' => 'tiling array data',
      'block_name' => 'predicted features',
      'available'=> 'species Homo_sapiens',

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
    'draggable' => {
      'on'  => "on",
      'pos' => 8000,
      'col' => 'black'
    },
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
      'on'  => "off",
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
      'on'  => "off",
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

  $self->add_track( 'draggable', 'on'  => "on", 'pos' => 8000);


## Additional tracks... on the forward strand ( top );
  $self->add_track( 'preliminary', 'on' => 'on', 'pos' => 1, 'str' => 'f' );
  $self->add_track( 'mod',         'on' => 'off', 'pos' => 3000200, 'str' => 'f' );
## Additional tracks... on the reverse strand ( bottom );
  $self->add_track( 'info',        'on' => 'on', 'str' => 'r', 'pos' => 3000300, '_menu' => 'options', 'caption' => 'Information track' );
  $self->add_track( 'missing',     'on' => 'on', 'str' => 'r', 'pos' => 3000100 );
  $self->add_track( 'gene_legend', 'on' => 'on', 'str' => 'r', 'pos' => 2000000,  '_menu' => 'options', 'caption' => 'Gene legend' );
  $self->add_track( 'variation_legend',  'on' => 'on', 'str' => 'r', 'pos' => 2000100, '_menu' => 'options', 'caption' => 'SNP legend'  );
  $self->add_track( 'fg_regulatory_features_legend',  'on' => 'on', 'str' => 'r', 'pos' => 2000200, '_menu' => 'options', 'caption' => 'Reg. feats legend'  );

  foreach my $METHOD (@multimethods) {
      $compara++;
      my $KEY = lc($METHOD->[4]).'_match';
      $self->{'general'}->{'contigviewbottom'}{$KEY} = {
        'glyphset' => 'multiple_alignment',
        'species'  => $species,
        'on'       => $METHOD->[7],
        'compact'  => $METHOD->[8],
        'dep'      => 6,
        'pos'      => $compara,
        'col'      => $METHOD->[1],
        'str'      => 'f',
        'axis_colour' => 'blue1',
        'available'=> $METHOD->[5],
   #     'method'   => $METHOD->[0],
	'method_id' => $METHOD->[4],
        'label'    => $METHOD->[2],
        'title'    => $METHOD->[3],
        'threshold' => '1000',
        'db_type'    => "compara",
        'wiggle_name' => 'conservation scores',
        'block_name' => 'constrained elements',
       'bumped'     => 'no',
       'jump_to_alignslice'    => $METHOD->[6],
      };
      push @{ $self->{'general'}->{'contigviewbottom'}{ '_artefacts'} }, $KEY;
      push @{ $self->{'general'}->{'contigviewbottom'}{'_settings'}{'compara'} },  [ $KEY , $METHOD->[3] ];
  }


}
1;
